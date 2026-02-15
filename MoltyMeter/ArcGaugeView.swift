import SwiftUI

struct ArcGaugeView: View {
    let sessionProgress: Double  // 0.0 to 1.0 (session context)
    let budgetProgress: Double  // 0.0 to 1.0 (monthly budget spent)
    let healthState: SessionHealthState

    private let arcLineWidth: CGFloat = 10
    private let startAngle: Double = 180
    private let sweepAngle: Double = 180

    private let tickColor = Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0)
    private let fillColor = Color(red: 0xDD/255.0, green: 0xDD/255.0, blue: 0xDD/255.0)

    // Budget remaining (inverted: 100% spent = empty, 0% spent = full)
    private var budgetRemaining: Double { 1.0 - min(budgetProgress, 1.0) }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let radius = (width / 2) - arcLineWidth
            // Arc center - moved up 10px more
            let center = CGPoint(x: (width / 2) - 2, y: height + 1)  // Right 8px, down 5px

            ZStack {
                // Molty at center of arc - rotates to face session level
                let lobsterRotation = -92.0 + (sessionProgress * 180.0)  // -2 deg offset
                Text("🦞")
                    .font(.system(size: 54))
                    .rotationEffect(.degrees(lobsterRotation))
                    .animation(.easeInOut(duration: 0.6), value: sessionProgress)
                    .position(x: center.x, y: center.y - 15)  // Moved up toward arc edge

                // Background track
                ArcShape(startAngle: startAngle, sweepAngle: sweepAngle)
                    .stroke(
                        Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Session arc fill (shows context usage)
                ArcShape(startAngle: startAngle, sweepAngle: sweepAngle)
                    .stroke(
                        fillColor,
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .mask(
                        ArcShape(startAngle: startAngle, sweepAngle: sweepAngle * max(0.01, sessionProgress))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: arcLineWidth + 4, lineCap: .round))
                            .frame(width: radius * 2, height: radius * 2)
                            .position(center)
                    )


            }
        }
    }
}

/// Battery-style circular gauge (like iOS battery widget)
struct BatteryGaugeView: View {
    let progress: Double  // 0.0 to 1.0 (amount remaining)
    let size: CGFloat

    private let trackColor = Color.white.opacity(0.15)
    private let fillColor = Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0)  // #BBBBBB

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(trackColor, lineWidth: size / 6)

            // Fill ring (clockwise from top)
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(fillColor, style: StrokeStyle(lineWidth: size / 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Dollar sign in center
            Text("$")
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundColor(.white)  // #FFFFFF
        }
        .frame(width: size, height: size)
    }
}

/// Needle shape - pointed at top
struct NeedleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        path.move(to: CGPoint(x: midX, y: 0))  // tip
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

struct ArcShape: Shape {
    let startAngle: Double
    let sweepAngle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let start = Angle(degrees: -startAngle)
        let end = Angle(degrees: -(startAngle - sweepAngle))
        path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        return path
    }
}
