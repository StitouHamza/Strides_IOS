//
//  Color+Hex.swift
//  Strides
//
//  Shared — single source of truth for hex color parsing.
//  Defined once here so every feature (HUD, ActivityKit, Shareable) can reuse it
//  without redeclaring the initializer.
//

import SwiftUI

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

/// Central palette for the "Wheelz" dark-cockpit visual signature.
enum StridesPalette {
    static let canvas = Color(hex: "09090B")       // Pitch Dark Canvas
    static let surface = Color(hex: "121216")      // Card / HUD Surface
    static let elevated = Color(hex: "1C1C22")     // Elevated borders / capsules
    static let voltageOrange = Color(hex: "FF5500") // Primary accent
    static let electricCyan = Color(hex: "00F0FF")  // Secondary accent

    /// Speed-gradient polyline colors, keyed by speed in m/s.
    static func speedColor(forMPS speedMPS: Double) -> Color {
        switch speedMPS {
        case ..<2.2: return Color(hex: "3B82F6")   // Recovery / Walk  (< ~7.9 km/h)
        case 2.2..<3.3: return Color(hex: "10B981") // Zone 2 / Easy   (~8–12 km/h)
        case 3.3..<4.2: return Color(hex: "F59E0B") // Threshold / Tempo
        default: return Color(hex: "EF4444")        // Max Sprint
        }
    }

    /// Human-readable zone label for a given speed in m/s.
    static func speedLabel(forMPS speedMPS: Double) -> String {
        switch speedMPS {
        case ..<2.2: return "RECOVERY"
        case 2.2..<3.3: return "EASY"
        case 3.3..<4.2: return "TEMPO"
        default: return "SPRINT"
        }
    }
}
