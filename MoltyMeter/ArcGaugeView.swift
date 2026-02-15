import SwiftUI

struct ArcGaugeView: View {
    let progress: Double  // 0.0 to 1.0
    let healthState: SessionHealthState

    private let arcLineWidth: CGFloat = 12
    private let startAngle: Double = 180
    private let sweepAngle: Double = 180

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let radius = (width / 2) - arcLineWidth - 8
            // Arc center at bottom-center of the frame
            let center = CGPoint(x: width / 2, y: height - 4)

            ZStack {
                // Background track
                ArcShape(startAngle: startAngle, sweepAngle: sweepAngle)
                    .stroke(
                        Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)

                // Gradient arc fill
                ArcShape(startAngle: startAngle, sweepAngle: sweepAngle)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0xBB/255.0, green: 0xBB/255.0, blue: 0xBB/255.0), .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: arcLineWidth, lineCap: .round)
                    )
                    .frame(width: radius * 2, height: radius * 2)
                    .position(center)
                    .mask(
                        ArcShape(startAngle: startAngle, sweepAngle: sweepAngle * max(0.01, progress))
                            .stroke(Color.white, style: StrokeStyle(lineWidth: arcLineWidth + 4, lineCap: .round))
                            .frame(width: radius * 2, height: radius * 2)
                            .position(center)
                    )

                // Lobster — centered on the arc's center point, rotates around it
                let rotation = -90.0 + (progress * 180.0) // -90° (left) → +90° (right)
                Text("🦞")
                    .font(.system(size: 48))
                    .rotationEffect(.degrees(rotation))
                    .position(center)
                    .offset(y: -4)
                    .animation(.easeInOut(duration: 0.6), value: progress)
            }
        }
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
