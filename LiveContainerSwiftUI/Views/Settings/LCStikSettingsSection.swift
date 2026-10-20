//
//  LCStikSettingsSection.swift
//  LiveContainerSwiftUI
//
//  Minimal StikDebug settings: status, pairing, enable JIT.
//

import SwiftUI
import UniformTypeIdentifiers

struct LCStikSettingsSection: View {
    @ObservedObject private var stik = LCStikIntegration.shared
    @ObservedObject private var theme = LCTheme.shared
    @State private var picking = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        Section {
            HStack {
                Text("StikDebug")
                Spacer()
                Text(stik.isInstalled ? "Installed" : "Not found")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(stik.isInstalled ? theme.success : theme.secondaryText)
            }
            
            HStack {
                Text("Pairing file")
                Spacer()
                Text(stik.pairingStatusText)
                    .font(.subheadline)
                    .foregroundStyle(stik.hasPairingFile ? theme.success : theme.secondaryText)
            }
            
            Button {
                picking = true
            } label: {
                Label("Import Pairing File…", systemImage: "doc.badge.plus")
            }
            
            if stik.hasPairingFile {
                Button("Remove Pairing File", role: .destructive) {
                    do {
                        try stik.clearPairingFile()
                        present("Done", "Pairing file removed.")
                    } catch {
                        present("Error", error.localizedDescription)
                    }
                }
            }
            
            Button {
                Task {
                    let ok = await stik.openEnableJIT()
                    if ok {
                        present("StikDebug", "Opened enable-JIT request.")
                    } else {
                        present("StikDebug", "Could not open StikDebug. Install it first, or use JIT Enabler → StikDebug (Another LiveContainer/Multitask).")
                    }
                }
            } label: {
                Label("Enable JIT", systemImage: "bolt.fill")
            }
        } header: {
            Text("StikDebug")
        } footer: {
            Text("iOS 17.4+. Import a pairing file, connect LocalDevVPN, then enable JIT. Prefer Settings → JIT Enabler → StikDebug for guest apps.")
        }
        .onAppear { stik.refreshStatus() }
        .betterFileImporter(
            isPresented: $picking,
            types: [UTType(filenameExtension: "mobiledevicepairing") ?? .data, .data, .item],
            multiple: false,
            callback: { urls in
                guard let url = urls.first else { return }
                do {
                    _ = try stik.importPairingFile(from: url)
                    present("Done", "Pairing file imported.")
                } catch {
                    present("Error", error.localizedDescription)
                }
            },
            onDismiss: { picking = false }
        )
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func present(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }
}
