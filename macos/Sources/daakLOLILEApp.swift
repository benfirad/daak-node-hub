import SwiftUI
import AppKit
import Foundation

private struct RelayStatus: Decodable {
    struct Permissions: Decodable {
        let power: Bool?
        let memory: Bool?
    }

    struct Service: Decodable {
        let running: Bool
    }

    struct Port: Decodable {
        let listening: Bool
    }

    struct Consensus: Decodable {
        let found: Bool
        let running: Bool
    }

    struct Configuration: Decodable {
        let nickname: String
        let contactInfo: String?
        let nonExit: Bool
        let rateMbps: Int
        let burstMbps: Int
    }

    struct Traffic: Decodable {
        let read: Double
        let write: Double
        let total: Double
        let quota: Double
        let unlimited: Bool?
        let period: String?
    }

    struct Snowflake: Decodable {
        struct Traffic: Decodable {
            let inbound: Double
            let outbound: Double
            let total: Double
            let connections: Double
        }

        let running: Bool
        let capacity: Int
        let natType: String
        let traffic: Traffic
    }

    struct Support: Decodable {
        let total: Double
        let activeProjects: Int?
    }

    struct Volunteer: Decodable {
        struct Folding: Decodable {
            let installed: Bool
            let running: Bool
            let state: String
            let detail: String
            let completedWorkUnitsObserved: Int?
        }

        struct Boinc: Decodable {
            struct Project: Decodable {
                let name: String
                let url: String?
            }

            let installed: Bool
            let running: Bool
            let state: String
            let detail: String
            let projects: [Project]?
            let activeTasks: Int?
        }

        struct RipeAtlas: Decodable {
            let installed: Bool
            let running: Bool
            let registered: Bool
            let state: String
            let detail: String
        }

        let available: Bool?
        let folding: Folding
        let boinc: Boinc
        let ripeAtlas: RipeAtlas
    }

    struct PowerMode: Decodable {
        let available: Bool
        let controlMode: String
        let effectiveMode: String
        let nightStart: String
        let nightEnd: String
    }

    struct MemoryMaintenance: Decodable {
        struct Schedule: Decodable {
            let dailyAt: String
            let runsWithoutLogin: Bool
        }

        let available: Bool
        let decision: String
        let message: String
        let pressureDetected: Bool
        let updatedAt: String?
        let reclaimedBytes: Double?
        let schedule: Schedule
    }

    struct Hardware: Decodable {
        struct Power: Decodable {
            let wallEstimateWatts: Double?
            let wallEstimateLowWatts: Double?
            let wallEstimateHighWatts: Double?
            let todayKWh: Double?
            let monthKWh: Double?
        }

        struct Processor: Decodable {
            let loadPercent: Double?
            let temperatureC: Double?
            let powerWatts: Double?
            let powerSource: String?
        }

        struct Graphics: Decodable {
            let loadPercent: Double?
            let temperatureC: Double?
            let powerWatts: Double?
            let powerSource: String?
        }

        struct Memory: Decodable {
            let loadPercent: Double?
            let usedBytes: Double?
            let totalBytes: Double?
        }

        struct NetworkGroup: Decodable {
            struct Adapter: Decodable {
                let downloadBytesPerSecond: Double?
                let uploadBytesPerSecond: Double?
            }

            let ethernet: Adapter?
            let tailscale: Adapter?
        }

        let available: Bool
        let ageSeconds: Double?
        let power: Power?
        let cpu: Processor?
        let gpu: Graphics?
        let memory: Memory?
        let network: NetworkGroup?
    }

    struct Electricity: Decodable {
        struct Tariff: Decodable {
            let location: String
            let subscriberGroup: String
            let effectiveFrom: String
            let lowTierDailyKWh: Double
            let lowTierTryPerKWh: Double
            let highTierTryPerKWh: Double
            let skttAnnualKWh: Double
        }

        struct Impact: Decodable {
            let kWh: Double
            let lowTierTry: Double
            let highTierTry: Double
        }

        struct AnnualImpact: Decodable {
            let kWh: Double
            let lowTierTry: Double
            let highTierTry: Double
            let skttPercent: Double
        }

        struct ScheduleRecommendation: Decodable {
            let ecoStart: String
            let ecoEnd: String
            let basis: String
            let standardTariffSamePriceAllDay: Bool
            let snowflakeAlwaysOn: Bool
        }

