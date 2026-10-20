//
//  LCOnboardingFlowView.swift
//  LiveContainerSwiftUI
//
//  Animated first-run setup (English). SideStore steps are guided from LC;
//  we cannot draw coach-marks inside the embedded SideStore process.
//

import SwiftUI
import NetworkExtension

struct LCOnboardingFlowView: View {
    @ObservedObject private var manager = LCOnboardingManager.shared
    @ObservedObject private var theme = LCTheme.shared
    @ObservedObject private var status = LCDashboardStatusManager.shared
    @State private var showFireworks = false
    @State private var confetti = false
    
    private let localDevAppStore = URL(string: "https://apps.apple.com/app/localdevvpn/id6755608044")!
    private let localDevScheme = URL(string: "localdevvpn://")!
    private let iloaderURL = URL(string: "https://github.com/nab138/iloader")!
    private let sideStoreDiscord = URL(string: "https://discord.gg/sidestore-949118421587548212")!
    private let issuesURL = URL(string: "https://github.com/nquangdungg/LiveContainer-Extended/issues")!
    private let upstreamURL = URL(string: "https://github.com/LiveContainer/LiveContainer")!
    
    var body: some View {
        ZStack {
            theme.pageBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                progressBar
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        stepContent
                    }
                    .padding(24)
                }
                bottomBar
            }
            if confetti {
                LCConfettiView().allowsHitTesting(false)
            }
        }
        .task {
            if manager.releaseNotes.isEmpty {
                await manager.fetchReleaseNotes()
            }
            status.refresh()
        }
    }
    
    private var progressBar: some View {
        let steps = LCOnboardingStep.allCases.filter { $0 != .done }
        let idx = steps.firstIndex(of: manager.step) ?? 0
        return VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: geo.size.width * CGFloat(idx + 1) / CGFloat(max(steps.count, 1)))
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            Text("Setup · Step \(idx + 1) of \(steps.count)")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.secondaryText)
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch manager.step {
        case .welcome:
            hero(icon: "shippingbox.fill", title: "Welcome to LiveContainer Extended",
                 body: "This short guide sets up LocalDevVPN, device pairing, SideStore login, and your signing certificate so apps install and refresh correctly.")
            tip("You can leave and come back — progress is saved. Welcome will not show again after you continue.")
            
        case .changelog:
            hero(icon: "sparkles", title: "What's New",
                 body: manager.releaseTag.isEmpty ? "Latest release notes" : "Release \(manager.releaseTag)")
            Text(manager.releaseNotes)
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
            if let url = manager.releaseURL {
                Link(destination: url) {
                    Label("View full release notes on GitHub", systemImage: "arrow.up.right.square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.accent)
                }
            }
            
        case .localDevVPN:
            hero(icon: "network", title: "Enable LocalDevVPN",
                 body: "SideStore refresh and many install flows need LocalDevVPN connected.")
            statusCard(
                ok: status.localDevVPN.state == .connected,
                okText: "LocalDevVPN is connected — you can continue.",
                badText: "LocalDevVPN is off or not installed."
            )
            if status.localDevVPN.state != .connected {
                VStack(spacing: 10) {
                    Button {
                        UIApplication.shared.open(localDevAppStore)
                    } label: {
                        labelButton("Install LocalDevVPN on the App Store", systemImage: "apple.logo", filled: true)
                    }
                    Button {
                        UIApplication.shared.open(localDevScheme)
                    } label: {
                        labelButton("Already installed? Turn on now", systemImage: "power", filled: false)
                    }
                }
            }
            
        case .pairing:
            hero(icon: "link", title: "Device Pairing File",
                 body: "Pairing lets SideStore talk to your device. Use iloader (or AltServer) to create the file, then import it.")
            VStack(alignment: .leading, spacing: 10) {
                numbered(1, "Install iloader if needed (Mac / Windows).")
                numbered(2, "Connect your iPhone, select the device, enter the passcode shown on screen to pair.")
                numbered(3, "In SideStore / pairing manager: open Manage Pairing File.")
                numbered(4, "Choose Set (or the localized equivalent of “Set”) or Import from a saved .mobiledevicepairing file.")
                numbered(5, "When import succeeds you will be asked to restart the app — confirm restart.")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
            Link(destination: iloaderURL) {
                Label("Open iloader on GitHub", systemImage: "arrow.down.app")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.accent)
            }
            Button {
                LCUtils.openSideStore(delegate: nil)
            } label: {
                labelButton("Open SideStore to import pairing", systemImage: "bag", filled: true)
            }
            tip("After importing, restart when prompted. Next launch continues here (welcome will not show again).")
            
        case .pairingRestartCheck:
            hero(icon: "checkmark.shield", title: "Pairing Status",
                 body: "Checking whether a pairing file is available after restart.")
            statusCard(
                ok: manager.hasPairingFile,
                okText: "Pairing data detected. Continue to SideStore login.",
                badText: "Pairing not detected yet. Open SideStore → manage pairing file → Set / Import, then restart again."
            )
            Button {
                LCUtils.openSideStore(delegate: nil)
            } label: {
                labelButton("Open SideStore", systemImage: "bag", filled: false)
            }
            
        case .sideStoreLogin:
            hero(icon: "person.crop.circle.badge.checkmark", title: "Sign in to SideStore",
                 body: "Open SideStore → Settings → Log In with your Apple ID. This is required before exporting a certificate.")
            VStack(alignment: .leading, spacing: 12) {
                coachRow("1", "Open SideStore")
                coachRow("2", "Go to Settings")
                coachRow("3", "Tap Log In and finish Apple ID sign-in")
                coachRow("4", "Return here and tap Continue when done")
            }
            Button {
                LCUtils.openSideStore(delegate: nil)
            } label: {
                labelButton("Open SideStore Settings flow", systemImage: "gearshape", filled: true)
            }
            tip("If login fails, fix it in SideStore — this guide will not loop. Only continue when login actually succeeded.")
            
        case .loginSuccessRestart:
            hero(icon: "party.popper.fill", title: "You're signed in",
                 body: "Great — next we import the signing certificate into LiveContainer Extended.")
            .onAppear {
                confetti = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) { confetti = false }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text("Need help?")
                    .font(.system(size: 15, weight: .semibold))
                Link("SideStore Discord", destination: sideStoreDiscord)
                Link("Create an issue here", destination: issuesURL)
                Link("Original LiveContainer project", destination: upstreamURL)
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(theme.accent)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
            tip("Tap Continue, then fully restart LiveContainer Extended so certificate import runs in the host app (avoids login-loop confusion).")
            
        case .importCertificate:
            hero(icon: "checkmark.seal.fill", title: "Import Signing Certificate",
                 body: "Import the certificate from SideStore (or a .p12 file) so JIT-less apps can be signed.")
            statusCard(
                ok: manager.hasCertificate,
                okText: "Certificate found. Setup is complete.",
                badText: "No certificate yet — open Settings → Certificate and import from SideStore or a .p12 file."
            )
            tip("Path: LiveContainer Extended → Settings → Certificate / Import.")
            
        case .done:
            EmptyView()
        }
    }
    
    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(primaryEnabled ? theme.accent : Color.gray.opacity(0.4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!primaryEnabled)
            
            if manager.step != .welcome {
                Button("Skip remaining setup") {
                    manager.complete()
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
    }
    
    private var primaryTitle: String {
        switch manager.step {
        case .localDevVPN:
            return status.localDevVPN.state == .connected ? "Continue" : "Check again"
        case .pairing:
            return "I've imported pairing — continue"
        case .pairingRestartCheck:
            return manager.hasPairingFile ? "Continue" : "Recheck pairing"
        case .sideStoreLogin:
            return "I've logged in — continue"
        case .loginSuccessRestart:
            return "Continue to certificate"
        case .importCertificate:
            return manager.hasCertificate ? "Finish" : "Recheck certificate"
        case .done:
            return "Done"
        default:
            return "Continue"
        }
    }
    
    private var primaryEnabled: Bool {
        switch manager.step {
        case .localDevVPN:
            // Allow continue only when connected; otherwise button is "Check again"
            return true
        default:
            return true
        }
    }
    
    private func primaryAction() {
        switch manager.step {
        case .welcome:
            manager.saveStep(.changelog)
        case .changelog:
            manager.saveStep(.localDevVPN)
        case .localDevVPN:
            status.refresh()
            if status.localDevVPN.state == .connected {
                manager.saveStep(.pairing)
            }
        case .pairing:
            // User claims import done → expect restart; save resume point
            manager.saveStep(.pairingRestartCheck)
        case .pairingRestartCheck:
            if manager.hasPairingFile {
                manager.saveStep(.sideStoreLogin)
            }
        case .sideStoreLogin:
            // Trust user + avoid loop: go to success screen then cert after restart cue
            manager.saveStep(.loginSuccessRestart)
        case .loginSuccessRestart:
            manager.saveStep(.importCertificate)
        case .importCertificate:
            if manager.hasCertificate {
                manager.complete()
            }
        case .done:
            manager.complete()
        }
    }
    
    // MARK: - UI helpers
    
    private func hero(icon: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text(body)
                .font(.system(size: 15))
                .foregroundStyle(theme.secondaryText)
        }
    }
    
    private func tip(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle.fill").foregroundStyle(theme.accent)
            Text(text).font(.system(size: 13)).foregroundStyle(theme.secondaryText)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.accent.opacity(0.1)))
    }
    
    private func statusCard(ok: Bool, okText: String, badText: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(ok ? Color.green : Color.orange)
            Text(ok ? okText : badText)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.06)))
    }
    
    private func numbered(_ n: Int, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(theme.accent))
            Text(text).font(.system(size: 14))
        }
    }
    
    private func coachRow(_ n: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text(n)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(width: 28, height: 28)
                .background(Circle().strokeBorder(theme.accent, lineWidth: 2))
            Text(text).font(.system(size: 15, weight: .medium))
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.05)))
    }
    
    private func labelButton(_ title: String, systemImage: String, filled: Bool) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(filled ? theme.accent : theme.accent.opacity(0.12))
            )
            .foregroundStyle(filled ? Color.white : theme.accent)
    }
}

// Simple confetti / fireworks layer
struct LCConfettiView: View {
    @State private var particles: [(id: Int, x: CGFloat, delay: Double, color: Color)] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles, id: \.id) { p in
                    Circle()
                        .fill(p.color)
                        .frame(width: 8, height: 8)
                        .position(x: p.x, y: -10)
                        .animation(
                            .easeIn(duration: 2.2).delay(p.delay),
                            value: particles.count
                        )
                        .modifier(LCFallModifier(distance: geo.size.height + 40, active: true))
                }
            }
            .onAppear {
                let colors: [Color] = [.red, .orange, .yellow, .green, .blue, .purple, .pink]
                particles = (0..<40).map { i in
                    (i, CGFloat.random(in: 0...geo.size.width), Double.random(in: 0...0.8), colors[i % colors.count])
                }
            }
        }
        .ignoresSafeArea()
    }
}

struct LCFallModifier: ViewModifier {
    let distance: CGFloat
    let active: Bool
    @State private var y: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .offset(y: y)
            .onAppear {
                withAnimation(.easeIn(duration: 2.4)) {
                    y = distance
                }
            }
    }
}
