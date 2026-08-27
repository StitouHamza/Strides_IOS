//
//  LiveRunningHUDView.swift
//  Strides
//
//  Features/LiveHUD — Telemetry cockpit dashboard.
//
//  NOTE: The `Color(hex:)` initializer now lives in Shared/Color+Hex.swift so it
//  can be shared across features without a duplicate-declaration error.
//

import SwiftUI
import MapKit

struct LiveRunningHUDView: View {
    @State private var telemetry = RunningTelemetryManager()
    @State private var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    @State private var summaryRun: CompletedRun?
    @State private var showHistory = false

    var body: some View {
        ZStack {
            Color(hex: "09090B").ignoresSafeArea()

            VStack(spacing: 16) {
                // Header: title + history
                HStack {
                    Text("STRIDES")
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundColor(.white)
                        .tracking(2)
                    Spacer()
                    Button { showHistory = true } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(Color(hex: "1C1C22"))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)

                // Top Live Minimap with Speed Polyline
                ZStack(alignment: .topTrailing) {
                    Map(position: $cameraPosition) {
                        ForEach(0..<max(0, telemetry.trajectory.count - 1), id: \.self) { idx in
                            let p1 = telemetry.trajectory[idx]
                            let p2 = telemetry.trajectory[idx + 1]
                            MapPolyline(coordinates: [p1.coordinate, p2.coordinate])
                                .stroke(speedColor(for: p2.speedMPS), lineWidth: 4)
                        }
                        // Ghost marker: where your PB was at this elapsed time.
                        if let ghost = telemetry.ghostCoordinate {
                            Annotation("Ghost", coordinate: ghost) {
                                ZStack {
                                    Circle().fill(StridesPalette.electricCyan.opacity(0.25)).frame(width: 30, height: 30)
                                    Image(systemName: "figure.run")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.black)
                                        .frame(width: 18, height: 18)
                                        .background(StridesPalette.electricCyan)
                                        .clipShape(Circle())
                                }
                            }
                        }
                        UserAnnotation()
                    }
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                    // Cadence / GPS Quality Pill
                    HStack(spacing: 6) {
                        Circle().fill(Color.green).frame(width: 8, height: 8)
                        Text("\(telemetry.currentCadenceSPM) SPM")
                            .font(.system(.caption2, design: .monospaced, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(12)

                    // Ghost delta pill (top-leading)
                    if telemetry.isGhostActive {
                        ghostDeltaPill
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal)

                // Main Telemetry Readout (Instant Pace Gauge)
                VStack(spacing: 4) {
                    Text("CURRENT PACE")
                        .font(.system(.caption, design: .rounded, weight: .bold))
                        .foregroundColor(.gray)
                        .tracking(2)

                    Text(telemetry.rollingPaceFormatted)
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundColor(Color(hex: "FF5500"))
                        .shadow(color: Color(hex: "FF5500").opacity(0.3), radius: 12, x: 0, y: 0)

                    Text("/KM")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(hex: "121216"))
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal)

                // Secondary Metrics Grid
                HStack(spacing: 12) {
                    MetricCard(
                        title: "DISTANCE",
                        value: String(format: "%.2f", telemetry.totalDistanceMeters / 1000.0),
                        unit: "KM"
                    )
                    MetricCard(
                        title: "TIME",
                        value: formatDuration(telemetry.activeDurationSeconds),
                        unit: "ELAPSED"
                    )
                }
                .padding(.horizontal)

                Spacer()

                // Phase-driven controls
                controlBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }

            // Location-denied overlay
            if telemetry.locationDenied {
                locationDeniedOverlay
            }
        }
        .onAppear {
            telemetry.requestPermissions()
            // Recover a run interrupted by a crash / force-quit.
            if summaryRun == nil, telemetry.phase == .idle,
               let recovered = RunStore.shared.consumePendingRun() {
                RunStore.shared.save(recovered)
                summaryRun = recovered
            }
        }
        .sheet(item: $summaryRun) { run in
            RunSummaryView(run: run)
        }
        .sheet(isPresented: $showHistory) {
            RunHistoryView()
        }
    }

    // MARK: - Controls

    @ViewBuilder
    private var controlBar: some View {
        switch telemetry.phase {
        case .idle:
            controlButton("START CRUISE", fill: Color(hex: "FF5500"), fg: .black) {
                telemetry.startSession()
            }
        case .running:
            HStack(spacing: 12) {
                controlButton("PAUSE", fill: Color(hex: "1C1C22"), fg: .white) {
                    telemetry.pauseSession()
                }
                controlButton("FINISH", fill: .red, fg: .white) {
                    telemetry.stopSession()
                    summaryRun = telemetry.lastCompletedRun
                }
            }
        case .paused:
            HStack(spacing: 12) {
                controlButton("RESUME", fill: Color(hex: "FF5500"), fg: .black) {
                    telemetry.resumeSession()
                }
                controlButton("FINISH", fill: .red, fg: .white) {
                    telemetry.stopSession()
                    summaryRun = telemetry.lastCompletedRun
                }
            }
        }
    }

    private func controlButton(_ title: String, fill: Color, fg: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundColor(fg)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(fill)
                .clipShape(Capsule())
                .shadow(color: fill.opacity(0.4), radius: 12)
        }
    }

    private var locationDeniedOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "FF5500"))
            Text("Location access needed")
                .font(.system(.title3, design: .rounded, weight: .heavy))
                .foregroundColor(.white)
            Text("Strides needs your location to track runs. Enable it in Settings to start a cruise.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("OPEN SETTINGS")
                    .font(.system(.subheadline, design: .rounded, weight: .heavy))
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .frame(height: 50)
                    .background(Color(hex: "FF5500"))
                    .clipShape(Capsule())
            }
        }
        .padding(32)
        .background(Color(hex: "121216"))
        .clipShape(RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .padding(32)
    }

    /// Live "vs GHOST" indicator: green when ahead of your PB, red when behind.
    private var ghostDeltaPill: some View {
        let delta = telemetry.ghostDeltaSeconds
        let ahead = delta <= 0
        let magnitude = abs(delta)
        return HStack(spacing: 6) {
            Image(systemName: ahead ? "arrow.up.forward" : "arrow.down.forward")
                .font(.system(size: 10, weight: .black))
            VStack(alignment: .leading, spacing: 0) {
                Text(String(format: "%@%d s", ahead ? "-" : "+", magnitude))
                    .font(.system(.caption, design: .monospaced, weight: .heavy))
                Text(ahead ? "AHEAD OF PB" : "BEHIND PB")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.8)
            }
        }
        .foregroundColor(ahead ? Color(hex: "10B981") : Color(hex: "EF4444"))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        return String(format: "%02d:%02d", min, sec)
    }

    private func speedColor(for speedMPS: Double) -> Color {
        switch speedMPS {
        case ..<2.2: return Color(hex: "3B82F6") // Blue
        case 2.2..<3.3: return Color(hex: "10B981") // Green
        case 3.3..<4.2: return Color(hex: "F59E0B") // Orange
        default: return Color(hex: "EF4444") // Crimson Sprint
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .foregroundColor(.gray)
                .tracking(1)

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                Text(unit)
                    .font(.system(.caption2, design: .rounded, weight: .bold))
                    .foregroundColor(Color(hex: "00F0FF"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(hex: "121216"))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    LiveRunningHUDView()
        .preferredColorScheme(.dark)
}
