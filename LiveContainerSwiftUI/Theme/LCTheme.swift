//
//  LCTheme.swift
//  LiveContainerSwiftUI
//
//  LiveContainer Extended — Theme & Accent (Cloudflare-inspired)
//

import SwiftUI
import UIKit

// MARK: - Accent presets

enum LCAccentPreset: String, CaseIterable, Identifiable {
    case orange = "Orange"
    case blue = "Blue"
    case indigo = "Indigo"
    case teal = "Teal"
    case green = "Green"
    case pink = "Pink"
    case purple = "Purple"
    case red = "Red"
    
    var id: String { rawValue }
    
    var color: Color {
        switch self {
        case .orange: return Color(red: 1.00, green: 0.42, blue: 0.21)
        case .blue:   return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .indigo: return Color(red: 0.35, green: 0.40, blue: 0.95)
        case .teal:   return Color(red: 0.10, green: 0.72, blue: 0.68)
        case .green:  return Color(red: 0.18, green: 0.72, blue: 0.40)
        case .pink:   return Color(red: 0.92, green: 0.30, blue: 0.55)
        case .purple: return Color(red: 0.62, green: 0.35, blue: 0.95)
        case .red:    return Color(red: 0.92, green: 0.28, blue: 0.28)
        }
    }
}

// MARK: - Theme

final class LCTheme: ObservableObject {
    static let shared = LCTheme()
    
    private let defaults: UserDefaults = LCUtils.appGroupUserDefault
    
    @Published var accentPreset: LCAccentPreset {
        didSet {
            defaults.set(accentPreset.rawValue, forKey: "LCAccentPreset")
        }
    }
    
    @Published var doubleTapStatusBarToExit: Bool {
        didSet {
            defaults.set(doubleTapStatusBarToExit, forKey: "LCDoubleTapStatusBarToExit")
        }
    }
    
    var accent: Color { accentPreset.color }
    
    var cardBackground: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 1)
            }
            return UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1)
        })
    }
    
    var cardBorder: Color {
        Color(UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(white: 1, alpha: 0.08)
            }
            return UIColor(white: 0, alpha: 0.06)
        })
    }
    
    var secondaryText: Color { Color(UIColor.secondaryLabel) }
    var success: Color { Color(red: 0.18, green: 0.72, blue: 0.40) }
    var warning: Color { Color(red: 0.95, green: 0.65, blue: 0.15) }
    var danger:  Color { Color(red: 0.92, green: 0.28, blue: 0.28) }
    
    private init() {
        let raw = defaults.string(forKey: "LCAccentPreset") ?? LCAccentPreset.orange.rawValue
        self.accentPreset = LCAccentPreset(rawValue: raw) ?? .orange
        
        if defaults.object(forKey: "LCDoubleTapStatusBarToExit") == nil {
            self.doubleTapStatusBarToExit = true
        } else {
            self.doubleTapStatusBarToExit = defaults.bool(forKey: "LCDoubleTapStatusBarToExit")
        }
    }
}

// MARK: - Card modifier

struct LCCardModifier: ViewModifier {
    @ObservedObject private var theme = LCTheme.shared
    
    func body(content: Content) -> some View {
        content
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func lcCard() -> some View {
        modifier(LCCardModifier())
    }
}
