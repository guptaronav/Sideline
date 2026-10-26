import SwiftUI

/// Welcome / sign-in. Full-bleed brand screen, sign-in options in the thumb zone, legal line below.
/// Demo switching is hidden: long-press the logo to pick who Apple/Google sign in as;
/// email sign-in accepts any password, and an unknown email falls back to that same account.
struct RoleGateView: View {
    @Environment(Session.self) private var session
    @State private var showEmail = false
    @State private var showPicker = false
    @State private var legal: LegalDoc?
    @State private var showRegister = false

    @Environment(\.horizontalSizeClass) private var hSize

    var body: some View {
        Group {
            if hSize == .regular { regularLayout } else { compactLayout }
        }
        .sheet(isPresented: $showEmail) { EmailSignInView().preferredColorScheme(.light) }
        .fullScreenCover(isPresented: $showRegister) { RegistrationView().preferredColorScheme(.light) }
        .sheet(item: $legal) { LegalView(doc: $0).preferredColorScheme(.light) }
        .sheet(isPresented: $showPicker) { presenterPicker.preferredColorScheme(.light) }
    }

    // MARK: iPhone: full-bleed brand screen, buttons in the thumb zone

    private var compactLayout: some View {
        ZStack {
            Palette.brand.ignoresSafeArea()
            // Respect the side safe area like Apple's own apps on iPhone Duo: content stops at the camera strip.
            SignInArtwork(compact: true).ignoresSafeArea(edges: [.top, .bottom])
            VStack(alignment: .leading, spacing: 0) {
                logo.padding(.top, 24)
                Spacer()
                headline(size: 40)
                VStack(spacing: 12) {
                    appleButton(onDark: true)
                    googleButton(onDark: true)
                    emailButton(onDark: true)
                }
                .padding(.top, 36)
                createAccount(onDark: true).padding(.top, 18)
                legalFooter(onDark: true).padding(.top, 14)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 16)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: iPad: brand panel left, sign-in panel right

    private var regularLayout: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                Palette.brand
                SignInArtwork()
                VStack(alignment: .leading, spacing: 0) {
                    logo
                    Spacer()
                    headline(size: 56)
                    VStack(alignment: .leading, spacing: 16) {
                        point("timer", "A 2-minute sideline check", "Eye and pupil tests on the phone's camera, right after a hit.")
                        point("waveform.path.ecg", "Biomarkers, not guesswork", "Each result is measured against thresholds and the athlete's own baseline.")
                        point("stethoscope", "Clinician sign-off on record", "Return to play stays with a licensed provider, with the full history.")
                    }
                    .padding(.top, 40)
                }
                .padding(56)
            }
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                Text("Sign in to Sideline").font(.system(size: 34, weight: .bold)).foregroundStyle(Palette.ink)
                Text("Coaches, athletes and healthcare providers use the same account.")
                    .font(.system(size: 17)).foregroundStyle(Palette.muted)
                    .padding(.top, 8)
                VStack(spacing: 12) {
                    appleButton(onDark: false)
                    googleButton(onDark: false)
                    emailButton(onDark: false)
                }
                .padding(.top, 32)
                createAccount(onDark: false).padding(.top, 20)
                Spacer()
                legalFooter(onDark: false).padding(.bottom, 24)
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 48)
            .frame(maxWidth: .infinity)
            .background(Palette.paper)
        }
        // One status bar spans navy and white halves, so no single text color reads on both. Hide it here.
        .statusBarHidden(true)
        .preferredColorScheme(.light)
    }

    // MARK: Pieces

    private var logo: some View {
        SidelineLockup(size: 32, color: Palette.brandInk)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.8) { showPicker = true }
    }

    private func headline(size: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Spot it early.\nCome back right.")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(Palette.brandInk)
                .lineSpacing(2)
                // Two lines always; shrinks on narrower brand panels (unfolded iPhone Duo) instead of truncating.
                .lineLimit(2)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            Text("Concussion checks and comeback plans for your team, from your phone's camera.")
                .font(.system(size: size > 50 ? 20 : 17))
                .foregroundStyle(Palette.brandMuted)
        }
    }

    private func point(_ symbol: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Palette.brandInk)
                .frame(width: 40, height: 40)
                .background(Palette.brandRaised, in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.brandInk)
                Text(detail).font(.system(size: 15)).foregroundStyle(Palette.brandMuted)
            }
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    // Apple HIG: white style on dark backgrounds, black style on light backgrounds.
    private func appleButton(onDark: Bool) -> some View {
        Button { session.account = session.appleAccount } label: {
            HStack(spacing: 8) {
                Image(systemName: "apple.logo").font(.system(size: 19, weight: .medium))
                Text("Continue with Apple").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(onDark ? Color.black : Color.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(onDark ? Color.white : Color.black, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // Google Identity branding: dark (#131314 / #8E918F / #E3E3E3) or light (#FFFFFF / #747775 / #1F1F1F).
    private func googleButton(onDark: Bool) -> some View {
        Button { session.account = session.appleAccount } label: {
            HStack(spacing: 10) {
                Image("GoogleG").resizable().frame(width: 20, height: 20)
                Text("Continue with Google").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(Color(hex: onDark ? 0xE3E3E3 : 0x1F1F1F))
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color(hex: onDark ? 0x131314 : 0xFFFFFF), in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: onDark ? 0x8E918F : 0x747775), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func emailButton(onDark: Bool) -> some View {
        Button { showEmail = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "envelope.fill").font(.system(size: 16, weight: .semibold))
                Text("Continue with email").font(.system(size: 17, weight: .semibold))
            }
            .foregroundStyle(onDark ? Palette.brandInk : Palette.ink)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(onDark ? Color.clear : Palette.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(onDark ? Color.white.opacity(0.35) : Color.clear, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func createAccount(onDark: Bool) -> some View {
        Button { showRegister = true } label: {
            (Text("New to Sideline? ").foregroundStyle(onDark ? Palette.brandMuted : Palette.muted)
             + Text("Create an account").foregroundStyle(onDark ? Palette.brandInk : Palette.steady).bold())
                .font(.system(size: 15))
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    private func legalFooter(onDark: Bool) -> some View {
        Text(LegalDoc.footer(linkColor: onDark ? .white : Palette.ink))
            .font(.system(size: 13))
            .foregroundStyle(onDark ? Palette.brandMuted : Palette.muted)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .environment(\.openURL, OpenURLAction { url in
                legal = LegalDoc(rawValue: url.host() ?? "")
                return .handled
            })
    }

    /// Presenter-only: who Apple/Google sign in as.
    private var presenterPicker: some View {
        NavigationStack {
            List(DemoAccount.allCases) { account in
                Button {
                    session.appleAccount = account
                    showPicker = false
                } label: {
                    HStack(spacing: 12) {
                        PhotoPlaceholder(size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name).foregroundStyle(Palette.ink)
                            Text(account.email).font(Typeface.caption).foregroundStyle(Palette.muted)
                        }
                        Spacer()
                        if session.appleAccount == account {
                            Image(systemName: Icon.check).foregroundStyle(Palette.steady)
                        }
                    }
                }
            }
            .navigationTitle("Sign in as")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

/// Field lines and an athlete silhouette behind the welcome text. Flat, no gradients.
private struct SignInArtwork: View {
    /// Phones: runner only, small, in the empty band beside the logo so it never sits behind text.
    /// A full-height sideline reads as a divider next to a side camera strip (iPhone Duo).
    var compact = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            if compact {
                Image(systemName: "figure.run")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.07))
                    .frame(height: h * 0.16)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, w * 0.04)
                    .offset(y: h * 0.1)
            } else {
            ZStack(alignment: .topTrailing) {
                Canvas { ctx, _ in
                    var lines = Path()
                    let x = w * 0.93
                    lines.move(to: CGPoint(x: x, y: 0)); lines.addLine(to: CGPoint(x: x, y: h))
                    var y: CGFloat = 20
                    var i = 0
                    while y < h {
                        let len: CGFloat = i % 5 == 0 ? 34 : 16
                        lines.move(to: CGPoint(x: x - len, y: y)); lines.addLine(to: CGPoint(x: x, y: y))
                        y += 22; i += 1
                    }
                    ctx.stroke(lines, with: .color(.white.opacity(0.07)), lineWidth: 2)
                }
                Image(systemName: "figure.run")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color.white.opacity(0.07))
                    .frame(height: h * 0.42)
                    .offset(x: w * 0.08, y: h * 0.08)
            }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Email sign-in, on its own screen as in real apps.
private struct EmailSignInView: View {
    @Environment(Session.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?
    private enum Field { case email, password }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text("Sign in with email").font(.system(size: 28, weight: .bold)).foregroundStyle(Palette.ink)
                    .padding(.bottom, 8)
                field("envelope") {
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                field("lock") {
                    SecureField("Password", text: $password)
                        .textContentType(.oneTimeCode)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(signIn)
                }
                Button("Sign in", action: signIn).buttonStyle(SolidButton(tint: Palette.steady))
                    .padding(.top, 8)
                Button("Forgot password?") {}
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.steady)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                Spacer()
            }
            .padding(24)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { focus = .email }
        }
    }

    private func field<Content: View>(_ icon: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.muted).frame(width: 20)
            content().font(.system(size: 17))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .background(Palette.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func signIn() {
        let typed = email.trimmingCharacters(in: .whitespaces).lowercased()
        // Demo: any password works; an unknown email signs in as the presenter's default account.
        session.account = DemoAccount.allCases.first(where: { $0.email == typed }) ?? session.appleAccount
        dismiss()
    }
}

enum LegalDoc: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }

    static func footer(linkColor: Color) -> AttributedString {
        var text = (try? AttributedString(markdown: "By continuing, you agree to Sideline's [Terms of Service](sideline://terms) and [Privacy Policy](sideline://privacy).")) ?? AttributedString("")
        for run in text.runs where run.link != nil {
            text[run.range].underlineStyle = .single
            text[run.range].foregroundColor = linkColor
        }
        return text
    }

    var title: String { self == .terms ? "Terms of Service" : "Privacy Policy" }

    var sections: [(String, String)] {
        switch self {
        case .terms: [
            ("What Sideline is", "Sideline helps coaches, athletes and healthcare providers notice possible concussion signs and follow a graduated return to sport. It does not diagnose concussion and does not clear anyone to play."),
            ("Medical decisions", "Only a licensed healthcare provider can evaluate an athlete or approve a return to play. Call emergency services if an athlete shows danger signs."),
            ("Accounts", "Coaches manage their teams. Athletes under 18 need a parent or guardian's consent."),
        ]
        case .privacy: [
            ("What we collect", "Eye and pupil measurements from the camera during a check, your team, and your recovery steps. Camera images are processed on the device."),
            ("Who sees it", "You, your coach (status and practice limits only), and the healthcare provider you share your report with."),
            ("Minors", "We collect data from athletes under 18 only with a parent or guardian's consent."),
        ]
        }
    }
}

struct LegalView: View {
    let doc: LegalDoc
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Last updated October 2026").font(Typeface.caption).foregroundStyle(Palette.muted)
                    ForEach(doc.sections, id: \.0) { section in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(section.0).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                            Text(section.1).font(Typeface.body).foregroundStyle(Palette.ink)
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle(doc.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
