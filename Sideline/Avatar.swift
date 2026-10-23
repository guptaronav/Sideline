import SwiftUI

/// Per-person styling data (backdrop tint, kit). Photos come from the asset catalog.
struct AvatarLook: Equatable {
    enum Hair: Equatable { case short, buzz, long, bun, ponytail, afro, curly }
    enum Kit: Equatable { case gi(belt: UInt32), jersey(number: Int, color: UInt32, trim: UInt32), polo(color: UInt32) }

    var skin: UInt32
    var hair: Hair
    var hairColor: UInt32
    var kit: Kit
    var backdrop: UInt32

    static let `default` = AvatarLook(skin: 0xC98E62, hair: .short, hairColor: 0x1E1A1A, kit: .polo(color: 0x0A0A0B), backdrop: 0xE8EBF5)
}

enum Belt {
    static let white: UInt32 = 0xF4F4F0, grey: UInt32 = 0x9AA0A6, yellow: UInt32 = 0xF2D21B
    static let orange: UInt32 = 0xF28C28, green: UInt32 = 0x22A35A, black: UInt32 = 0x111111
}

/// Shown until a person uploads a photo: a neutral silhouette, like iOS Contacts.
struct PhotoPlaceholder: View {
    var size: CGFloat = 44
    var square = false

    var body: some View {
        ZStack {
            Palette.rule
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(Palette.paper.opacity(0.95))
                .frame(width: size * 0.62)
                .offset(y: size * 0.12)
        }
        .frame(width: size, height: size)
        .clipShape(square ? AnyShape(RoundedRectangle(cornerRadius: 16)) : AnyShape(Circle()))
        .accessibilityLabel("No photo yet")
    }
}

/// Team header with the sport's own line art behind it: the cage for Ridgeline Academy, the court for Chesapeake State.
struct TeamBackdrop: View {
    let team: Team?

    var body: some View {
        Canvas { ctx, sz in
            let w = sz.width, h = sz.height
            let line = GraphicsContext.Shading.color(.white.opacity(0.22))
            switch team {
            case .ridgeline:
                // octagon cage and the mat's center circle
                let cx = w * 0.78, cy = h * 0.55, rad = h * 0.75
                var oct = Path()
                for i in 0..<8 {
                    let a = Double(i) * .pi / 4 + .pi / 8
                    let p = CGPoint(x: cx + rad * cos(a), y: cy + rad * sin(a))
                    i == 0 ? oct.move(to: p) : oct.addLine(to: p)
                }
                oct.closeSubpath()
                ctx.stroke(oct, with: line, lineWidth: 3)
                ctx.stroke(Path(ellipseIn: CGRect(x: cx - rad * 0.38, y: cy - rad * 0.38, width: rad * 0.76, height: rad * 0.76)), with: line, lineWidth: 2)
                var mesh = Path()
                var x = -h
                while x < w { mesh.move(to: CGPoint(x: x, y: h)); mesh.addLine(to: CGPoint(x: x + h, y: 0)); x += 14 }
                ctx.stroke(mesh, with: .color(.white.opacity(0.05)), lineWidth: 1)
            case .chesapeake:
                // half court: key, free-throw circle, three-point arc
                let base = w * 0.98
                let lane = CGRect(x: base - w * 0.34, y: h * 0.3, width: w * 0.34, height: h * 0.4)
                ctx.stroke(Path(lane), with: line, lineWidth: 2.5)
                ctx.stroke(Path(ellipseIn: CGRect(x: lane.minX - h * 0.2, y: h * 0.3, width: h * 0.4, height: h * 0.4)), with: line, lineWidth: 2.5)
                var arc = Path()
                arc.addArc(center: CGPoint(x: base, y: h * 0.5), radius: w * 0.55, startAngle: .degrees(110), endAngle: .degrees(250), clockwise: false)
                ctx.stroke(arc, with: line, lineWidth: 2.5)
                ctx.stroke(Path(ellipseIn: CGRect(x: base - 10, y: h * 0.5 - 6, width: 12, height: 12)), with: line, lineWidth: 2)
            case nil:
                // a sideline with yard marks
                var p = Path()
                p.move(to: CGPoint(x: w * 0.72, y: 0)); p.addLine(to: CGPoint(x: w * 0.72, y: h))
                var y: CGFloat = 8
                while y < h { p.move(to: CGPoint(x: w * 0.72, y: y)); p.addLine(to: CGPoint(x: w * 0.72 + 16, y: y)); y += 18 }
                ctx.stroke(p, with: line, lineWidth: 3)
            }
        }
        .background(team?.color ?? Palette.steady)
        .overlay(alignment: .bottomTrailing) {
            // the sport's athlete silhouette, cropped at the card's edge
            Image(systemName: team?.figure ?? "figure.run")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.16))
                .frame(height: 170)
                .offset(x: 18, y: 26)
        }
        .clipped()
    }
}

extension Team {
    var color: Color { self == .ridgeline ? Color(hex: 0x0E6E6A) : Color(hex: 0x13294B) }
    var accent: UInt32 { self == .ridgeline ? 0x7FE3C9 : 0xF2A900 }
    /// SF Symbols athlete silhouette for the team's sport.
    var figure: String { self == .ridgeline ? "figure.martial.arts" : "figure.basketball" }
}

/// A rounded team hero card: sport artwork behind a title.
struct TeamHero<Content: View>: View {
    let team: Team?
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(TeamBackdrop(team: team))
            .clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

/// A player's picture: the photo in the asset catalog ("photo-<first name>"), or a placeholder until one is uploaded.
struct PlayerPhoto: View {
    let athlete: Athlete
    var size: CGFloat = 44
    var square = false
    @Environment(Session.self) private var session

    var body: some View {
        Group {
            // The signed-in athlete's own uploaded photo wins over the bundled one.
            if session.athleteID == athlete.id, session.role == .athlete, let data = session.photo, let ui = UIImage(data: data) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else if let ui = UIImage(named: photoName(athlete.name)) {
                Image(uiImage: ui).resizable().scaledToFill()
            } else {
                PhotoPlaceholder(size: size, square: square)
            }
        }
        .frame(width: size, height: size)
        .clipShape(square ? AnyShape(RoundedRectangle(cornerRadius: 16)) : AnyShape(Circle()))
    }
}

/// Asset name for a person's bundled photo: "photo-" + first name, lowercased, accents and titles dropped.
/// "Tomás Herrera" → photo-tomas, "Dr. Tom Okafor" → photo-tom.
func photoName(_ fullName: String) -> String {
    let first = fullName.split(separator: " ").first { !$0.hasSuffix(".") } ?? ""
    return "photo-" + first.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .init(identifier: "en_US")).lowercased()
}
