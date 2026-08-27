//
//  RunRecapCard.swift
//  Strides
//
//  Features/Shareable — 1-tap exportable recap card for Instagram Stories.
//  Renders an Instagram-Story-sized (1080×1920) telemetry card off-screen with
//  `ImageRenderer`, then hands back a UIImage ready for ShareLink / activity sheet.
//

import SwiftUI

/// Immutable summary of a finished run, used to populate the recap card.
struct RunSummary {
    let distanceKm: Double
    let durationSeconds: TimeInterval
    let avgPaceFormatted: String   // e.g. "5'12\""
    let avgCadenceSPM: Int
    let elevationGainMeters: Double
    let dateLabel: String          // e.g. "AUG 19, 2026"

    var durationFormatted: String {
        let h = Int(durationSeconds) / 3600
        let m = (Int(durationSeconds) % 3600) / 60
        let s = Int(durationSeconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    static let placeholder = RunSummary(
        distanceKm: 8.42,
        durationSeconds: 2712,
        avgPaceFormatted: "5'22\"",
        avgCadenceSPM: 178,
        elevationGainMeters: 96,
        dateLabel: "AUG 19, 2026"
    )
}

/// The visual card. Designed at Instagram Story aspect (9:16). All sizes are
/// authored for a 1080×1920 canvas; `RunRecapRenderer` scales to that resolution.
struct RunRecapCardView: View {
    let summary: RunSummary

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "09090B"), Color(hex: "121216")],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    Text("STRIDES")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(4)
                    Spacer()
                    Text(summary.dateLabel)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.gray)
                }

                Spacer()

                // Hero: distance
                Text("DISTANCE")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(3)
                HStack(alignment: .lastTextBaseline, spacing: 12) {
                    Text(String(format: "%.2f", summary.distanceKm))
                        .font(.system(size: 140, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "FF5500"))
                        .shadow(color: Color(hex: "FF5500").opacity(0.4), radius: 30)
                    Text("KM")
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .foregroundColor(.white)
                }

                Spacer()

                // Stat grid
                HStack(spacing: 20) {
                    recapStat("TIME", summary.durationFormatted, tint: .white)
                    recapStat("AVG PACE", summary.avgPaceFormatted, tint: Color(hex: "00F0FF"))
                }
                HStack(spacing: 20) {
                    recapStat("CADENCE", "\(summary.avgCadenceSPM) SPM", tint: .white)
                    recapStat("ELEV GAIN", "\(Int(summary.elevationGainMeters)) M", tint: Color(hex: "00F0FF"))
                }
                .padding(.top, 20)

                Spacer()

                // Footer
                Text("TELEMETRY-FIRST RUNNING")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .tracking(2)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(70)
        }
        .frame(width: 1080, height: 1920)
    }

    private func recapStat(_ title: String, _ value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.gray)
                .tracking(2)
            Text(value)
                .font(.system(size: 52, weight: .bold, design: .monospaced))
                .foregroundColor(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(28)
        .background(Color(hex: "1C1C22"))
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}

/// Renders `RunRecapCardView` to a UIImage at full Story resolution.
@MainActor
enum RunRecapRenderer {
    static func makeImage(for summary: RunSummary) -> UIImage? {
        let renderer = ImageRenderer(content: RunRecapCardView(summary: summary))
        // 1080 / 1080pt = 1.0, but render at native points; the view is already
        // authored at 1080×1920 points, so scale 1.0 yields a 1080×1920 image.
        renderer.scale = 1.0
        renderer.isOpaque = true
        return renderer.uiImage
    }

    /// Writes the recap card to a temporary PNG and returns its URL, ready to hand
    /// to `ShareLink` / the system share sheet (Instagram Stories, Messages, etc.).
    static func makePNGURL(for summary: RunSummary) -> URL? {
        guard let image = makeImage(for: summary), let data = image.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("StridesRecap-\(UUID().uuidString).png")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

#Preview {
    RunRecapCardView(summary: .placeholder)
        .scaleEffect(0.3) // shrink the 1080-wide card to fit the preview canvas
}