        let available: Bool
        let tariff: Tariff
        let today: Impact
        let month: Impact
        let runRate30Days: Impact
        let runRateAnnual: AnnualImpact
        let scheduleRecommendation: ScheduleRecommendation?
    }

    let updatedAt: String
    let permissions: Permissions?
    let service: Service
    let port: Port
    let bootstrap: Int
    let consensus: Consensus
    let config: Configuration
    let traffic: Traffic
    let snowflake: Snowflake?
    let support: Support?
    let hardware: Hardware?
    let electricity: Electricity?
    let power: PowerMode?
    let memoryMaintenance: MemoryMaintenance?
    let volunteer: Volunteer?
}

private struct NodeStatus: Decodable {
    let schema: Int
    let state: String
    let updatedAt: TimeInterval
    let lastSuccessAt: TimeInterval
    let consecutiveFailures: Int
    let lastError: String?
}

private struct CommandResult: Sendable {
    let exitCode: Int32
    let output: String
}

private enum LocalCommand {
    static func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                return CommandResult(
                    exitCode: process.terminationStatus,
                    output: String(decoding: data, as: UTF8.self)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } catch {
                return CommandResult(exitCode: 127, output: error.localizedDescription)
            }
        }.value
    }

    static func launch(_ executable: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        try process.run()
    }
}

@MainActor
private final class NodeMonitor: ObservableObject {
    @Published private(set) var status: NodeStatus?
    @Published private(set) var lastError: String?
    @Published private(set) var actionMessage: String?
    @Published private(set) var isRefreshing = false
    @Published var host: String

    private let hostKey = "daakNodeHost"
    private let sshPort = "8022"
    private let adbPort = "5555"
    private var timer: Timer?

    init() {
        host = UserDefaults.standard.string(forKey: hostKey) ?? ""
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        Task { await refresh() }
    }

    deinit {
        timer?.invalidate()
    }

    var isOnline: Bool { status != nil }
    var hasLocation: Bool { (status?.lastSuccessAt ?? 0) > 0 }

    var stateLabel: String {
        guard let status else { return "Bağlantı bekleniyor" }
        switch status.state {
        case "ready": return "Konum hazır"
        case "waiting-for-gps": return "GPS sabitleniyor"
        case "permission-required": return "Konum izni gerekli"
        default: return status.state.replacingOccurrences(of: "-", with: " ").capitalized
        }
    }

    var lastLocationLabel: String {
        guard let timestamp = status?.lastSuccessAt, timestamp > 0 else {
            return "Henüz gerçek GPS koordinatı alınmadı"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: Date(timeIntervalSince1970: timestamp), relativeTo: Date())
    }

    func saveAndRefresh() async {
        host = Self.cleanedHost(host)
        UserDefaults.standard.set(host, forKey: hostKey)
        status = nil
        lastError = nil
        await refresh()
    }

    func refresh() async {
        guard Self.isSafeHost(host) else {
            status = nil
            lastError = "DAAK NODE Tailscale IP’si geçerli değil."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }
        let result = await LocalCommand.run("/usr/bin/ssh", sshArguments(remoteCommand: ".local/bin/daak-find status"))
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(NodeStatus.self, from: data) else {
            status = nil
            lastError = "S9’a ulaşılamadı. Tailscale ve Termux SSH bağlantısını kontrol et."
            return
        }
        status = decoded
        lastError = nil
    }

    func openFind() async {
        guard hasLocation else {
            actionMessage = "Harita için önce gerçek bir GPS koordinatı gerekiyor."
            return
        }
        let result = await LocalCommand.run(NSHomeDirectory() + "/.local/bin/daak-find", ["open"])
        actionMessage = result.exitCode == 0
            ? "DAAK NODE haritada açıldı."
            : "Konum açılamadı: \(result.output)"
    }

    func openLiveScreen() async {
        guard Self.isSafeHost(host) else { return }
        actionMessage = "S9 ekranına bağlanılıyor…"
        let serial = "\(host):\(adbPort)"
        let adb = await LocalCommand.run("/opt/homebrew/bin/adb", ["connect", serial])
        guard adb.exitCode == 0 else {
            actionMessage = "ADB bağlantısı kurulamadı: \(adb.output)"
            return
        }
        do {
            try LocalCommand.launch(
                "/opt/homebrew/bin/scrcpy",
                ["--serial", serial, "--no-audio", "--stay-awake", "--window-title", "DAAK NODE · Galaxy S9+"]
            )
            actionMessage = "Canlı ekran açıldı."
        } catch {
            actionMessage = "Canlı ekran açılamadı: \(error.localizedDescription)"
        }
    }

