import Foundation
import HealthKit

/// Real HealthKit for the push side: the iOS permission sheet, and each check saved to Health as a clinical
/// document (CDA). Health has no native type for these eye biomarkers, so the document carries them as a table.
/// Reading from Health (sleep, heart rate, workouts) is HealthReader.
enum HealthBridge {
    static let store = HKHealthStore()

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    static var document: HKDocumentType { HKObjectType.documentType(forIdentifier: .CDA)! }

    static var readTypes: Set<HKObjectType> {
        [HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
         HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
         HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
         HKObjectType.workoutType()]
    }

    static var canWrite: Bool { isAvailable && store.authorizationStatus(for: document) == .sharingAuthorized }

    /// Shows the iOS Health permission sheet for what the person chose to share.
    static func requestAccess(write: Bool, read: Bool) async {
        guard isAvailable else { return }
        let share: Set<HKSampleType> = write ? [document] : []
        let readSet: Set<HKObjectType> = read ? readTypes : []
        try? await store.requestAuthorization(toShare: share, read: readSet)
    }

    struct Row {
        let name: String
        let code: String
        let today: String
        let baseline: String
        let threshold: String
        let status: String
    }

    /// Saves one check as a clinical document. Throws if HealthKit rejects the document or writing isn't allowed.
    static func saveCheck(title: String, athlete: Athlete, rows: [Row], decision: String) async throws {
        let now = Date()
        let xml = cda(title: title, athlete: athlete, rows: rows, decision: decision, at: now)
        let sample = try HKCDADocumentSample(data: Data(xml.utf8), start: now, end: now, metadata: nil)
        try await store.save(sample)
    }

    // MARK: CDA

    private static func cda(title: String, athlete: Athlete, rows: [Row], decision: String, at date: Date) -> String {
        let stamp: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyyMMddHHmmssZ"
            return f.string(from: date)
        }()
        let parts = athlete.name.split(separator: " ", maxSplits: 1).map(String.init)
        let given = esc(parts.first ?? athlete.name)
        let family = esc(parts.count > 1 ? parts[1] : "")
        let body = rows.map { r in
            "<tr><td>\(esc(r.name))</td><td>\(esc(r.code))</td><td>\(esc(r.today))</td><td>\(esc(r.baseline))</td><td>\(esc(r.threshold))</td><td>\(esc(r.status))</td></tr>"
        }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <ClinicalDocument xmlns="urn:hl7-org:v3">
          <realmCode code="US"/>
          <typeId root="2.16.840.1.113883.1.3" extension="POCD_HD000040"/>
          <templateId root="2.16.840.1.113883.10.20.22.1.1"/>
          <id root="\(UUID().uuidString)"/>
          <code code="11506-3" codeSystem="2.16.840.1.113883.6.1" displayName="Progress note"/>
          <title>\(esc(title))</title>
          <effectiveTime value="\(stamp)"/>
          <confidentialityCode code="N" codeSystem="2.16.840.1.113883.5.25"/>
          <languageCode code="en-US"/>
          <recordTarget>
            <patientRole>
              <id root="2.16.840.1.113883.19.5" extension="\(athlete.id)"/>
              <patient><name><given>\(given)</given><family>\(family)</family></name></patient>
            </patientRole>
          </recordTarget>
          <author>
            <time value="\(stamp)"/>
            <assignedAuthor>
              <id root="2.16.840.1.113883.19.5"/>
              <assignedPerson><name>Sideline concussion screen</name></assignedPerson>
            </assignedAuthor>
          </author>
          <custodian>
            <assignedCustodian>
              <representedCustodianOrganization>
                <id root="2.16.840.1.113883.19.5"/>
                <name>Sideline</name>
              </representedCustodianOrganization>
            </assignedCustodian>
          </custodian>
          <component>
            <structuredBody>
              <component>
                <section>
                  <title>Biomarkers</title>
                  <text>
                    <table border="1">
                      <thead><tr><th>Biomarker</th><th>Code</th><th>Today</th><th>Baseline</th><th>Threshold</th><th>Status</th></tr></thead>
                      <tbody>\(body)</tbody>
                    </table>
                  </text>
                </section>
              </component>
              <component>
                <section>
                  <title>Result</title>
                  <text><paragraph>\(esc(decision))</paragraph><paragraph>Measured by the phone camera against the OculoDx catalog thresholds and this athlete's own baseline. Sideline does not diagnose concussion; a licensed provider decides return to play.</paragraph></text>
                </section>
              </component>
            </structuredBody>
          </component>
        </ClinicalDocument>
        """
    }

    private static func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
