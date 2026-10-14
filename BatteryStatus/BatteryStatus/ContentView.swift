import SwiftUI
import Combine
import UniformTypeIdentifiers

struct ContentView: View {
    // Live battery
    @State private var level: Float = 0
    @State private var state = "Unknown"

    // System data related to the battery (public iOS APIs)
    @State private var monitoringOn = false
    @State private var pluggedIn = false
    @State private var lowPowerMode = false
    @State private var thermal = "Unknown"
    @State private var lastChecked = Date()

    // Analytics data
    @State private var info: BatteryInfo?
    @State private var sourceName: String?
    @State private var folderName: String?
    @State private var errorMessage: String?

    @State private var showFolderPicker = false
    @State private var showFilePicker = false

    private let bookmarkKey = "analyticsFolderBookmark"

    var body: some View {
        NavigationStack {
            List {
                liveSection
                systemSection
                sourceSection
                helpSection
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(.red) }
                }
                if let info {
                    healthSection(info)
                    dailySection(info)
                    fileInfoSection(info)
                }
            }
            .navigationTitle("Battery Status")
        }
        .safeAreaInset(edge: .bottom) {
            AdBannerView()
                .frame(maxWidth: .infinity)
                .background(.bar)
        }
        .onAppear {
            UIDevice.current.isBatteryMonitoringEnabled = true
            updateLive()
            loadLatestFromFolder()   // auto-load newest file on launch
        }
        .onReceive(batteryEvents) { _ in updateLive() }
        .fileImporter(isPresented: $showFolderPicker,
                      allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                saveFolder(url)
                loadLatestFromFolder()
            }
        }
        .fileImporter(isPresented: $showFilePicker,
                      allowedContentTypes: [.data]) { result in
            handleSingleFile(result)
        }
    }

    // MARK: - Sections

    private var liveSection: some View {
        Section("Right now") {
            row("Charge", level >= 0 ? "\(Int(level * 100))%" : "n/a")
            row("State", state)
            Button("Refresh") { updateLive() }
        }
    }

    /// Fires whenever iOS reports a change in battery level, charging state,
    /// Low Power Mode or thermal state, so the screen updates by itself.
    private var batteryEvents: AnyPublisher<Notification, Never> {
        let center = NotificationCenter.default
        return Publishers.MergeMany([
            center.publisher(for: UIDevice.batteryLevelDidChangeNotification),
            center.publisher(for: UIDevice.batteryStateDidChangeNotification),
            center.publisher(for: .NSProcessInfoPowerStateDidChange),
            center.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
        ])
        .eraseToAnyPublisher()
    }

    private var systemSection: some View {
        Section {
            row("Battery monitoring", monitoringOn ? "On" : "Off")
            row("Battery level", level >= 0 ? String(format: "%.2f (%d%%)", level, Int(level * 100)) : "n/a")
            row("Charging state", state)
            row("Plugged in", pluggedIn ? "Yes" : "No")
            row("Low Power Mode", lowPowerMode ? "On" : "Off")
            row("Thermal state", thermal)
            row("Device", UIDevice.current.model)
            row("iOS version", UIDevice.current.systemVersion)
            row("Last checked", lastChecked.formatted(date: .omitted, time: .standard))
        } header: {
            Text("System battery data")
        } footer: {
            Text("iOS does not give apps the cycle count, health, temperature, voltage or current. Those only come from the analytics file below.")
        }
    }

    private var sourceSection: some View {
        Section("Analytics data") {
            row("Folder", folderName ?? "Not chosen")
            row("Latest file used", sourceName)
            Button("Choose analytics folder") { showFolderPicker = true }
            Button("Reload latest file") { loadLatestFromFolder() }
            Button("Import a single file") { showFilePicker = true }
        }
    }

    /// Step-by-step instructions shown inside the app.
    private var helpSection: some View {
        Section("How to get the analytics data") {
            DisclosureGroup("Step 1: Save the file from Settings") {
                lines([
                    "Open Settings → Privacy & Security → Analytics & Improvements.",
                    "Make sure \"Share iPhone Analytics\" is turned on. Without it, iOS does not create the files.",
                    "Tap Analytics Data. A long list of files appears.",
                    "Find the newest file whose name starts with \"Analytics-\" followed by a date, for example Analytics-2026-10-07-070006. Tap it.",
                    "Tap the Share button (top right), then Save to Files.",
                    "Choose your BatteryLogs folder (create it first in the Files app if needed) and tap Save."
                ], numbered: true)
            }

            DisclosureGroup("Step 2: Import it into this app") {
                lines([
                    "Tap \"Choose analytics folder\" above and select your BatteryLogs folder. You only do this once.",
                    "The app loads the newest analytics file in that folder automatically.",
                    "After you save a newer file, open the app or tap \"Reload latest file\".",
                    "Alternatively, tap \"Import a single file\" and pick one file by hand."
                ], numbered: true)
            }

            DisclosureGroup("Tips and problems") {
                lines([
                    "iOS creates about one analytics file per day, so new data appears once a day.",
                    "If the Analytics Data list is empty, turn on Share iPhone Analytics and check again after a day or two.",
                    "Not every file contains battery data. The app tries the 10 newest files and uses the first one that does.",
                    "If the folder is in iCloud Drive, open it in the Files app first so the newest file finishes downloading.",
                    "The file contains your device ID and carrier name, so do not share it publicly."
                ], numbered: false)
            }
        }
    }

    private func lines(_ items: [String], numbered: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, text in
                Text(numbered ? "\(index + 1). \(text)" : "• \(text)")
            }
        }
        .font(.footnote)
        .padding(.vertical, 4)
    }

    private func healthSection(_ i: BatteryInfo) -> some View {
        Section("Battery health") {
            row("Maximum capacity", i.maxCapacityPercent.map { "\($0)%" })
            row("Cycle count", i.cycleCount.map(String.init))
            row("Nominal charge capacity", i.nominalChargeCapacity.map { "\($0) mAh" })
            row("Raw max capacity", i.rawMaxCapacity.map { "\($0) mAh" })
            row("Full charge capacity (max)", i.maxFCC.map { "\($0) mAh" })
            row("Full charge capacity (min)", i.minFCC.map { "\($0) mAh" })
        }
    }

    private func dailySection(_ i: BatteryInfo) -> some View {
        Section("Daily readings") {
            row("Highest charge", i.dailyMaxSoc.map { "\($0)%" })
            row("Lowest charge", i.dailyMinSoc.map { "\($0)%" })
            row("Average temperature", i.averageTemperature.map { "\($0) °C" })
            row("Max pack voltage", i.maxPackVoltage.map { "\($0) mV" })
            row("Min pack voltage", i.minPackVoltage.map { "\($0) mV" })
        }
    }

    private func fileInfoSection(_ i: BatteryInfo) -> some View {
        Section("Report details") {
            row("iOS version", i.osVersion)
            row("Report time", i.reportTimestamp)
            row("Battery data updated",
                i.lastUpdate.map { $0.formatted(date: .abbreviated, time: .shortened) })
        }
    }

    // MARK: - Helpers

    private func row(_ title: String, _ value: String?) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value ?? "n/a").foregroundStyle(.secondary)
        }
    }

    private func updateLive() {
        let device = UIDevice.current
        monitoringOn = device.isBatteryMonitoringEnabled
        level = device.batteryLevel

        switch device.batteryState {
        case .charging:  state = "Charging"
        case .full:      state = "Full"
        case .unplugged: state = "On battery"
        default:         state = "Unknown"
        }
        pluggedIn = (device.batteryState == .charging || device.batteryState == .full)

        let process = ProcessInfo.processInfo
        lowPowerMode = process.isLowPowerModeEnabled
        switch process.thermalState {
        case .nominal:  thermal = "Nominal"
        case .fair:     thermal = "Fair"
        case .serious:  thermal = "Serious"
        case .critical: thermal = "Critical"
        @unknown default: thermal = "Unknown"
        }

        lastChecked = Date()
    }

    // MARK: - Folder handling

    /// Remember the folder the user picked, so we can reopen it next launch.
    private func saveFolder(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Could not open the folder."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try url.bookmarkData(options: [],
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
            folderName = url.lastPathComponent
        } catch {
            errorMessage = "Could not remember the folder: \(error.localizedDescription)"
        }
    }

    /// Open the remembered folder, find the newest analytics file that
    /// contains battery data, and parse it.
    private func loadLatestFromFolder() {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        errorMessage = nil

        var stale = false
        guard let folder = try? URL(resolvingBookmarkData: data,
                                    options: [],
                                    relativeTo: nil,
                                    bookmarkDataIsStale: &stale) else {
            errorMessage = "The saved folder is no longer available. Choose it again."
            return
        }
        guard folder.startAccessingSecurityScopedResource() else {
            errorMessage = "Could not open the saved folder. Choose it again."
            return
        }
        defer { folder.stopAccessingSecurityScopedResource() }

        if stale, let fresh = try? folder.bookmarkData(options: [],
                                                       includingResourceValuesForKeys: nil,
                                                       relativeTo: nil) {
            UserDefaults.standard.set(fresh, forKey: bookmarkKey)
        }
        folderName = folder.lastPathComponent

        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: nil)) ?? []

        // File names contain the date (Analytics-2026-10-07-...), so sorting
        // by name, newest first, finds the latest file.
        let candidates = files
            .filter {
                let n = $0.lastPathComponent
                return n.hasPrefix("Analytics") || n.hasPrefix("log-aggregated")
            }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
            .prefix(10)

        if candidates.isEmpty {
            errorMessage = "No analytics files found in this folder."
            return
        }

        // Not every file has battery data, so try newest first until one works.
        for file in candidates {
            if let text = try? String(contentsOf: file, encoding: .utf8),
               let parsed = BatteryParser.parse(text) {
                info = parsed
                sourceName = file.lastPathComponent
                return
            }
        }
        info = nil
        sourceName = nil
        errorMessage = "No battery data found in the latest files."
    }

    // MARK: - Single file import (kept as a backup)

    private func handleSingleFile(_ result: Result<URL, Error>) {
        errorMessage = nil
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                errorMessage = "Could not open the file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                errorMessage = "Could not read the file as text."
                return
            }
            if let parsed = BatteryParser.parse(text) {
                info = parsed
                sourceName = url.lastPathComponent
            } else {
                info = nil
                errorMessage = "No battery data found in this file."
            }
        }
    }
}

#Preview {
    ContentView()
}