    func openSSH() {
        guard Self.isSafeHost(host), let url = URL(string: "ssh://\(host):\(sshPort)") else { return }
        NSWorkspace.shared.open(url)
        actionMessage = "S9 terminali açılıyor."
    }

    private func sshArguments(remoteCommand: String) -> [String] {
        [
            "-p", sshPort,
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=4",
            "-o", "ConnectionAttempts=1",
            "-o", "ServerAliveInterval=10",
            "-o", "StrictHostKeyChecking=yes",
            host,
            remoteCommand
        ]
    }

    private static func cleanedHost(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "ssh://", with: "", options: [.caseInsensitive, .anchored])
            .split(separator: ":", maxSplits: 1)
            .first
            .map(String.init) ?? ""
    }

    private static func isSafeHost(_ value: String) -> Bool {
        let pattern = #"^[A-Za-z0-9](?:[A-Za-z0-9.-]{0,251}[A-Za-z0-9])?$"#
        return value.range(of: pattern, options: .regularExpression) != nil
    }
}

@MainActor
private final class RelayMonitor: ObservableObject {
    @Published private(set) var status: RelayStatus?
    @Published private(set) var lastError: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSettingPower = false
    @Published private(set) var isMaintainingMemory = false
    @Published var host: String

    private var timer: Timer?
    private let hostKey = "daaklolileHost"
    private let legacyHostKey = "lolileHost"

    init() {
        host = UserDefaults.standard.string(forKey: hostKey)
            ?? UserDefaults.standard.string(forKey: legacyHostKey)
            ?? ""
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        Task { await refresh() }
    }

    deinit {
        timer?.invalidate()
    }

    var isOnline: Bool {
        guard let status else { return false }
        return status.service.running && status.port.listening && status.bootstrap >= 100
    }

    var isConnected: Bool {
        status != nil
    }

    var menuTitle: String {
        guard let status else { return "daakLOLILE —" }
        if status.hardware?.available == true,
           let watts = status.hardware?.power?.wallEstimateWatts {
            return "daakLOLILE \(String(format: "%.0f W", watts))"
        }
        return "daakLOLILE \(Self.formatGigabytes(status.support?.total ?? status.traffic.total))"
    }

    var baseURL: URL? {
        Self.makeBaseURL(from: host)
    }

    func saveAndRefresh() async {
        host = Self.cleanedHost(host)
        UserDefaults.standard.set(host, forKey: hostKey)
        status = nil
        lastError = nil
        await refresh()
    }

