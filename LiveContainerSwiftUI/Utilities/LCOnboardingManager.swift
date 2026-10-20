//
//  LCOnboardingManager.swift
//  LiveContainerSwiftUI
//
//  First-run + resume onboarding state machine (English UI).
//

import Foundation
import SwiftUI
import Combine

enum LCOnboardingStep: String, Codable, CaseIterable {
    case welcome
    case changelog
    case localDevVPN
    case pairing
    case pairingRestartCheck
    case sideStoreLogin
    case loginSuccessRestart
    case importCertificate
    case done
}

@MainActor
final class LCOnboardingManager: ObservableObject {
    static let shared = LCOnboardingManager()
    
    private let stepKey = "LCOnboardingStep"
    private let completedKey = "LCOnboardingCompleted"
    private let releaseNotesCacheKey = "LCOnboardingReleaseNotes"
    private let releaseURLCacheKey = "LCOnboardingReleaseURL"
    
    @Published var step: LCOnboardingStep
    @Published var isActive: Bool
    @Published var releaseNotes: String = ""
    @Published var releaseURL: URL? = nil
    @Published var releaseTag: String = ""
    
    private init() {
        let completed = UserDefaults.standard.bool(forKey: completedKey)
        if completed {
            step = .done
            isActive = false
        } else if let raw = UserDefaults.standard.string(forKey: stepKey),
                  let s = LCOnboardingStep(rawValue: raw) {
            step = s == .welcome ? .welcome : s  // resume mid-flow (skip welcome only handled in advance)
            // After restart we may resume at pairingRestartCheck / importCertificate
            isActive = s != .done
        } else {
            // First launch: only show onboarding if cert OR pairing looks missing
            step = .welcome
            isActive = true
        }
        releaseNotes = UserDefaults.standard.string(forKey: releaseNotesCacheKey) ?? ""
        if let s = UserDefaults.standard.string(forKey: releaseURLCacheKey) {
            releaseURL = URL(string: s)
        }
    }
    
    func evaluateShouldShow() {
        if UserDefaults.standard.bool(forKey: completedKey) {
            isActive = false
            step = .done
            return
        }
        // Resume saved step (e.g. after restart for pairing / cert)
        if let raw = UserDefaults.standard.string(forKey: stepKey),
           let s = LCOnboardingStep(rawValue: raw), s != .done, s != .welcome {
            step = s
            isActive = true
            return
        }
        // Fresh user: no cert → onboarding
        let hasCert = LCUtils.certificateData() != nil
        if !hasCert {
            step = .welcome
            isActive = true
        } else {
            complete()
        }
    }
    
    func saveStep(_ s: LCOnboardingStep) {
        step = s
        UserDefaults.standard.set(s.rawValue, forKey: stepKey)
        isActive = s != .done
    }
    
    func advance() {
        let all = LCOnboardingStep.allCases
        guard let idx = all.firstIndex(of: step), idx + 1 < all.count else {
            complete()
            return
        }
        saveStep(all[idx + 1])
    }
    
    func complete() {
        step = .done
        isActive = false
        UserDefaults.standard.set(true, forKey: completedKey)
        UserDefaults.standard.set(LCOnboardingStep.done.rawValue, forKey: stepKey)
    }
    
    func resetForTesting() {
        restartOnboarding()
    }
    
    /// Re-show Welcome + full setup flow (Settings button / testing).
    func restartOnboarding() {
        UserDefaults.standard.removeObject(forKey: completedKey)
        UserDefaults.standard.set(LCOnboardingStep.welcome.rawValue, forKey: stepKey)
        step = .welcome
        isActive = true
    }
    
    /// Fetch release notes from this fork's latest GitHub release (not invented).
    func fetchReleaseNotes() async {
        let url = URL(string: "https://api.github.com/repos/nquangdungg/LiveContainer-Extended/releases/latest")!
        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        do {
            let (data, _) = try await URLSession.shared.data(for: req)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let body = (json["body"] as? String) ?? "No release notes available."
                let tag = (json["tag_name"] as? String) ?? ""
                let html = (json["html_url"] as? String) ?? "https://github.com/nquangdungg/LiveContainer-Extended/releases"
                await MainActor.run {
                    self.releaseNotes = body
                    self.releaseTag = tag
                    self.releaseURL = URL(string: html)
                    UserDefaults.standard.set(body, forKey: self.releaseNotesCacheKey)
                    UserDefaults.standard.set(html, forKey: self.releaseURLCacheKey)
                }
            }
        } catch {
            await MainActor.run {
                if self.releaseNotes.isEmpty {
                    self.releaseNotes = "Could not load release notes. Open the releases page for details."
                    self.releaseURL = URL(string: "https://github.com/nquangdungg/LiveContainer-Extended/releases")
                }
            }
        }
    }
    
    var hasCertificate: Bool {
        LCUtils.certificateData() != nil
    }
    
    /// Best-effort pairing detection (SideStore / AltStore style paths in app group).
    var hasPairingFile: Bool {
        let defaults = LCUtils.appGroupUserDefault
        if defaults.data(forKey: "PairingFile") != nil { return true }
        if defaults.string(forKey: "PairingFile") != nil { return true }
        // Common filenames in shared container
        if let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: defaults.object(forKey: "LCAppGroupID") as? String ?? "") {
            let candidates = ["pairing.mobiledevicepairing", "PairingFile", "pairingFile"]
            for name in candidates {
                if FileManager.default.fileExists(atPath: group.appendingPathComponent(name).path) {
                    return true
                }
            }
        }
        // Scan app group root for *.mobiledevicepairing
        if let suite = Bundle.main.object(forInfoDictionaryKey: "LCAppGroupPath") as? String {
            _ = suite
        }
        let fm = FileManager.default
        if let groups = try? fm.contentsOfDirectory(atPath: "/private/var/mobile/Containers/Shared/AppGroup") {
            // too invasive — skip
            _ = groups
        }
        // SideStore integration may expose via UserDefaults
        if defaults.bool(forKey: "isPairingReady") { return true }
        if defaults.object(forKey: "UDID") != nil { return true }
        return false
    }
}
