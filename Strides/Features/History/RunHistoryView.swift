//
//  RunHistoryView.swift
//  Strides
//

import SwiftUI

struct RunHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var runs: [CompletedRun] = RunStore.shared.allRuns()
    @State private var selectedRun: CompletedRun?

    var body: some View {
        NavigationStack {
            ZStack {
                StridesPalette.canvas.ignoresSafeArea()

                if runs.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 48))
                            .foregroundColor(StridesPalette.elevated)
                        Text("NO MISSION LOGS")
                            .font(.system(.headline, design: .rounded, weight: .heavy))
                            .foregroundColor(.gray)
                            .tracking(2)
                    }
                } else {
                    List {
                        ForEach(runs) { run in
                            HistoryRunCard(run: run)
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .onTapGesture {
                                    selectedRun = run
                                }
                        }
                        .onDelete(perform: deleteRun)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("LOGBOOK")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("DONE") { dismiss() }
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .foregroundColor(StridesPalette.voltageOrange)
                }
            }
            .sheet(item: $selectedRun) { run in
                RunSummaryView(run: run)
            }
        }
    }

    private func deleteRun(at offsets: IndexSet) {
        for idx in offsets {
            RunStore.shared.delete(runs[idx])
        }
        runs.remove(atOffsets: offsets)
    }
}

struct HistoryRunCard: View {
    let run: CompletedRun

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Text(run.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.gray)
                Spacer()
                if run.isPersonalBest {
                    Text("PB")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(StridesPalette.voltageOrange)
                        .clipShape(Capsule())
                }
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "%.2f", run.totalDistanceMeters / 1000.0))
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("KM")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(StridesPalette.electricCyan)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(run.avgPaceFormatted)
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("PACE")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatDuration(run.durationSeconds))
                        .font(.system(size: 22, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                    Text("TIME")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium)
                .fill(StridesPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusMedium).stroke(StridesTheme.hairlineBorder, lineWidth: 1))
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}