    func refresh() async {
        guard let baseURL else {
            lastError = host.isEmpty ? "Önce Windows PC’nin Tailscale IP’sini yaz." : "IP adresi geçerli değil."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let url = baseURL.appendingPathComponent("api/status")
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = 8
            request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw MonitorError.badResponse
            }
            let decoded = try JSONDecoder().decode(RelayStatus.self, from: data)
            status = decoded
            lastError = nil
        } catch {
            lastError = "PC’ye ulaşılamadı. İki cihazda da Tailscale’in açık olduğundan emin ol."
        }
    }

    func openDashboard() {
        guard let baseURL else { return }
        NSWorkspace.shared.open(baseURL)
    }

    func setPowerMode(_ mode: String) async {
        guard let baseURL, status?.permissions?.power == true else { return }
        isSettingPower = true
        defer { isSettingPower = false }
        do {
            let url = baseURL.appendingPathComponent("api/power")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 12
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["mode": mode])
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw MonitorError.badResponse
            }
            await refresh()
        } catch {
            lastError = "Güç modu değiştirilemedi. Tailscale bağlantısını kontrol et."
        }
    }

    func maintainMemory() async {
        guard let baseURL, status?.permissions?.memory == true else { return }
        isMaintainingMemory = true
        defer { isMaintainingMemory = false }
        do {
            let url = baseURL.appendingPathComponent("api/memory/maintain")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 20
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")
            request.httpBody = Data("{}".utf8)
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                throw MonitorError.badResponse
            }
            await refresh()
        } catch {
            lastError = "Bellek bakımı başlatılamadı. Tailscale bağlantısını kontrol et."
        }
    }

    static func formatBytes(_ bytes: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .decimal
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(max(0, bytes)))
    }

    static func formatGigabytes(_ bytes: Double) -> String {
        let value = max(0, bytes) / 1_000_000_000
        if value >= 100 { return String(format: "%.0f GB", value) }
        if value >= 10 { return String(format: "%.1f GB", value) }
        return String(format: "%.2f GB", value)
    }

    static func formatPercent(_ value: Double?) -> String {
        String(format: "%%%.0f", max(0, value ?? 0))
    }

    static func formatTemperature(_ value: Double?) -> String {
        guard let value else { return "sensör yok" }
        return String(format: "%.0f°C", value)
    }

    static func formatPower(_ value: Double?, estimated: Bool = false) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f W%@", value, estimated ? " tah." : "")
    }

    static func formatCostRange(low: Double, high: Double) -> String {
        String(format: "₺%.2f–%.2f", max(0, low), max(0, high))
    }

    static func formatRate(_ bytes: Double?) -> String {
        "\(formatBytes(max(0, bytes ?? 0)))/sn"
    }

    static func volunteerState(_ state: String, running: Bool) -> String {
        if running {
            switch state {
            case "working": return "İşliyor"
            case "measuring": return "Ölçüm yapıyor"
            default: return "Çalışıyor"
            }
        }
        switch state {
        case "account-required": return "Hesap bekliyor"
        case "windows-feature-required": return "WSL bekliyor"
        case "distro-required": return "Linux bekliyor"
        case "reboot-required": return "Yeniden başlatma bekliyor"
        case "probe-install-required": return "Prob bekliyor"
        case "not-installed": return "Kurulum bekliyor"
        case "stopped": return "Kapalı"
        case "error": return "Hata"
        default: return "Hazırlanıyor"
        }
    }

    private static func cleanedHost(_ value: String) -> String {
        var cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "http://", with: "", options: [.caseInsensitive, .anchored])
        cleaned = cleaned.replacingOccurrences(of: "https://", with: "", options: [.caseInsensitive, .anchored])
        if let slash = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slash])
        }
        if cleaned.hasSuffix(":17657") {
            cleaned.removeLast(6)
        }
        return cleaned
    }

    private static func makeBaseURL(from value: String) -> URL? {
        let cleaned = cleanedHost(value)
        guard !cleaned.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "http"
        components.host = cleaned
        components.port = 17657
        return components.url
    }

    private enum MonitorError: Error {
        case badResponse
    }
}

private struct StatusPill: View {
    let online: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(online ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(online ? "PC bağlı" : "Bağlantı bekleniyor")
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.quaternary, in: Capsule())
    }
}

private struct MetricRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontDesign(.monospaced)
                .textSelection(.enabled)
        }
        .font(.callout)
    }
}

private enum DevicePanel: String, CaseIterable, Identifiable {
    case devices
    case lolile
    case node

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: return "Cihazlar"
        case .lolile: return "LOLİLE"
        case .node: return "S9+"
        }
    }
}

