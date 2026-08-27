//
//  RunHistoryView.swift
//  Strides
//
//  Features/History — list of past runs. Rows reuse the post-run summary screen.
//

import SwiftUI

struct RunHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    private var store = RunStore.shared
    @State private var selectedRun: CompletedRun?

    /// Newest first.
    private var runs: [CompletedRun] {
        store.runs.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            Group {
                if runs.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(runs) { run in
                            Button { selectedRun = run } label: {
                                RunHistoryRow(run: run, isPB: store.isPersonalBest(run))
                            }
                            .listRowBackground(StridesPalette.surface)
                            .listRowSeparatorTint(Color.white.opacity(0.08))
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(StridesPalette.canvas.ignoresSafeArea())
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(StridesPalette.voltageOrange)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $selectedRun) { run in
                RunSummaryView(run: run)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            store.delete(runs[index])
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 52))
                .foregroundColor(StridesPalette.voltageOrange)
            Text("No runs yet")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundColor(.white)
            Text("Start your first cruise to see it here.")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RunHistoryRow: View {
    let run: CompletedRun
    let isPB: Bool

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d · h:mm a"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(Self.dateFormatter.string(from: run.date))
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundColor(.gray)
                Spacer()
                if isPB {
                    HStack(spacing: 3) {
                        Image(systemName: "trophy.fill")
                        Text("PB")
                    }
                    .font(.system(size: 10, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(StridesPalette.electricCyan)
                    .clipShape(Capsule())
                }
            }

            HStack(alignment: .lastTextBaseline, spacing: 16) {
                metric(String(format: "%.2f", run.distanceKm), "KM", tint: StridesPalette.voltageOrange)
                metric(formatDuration(run.durationSeconds), "TIME", tint: .white)
                metric(run.avgPaceFormatted, "/KM", tint: StridesPalette.electricCyan)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private func metric(_ value: String, _ label: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.gray)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let h = Int(duration) / 3600
        let m = (Int(duration) % 3600) / 60
        let s = Int(duration) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
