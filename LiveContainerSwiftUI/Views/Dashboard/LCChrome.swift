//
//  LCChrome.swift
//  LiveContainerSwiftUI
//
//  Shared Extended chrome for every tab (iOS 15+ safe)
//

import SwiftUI
import UIKit

/// Hero header used on Settings / Sources / Tweaks
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
    }
}

struct LCChromePageBackground: View {
    @ObservedObject private var theme = LCTheme.shared
    var body: some View {
        theme.pageBackground.ignoresSafeArea()
    }
}

// MARK: - iOS 15-safe list background hide

struct LCHideListBackgroundModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content.scrollContentBackground(.hidden)
        } else {
            content.onAppear {
                UITableView.appearance().backgroundColor = .clear
            }
            .onDisappear {
                UITableView.appearance().backgroundColor = nil
            }
        }
    }
}

extension View {
    /// Hides default List/Form background on iOS 16+; best-effort clear on iOS 15.
    func lcHideListBackground() -> some View {
        modifier(LCHideListBackgroundModifier())
    }
    
    func lcChromeListStyle() -> some View {
        self
            .listStyle(.insetGrouped)
            .lcHideListBackground()
    }
}
