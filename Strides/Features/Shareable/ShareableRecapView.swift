//
//  ShareableRecapView.swift
//  Strides
//

import SwiftUI
import MapKit

struct ShareableRecapView: View {
    let run: CompletedRun
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            // High-resolution render target (9:16 aspect ratio canvas)
            ShareableRecapCard(run: run)
                .frame(width: 324, height: 576) // Scaled 1080x1920 preview
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .shadow(color: .black.opacity(0.6), radius: 20)

            ShareLink(
                item: Image(uiImage: generateImage()),
                preview: SharePreview("Mission Recap", image: Image(uiImage: generateImage()))
            ) {
                Label("SHARE TELEMETRY CARD", systemImage: "square.and.arrow.up")
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(StridesPalette.voltageOrange)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
        }
        .padding()
        .background(StridesPalette.canvas.ignoresSafeArea())
    }

    @MainActor
    private func generateImage() -> UIImage {
        let renderer = ImageRenderer(content: ShareableRecapCard(run: run).frame(width: 1080, height: 1920))
        renderer.scale = 1.0
        return renderer.uiImage ?? UIImage()
    }
}

struct ShareableRecapCard: View {
    let run: CompletedRun

    var body: some View {
        ZStack {
            StridesPalette.canvas

            VStack(alignment: .leading, spacing: 28) {
                // Header Badge
                HStack {
                    Text("STRIDES // TELEMETRY")
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)
                    Spacer()
                    if run.isPersonalBest {
                        Text("PB")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(StridesPalette.voltageOrange)
                            .clipShape(Capsule())
                    }
                }

                // Center Trajectory Visual
                ZStack {
                    RoundedRectangle(cornerRadius: 32)
                        .fill(StridesPalette.surface)

                    // Stylized Polyline Canvas
                    Canvas { context, size in
                        guard run.trajectory.count > 1 else { return }
                        let minLat = run.trajectory.map(\.latitude).min() ?? 0
                        let maxLat = run.trajectory.map(\.latitude).max() ?? 1
                        let minLon = run.trajectory.map(\.longitude).min() ?? 0
                        let maxLon = run.trajectory.map(\.longitude).max() ?? 1

                        let latSpan = max(maxLat - minLat, 0.0001)
                        let lonSpan = max(maxLon - minLon, 0.0001)

                        var path = Path()
                        for (idx, point) in run.trajectory.enumerated() {
                            let x = (point.longitude - minLon) / lonSpan * (size.width - 60) + 30
                            let y = (1.0 - (point.latitude - minLat) / latSpan) * (size.height - 60) + 30
                            if idx == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                        context.stroke(path, with: .color(StridesPalette.voltageOrange), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                    }
                }
                .frame(maxHeight: .infinity)

                // Large Numerics
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("DISTANCE")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            Text(String(format: "%.2f KM", run.totalDistanceMeters / 1000.0))
                                .font(.system(size: 54, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        Spacer()
                    }

                    HStack(spacing: 40) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("PACE")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            Text(run.avgPaceFormatted)
                                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                                .foregroundColor(StridesPalette.voltageOrange)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("TIME")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.gray)
                            Text(formatDuration(run.durationSeconds))
                                .font(.system(size: 38, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
