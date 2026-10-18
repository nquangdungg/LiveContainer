//
//  LCChrome.swift
//  LiveContainerSwiftUI
//
//  Shared Extended chrome for every tab
//

import SwiftUI

/// Hero header used on Settings / Sources / Tweaks / Apps-adjacent screens
struct LCChromeHeader: View {
    @ObservedObject private var theme = LCTheme.shared
    var title: String
    var accentWord: String? = "Extended"
    var subtitle: String?
    var trailing: AnyView? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                if let accentWord {
                    Text(accentWord)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(theme.accent)
                }
                Spacer(minLength: 0)
                if let trailing {
                    trailing
                }
            }
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.pageBackground.opacity(0.001)) // hit testing
    }
}

/// Row style matching Extended cards inside lists
struct LCChromeRowBackground: View {
    @ObservedObject private var theme = LCTheme.shared
    var body: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(theme.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    /// Apply Extended list aesthetics where possible
    func lcChromeListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
    }
}

/// Tab root background
struct LCChromePageBackground: View {
    @ObservedObject private var theme = LCTheme.shared
    var body: some View {
        theme.pageBackground.ignoresSafeArea()
    }
}
