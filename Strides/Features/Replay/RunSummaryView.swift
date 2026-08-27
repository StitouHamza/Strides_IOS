//
//  RunSummaryView.swift
//  Strides
//
//  Features/Replay — post-run recap: speed-gradient route, headline stats,
//  per-km splits, plus entry points to the 3D flyover and the shareable card.
//

import SwiftUI

struct RunSummaryView: View {
    let run: CompletedRun

    @Environment(\.dismiss) private var dismiss
    @State private var showReplay = false
    @State private var recapURL: URL?
    @State private var isPersonalBest = false

    private var fastestPace: Double {
        run.splits.map(\.paceSecondsPerKm).filter { $0 > 0 }.min() ?? 0
    }
    private var slowestPace: Double {
        run.splits.map(\.paceSecondsPerKm).max() ?? 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if isPersonalBest {
                        HStack(spacing: 8) {
                            Image(systemName: "trophy.fill")
                            Text("NEW PERSONAL BEST")
                                .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                .tracking(1)
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(StridesPalette.electricCyan)
                        .clipShape(Capsule())
                    }

                    // Route map
                    SpeedGradientMapView(trajectory: run.trajectory, interactive: true)
                        .frame(height: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                showReplay = true
                            } label: {
                                Label("3D Flyover", systemImage: "play.fill")
                                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(StridesPalette.voltageOrange)
                                    .clipShape(Capsule())
                            }
                            .padding(12)
                        }

                    // Headline stats
                    HStack(spacing: 12) {
                        summaryStat("DISTANCE", String(format: "%.2f", run.distanceKm), "KM")
                        summaryStat("TIME", formatDuration(run.durationSeconds), "")
                        summaryStat("AVG PACE", run.avgPaceFormatted, "/KM")
                    }

                    HStack(spacing: 12) {
                        summaryStat("CADENCE", "\(run.avgCadenceSPM)", "SPM")
                        summaryStat("ELEV GAIN", "\(Int(run.elevationGainMeters))", "M")
                    }

                    // Splits
                    if !run.splits.isEmpty {
                        splitsSection
                    }

                    // Share
                    shareButton
                        .padding(.top, 4)
                }
                .padding()
            }
            .background(StridesPalette.canvas.ignoresSafeArea())
            .navigationTitle("Run Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(StridesPalette.voltageOrange)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .fullScreenCover(isPresented: $showReplay) {
                RouteReplayView(run: run)
            }
            .task {
                // Pre-render the Instagram card so Share is instant.
                recapURL = RunRecapRenderer.makePNGURL(for: run.toRunSummary())
                isPersonalBest = RunStore.shared.isPersonalBest(run)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Sections

    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("SPLITS")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundColor(.gray)
                .tracking(2)

            ForEach(run.splits) { split in
                HStack(spacing: 12) {
                    Text(split.isPartial ? String(format: "%.2f", split.distanceKm) : "\(split.index)")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 40, alignment: .leading)

                    // Relative pace bar (fastest = full, slowest = short)
                    GeometryReader { geo in
                        Capsule()
                            .fill(split.paceSecondsPerKm <= fastestPace + 0.01
                                  ? StridesPalette.electricCyan
                                  : StridesPalette.voltageOrange)
                            .frame(width: geo.size.width * barFraction(for: split))
                    }
                    .frame(height: 10)

                    Text(split.paceFormatted)
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, alignment: .trailing)
                }
                .padding(.vertical, 6)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(StridesPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var shareButton: some View {
        Group {
            if let recapURL {
                ShareLink(item: recapURL) {
                    Label("Share Recap Card", systemImage: "square.and.arrow.up")
                        .font(.system(.headline, design: .rounded, weight: .heavy))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(StridesPalette.voltageOrange)
                        .clipShape(Capsule())
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .tint(StridesPalette.voltageOrange)
            }
        }
    }

    // MARK: - Helpers

    /// Maps a split's pace to a 0.15–1.0 bar width (faster = longer).
    private func barFraction(for split: RunSplit) -> CGFloat {
        guard slowestPace > fastestPace else { return 1.0 }
        let t = (split.paceSecondsPerKm - fastestPace) / (slowestPace - fastestPace)
        return CGFloat(1.0 - t * 0.85)
    }

    private func summaryStat(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                if !unit.isEmpty {
                    Text(unit)
                        .font(.system(.caption2, design: .rounded, weight: .bold))
                        .foregroundColor(StridesPalette.electricCyan)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(StridesPalette.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