private struct DeviceCard: View {
    let name: String
    let detail: String
    let symbol: String
    let online: Bool
    let status: String
    let actionTitle: String
    let action: () -> Void
    let openDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: openDetails) {
                HStack(spacing: 12) {
                    Image(systemName: symbol)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(online ? Color.green : Color.orange)
                        .frame(width: 38, height: 38)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(name)
                            .font(.headline)
                        Text(detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 5) {
                        Circle()
                            .fill(online ? Color.green : Color.orange)
                            .frame(width: 8, height: 8)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(13)
        .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct DeviceOverviewView: View {
    @EnvironmentObject private var relay: RelayMonitor
    @EnvironmentObject private var node: NodeMonitor
    @Binding var selection: DevicePanel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tüm cihazların tek güvenli merkezde")
                .font(.caption)
                .foregroundStyle(.secondary)

            DeviceCard(
                name: "LOLİLE",
                detail: "Windows · Relay · Uzaktan kontrol",
                symbol: "desktopcomputer",
                online: relay.isConnected,
                status: relay.isConnected ? "Tailscale üzerinden bağlı" : "Bağlantı bekleniyor",
                actionTitle: "Paneli aç",
                action: relay.openDashboard,
                openDetails: { selection = .lolile }
            )

            DeviceCard(
                name: "DAAK NODE",
                detail: "Galaxy S9+ · Find · SSH · Canlı ekran",
                symbol: "iphone",
                online: node.isOnline,
                status: node.stateLabel,
                actionTitle: "Ekranı aç",
                action: { Task { await node.openLiveScreen() } },
                openDetails: { selection = .node }
            )

            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BU MAC")
                        .font(.caption.weight(.semibold))
                    Text("DAAK cihaz kontrol merkezi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Yerel")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)

            Divider()

            HStack {
                Button {
                    Task {
                        async let relayRefresh: Void = relay.refresh()
                        async let nodeRefresh: Void = node.refresh()
                        _ = await (relayRefresh, nodeRefresh)
                    }
                } label: {
                    Label("Tümünü yenile", systemImage: "arrow.clockwise")
                }
                .disabled(relay.isRefreshing || node.isRefreshing)

                Spacer()

                Button("Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
    }
}

private struct NodeMenuView: View {
    @EnvironmentObject private var node: NodeMonitor
    @State private var draftHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DAAK NODE")
                        .font(.headline)
                    Text("Galaxy S9+ · özel Tailscale hattı")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(node.isOnline ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(node.isOnline ? "Bağlı" : "Bekleniyor")
                        .font(.caption.weight(.medium))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Image(systemName: node.hasLocation ? "location.fill" : "location.slash")
                        .foregroundStyle(node.hasLocation ? Color.green : Color.orange)
                    Text(node.stateLabel)
                        .font(.headline)
                }
                Text(node.lastLocationLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let detail = node.status?.lastError, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 8) {
                Button {
                    Task { await node.openFind() }
                } label: {
                    Label("Haritada bul", systemImage: "map")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!node.hasLocation)

                Button {
                    Task { await node.openLiveScreen() }
                } label: {
                    Label("Canlı ekran", systemImage: "rectangle.inset.filled.and.person.filled")
                }
                .buttonStyle(.bordered)
                .disabled(!node.isOnline)

                Button {
                    node.openSSH()
                } label: {
                    Label("SSH", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .disabled(!node.isOnline)
            }

            if let message = node.actionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let error = node.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("S9+ · Tailscale IP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("100.x.x.x", text: $draftHost)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            node.host = draftHost
                            Task { await node.saveAndRefresh() }
                        }
                    Button("Bağlan") {
                        node.host = draftHost
                        Task { await node.saveAndRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button {
                    Task { await node.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(node.isRefreshing)

                Spacer()

                Text("Konum dışarı açılmaz · yalnızca Tailnet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .onAppear { draftHost = node.host }
    }
}

private struct DAAKDevicesMenuView: View {
    @EnvironmentObject private var relay: RelayMonitor
    @EnvironmentObject private var node: NodeMonitor
    @State private var selection: DevicePanel = .devices

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "circle.grid.2x2.fill")
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 1) {
                    Text("DAAK NODE")
                        .font(.headline)
                    Text("Cihaz merkezi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\([relay.isConnected, node.isOnline].filter { $0 }.count)/2 bağlı")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Picker("Cihaz", selection: $selection) {
                ForEach(DevicePanel.allCases) { panel in
                    Text(panel.title).tag(panel)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            switch selection {
            case .devices:
                DeviceOverviewView(selection: $selection)
            case .lolile:
                ScrollView {
                    RelayMenuView()
                }
                .frame(maxHeight: 690)
            case .node:
                NodeMenuView()
            }
        }
        .frame(width: 420)
    }
}

private struct RelayMenuView: View {
    @EnvironmentObject private var monitor: RelayMonitor
    @State private var draftHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("daakLOLILE")
                        .font(.headline)
                    Text("Windows sistem monitörü")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(online: monitor.isConnected)
            }

            Divider()

            if let status = monitor.status {
                if let hardware = status.hardware, hardware.available {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(String(format: "%.0f", hardware.power?.wallEstimateWatts ?? 0))
                                .font(.system(size: 38, weight: .semibold, design: .rounded))
                            Text("W")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(.purple)
                        }
                        Text("Tahmini anlık priz tüketimi")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 9) {
                        MetricRow(
                            title: "CPU",
                            value: "\(RelayMonitor.formatPercent(hardware.cpu?.loadPercent)) · \(RelayMonitor.formatTemperature(hardware.cpu?.temperatureC)) · \(RelayMonitor.formatPower(hardware.cpu?.powerWatts, estimated: hardware.cpu?.powerSource != "sensor"))"
                        )
                        MetricRow(
                            title: "GPU",
                            value: "\(RelayMonitor.formatPercent(hardware.gpu?.loadPercent)) · \(RelayMonitor.formatTemperature(hardware.gpu?.temperatureC)) · \(RelayMonitor.formatPower(hardware.gpu?.powerWatts, estimated: hardware.gpu?.powerSource != "sensor"))"
                        )
                        MetricRow(
                            title: "RAM",
                            value: "\(RelayMonitor.formatPercent(hardware.memory?.loadPercent)) · \(RelayMonitor.formatBytes(hardware.memory?.usedBytes ?? 0))"
                        )
                        MetricRow(
                            title: "Ethernet",
                            value: "↓ \(RelayMonitor.formatRate(hardware.network?.ethernet?.downloadBytesPerSecond)) · ↑ \(RelayMonitor.formatRate(hardware.network?.ethernet?.uploadBytesPerSecond))"
                        )
                        MetricRow(
                            title: "Bugün / Bu ay",
                            value: String(format: "%.3f / %.3f kWh", hardware.power?.todayKWh ?? 0, hardware.power?.monthKWh ?? 0)
                        )
                    }
                } else {
                    Text("Donanım sensörleri hazırlanıyor…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Divider()

                if let electricity = status.electricity, electricity.available {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Elektrik faturası · bu ay")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(RelayMonitor.formatCostRange(
                                    low: electricity.month.lowTierTry,
                                    high: electricity.month.highTierTry
                                ))
                                .font(.headline.monospacedDigit())
                            }
                            Spacer()
                            Text(String(format: "%.3f kWh", electricity.month.kWh))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }

                        MetricRow(
                            title: "Bugün",
                            value: RelayMonitor.formatCostRange(
                                low: electricity.today.lowTierTry,
                                high: electricity.today.highTierTry
                            )
                        )
                        MetricRow(
                            title: "Bu güç 30 gün sürerse",
                            value: RelayMonitor.formatCostRange(
                                low: electricity.runRate30Days.lowTierTry,
                                high: electricity.runRate30Days.highTierTry
                            )
                        )
                        MetricRow(
                            title: "Yıllık çalışma hızı",
                            value: String(
                                format: "%.0f kWh · SKTT %%%.1f",
                                electricity.runRateAnnual.kWh,
                                electricity.runRateAnnual.skttPercent
                            )
                        )
                        Text("\(electricity.tariff.location) · düşük/yüksek mesken kademesi · akıllı priz yok, PC payı tahminidir.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if let recommendation = electricity.scheduleRecommendation {
                            Text("Puant eko \(recommendation.ecoStart)–\(recommendation.ecoEnd) · Snowflake açık kalır · tek zamanlı tarifede saatlik fiyat değişmez.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()
                }

                if let power = status.power, power.available {
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Güç modu")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(powerModeLabel(power.effectiveMode))
                                    .font(.headline)
                            }
                            Spacer()
                            Text(power.controlMode == "auto" ? "Puant \(power.nightStart)–\(power.nightEnd)" : "Elle seçildi")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 6) {
                            powerButton("Oto", mode: "auto", selected: power.controlMode == "auto")
                            powerButton("Eko", mode: "eco", selected: power.controlMode == "eco")
                            powerButton("Denge", mode: "balanced", selected: power.controlMode == "balanced")
                            powerButton("Hız", mode: "performance", selected: power.controlMode == "performance")
                        }

                        Text("Uyku kapalıdır; Tor, Tailscale, uzaktan masaüstü ve disk paylaşımı çalışmaya devam eder.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                if let memory = status.memoryMaintenance, memory.available {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Güvenli RAM bakımı")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(memory.pressureDetected ? "Bellek baskısı izlendi" : "RAM dengeli")
                                    .font(.headline)
                            }
                            Spacer()
                            Button(monitor.isMaintainingMemory ? "Bakım yapılıyor…" : "Şimdi bakım") {
                                Task { await monitor.maintainMemory() }
                            }
                            .disabled(
                                monitor.isMaintainingMemory ||
                                status.permissions?.memory != true
                            )
                        }

                        Text("Her gün \(memory.schedule.dailyAt) · Windows önbelleği, Tor ve uzaktan bağlantılar korunur.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                if let volunteer = status.volunteer {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Gönüllü projeler")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("\(status.support?.activeProjects ?? 0)/4 aktif")
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        MetricRow(
                            title: "Folding@home",
                            value: RelayMonitor.volunteerState(volunteer.folding.state, running: volunteer.folding.running)
                        )
                        MetricRow(
                            title: "BOINC",
                            value: RelayMonitor.volunteerState(volunteer.boinc.state, running: volunteer.boinc.running)
                        )
                        MetricRow(
                            title: "RIPE Atlas",
                            value: RelayMonitor.volunteerState(volunteer.ripeAtlas.state, running: volunteer.ripeAtlas.running)
                        )
                        Text("Snowflake 7/24; bilimsel işler kontrollü kaynaklarla. Genel disk paylaşımı yok.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Divider()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Ağ desteği")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(RelayMonitor.formatGigabytes(status.support?.total ?? status.traffic.total))
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                }

                VStack(spacing: 9) {
                    MetricRow(title: "Middle relay", value: RelayMonitor.formatBytes(status.traffic.total))
                    MetricRow(
                        title: "Snowflake",
                        value: status.snowflake?.running == true
                            ? "\(RelayMonitor.formatBytes(status.snowflake?.traffic.total ?? 0)) · aktif"
                            : "Kapalı"
                    )
                    MetricRow(title: "Eşleşme", value: "Tor talebine göre")
                    Text("Bağlantı oturumları benzersiz kişi sayısı değildir; gizlilik gereği kişi tahmini gösterilmez.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    MetricRow(
                        title: "Aylık kota",
                        value: (status.traffic.unlimited ?? (status.traffic.quota <= 0))
                            ? "Sınırsız"
                            : RelayMonitor.formatBytes(status.traffic.quota)
                    )
                    MetricRow(title: "Hız", value: "\(status.config.rateMbps) / \(status.config.burstMbps) Mbps")
                    MetricRow(title: "Bootstrap", value: "%\(status.bootstrap)")
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(monitor.lastError ?? "Relay durumu alınıyor…")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
            }

            if let error = monitor.lastError, monitor.status != nil {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                Text("Windows PC · Tailscale IP")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    TextField("100.x.x.x", text: $draftHost)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit {
                            monitor.host = draftHost
                            Task { await monitor.saveAndRefresh() }
                        }
                    Button("Bağlan") {
                        monitor.host = draftHost
                        Task { await monitor.saveAndRefresh() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            HStack {
                Button {
                    Task { await monitor.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(monitor.isRefreshing)

                Button {
                    monitor.openDashboard()
                } label: {
                    Label("Paneli aç", systemImage: "safari")
                }
                .disabled(monitor.baseURL == nil)

                Spacer()

                Button("Çıkış") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .frame(width: 390)
        .onAppear {
            draftHost = monitor.host
        }
    }

    private func powerButton(_ title: String, mode: String, selected: Bool) -> some View {
        Button(title) {
            Task { await monitor.setPowerMode(mode) }
        }
        .buttonStyle(.bordered)
        .tint(selected ? .green : .purple)
        .disabled(monitor.isSettingPower || monitor.status?.permissions?.power != true)
    }

    private func powerModeLabel(_ mode: String) -> String {
        switch mode {
        case "eco": return "Derin eko"
        case "performance": return "Yüksek performans"
        case "balanced": return "Dengeli"
        default: return "Hazırlanıyor"
        }
    }
}

@main
struct daakLOLILEApp: App {
    @StateObject private var relay = RelayMonitor()
    @StateObject private var node = NodeMonitor()

    var body: some Scene {
        MenuBarExtra {
            DAAKDevicesMenuView()
                .environmentObject(relay)
                .environmentObject(node)
        } label: {
            Image(systemName: "circle.grid.2x2.fill")
                .accessibilityLabel("DAAK NODE cihaz merkezi")
        }
        .menuBarExtraStyle(.window)
    }
}
