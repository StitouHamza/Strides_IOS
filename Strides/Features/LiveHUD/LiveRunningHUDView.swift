//
//  LiveRunningHUDView.swift
//  Strides
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
            StridesPalette.canvas.ignoresSafeArea()

            VStack(spacing: 12) {
                // Cockpit Header
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(telemetry.isRunning ? Color.green : StridesPalette.voltageOrange)
                            .frame(width: 8, height: 8)
                            .shadow(color: (telemetry.isRunning ? Color.green : StridesPalette.voltageOrange).opacity(0.8), radius: 6)

                        Text("STRIDES")
                            .font(.system(.title3, design: .rounded, weight: .black))
                            .foregroundColor(.white)
                            .tracking(3)
                    }

                    Spacer()

                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 42, height: 42)
                            .background(StridesPalette.surface)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(StridesTheme.hairlineBorder, lineWidth: 1))
                    }
                    .sensoryFeedback(.impact(weight: .light), trigger: showHistory)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)

                // Minimap Telemetry Panel
                ZStack(alignment: .top) {
                    Map(position: $cameraPosition) {
                        ForEach(0..<max(0, telemetry.trajectory.count - 1), id: \.self) { idx in
                            let p1 = telemetry.trajectory[idx]
                            let p2 = telemetry.trajectory[idx + 1]
                            MapPolyline(coordinates: [p1.coordinate, p2.coordinate])
                                .stroke(StridesPalette.speedColor(forMPS: p2.speedMPS), lineWidth: 4)
                        }

                        if let ghost = telemetry.ghostCoordinate {
                            Annotation("Ghost", coordinate: ghost) {
                                GhostDuelMarkerView()
                            }
                        }
                        UserAnnotation()
                    }
                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge))
                    .overlay(
                        RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge)
                            .stroke(StridesTheme.hairlineBorder, lineWidth: 1)
                    )

                    // HUD Overlays
                    HStack {
                        if telemetry.isGhostActive {
                            GhostStatusPill(deltaSeconds: telemetry.ghostDeltaSeconds)
                        }
                        Spacer()
                        CadenceStatusPill(cadence: telemetry.currentCadenceSPM)
                    }
                    .padding(10)
                }
                .padding(.horizontal, 16)

                // Primary Speedometer Instrument
                CockpitGaugeView(
                    speedMPS: telemetry.currentSpeedMPS,
                    paceFormatted: telemetry.rollingPaceFormatted,
                    isRunning: telemetry.isRunning
                )
                .padding(.horizontal, 16)

                // Secondary Telemetry Row
                HStack(spacing: 10) {
                    HUDMetricCard(
                        title: "DISTANCE",
                        value: String(format: "%.2f", telemetry.totalDistanceMeters / 1000.0),
                        unit: "KM"
                    )
                    HUDMetricCard(
                        title: "ELAPSED",
                        value: formatDuration(telemetry.activeDurationSeconds),
                        unit: "TIME",
                        accentColor: StridesPalette.voltageOrange
                    )
                }
                .padding(.horizontal, 16)

                Spacer(minLength: 8)

                // Tactical Control Deck
                cockpitControlBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }

            if telemetry.locationDenied {
                LocationDeniedCockpitOverlay()
            }
        }
        .onAppear {
            telemetry.requestPermissions()
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

    // MARK: - Subviews & Controls

    @ViewBuilder
    private var cockpitControlBar: some View {
        switch telemetry.phase {
        case .idle:
            Button("ENGAGE CRUISE") {
                telemetry.startSession()
            }
            .buttonStyle(CockpitButtonStyle(baseColor: StridesPalette.voltageOrange, foregroundColor: .black, isHero: true))
            .sensoryFeedback(.start, trigger: telemetry.phase)

        case .running:
            HStack(spacing: 12) {
                Button("PAUSE") {
                    telemetry.pauseSession()
                }
                .buttonStyle(CockpitButtonStyle(baseColor: StridesPalette.elevated, foregroundColor: .white))
                .sensoryFeedback(.impact(weight: .medium), trigger: telemetry.phase)

                Button("TERMINATE") {
                    telemetry.stopSession()
                    summaryRun = telemetry.lastCompletedRun
                }
                .buttonStyle(CockpitButtonStyle(baseColor: Color(hex: "EF4444"), foregroundColor: .white))
                .sensoryFeedback(.stop, trigger: telemetry.phase)
            }

        case .paused:
            HStack(spacing: 12) {
                Button("RESUME") {
                    telemetry.resumeSession()
                }
                .buttonStyle(CockpitButtonStyle(baseColor: StridesPalette.voltageOrange, foregroundColor: .black, isHero: true))
                .sensoryFeedback(.start, trigger: telemetry.phase)

                Button("TERMINATE") {
                    telemetry.stopSession()
                    summaryRun = telemetry.lastCompletedRun
                }
                .buttonStyle(CockpitButtonStyle(baseColor: Color(hex: "EF4444"), foregroundColor: .white))
                .sensoryFeedback(.stop, trigger: telemetry.phase)
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let min = Int(duration) / 60
        let sec = Int(duration) % 60
        return String(format: "%02d:%02d", min, sec)
    }
}

// MARK: - Supplementary HUD Components

struct GhostDuelMarkerView: View {
    @State private var ping = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(StridesPalette.electricCyan, lineWidth: 1.5)
                .frame(width: ping ? 44 : 20, height: ping ? 44 : 20)
                .opacity(ping ? 0 : 0.8)

            Circle()
                .fill(StridesPalette.electricCyan.opacity(0.3))
                .frame(width: 28, height: 28)

            Image(systemName: "figure.run")
                .font(.system(size: 12, weight: .black))
                .foregroundColor(.black)
                .frame(width: 18, height: 18)
                .background(StridesPalette.electricCyan)
                .clipShape(Circle())
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                ping = true
            }
        }
    }
}

struct GhostStatusPill: View {
    let deltaSeconds: Int

    private var isAhead: Bool { deltaSeconds <= 0 }
    private var color: Color { isAhead ? Color(hex: "10B981") : Color(hex: "EF4444") }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isAhead ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                .font(.system(size: 12, weight: .bold))
            VStack(alignment: .leading, spacing: 0) {
                Text("\(isAhead ? "-" : "+")\(abs(deltaSeconds))s")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                Text(isAhead ? "AHEAD" : "BEHIND")
                    .font(.system(size: 7, weight: .black))
                    .opacity(0.8)
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1))
        .sensoryFeedback(.impact(weight: .heavy), trigger: isAhead)
    }
}

struct CadenceStatusPill: View {
    let cadence: Int

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(cadence > 165 ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            Text("\(cadence)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            Text("SPM")
                .font(.system(size: 8, weight: .black))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .overlay(Capsule().stroke(StridesTheme.hairlineBorder, lineWidth: 1))
    }
}

struct LocationDeniedCockpitOverlay: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 38, weight: .medium))
                .foregroundColor(StridesPalette.voltageOrange)

            Text("GPS LINK OFFLINE")
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .foregroundColor(.white)
                .tracking(2)

            Text("Instrument telemetry requires active satellite lock to record telemetry points.")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            Button("AUTHORIZE SENSORS") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(CockpitButtonStyle(baseColor: StridesPalette.voltageOrange, foregroundColor: .black))
            .padding(.top, 4)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge)
                .fill(StridesPalette.surface)
                .overlay(RoundedRectangle(cornerRadius: StridesTheme.cornerRadiusLarge).stroke(StridesTheme.hairlineBorder, lineWidth: 1))
        )
        .padding(32)
    }
}
