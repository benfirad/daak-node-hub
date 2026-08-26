import SwiftUI
import AppKit
import Combine
import Foundation
@preconcurrency import CoreLocation
import UserNotifications
import LocalAuthentication

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
    let provider: String?
    let accuracyMeters: Double?
}

private struct NodeLocation: Decodable, Equatable {
    let provider: String
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double
    let capturedAt: TimeInterval
}

private struct NodeDeviceHealth: Decodable, Sendable {
    let batteryPercent: Int?
    let batteryTemperatureC: Double?
    let cpuTemperatureC: Double?
    let memoryFreePercent: Int?
    let powerLabel: String?
}

private struct LocalMacHealth: Decodable, Sendable {
    let batteryPercent: Int?
    let batteryTemperatureC: Double?
    let cpuTemperatureC: Double?
    let memoryFreePercent: Int?
    let powerLabel: String
}

private struct MYAL11Status: Decodable {
    struct Services: Decodable {
        let tailscale: Bool
        let ssh: Bool
        let screenSharing: Bool
        let stats: Bool?
        let keepingYouAwake: Bool
        let awaykeProcess: Bool
        let awaykeActive: Bool
        let caffeinateGuard: Bool
        let daakRemember: Bool?
        let daakRememberSync: Bool?
        let mail: Bool?
        let webmail: Bool?
        let mailGateway: Bool?
        let adblock: Bool?
        let listmonk: Bool?
        let diskShare: Bool?
    }

    let updatedAt: String
    let name: String
    let model: String
    let tailscaleIP: String
    let powerSource: String
    let batteryPercent: Int
    let batteryMinutesRemaining: Int?
    let upsState: String?
    let upsMessage: String?
    let batteryCondition: String
    let batteryCycles: Int
    let diskFreeKB: Int64
    let memoryFreePercent: Int
    let loadAverage: String
    let uptime: String
    let dockerContainersRunning: Int
    let cpuUsagePercent: Double?
    let cpuTemperatureC: Double?
    let gpuTemperatureC: Double?
    let diskUsedPercent: Double?
    let services: Services

    // JSONDecoder's convertFromSnakeCase preserves neither acronym spelling:
    // `tailscale_ip` becomes `tailscaleIp` and `disk_free_kb` becomes
    // `diskFreeKb`. Map these two required acronym fields explicitly so a
    // valid telemetry payload does not fail as a whole.
    enum CodingKeys: String, CodingKey {
        case updatedAt
        case name
        case model
        case tailscaleIP = "tailscaleIp"
        case powerSource
        case batteryPercent
        case batteryMinutesRemaining
        case upsState
        case upsMessage
        case batteryCondition
        case batteryCycles
        case diskFreeKB = "diskFreeKb"
        case memoryFreePercent
        case loadAverage
        case uptime
        case dockerContainersRunning
        case cpuUsagePercent
        case cpuTemperatureC
        case gpuTemperatureC
        case diskUsedPercent
        case services
    }
}

private struct LinuxRuntimeStatus: Decodable {
    let displayName: String
    let driver: String
    let arch: String
    let runtime: String
    let mountType: String
    let cpu: Int
    let memory: Int64
    let disk: Int64
}

private struct DockerContainerStatus: Identifiable {
    var id: String { name }
    let name: String
    let image: String
    let state: String
    let status: String
    let cpuPercent: String?
    let memoryUsage: String?
    let memoryPercent: String?

    var isHealthy: Bool {
        state == "running" && !status.localizedCaseInsensitiveContains("unhealthy")
    }

    var purpose: String {
        switch name {
        case "stalwart": return "Mail, IMAP, SMTP ve takvim çekirdeği"
        case "roundcube": return "Webmail arayüzü"
        case "mail-inbound-gateway": return "Gelen mail yönlendiricisi"
        case "mail-public-gateway": return "Dış bağlantı geçidi"
        case "mail-cloudflared": return "Cloudflare güvenli tüneli"
        case "listmonk": return "Toplu mail ve otomasyon"
        case "listmonk_db": return "Kampanya veritabanı"
        case "mailpit": return "Güvenli test posta kutusu"
        case "portainer": return "Konteyner yönetim paneli"
        case "daak-adguard": return "DNS ve reklam engelleme"
        default: return image
        }
    }
}

private struct FastDropStatus: Decodable {
    let updatedAt: TimeInterval
    let state: String
    let mounted: Bool
    let capacityBytes: Int64
    let usedBytes: Int64
    let availableBytes: Int64
    let incomingFiles: Int
    let incomingBytes: Int64
    let retainedFiles: Int
    let retainedBytes: Int64
    let currentFile: String?
    let lastSuccessAt: TimeInterval?
    let lastError: String?
}

private struct TailnetStatus: Decodable {
    struct ExitNodeStatus: Decodable {
        let tailscaleIPs: [String]?

        enum CodingKeys: String, CodingKey {
            case tailscaleIPs = "TailscaleIPs"
        }
    }

    struct Peer: Decodable {
        let tailscaleIPs: [String]?
        let exitNodeOption: Bool?

        enum CodingKeys: String, CodingKey {
            case tailscaleIPs = "TailscaleIPs"
            case exitNodeOption = "ExitNodeOption"
        }
    }

    let exitNodeStatus: ExitNodeStatus?
    let peers: [String: Peer]

    enum CodingKeys: String, CodingKey {
        case exitNodeStatus = "ExitNodeStatus"
        case peers = "Peer"
    }
}

private struct CommandResult: Sendable {
    let exitCode: Int32
    let output: String
}

private struct UpdateCommandResult: Decodable {
    let status: String
    let current: String
    let latest: String
    let message: String
}

private struct NodeConfiguration: Decodable {
    let directHost: String?
    let tailHost: String?
    let webmailURL: String?
    let mailAdminURL: String?
    let campaignsURL: String?
    let mailPreviewURL: String?
    let containerPanelURL: String?
    let dnsPanelURL: String?
    let brevoSMTPURL: String?
    let brevoDomainsURL: String?
    let brevoSMTPHost: String?
    let brevoSMTPPort: Int?
    let brevoSMTPLogin: String?
    let inboundProvider: String?
    let inboundMX: String?
    let wakeMAC: String?
    let wakeBroadcasts: [String]?

    static func load() -> NodeConfiguration? {
        let path = NSHomeDirectory() + "/Library/Application Support/DAAK/node-config.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return try? JSONDecoder().decode(NodeConfiguration.self, from: data)
    }
}

private struct MailAccountList: Decodable {
    struct Account: Decodable, Identifiable {
        var id: String { address }
        let address: String
        let displayName: String
        let passwordStored: Bool
        let quotaBytes: Int64
        let usedBytes: Int64
    }

    struct Server: Decodable {
        struct Endpoint: Decodable {
            let host: String
            let port: Int
            let security: String
            let authentication: Bool?
        }

        let imap: Endpoint
        let smtp: Endpoint
        let caldav: String
        let carddav: String
        let webmail: String
        let accountManager: String
        let networkRequirement: String
    }

    let accounts: [Account]
    let server: Server
}

private struct MailCredential: Decodable {
    let address: String
    let password: String
}

private enum LocalCommand {
    private static var environment: [String: String] {
        let inherited = ProcessInfo.processInfo.environment
        var value: [String: String] = [
            "HOME": NSHomeDirectory(),
            "USER": NSUserName(),
            "LOGNAME": NSUserName(),
            "PATH": "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
            "ADB": "/opt/homebrew/bin/adb",
            "LANG": inherited["LANG"] ?? "en_US.UTF-8",
            "TMPDIR": inherited["TMPDIR"] ?? "/tmp"
        ]
        if let socket = inherited["SSH_AUTH_SOCK"], !socket.isEmpty {
            value["SSH_AUTH_SOCK"] = socket
        }
        return value
    }

    static func run(_ executable: String, _ arguments: [String]) async -> CommandResult {
        await Task.detached(priority: .utility) {
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = pipe
            process.standardError = pipe

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
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
        process.environment = environment
        try process.run()
    }

    static func run(_ executable: String, _ arguments: [String], input: String) async -> CommandResult {
        await Task.detached(priority: .userInitiated) {
            let process = Process()
            let output = Pipe()
            let stdin = Pipe()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.environment = environment
            process.standardOutput = output
            process.standardError = output
            process.standardInput = stdin
            do {
                try process.run()
                stdin.fileHandleForWriting.write(Data(input.utf8))
                try? stdin.fileHandleForWriting.close()
                let data = output.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
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
}

@MainActor
private final class UpdateMonitor: ObservableObject {
    @Published private(set) var state = "Hazır"
    @Published private(set) var message = "Güncellemeler main kanalından otomatik denetlenir."
    @Published private(set) var isWorking = false
    @Published private(set) var updateAvailable = false

    private let interval: TimeInterval = 6 * 60 * 60
    private let lastCheckKey = "DAAKNodeLastUpdateCheck"

    var versionLabel: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let commit = Bundle.main.object(forInfoDictionaryKey: "DAAKSourceCommit") as? String ?? "development"
        return "v\(version) • \(String(commit.prefix(7)))"
    }

    init() {
        Task { await checkIfDue() }
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                await checkAndInstallIfNeeded()
            }
        }
    }

    func checkNow() async {
        await runUpdater(mode: "--check", installWhenAvailable: false)
    }

    func installNow() async {
        await runUpdater(mode: "--install", installWhenAvailable: false)
    }

    private func checkIfDue() async {
        let lastCheck = UserDefaults.standard.double(forKey: lastCheckKey)
        guard Date().timeIntervalSince1970 - lastCheck >= interval else { return }
        await checkAndInstallIfNeeded()
    }

    private func checkAndInstallIfNeeded() async {
        await runUpdater(mode: "--check", installWhenAvailable: true)
    }

    private func runUpdater(mode: String, installWhenAvailable: Bool) async {
        guard !isWorking else { return }
        guard let script = Bundle.main.url(forResource: "update-daak-node", withExtension: "zsh")?.path else {
            state = "Updater eksik"
            message = "Bu sürüm güncelleme aracını içermiyor."
            return
        }

        isWorking = true
        state = mode == "--install" ? "Güncelleniyor" : "Denetleniyor"

        let command = await LocalCommand.run("/bin/zsh", [script, mode])
        guard let line = command.output.split(separator: "\n").last,
              let data = String(line).data(using: .utf8),
              let result = try? JSONDecoder().decode(UpdateCommandResult.self, from: data) else {
            state = "Hata"
            message = command.output.isEmpty ? "Güncelleme aracı yanıt vermedi." : command.output
            isWorking = false
            return
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastCheckKey)
        message = result.message
        updateAvailable = result.status == "available"
        switch result.status {
        case "current": state = "Güncel"
        case "available": state = "Güncelleme hazır"
        case "installed":
            state = "Kuruldu"
            updateAvailable = false
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                NSApplication.shared.terminate(nil)
            }
        case "busy": state = "Güncelleniyor"
        case "held":
            state = "Yerel sürüm korundu"
            updateAvailable = false
        default: state = "Hata"
        }

        isWorking = false
        if installWhenAvailable && result.status == "available" {
            await runUpdater(mode: "--install", installWhenAvailable: false)
        }
    }
}

@MainActor
private final class MailAccountMonitor: ObservableObject {
    @Published private(set) var data: MailAccountList?
    @Published var selectedAddress = "begum@redmono.com"
    @Published var revealedPassword: String?
    @Published var newPassword = ""
    @Published private(set) var message: String?
    @Published private(set) var isWorking = false

    private let control = NSHomeDirectory() + "/Library/Application Support/DAAK/mail-account-control.zsh"
    private let configuration = NodeConfiguration.load()

    init() { Task { await refresh() } }

    var selectedAccount: MailAccountList.Account? {
        data?.accounts.first { $0.address == selectedAddress }
    }

    func refresh() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let result = await LocalCommand.run("/bin/zsh", [control, "list"])
        guard result.exitCode == 0,
              let payload = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(MailAccountList.self, from: payload) else {
            message = "Mail hesapları sunucudan okunamadı."
            return
        }
        data = decoded
        if !decoded.accounts.contains(where: { $0.address == selectedAddress }),
           let first = decoded.accounts.first { selectedAddress = first.address }
        message = nil
    }

    func revealOrCopy(copyOnly: Bool) async {
        guard await authenticate(reason: copyOnly ? "Mail parolasını panoya kopyalamak için doğrulayın." : "Mail parolasını göstermek için doğrulayın.") else {
            message = "Kimlik doğrulama tamamlanmadı."
            return
        }
        isWorking = true
        defer { isWorking = false }
        let result = await LocalCommand.run("/bin/zsh", [control, "show", selectedAddress])
        guard result.exitCode == 0,
              let payload = result.output.data(using: .utf8),
              let credential = try? JSONDecoder().decode(MailCredential.self, from: payload) else {
            message = "Parola okunamadı."
            return
        }
        if copyOnly {
            copySecret(credential.password)
            message = "Parola panoya kopyalandı; 2 dakika sonra otomatik temizlenecek."
        } else {
            revealedPassword = credential.password
            message = "Parola gösteriliyor; işin bitince gizle."
        }
    }

    func generatePassword() async {
        guard await authenticate(reason: "Mail parolasını güçlü yeni bir parolayla değiştirmek için doğrulayın.") else { return }
        isWorking = true
        defer { isWorking = false }
        let result = await LocalCommand.run("/bin/zsh", [control, "generate", selectedAddress])
        guard result.exitCode == 0,
              let payload = result.output.data(using: .utf8),
              let credential = try? JSONDecoder().decode(MailCredential.self, from: payload) else {
            message = "Parola değiştirilemedi; mevcut parola korunuyor."
            return
        }
        revealedPassword = credential.password
        copySecret(credential.password)
        message = "Yeni güçlü parola uygulandı, test edildi ve panoya kopyalandı."
    }

    func applyCustomPassword() async {
        guard newPassword.count >= 12 else {
            message = "Yeni parola en az 12 karakter olmalı."
            return
        }
        guard await authenticate(reason: "Seçili mail hesabının parolasını değiştirmek için doğrulayın.") else { return }
        isWorking = true
        defer { isWorking = false }
        let value = newPassword
        let result = await LocalCommand.run("/bin/zsh", [control, "set", selectedAddress], input: value + "\n")
        guard result.exitCode == 0 else {
            message = "Parola değiştirilemedi; mevcut parola korunuyor."
            return
        }
        newPassword = ""
        revealedPassword = value
        message = "Yeni parola uygulandı ve IMAP/SMTP ile doğrulandı."
    }

    func copySetup() {
        guard let server = data?.server else { return }
        let relayHost = configuration?.brevoSMTPHost ?? "smtp-relay.brevo.com"
        let relayPort = configuration?.brevoSMTPPort ?? 587
        let inboundProvider = configuration?.inboundProvider ?? "IONOS (MX geçişi yapılmadı)"
        let inboundMX = configuration?.inboundMX ?? "mx00.ionos.es / mx01.ionos.es"
        let text = """
        REDMONO MAIL KURULUMU
        E-posta / kullanıcı adı: \(selectedAddress)

        MAIL UYGULAMASINA YAZILACAK
        Gelen posta (IMAP): \(server.imap.host)
        IMAP portu: \(server.imap.port) · \(server.imap.security)
        Giden posta (SMTP): \(server.smtp.host)
        SMTP portu: \(server.smtp.port) · \(server.smtp.security) · kimlik doğrulama açık
        IMAP ve SMTP kullanıcı adı: \(selectedAddress)

        ARKA PLAN TESLİMATI
        Giden relay: Brevo · \(relayHost):\(relayPort) · STARTTLS
        Brevo bilgileri mail uygulamasına yazılmaz; MYA-L11 bunları güvenli depodan kullanır.
        Brevo IMAP veya gelen posta kutusu sağlamaz.
        redmono.com mevcut gelen MX: \(inboundProvider) · \(inboundMX)

        TAKVİM VE KİŞİLER
        CalDAV: \(server.caldav)
        CardDAV: \(server.carddav)
        Webmail: \(server.webmail)
        Parola yönetimi: \(server.accountManager)
        Gereksinim: Özel IMAP/SMTP, webmail ve takvim için cihazda Tailscale bağlı olmalı.
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        message = "Kurulum bilgileri panoya kopyalandı; parola ayrı gönderilmeli."
    }

    func hidePassword() { revealedPassword = nil }

    private func authenticate(reason: String) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Vazgeç"
        do { return try await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) }
        catch { return false }
    }

    private func copySecret(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 120_000_000_000)
            if NSPasteboard.general.string(forType: .string) == value {
                NSPasteboard.general.clearContents()
            }
        }
    }
}

@MainActor
private final class MYAL11Monitor: ObservableObject {
    enum Route: String {
        case cable = "Kablo · otomatik"
        case tailscale = "Tailscale · otomatik"
        case offline = "Bağlantı yok"
    }

    @Published private(set) var status: MYAL11Status?
    @Published private(set) var fastDrop: FastDropStatus?
    @Published private(set) var route: Route = .offline
    @Published private(set) var linuxRuntime: LinuxRuntimeStatus?
    @Published private(set) var containers: [DockerContainerStatus] = []
    @Published private(set) var infrastructureError: String?
    @Published private(set) var infrastructureUpdatedAt: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var actionMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isRunningAction = false
    @Published private(set) var isRefreshingInfrastructure = false

    private let statusPath = NSHomeDirectory() + "/Library/Application Support/DAAK/Nodes/mya-l11/status.json"
    private let fastDropStatusPath = NSHomeDirectory() + "/Library/Application Support/DAAK/Nodes/mya-l11/fastdrop-status.json"
    private let routeSelectorPath = NSHomeDirectory() + "/Library/Application Support/DAAK/mya-direct.zsh"
    private let configuration = NodeConfiguration.load()
    private var timer: Timer?
    private var lastUPSState: String?

    init() {
        timer = Self.makeCoalescedTimer(interval: 60, tolerance: 12) { [weak self] in
            await self?.refresh()
        }
        Task { await refresh() }
    }

    deinit { timer?.invalidate() }

    // Reachability and telemetry age are intentionally separate. The Mac may be
    // perfectly reachable while its background status writer is catching up.
    var isOnline: Bool { route != .offline }
    var isFresh: Bool {
        guard let value = status?.updatedAt,
              let date = ISO8601DateFormatter().date(from: value) else { return false }
        return abs(date.timeIntervalSinceNow) < 180
    }

    var routeLabel: String { route.rawValue }

    var connectionSummary: String {
        guard isOnline else { return "Bağlantı bekleniyor" }
        return isFresh ? routeLabel : "\(routeLabel) · veri güncelleniyor"
    }

    var overviewSummary: String {
        guard isOnline else { return connectionSummary }
        var parts = [connectionSummary]
        if let cpu = status?.cpuTemperatureC { parts.append(String(format: "CPU %.0f°C", cpu)) }
        if let gpu = status?.gpuTemperatureC { parts.append(String(format: "GPU %.0f°C", gpu)) }
        if isOnBattery, let battery = status?.batteryPercent { parts.append("Pilde %\(battery)") }
        return parts.joined(separator: " · ")
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        // Render the latest mirrored telemetry immediately. Route probing may
        // take a few seconds and must not leave an old AC/UPS state on screen.
        reloadCachedTelemetry()
        await refreshRoute()

        guard status != nil else { return }
        lastError = isFresh ? nil : "Son telemetri güncel değil."
        if infrastructureUpdatedAt.map({ Date().timeIntervalSince($0) > 300 }) ?? true {
            await refreshInfrastructure()
        }
    }

    func reloadCachedTelemetry() {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: statusPath))
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let decoded = try decoder.decode(MYAL11Status.self, from: data)
            status = decoded
            if let fastDropData = try? Data(contentsOf: URL(fileURLWithPath: fastDropStatusPath)),
               let decodedFastDrop = try? decoder.decode(FastDropStatus.self, from: fastDropData) {
                fastDrop = decodedFastDrop
            } else {
                fastDrop = nil
            }
            evaluateUPSNotification(decoded)
            lastError = isFresh ? nil : "Son telemetri güncel değil."
        } catch {
            status = nil
            fastDrop = nil
            lastError = "MYA-L11 telemetrisi okunamadı."
        }
    }

    func refreshInfrastructure() async {
        guard isOnline, !isRefreshingInfrastructure else { return }
        isRefreshingInfrastructure = true
        defer { isRefreshingInfrastructure = false }

        let remoteCommand = #"""
        export PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin
        printf '__DAAK_LINUX__\n'
        colima status --json 2>/dev/null || true
        printf '__DAAK_CONTAINERS__\n'
        docker ps --format '{{.Names}}\t{{.Image}}\t{{.State}}\t{{.Status}}' 2>/dev/null || true
        printf '__DAAK_STATS__\n'
        docker stats --no-stream --format '{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}' 2>/dev/null || true
        """#
        let result = await LocalCommand.run(
            "/usr/bin/ssh",
            ["-o", "BatchMode=yes", "-o", "ConnectTimeout=5", selectedSSHHost, remoteCommand]
        )
        guard result.exitCode == 0 else {
            infrastructureError = "Linux/Docker verisi alınamadı."
            return
        }

        let linuxMarker = "__DAAK_LINUX__\n"
        let containerMarker = "__DAAK_CONTAINERS__\n"
        let statsMarker = "__DAAK_STATS__\n"
        guard let linuxStart = result.output.range(of: linuxMarker)?.upperBound,
              let containerRange = result.output.range(of: containerMarker, range: linuxStart..<result.output.endIndex),
              let statsRange = result.output.range(of: statsMarker, range: containerRange.upperBound..<result.output.endIndex) else {
            infrastructureError = "Linux/Docker yanıtı geçersiz."
            return
        }

        let linuxJSON = String(result.output[linuxStart..<containerRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        linuxRuntime = try? decoder.decode(LinuxRuntimeStatus.self, from: Data(linuxJSON.utf8))

        var statsByName: [String: (cpu: String, memory: String, percent: String)] = [:]
        for line in result.output[statsRange.upperBound...].split(separator: "\n") {
            let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 4 else { continue }
            statsByName[fields[0]] = (fields[1], fields[2], fields[3])
        }

        containers = result.output[containerRange.upperBound..<statsRange.lowerBound]
            .split(separator: "\n")
            .compactMap { line in
                let fields = line.split(separator: "\t", maxSplits: 3, omittingEmptySubsequences: false).map(String.init)
                guard fields.count == 4 else { return nil }
                let stats = statsByName[fields[0]]
                return DockerContainerStatus(
                    name: fields[0],
                    image: fields[1],
                    state: fields[2],
                    status: fields[3],
                    cpuPercent: stats?.cpu,
                    memoryUsage: stats?.memory,
                    memoryPercent: stats?.percent
                )
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        infrastructureUpdatedAt = Date()
        infrastructureError = linuxRuntime == nil ? "Colima bilgisi okunamadı." : nil
    }

    var linuxSummary: String {
        guard let linuxRuntime else { return infrastructureError ?? "Linux verisi bekleniyor" }
        return "\(linuxRuntime.runtime.capitalized) · \(linuxRuntime.cpu) CPU · \(ByteCountFormatter.string(fromByteCount: linuxRuntime.memory, countStyle: .memory)) RAM"
    }

    var dockerSummary: String {
        guard !containers.isEmpty else {
            return status.map { "\($0.dockerContainersRunning) konteyner · ayrıntılar bekleniyor" } ?? "Docker verisi bekleniyor"
        }
        let healthy = containers.filter(\.isHealthy).count
        return "\(healthy)/\(containers.count) sağlıklı"
    }

    private static func makeCoalescedTimer(
        interval: TimeInterval,
        tolerance: TimeInterval,
        action: @escaping @MainActor () async -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in
            Task { @MainActor in await action() }
        }
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }

    var fastDropOnline: Bool {
        guard let fastDrop else { return false }
        return fastDrop.mounted && abs(Date().timeIntervalSince1970 - fastDrop.updatedAt) < 180
    }

    var fastDropSummary: String {
        guard let fastDrop else { return "Durum bekleniyor" }
        if let error = fastDrop.lastError, !error.isEmpty { return "Hata · \(error)" }
        if fastDrop.state == "uploading", let file = fastDrop.currentFile {
            return "Aktarılıyor · \(file)"
        }
        let available = ByteCountFormatter.string(fromByteCount: fastDrop.availableBytes, countStyle: .file)
        if fastDrop.incomingFiles > 0 { return "\(fastDrop.incomingFiles) dosya sırada · \(available) boş" }
        return "Hazır · \(available) boş · \(fastDrop.retainedFiles) dosya 72 saat korunuyor"
    }

    private func refreshRoute() async {
        if FileManager.default.isExecutableFile(atPath: routeSelectorPath) {
            let selected = await LocalCommand.run("/bin/zsh", [routeSelectorPath, "status"])
            switch selected.output.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "cable", "thunderbolt":
                route = .cable
                return
            case "tailscale":
                route = .tailscale
                return
            case "offline":
                route = .offline
                return
            default:
                break
            }
        }

        // Keep the configuration probes as a compatibility fallback for older
        // installations that do not have the shared route selector yet.
        if let directHost = configuration?.directHost, !directHost.isEmpty {
            let cable = await LocalCommand.run("/usr/bin/nc", ["-6", "-z", "-G", "1", directHost, "22"])
            if cable.exitCode == 0 {
                route = .cable
                return
            }
        }
        guard let tailHost = configuration?.tailHost, !tailHost.isEmpty else {
            route = .offline
            return
        }
        let tail = await LocalCommand.run("/usr/bin/nc", ["-z", "-G", "2", tailHost, "22"])
        route = tail.exitCode == 0 ? .tailscale : .offline
    }

    var isOnBattery: Bool {
        guard let status else { return false }
        return status.upsState.map { $0 != "ac" } ?? (status.powerSource == "Battery Power")
    }

    var upsSummary: String {
        guard let status else { return "UPS telemetrisi bekleniyor" }
        if let message = status.upsMessage, !message.isEmpty { return message }
        return isOnBattery
            ? "Adaptör bağlı değil · pil %\(status.batteryPercent)"
            : "Adaptör bağlı · pil UPS olarak hazır"
    }

    private func evaluateUPSNotification(_ newStatus: MYAL11Status) {
        let newState = newStatus.upsState ?? (newStatus.powerSource == "Battery Power" ? "battery" : "ac")
        defer { lastUPSState = newState }
        guard newState != "ac", newState != lastUPSState else { return }

        let content = UNMutableNotificationContent()
        content.title = newState == "critical" || newState == "emergency"
            ? "MYA-L11 yakında kapanabilir"
            : "MYA-L11 adaptörden ayrıldı"
        content.body = newStatus.upsMessage ?? "Intel Mac pilde çalışıyor · %\(newStatus.batteryPercent)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "app.daaknode.mya-l11-ups.\(newState)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private var selectedSSHHost: String {
        route == .cable ? "mya-l11-direct" : "mya-l11-tail"
    }

    func openScreen() {
        try? LocalCommand.launch("/bin/zsh", [NSHomeDirectory() + "/Library/Application Support/DAAK/mya-direct.zsh", "screen"])
        actionMessage = "Ekran Paylaşımı en hızlı kullanılabilir hattan açılıyor."
    }

    func openDisk() {
        try? LocalCommand.launch("/bin/zsh", [NSHomeDirectory() + "/Library/Application Support/DAAK/mya-direct.zsh", "disk"])
    }

    func openSSH() {
        try? LocalCommand.launch("/bin/zsh", [routeSelectorPath, "ssh"])
        actionMessage = "SSH en hızlı kullanılabilir hattan açılıyor."
    }

    func openWebmail() { openURL(configuration?.webmailURL) }
    func openMailAdmin() { openURL(configuration?.mailAdminURL) }
    func openCampaigns() { openURL(configuration?.campaignsURL) }
    func openMailPreview() { openURL(configuration?.mailPreviewURL) }
    func openContainerPanel() { openURL(configuration?.containerPanelURL) }
    func openDNSPanel() { openURL(configuration?.dnsPanelURL) }
    func openBrevoSMTP() { openURL(configuration?.brevoSMTPURL) }
    func openBrevoDomains() { openURL(configuration?.brevoDomainsURL) }

    func openCalendar() {
        let calendar = URL(fileURLWithPath: "/System/Applications/Calendar.app")
        NSWorkspace.shared.openApplication(at: calendar, configuration: .init())
    }

    func openAccountSettings() {
        openURL("x-apple.systempreferences:com.apple.Internet-Accounts-Settings.extension")
    }

    private func openURL(_ value: String?) {
        guard let value, let url = URL(string: value) else {
            actionMessage = "Bu servis için node-config.json ayarı gerekli."
            return
        }
        NSWorkspace.shared.open(url)
    }

    func power(_ action: String) async {
        guard ["wake", "sleep", "restart", "shutdown"].contains(action), !isRunningAction else { return }
        isRunningAction = true
        defer { isRunningAction = false }

        if action == "wake" {
            guard let mac = configuration?.wakeMAC,
                  !mac.isEmpty,
                  let broadcasts = configuration?.wakeBroadcasts,
                  !broadcasts.isEmpty,
                  let payload = try? JSONEncoder().encode(broadcasts),
                  let broadcastJSON = String(data: payload, encoding: .utf8) else {
                actionMessage = "Wake-on-LAN için node-config.json ayarı gerekli."
                return
            }
            let wakeScript = #"""
            import json, socket, sys
            mac = bytes.fromhex(sys.argv[1].replace(":", "").replace("-", ""))
            packet = b"\xff" * 6 + mac * 16
            sent, errors = [], []
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
            for host in json.loads(sys.argv[2]):
                try:
                    sock.sendto(packet, (host, 9))
                    sent.append(host)
                except OSError as error:
                    errors.append(f"{host}: {error}")
            print(json.dumps({"sent": sent, "errors": errors}))
            raise SystemExit(0 if sent else 1)
            """#
            let result = await LocalCommand.run(
                "/usr/bin/python3",
                ["-c", wakeScript, mac, broadcastJSON]
            )
            actionMessage = result.exitCode == 0 ? "Uyandırma paketi yerel ağa gönderildi." : "Uyandırma paketi gönderilemedi."
            return
        }

        let result = await LocalCommand.run(
            "/usr/bin/ssh",
            ["-o", "BatchMode=yes", "-o", "ConnectTimeout=4", selectedSSHHost,
             "sudo -n /usr/local/sbin/daak-node-power \(action)"]
        )
        if result.exitCode == 0 {
            switch action {
            case "sleep": actionMessage = "MYA-L11 uykuya alındı."
            case "restart": actionMessage = "MYA-L11 yeniden başlatılıyor."
            default: actionMessage = "MYA-L11 kapatılıyor. Tekrar açmak fiziksel güç veya çalışan Wake-on-LAN gerektirebilir."
            }
        } else {
            actionMessage = "Güç komutu çalışmadı: \(result.output)"
        }
    }
}

@MainActor
private final class NodeMonitor: ObservableObject {
    @Published private(set) var status: NodeStatus?
    @Published private(set) var location: NodeLocation?
    @Published private(set) var lastError: String?
    @Published private(set) var actionMessage: String?
    @Published private(set) var isRefreshing = false
    @Published private(set) var isSettingExitNode = false
    @Published private(set) var isPhoneExitNodeAvailable = false
    @Published private(set) var isUsingPhoneExitNode = false
    @Published private(set) var deviceHealth: NodeDeviceHealth?
    @Published var host: String

    private let hostKey = "daakNodeHost"
    private let sshPort = "8022"
    private let adbPort = "5555"
    private let tailscaleCLI = "/Applications/Tailscale.app/Contents/MacOS/Tailscale"
    private var timer: Timer?

    init() {
        host = UserDefaults.standard.string(forKey: hostKey) ?? ""
        timer = Timer(timeInterval: 90, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        timer?.tolerance = 18
        if let timer { RunLoop.main.add(timer, forMode: .common) }
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
        case "ready-last-gps": return "Son hassas GPS noktası korunuyor"
        case "ready-approximate": return "Yaklaşık konum hazır"
        case "acquiring-gps":
            return hasLocation ? "Yaklaşık konum hazır · GPS aranıyor" : "Hassas GPS aranıyor"
        case "waiting-for-gps": return hasLocation ? "Son konum hazır · GPS aranıyor" : "GPS sinyali bekleniyor"
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

    var healthSummary: String {
        guard isOnline else { return "Bağlantı bekleniyor" }
        var parts: [String] = []
        if let value = deviceHealth?.batteryPercent { parts.append("Pil %\(value)") }
        if let value = deviceHealth?.cpuTemperatureC { parts.append(String(format: "CPU %.0f°C", value)) }
        if let value = deviceHealth?.batteryTemperatureC { parts.append(String(format: "Pil %.0f°C", value)) }
        return parts.isEmpty ? stateLabel : parts.joined(separator: " · ")
    }

    func saveAndRefresh() async {
        host = Self.cleanedHost(host)
        UserDefaults.standard.set(host, forKey: hostKey)
        status = nil
        lastError = nil
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        await refreshCachedLocation()
        await refreshExitNodeState()
        guard Self.isSafeHost(host) else {
            status = nil
            lastError = "DAAK NODE Tailscale IP’si geçerli değil."
            return
        }

        let result = await LocalCommand.run("/usr/bin/ssh", sshArguments(remoteCommand: ".local/bin/daak-find status"))
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(NodeStatus.self, from: data) else {
            status = nil
            lastError = "Vaytniga’ya ulaşılamadı. Tailscale ve Termux SSH bağlantısını kontrol et."
            return
        }
        status = decoded
        await refreshDeviceHealth()
        lastError = nil
    }

    private func refreshDeviceHealth() async {
        guard Self.isSafeHost(host) else { return }
        let serial = "\(host):\(adbPort)"
        let connected = await LocalCommand.run("/opt/homebrew/bin/adb", ["connect", serial])
        guard connected.exitCode == 0 else { return }
        async let batteryResult = LocalCommand.run("/opt/homebrew/bin/adb", ["-s", serial, "shell", "dumpsys", "battery"])
        async let thermalResult = LocalCommand.run("/opt/homebrew/bin/adb", ["-s", serial, "shell", "dumpsys", "thermalservice"])
        async let memoryResult = LocalCommand.run("/opt/homebrew/bin/adb", ["-s", serial, "shell", "cat", "/proc/meminfo"])
        let (battery, thermal, memory) = await (batteryResult, thermalResult, memoryResult)
        guard battery.exitCode == 0 else { return }
        let level = Self.firstNumber(in: battery.output, pattern: #"(?m)^\s*level:\s*(\d+)\s*$"#).map { Int($0) }
        let rawBatteryTemperature = Self.firstNumber(in: battery.output, pattern: #"(?m)^\s*temperature:\s*(\d+)\s*$"#)
        let batteryTemperature = rawBatteryTemperature.map { $0 / 10 }
        let cpuTemperature = Self.allNumbers(
            in: thermal.output,
            pattern: #"mValue=([-0-9.]+),\s*mType=1,"#
        ).last(where: { $0 > 0 })
        let total = Self.firstNumber(in: memory.output, pattern: #"(?m)^MemTotal:\s*(\d+)"#)
        let available = Self.firstNumber(in: memory.output, pattern: #"(?m)^MemAvailable:\s*(\d+)"#)
        let memoryFree = total.flatMap { total in available.map { Int(($0 * 100 / total).rounded()) } }
        let power = battery.output.contains("AC powered: true") ? "AC" :
            (battery.output.contains("USB powered: true") ? "USB" : "UNPLUGGED")
        deviceHealth = NodeDeviceHealth(
            batteryPercent: level,
            batteryTemperatureC: batteryTemperature,
            cpuTemperatureC: cpuTemperature,
            memoryFreePercent: memoryFree,
            powerLabel: power
        )
    }

    private static func firstNumber(in value: String, pattern: String) -> Double? {
        allNumbers(in: value, pattern: pattern).first
    }

    private static func allNumbers(in value: String, pattern: String) -> [Double] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(value.startIndex..., in: value)
        return expression.matches(in: value, range: range).compactMap { match in
            guard match.numberOfRanges > 1,
                  let numberRange = Range(match.range(at: 1), in: value) else { return nil }
            return Double(value[numberRange])
        }
    }

    func setPhoneExitNode(enabled: Bool) async {
        guard Self.isSafeHost(host), !isSettingExitNode else { return }
        isSettingExitNode = true
        defer { isSettingExitNode = false }
        let arguments = enabled
            ? ["set", "--exit-node=\(host)", "--exit-node-allow-lan-access=true"]
            : ["set", "--exit-node="]
        let result = await LocalCommand.run(tailscaleCLI, arguments)
        await refreshExitNodeState()
        if result.exitCode == 0 {
            actionMessage = enabled
                ? "Mac interneti artık Vaytniga üzerinden çıkıyor."
                : "Mac normal internet rotasına döndü."
        } else {
            actionMessage = "Vaytniga çıkış rotası değiştirilemedi: \(result.output)"
        }
    }

    private func refreshExitNodeState() async {
        guard FileManager.default.isExecutableFile(atPath: tailscaleCLI) else {
            isPhoneExitNodeAvailable = false
            isUsingPhoneExitNode = false
            return
        }
        let result = await LocalCommand.run(tailscaleCLI, ["status", "--json"])
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(TailnetStatus.self, from: data) else {
            return
        }
        isPhoneExitNodeAvailable = decoded.peers.values.contains {
            $0.exitNodeOption == true && Self.addresses($0.tailscaleIPs, contain: host)
        }
        isUsingPhoneExitNode = Self.addresses(decoded.exitNodeStatus?.tailscaleIPs, contain: host)
    }

    private static func addresses(_ addresses: [String]?, contain host: String) -> Bool {
        (addresses ?? []).contains {
            $0.split(separator: "/", maxSplits: 1).first.map(String.init) == host
        }
    }

    private func refreshCachedLocation() async {
        let result = await LocalCommand.run(NSHomeDirectory() + "/.local/bin/daak-find", ["raw-cached"])
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(NodeLocation.self, from: data),
              (-90...90).contains(decoded.latitude),
              (-180...180).contains(decoded.longitude),
              decoded.accuracyMeters >= 0,
              decoded.accuracyMeters <= (decoded.provider == "gps" ? 500 : 2_000) else {
            return
        }
        location = decoded
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
        actionMessage = "Vaytniga ekranına bağlanılıyor…"
        let serial = "\(host):\(adbPort)"
        let adb = await LocalCommand.run("/opt/homebrew/bin/adb", ["connect", serial])
        guard adb.exitCode == 0 else {
            actionMessage = "ADB bağlantısı kurulamadı: \(adb.output)"
            return
        }
        do {
            try LocalCommand.launch(
                "/opt/homebrew/bin/scrcpy",
                ["--serial", serial, "--no-audio", "--stay-awake", "--window-title", "DAAK NODE · Vaytniga"]
            )
            actionMessage = "Canlı ekran açıldı."
        } catch {
            actionMessage = "Canlı ekran açılamadı: \(error.localizedDescription)"
        }
    }

    func openSSH() {
        guard Self.isSafeHost(host), let url = URL(string: "ssh://\(host):\(sshPort)") else { return }
        NSWorkspace.shared.open(url)
        actionMessage = "Vaytniga terminali açılıyor."
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
private final class SeparationMonitor: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var distanceMeters: Double?
    @Published private(set) var statusLabel = "Ayrılma uyarısı hazırlanıyor"

    private let manager = CLLocationManager()
    private let alertDistance = 750.0
    private let reunionDistance = 400.0
    private var phoneLocation: NodeLocation?
    private var macLocation: CLLocation?
    private var consecutiveAwaySamples = 0
    private var hasAlerted = false
    private var notificationResolved = false
    private var notificationAllowed = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100
        manager.activityType = .other
        manager.pausesLocationUpdatesAutomatically = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, _ in
            Task { @MainActor in
                guard let self else { return }
                self.notificationResolved = true
                self.notificationAllowed = granted
                UserDefaults.standard.set(granted, forKey: "daakSeparationNotificationAllowed")
                if !granted {
                    self.statusLabel = "Ayrılma uyarısı için bildirim izni gerekli"
                }
            }
        }
        manager.requestWhenInUseAuthorization()
        startIfAuthorized()
    }

    func updatePhoneLocation(_ location: NodeLocation?) {
        phoneLocation = location
        evaluate()
    }

    func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension") else { return }
        NSWorkspace.shared.open(url)
    }

    func openLocationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") else { return }
        NSWorkspace.shared.open(url)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        startIfAuthorized()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        macLocation = latest
        evaluate()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        statusLabel = "Mac konumu bekleniyor"
    }

    private func startIfAuthorized() {
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            manager.startUpdatingLocation()
            UserDefaults.standard.set(true, forKey: "daakSeparationLocationAllowed")
            statusLabel = notificationResolved && !notificationAllowed
                ? "Ayrılma uyarısı için bildirim izni gerekli"
                : "Ayrılma uyarısı açık · 750 m"
        case .denied, .restricted:
            manager.stopUpdatingLocation()
            UserDefaults.standard.set(false, forKey: "daakSeparationLocationAllowed")
            statusLabel = "Ayrılma uyarısı için Mac konum izni gerekli"
        case .notDetermined:
            statusLabel = "Mac konum izni bekleniyor"
        @unknown default:
            statusLabel = "Mac konumu bekleniyor"
        }
    }

    private func evaluate() {
        guard !notificationResolved || notificationAllowed else {
            statusLabel = "Ayrılma uyarısı için bildirim izni gerekli"
            return
        }
        guard let phoneLocation, let macLocation else { return }
        let now = Date().timeIntervalSince1970
        guard now - phoneLocation.capturedAt <= 20 * 60,
              abs(macLocation.timestamp.timeIntervalSinceNow) <= 5 * 60,
              macLocation.horizontalAccuracy >= 0,
              macLocation.horizontalAccuracy <= 500 else {
            statusLabel = "Ayrılma uyarısı açık · güncel konum bekleniyor"
            return
        }

        let phone = CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: phoneLocation.latitude,
                longitude: phoneLocation.longitude
            ),
            altitude: 0,
            horizontalAccuracy: phoneLocation.accuracyMeters,
            verticalAccuracy: -1,
            timestamp: Date(timeIntervalSince1970: phoneLocation.capturedAt)
        )
        let rawDistance = macLocation.distance(from: phone)
        let effectiveDistance = max(
            0,
            rawDistance - macLocation.horizontalAccuracy - phoneLocation.accuracyMeters
        )
        distanceMeters = rawDistance

        if effectiveDistance >= alertDistance {
            consecutiveAwaySamples += 1
            statusLabel = "Telefon yaklaşık \(Self.distanceText(rawDistance)) uzakta"
            if consecutiveAwaySamples >= 2 && !hasAlerted {
                hasAlerted = true
                sendAwayNotification(distance: rawDistance)
            }
        } else if effectiveDistance <= reunionDistance {
            consecutiveAwaySamples = 0
            hasAlerted = false
            statusLabel = "Telefon yanında · ayrılma uyarısı açık"
        } else {
            consecutiveAwaySamples = 0
            statusLabel = "Ayrılma uyarısı açık · \(Self.distanceText(rawDistance))"
        }
    }

    private func sendAwayNotification(distance: Double) {
        let content = UNMutableNotificationContent()
        content.title = "DAAK NODE senden uzaklaştı"
        content.body = "Vaytniga yaklaşık \(Self.distanceText(distance)) uzakta. Son konumu DAAK NODE menüsünden açabilirsin."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "app.daaknode.phone-separated",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func distanceText(_ distance: Double) -> String {
        if distance >= 1_000 {
            return String(format: "%.1f km", distance / 1_000)
        }
        return "\(Int(distance.rounded())) m"
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
        timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.refresh()
            }
        }
        timer?.tolerance = 12
        if let timer { RunLoop.main.add(timer, forMode: .common) }
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
        guard !isRefreshing else { return }
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

    func openRemoteDesktop() {
        try? LocalCommand.launch(
            "/bin/zsh",
            [NSHomeDirectory() + "/Library/Application Support/DAAK/lolile-windows-app.zsh"]
        )
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

@MainActor
private final class LocalMacMonitor: ObservableObject {
    @Published private(set) var health: LocalMacHealth?
    private var timer: Timer?
    private var isRefreshing = false

    init() {
        timer = Timer(timeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        timer?.tolerance = 12
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        Task { await refresh() }
    }

    deinit { timer?.invalidate() }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let script = #"""
        batt=$(/usr/bin/pmset -g batt)
        level=$(printf '%s\n' "$batt" | awk 'NR==2 {for(i=1;i<=NF;i++) if($i ~ /%/) {gsub(/[^0-9]/,"",$i); print $i; exit}}')
        power=$(printf '%s\n' "$batt" | head -1 | sed "s/Now drawing from '//; s/'$//")
        mem=$(/usr/bin/memory_pressure 2>/dev/null | awk -F': ' '/System-wide memory free percentage/ {gsub(/%/,"",$2); print $2; exit}')
        smc='/Applications/Stats.app/Contents/Resources/smc'
        cpu=null
        btemp=null
        if [[ -x "$smc" ]]; then
          temps=$("$smc" list -t 2>/dev/null)
          cpu=$(printf '%s\n' "$temps" | awk '$1=="[TCHP]" {print $2; exit}')
          btemp=$(printf '%s\n' "$temps" | awk '$1=="[TB0T]" {print $2; exit}')
        fi
        printf '{"batteryPercent":%s,"batteryTemperatureC":%s,"cpuTemperatureC":%s,"memoryFreePercent":%s,"powerLabel":"%s"}\n' "${level:-null}" "${btemp:-null}" "${cpu:-null}" "${mem:-null}" "$power"
        """#
        let result = await LocalCommand.run("/bin/zsh", ["-c", script])
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(LocalMacHealth.self, from: data) else { return }
        health = decoded
    }

    var summary: String {
        guard let health else { return "Yerel telemetri bekleniyor" }
        var parts = [health.powerLabel]
        if let value = health.batteryPercent { parts.append("Pil %\(value)") }
        if let value = health.cpuTemperatureC { parts.append(String(format: "CPU %.0f°C", value)) }
        return parts.joined(separator: " · ")
    }
}

private enum DevicePanel: String, CaseIterable, Identifiable {
    case devices
    case operations
    case lolile
    case myaL11
    case node

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: return "Merkez"
        case .operations: return "Servisler"
        case .lolile: return "LOLİLE"
        case .myaL11: return "MYA-L11"
        case .node: return "Vaytniga"
        }
    }

    var symbol: String {
        switch self {
        case .devices: return "square.grid.2x2.fill"
        case .operations: return "server.rack"
        case .lolile: return "desktopcomputer"
        case .myaL11: return "laptopcomputer"
        case .node: return "iphone"
        }
    }
}

private struct DAAKPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(
                reduceMotion ? .easeOut(duration: 0.1) : .interactiveSpring(response: 0.24, dampingFraction: 1),
                value: configuration.isPressed
            )
    }
}

private struct DAAKPanelPicker: View {
    @Binding var selection: DevicePanel
    @Namespace private var selectionSurface
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 3) {
            ForEach(DevicePanel.allCases) { panel in
                Button {
                    guard selection != panel else { return }
                    withAnimation(reduceMotion ? .easeOut(duration: 0.14) : .interactiveSpring(response: 0.34, dampingFraction: 1)) {
                        selection = panel
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: panel.symbol)
                            .font(.caption2.weight(.semibold))
                        Text(panel.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(selection == panel ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .contentShape(Rectangle())
                    .background {
                        if selection == panel {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(.regularMaterial)
                                .matchedGeometryEffect(id: "panel-selection", in: selectionSurface)
                                .shadow(color: .black.opacity(0.13), radius: 2, y: 1)
                        }
                    }
                }
                .buttonStyle(DAAKPressStyle())
                .accessibilityLabel(panel.title)
                .accessibilityAddTraits(selection == panel ? .isSelected : [])
            }
        }
        .padding(3)
        .background(.quaternary.opacity(0.8), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct MailAccountsView: View {
    @EnvironmentObject private var mail: MailAccountMonitor
    @State private var confirmsGenerate = false
    private let configuration = NodeConfiguration.load()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("MAIL HESAPLARI").font(.headline)
                        Text("Gelen · Giden · Brevo relay · Takvim · Parola").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if mail.isWorking { ProgressView().controlSize(.small) }
                }

                if let accounts = mail.data?.accounts, !accounts.isEmpty {
                    Picker("Hesap", selection: $mail.selectedAddress) {
                        ForEach(accounts) { account in
                            Text("\(account.displayName) · \(account.address)").tag(account.address)
                        }
                    }
                    .labelsHidden()

                    if let account = mail.selectedAccount {
                        VStack(spacing: 8) {
                            MetricRow(title: "E-posta", value: account.address)
                            MetricRow(title: "Kullanılan", value: ByteCountFormatter.string(fromByteCount: account.usedBytes, countStyle: .file))
                            MetricRow(title: "Kalan", value: ByteCountFormatter.string(fromByteCount: max(0, account.quotaBytes - account.usedBytes), countStyle: .file))
                            MetricRow(title: "Kota", value: ByteCountFormatter.string(fromByteCount: account.quotaBytes, countStyle: .file))
                            ProgressView(value: min(1, account.quotaBytes > 0 ? Double(account.usedBytes) / Double(account.quotaBytes) : 0))
                                .tint(account.quotaBytes > 0 && Double(account.usedBytes) / Double(account.quotaBytes) >= 0.9 ? .red : .blue)
                            HStack {
                                Text("Doluluk")
                                Spacer()
                                Text(account.quotaBytes > 0 ? String(format: "%.2f%%", Double(account.usedBytes) / Double(account.quotaBytes) * 100) : "—")
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            MetricRow(title: "Parola deposu", value: account.passwordStored ? "Güvenli · hazır" : "Kontrol gerekli")
                        }
                    }

                    if let server = mail.data?.server {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("1 · Mail uygulamasına yazılacak").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            MetricRow(title: "Gelen IMAP", value: "\(server.imap.host):\(server.imap.port) · \(server.imap.security)")
                            MetricRow(title: "Giden SMTP", value: "\(server.smtp.host):\(server.smtp.port) · \(server.smtp.security)")
                            MetricRow(title: "Kullanıcı", value: mail.selectedAddress)
                            Text("Parola seçili posta kutusunun parolasıdır. Cihazda Tailscale açık olmalı.")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        .padding(10)
                        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 11))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("2 · Giden postanın arka plan yolu").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            MetricRow(title: "Akış", value: "Mail uygulaması → MYA-L11 → Brevo → alıcı")
                            MetricRow(title: "Brevo relay", value: "\(configuration?.brevoSMTPHost ?? "smtp-relay.brevo.com"):\(configuration?.brevoSMTPPort ?? 587) · STARTTLS")
                            if let login = configuration?.brevoSMTPLogin {
                                MetricRow(title: "Brevo oturumu", value: login)
                            }
                            Text("Brevo bir IMAP/gelen kutusu değildir. Brevo anahtarı mail uygulamasına verilmez; MYA-L11 güvenli depodan kullanır.")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(10)
                        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))

                        VStack(alignment: .leading, spacing: 8) {
                            Text("3 · redmono.com gelen posta durumu").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            MetricRow(title: "Mevcut sağlayıcı", value: configuration?.inboundProvider ?? "IONOS")
                            MetricRow(title: "MX", value: configuration?.inboundMX ?? "mx00.ionos.es / mx01.ionos.es")
                            Text("MX henüz özel sunucuya taşınmadı. İnternetten gelen gerçek postanın ilk durağı hâlâ IONOS.")
                                .font(.caption2).foregroundStyle(.orange)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 11))
                    }

                    HStack(spacing: 7) {
                        Button("Kurulumu kopyala", action: mail.copySetup)
                        Button("Parolayı kopyala") { Task { await mail.revealOrCopy(copyOnly: true) } }
                        Button(mail.revealedPassword == nil ? "Parolayı göster" : "Gizle") {
                            if mail.revealedPassword == nil { Task { await mail.revealOrCopy(copyOnly: false) } }
                            else { mail.hidePassword() }
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    HStack(spacing: 12) {
                        if let value = configuration?.brevoSMTPURL, let url = URL(string: value) {
                            Link("Brevo SMTP paneli", destination: url)
                        }
                        if let value = configuration?.brevoDomainsURL, let url = URL(string: value) {
                            Link("Brevo domain durumu", destination: url)
                        }
                    }
                    .font(.caption)

                    if let password = mail.revealedPassword {
                        HStack {
                            Text(password)
                                .font(.callout.monospaced())
                                .textSelection(.enabled)
                            Spacer()
                            Image(systemName: "eye.fill").foregroundStyle(.orange)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                    }

                    Divider()

                    Text("Parolayı değiştir").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    SecureField("En az 12 karakter", text: $mail.newPassword)
                        .textFieldStyle(.roundedBorder)
                    HStack {
                        Button("Yazdığım parolayı uygula") { Task { await mail.applyCustomPassword() } }
                            .buttonStyle(.borderedProminent)
                            .disabled(mail.newPassword.count < 12 || mail.isWorking)
                        Button("Güçlü parola üret") { confirmsGenerate = true }
                            .buttonStyle(.bordered)
                            .disabled(mail.isWorking)
                    }

                    Text("Parola değişince eski telefon/PC bağlantıları durur; yeni parolayı cihazlara tekrar girmek gerekir.")
                        .font(.caption2).foregroundStyle(.secondary)
                } else if mail.isWorking {
                    Text("Hesaplar yükleniyor…").font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Mail hesabı bulunamadı.").font(.callout).foregroundStyle(.secondary)
                }

                if let message = mail.message {
                    Text(message).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button("Yenile") { Task { await mail.refresh() } }.buttonStyle(.borderless)
                    Spacer()
                    Text("Parolalar Git’e ve uygulamaya yazılmaz").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 700)
        .confirmationDialog("\(mail.selectedAddress) için yeni güçlü parola üretilsin mi?", isPresented: $confirmsGenerate) {
            Button("Üret ve değiştir") { Task { await mail.generatePassword() } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Mevcut parola geçersiz olacak; mail uygulamalarına yeni parolayı girmen gerekecek.")
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
            .buttonStyle(DAAKPressStyle())

            HStack {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(13)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.08), radius: 8, y: 3)
    }
}

private struct DeviceOverviewView: View {
    @EnvironmentObject private var relay: RelayMonitor
    @EnvironmentObject private var node: NodeMonitor
    @EnvironmentObject private var myaL11: MYAL11Monitor
    @EnvironmentObject private var localMac: LocalMacMonitor
    @Binding var selection: DevicePanel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("SUNUCU DURUMU").font(.caption.weight(.bold))
                    Text("Güç, sıcaklık ve erişim tek bakışta")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Text("60 sn ekonomik canlı")
                    .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            }

            if let status = myaL11.status {
                HStack(spacing: 10) {
                    Image(systemName: myaL11.isOnBattery ? "exclamationmark.triangle.fill" : "battery.100percent.bolt")
                        .font(.title3)
                        .foregroundStyle(myaL11.isOnBattery ? Color.orange : Color.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(myaL11.isOnBattery ? "UPS DEVREDE" : "UPS HAZIR")
                            .font(.callout.weight(.bold))
                        Text(myaL11.upsSummary)
                            .font(.caption2)
                            .foregroundStyle(myaL11.isOnBattery ? Color.orange : Color.secondary)
                    }
                    Spacer()
                    if myaL11.isOnBattery, let minutes = status.batteryMinutesRemaining, minutes >= 0 {
                        Text("≈ \(minutes) dk")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(.orange)
                    } else {
                        Text("%\(status.batteryPercent)")
                            .font(.headline.monospacedDigit())
                    }
                }
                .padding(12)
                .background(
                    (myaL11.isOnBattery ? Color.orange : Color.green).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 13)
                )
            }

            DeviceCard(
                name: "LOLİLE",
                detail: "Windows · Relay · Uzaktan kontrol",
                symbol: "desktopcomputer",
                online: relay.isConnected,
                status: relay.status?.hardware?.available == true
                    ? "CPU \(RelayMonitor.formatTemperature(relay.status?.hardware?.cpu?.temperatureC)) · GPU \(RelayMonitor.formatTemperature(relay.status?.hardware?.gpu?.temperatureC)) · \(relay.menuTitle)"
                    : (relay.isConnected ? "Tailscale üzerinden bağlı" : "Bağlantı bekleniyor"),
                actionTitle: "Ekranı aç",
                action: relay.openRemoteDesktop,
                openDetails: { selection = .lolile }
            )

            DeviceCard(
                name: "MYA-L11",
                detail: "Intel Mac · Sunucu · Ekran · Disk",
                symbol: "laptopcomputer",
                online: myaL11.isOnline,
                status: myaL11.overviewSummary,
                actionTitle: "Ekranı aç",
                action: myaL11.openScreen,
                openDetails: { selection = .myaL11 }
            )

            DeviceCard(
                name: "DAAK NODE",
                detail: "Vaytniga · Find · SSH · Canlı ekran",
                symbol: "iphone",
                online: node.isOnline,
                status: node.healthSummary,
                actionTitle: "Ekranı aç",
                action: { Task { await node.openLiveScreen() } },
                openDetails: { selection = .node }
            )

            HStack(spacing: 10) {
                Image(systemName: "laptopcomputer")
                    .foregroundStyle(.green)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text("BU MAC").font(.caption.weight(.semibold))
                    Text(localMac.summary).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if let temp = localMac.health?.batteryTemperatureC {
                    Text(String(format: "Pil %.0f°C", temp))
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            }
            .padding(10)
            .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))

            Divider()

            HStack {
                Button {
                    Task {
                        async let relayRefresh: Void = relay.refresh()
                        async let nodeRefresh: Void = node.refresh()
                        async let myaRefresh: Void = myaL11.refresh()
                        _ = await (relayRefresh, nodeRefresh, myaRefresh)
                    }
                } label: {
                    Label("Tümünü yenile", systemImage: "arrow.clockwise")
                }
                .disabled(relay.isRefreshing || node.isRefreshing || myaL11.isRefreshing)

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

private struct ServiceShortcut: View {
    let title: String
    let detail: String
    let symbol: String
    let tint: Color
    let available: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.callout.weight(.semibold))
                    Text(detail).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(available ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .disabled(!available)
    }
}

private struct LinuxRuntimeCard: View {
    let runtime: LinuxRuntimeStatus?
    let summary: String
    let online: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 10) {
                Image(systemName: "server.rack")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.indigo)
                    .frame(width: 34, height: 34)
                    .background(Color.indigo.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Linux motoru").font(.callout.weight(.semibold))
                    Text(summary).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(online: online && runtime != nil)
            }
            if let runtime {
                Divider()
                HStack {
                    Label("\(runtime.cpu) vCPU", systemImage: "cpu")
                    Spacer()
                    Label(ByteCountFormatter.string(fromByteCount: runtime.memory, countStyle: .memory), systemImage: "memorychip")
                    Spacer()
                    Label(ByteCountFormatter.string(fromByteCount: runtime.disk, countStyle: .file), systemImage: "internaldrive")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                Text("\(runtime.displayName) · \(runtime.driver) · \(runtime.arch) · \(runtime.mountType)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct DockerContainerRow: View {
    let container: DockerContainerStatus

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(container.isHealthy ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            VStack(alignment: .leading, spacing: 2) {
                Text(container.name).font(.caption.weight(.semibold))
                Text(container.purpose).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(container.isHealthy ? "Çalışıyor" : container.status)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(container.isHealthy ? Color.green : Color.orange)
                    .lineLimit(1)
                if let cpu = container.cpuPercent, let memory = container.memoryUsage {
                    Text("CPU \(cpu) · RAM \(memory.components(separatedBy: " / ").first ?? memory)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 5)
    }
}

private struct ServerServicesView: View {
    @EnvironmentObject private var monitor: MYAL11Monitor
    @State private var showContainers = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("REDMONO SUNUCU MERKEZİ").font(.headline)
                        Text("Mail · Takvim · Linux · DNS").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(online: monitor.isOnline)
                }

                Text("Servisler yalnızca kablo veya güvenli Tailnet üzerinden açılır.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Group {
                    Text("Mail ve takvim").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    ServiceShortcut(title: "Webmail", detail: "Gelen kutusu ve mail gönderme", symbol: "envelope.fill", tint: .blue, available: monitor.isOnline && (monitor.status?.services.webmail ?? true), action: monitor.openWebmail)
                    ServiceShortcut(title: "Mail ve takvim yönetimi", detail: "Hesaplar, alan adları, CalDAV/CardDAV", symbol: "person.crop.circle.badge.gearshape", tint: .purple, available: monitor.isOnline && (monitor.status?.services.mail ?? true), action: monitor.openMailAdmin)
                    ServiceShortcut(title: "Takvim", detail: "Mac Takvim uygulamasını aç", symbol: "calendar", tint: .red, available: true, action: monitor.openCalendar)
                    ServiceShortcut(title: "Hesabı Mac’e ekle", detail: "Mail + Takvim için İnternet Hesapları", symbol: "person.badge.plus", tint: .indigo, available: true, action: monitor.openAccountSettings)
                    ServiceShortcut(title: "Kampanyalar", detail: "Listeler ve toplu gönderimler", symbol: "paperplane.fill", tint: .orange, available: monitor.isOnline && (monitor.status?.services.listmonk ?? true), action: monitor.openCampaigns)
                    ServiceShortcut(title: "Test posta kutusu", detail: "Dışarı çıkmayan güvenli önizleme", symbol: "shippingbox.fill", tint: .mint, available: monitor.isOnline, action: monitor.openMailPreview)
                    ServiceShortcut(title: "Brevo SMTP ve API", detail: "Giden relay, anahtarlar ve kullanım", symbol: "paperplane.circle.fill", tint: .blue, available: true, action: monitor.openBrevoSMTP)
                    ServiceShortcut(title: "Brevo domain doğrulama", detail: "redmono.com DKIM ve doğrulama durumu", symbol: "checkmark.seal.fill", tint: .green, available: true, action: monitor.openBrevoDomains)
                }

                Divider()

                Group {
                    Text("Linux altyapısı").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    LinuxRuntimeCard(runtime: monitor.linuxRuntime, summary: monitor.linuxSummary, online: monitor.isOnline)
                    DisclosureGroup(isExpanded: $showContainers) {
                        if monitor.containers.isEmpty {
                            Text(monitor.infrastructureError ?? "Konteyner ayrıntıları bekleniyor…")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 8)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(monitor.containers) { container in
                                    DockerContainerRow(container: container)
                                    if container.id != monitor.containers.last?.id { Divider() }
                                }
                            }
                            .padding(.top, 5)
                        }
                    } label: {
                        HStack {
                            Label("Docker konteynerleri", systemImage: "shippingbox.fill")
                                .font(.callout.weight(.semibold))
                            Spacer()
                            Text(monitor.dockerSummary)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(10)
                    .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
                    ServiceShortcut(title: "FastDrop", detail: monitor.fastDropSummary, symbol: "arrow.left.arrow.right.circle.fill", tint: .blue, available: monitor.fastDropOnline, action: monitor.openDisk)
                    ServiceShortcut(title: "Konteyner paneli", detail: "Portainer · servisleri gör ve yönet", symbol: "shippingbox.and.arrow.backward.fill", tint: .teal, available: monitor.isOnline, action: monitor.openContainerPanel)
                    ServiceShortcut(title: "DNS ve reklam engelleme", detail: "AdGuard Home", symbol: "shield.lefthalf.filled", tint: .green, available: monitor.isOnline && (monitor.status?.services.adblock ?? true), action: monitor.openDNSPanel)
                    ServiceShortcut(title: "Sunucu ekranı", detail: "Tek tuş Apple Ekran Paylaşımı", symbol: "rectangle.on.rectangle", tint: .cyan, available: monitor.isOnline, action: monitor.openScreen)
                    ServiceShortcut(title: "Sunucu terminali", detail: "SSH bağlantısını aç", symbol: "terminal.fill", tint: .gray, available: monitor.isOnline, action: monitor.openSSH)
                }

                HStack {
                    Text(monitor.connectionSummary).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("Yenile") {
                        Task {
                            await monitor.refreshInfrastructure()
                            await monitor.refresh()
                        }
                    }
                        .buttonStyle(.borderless)
                        .disabled(monitor.isRefreshing)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 700)
    }
}

private struct OperationsView: View {
    @State private var section = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("Servis grubu", selection: $section) {
                Text("Altyapı").tag(0)
                Text("Mail").tag(1)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().padding(.top, 10)

            if section == 0 {
                ServerServicesView()
            } else {
                MailAccountsView()
            }
        }
    }
}

private struct MYAL11MenuView: View {
    @EnvironmentObject private var monitor: MYAL11Monitor
    @State private var confirmsShutdown = false
    @State private var confirmsRestart = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MYA-L11")
                        .font(.headline)
                    Text("Intel i9 MacBook Pro 16 · sunucu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                StatusPill(online: monitor.isOnline)
            }

            HStack(spacing: 6) {
                Image(systemName: monitor.route == .cable ? "cable.connector" : "network")
                    .foregroundStyle(monitor.isOnline ? Color.green : Color.orange)
                Text(monitor.routeLabel)
                    .font(.caption.weight(.medium))
                Spacer()
                Text("Kablo öncelikli · otomatik geçiş")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 10))

            if let status = monitor.status {
                HStack(spacing: 8) {
                    Image(systemName: monitor.isOnBattery ? "exclamationmark.triangle.fill" : "battery.100percent.bolt")
                        .foregroundStyle(monitor.isOnBattery ? Color.orange : Color.green)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(monitor.isOnBattery ? "UPS DEVREDE" : "UPS HAZIR")
                            .font(.caption.weight(.bold))
                        Text(monitor.upsSummary)
                            .font(.caption2)
                            .foregroundStyle(monitor.isOnBattery ? Color.orange : Color.secondary)
                    }
                    Spacer()
                }
                .padding(10)
                .background(
                    (monitor.isOnBattery ? Color.orange : Color.green).opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )

                VStack(spacing: 9) {
                    MetricRow(title: "Pil", value: "%\(status.batteryPercent) · \(status.batteryCondition) · \(status.batteryCycles) döngü")
                    MetricRow(title: "Güç", value: status.powerSource)
                    if monitor.isOnBattery, let minutes = status.batteryMinutesRemaining, minutes >= 0 {
                        MetricRow(title: "Tahmini süre", value: "\(minutes) dakika")
                    }
                    MetricRow(title: "CPU", value: status.cpuUsagePercent.map { String(format: "%%%.0f", $0) } ?? status.loadAverage.trimmingCharacters(in: .whitespaces))
                    MetricRow(title: "CPU sıcaklığı", value: status.cpuTemperatureC.map { String(format: "%.0f°C", $0) } ?? "Sensör okunamadı")
                    MetricRow(title: "GPU sıcaklığı", value: status.gpuTemperatureC.map { String(format: "%.0f°C", $0) } ?? "Sensör okunamadı")
                    MetricRow(title: "Boş RAM", value: "%\(status.memoryFreePercent)")
                    MetricRow(title: "Boş disk", value: Self.formatKB(status.diskFreeKB))
                    MetricRow(title: "Docker", value: "\(status.dockerContainersRunning) konteyner")
                    MetricRow(title: "FastDrop", value: monitor.fastDropSummary)
                    MetricRow(title: "Stats", value: status.services.stats == true ? "Çalışıyor" : "Kontrol gerekli")
                    MetricRow(title: "SSH", value: status.services.ssh ? "Bağlanılabilir" : "Kontrol gerekli")
                    MetricRow(title: "Ekran", value: status.services.screenSharing ? "Bağlanılabilir" : "Kontrol gerekli")
                    MetricRow(title: "Uyanık tutma", value: status.services.caffeinateGuard ? "Aktif" : "Kontrol gerekli")
                }
            } else {
                Text(monitor.lastError ?? "Telemetri bekleniyor…")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button(action: monitor.openScreen) {
                    Label("Ekran", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(monitor.route == .offline)

                Button(action: monitor.openDisk) {
                    Label("Disk", systemImage: "externaldrive")
                }
                .buttonStyle(.bordered)
                .disabled(monitor.route == .offline)

                Button(action: monitor.openSSH) {
                    Label("SSH", systemImage: "terminal")
                }
                .buttonStyle(.bordered)
                .disabled(monitor.route == .offline)
            }

            Divider()

            HStack(spacing: 7) {
                Button("Uyandır") { Task { await monitor.power("wake") } }
                    .disabled(monitor.isRunningAction)
                Button("Uyut") { Task { await monitor.power("sleep") } }
                    .disabled(!monitor.isOnline || monitor.isRunningAction)
                Button("Yeniden başlat") { confirmsRestart = true }
                    .disabled(!monitor.isOnline || monitor.isRunningAction)
                Button("Kapat") { confirmsShutdown = true }
                    .disabled(!monitor.isOnline || monitor.isRunningAction)
                    .tint(.red)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Text("Kapatma sonrası Wake-on-LAN garanti değildir; uzaktan erişimi kaybetmemek için normalde yeniden başlat veya uyut.")
                .font(.caption2)
                .foregroundStyle(.orange)

            if let message = monitor.actionMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button {
                    Task { await monitor.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .disabled(monitor.isRefreshing)
                Spacer()
                Text("Yalnızca kablo / Tailnet")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(16)
        .confirmationDialog("MYA-L11 yeniden başlatılsın mı?", isPresented: $confirmsRestart) {
            Button("Yeniden başlat") { Task { await monitor.power("restart") } }
            Button("Vazgeç", role: .cancel) {}
        }
        .confirmationDialog("MYA-L11 kapatılsın mı?", isPresented: $confirmsShutdown) {
            Button("Kapat", role: .destructive) { Task { await monitor.power("shutdown") } }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Tamamen kapandıktan sonra uzaktan yeniden açılması garanti değildir.")
        }
    }

    private static func formatKB(_ value: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: max(0, value) * 1024)
    }
}

private struct NodeMenuView: View {
    @EnvironmentObject private var node: NodeMonitor
    @EnvironmentObject private var separation: SeparationMonitor
    @State private var draftHost = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("DAAK NODE")
                        .font(.headline)
                    Text("Vaytniga · özel Tailscale hattı")
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
                HStack(spacing: 5) {
                    Image(systemName: "bell.and.waves.left.and.right")
                    Text(separation.statusLabel)
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
                if separation.statusLabel.contains("izin gerekli") {
                    HStack(spacing: 10) {
                        Button("Bildirim izni") {
                            separation.openNotificationSettings()
                        }
                        Button("Konum izni") {
                            separation.openLocationSettings()
                        }
                    }
                    .font(.caption)
                    .buttonStyle(.link)
                }
                if let detail = node.status?.lastError, !detail.isEmpty {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))

            if let health = node.deviceHealth {
                VStack(spacing: 9) {
                    MetricRow(title: "Pil", value: health.batteryPercent.map { "%\($0) · \(health.powerLabel ?? "bilinmiyor")" } ?? "Sensör bekleniyor")
                    MetricRow(title: "CPU sıcaklığı", value: health.cpuTemperatureC.map { String(format: "%.0f°C", $0) } ?? "Sensör okunamadı")
                    MetricRow(title: "Pil sıcaklığı", value: health.batteryTemperatureC.map { String(format: "%.0f°C", $0) } ?? "Sensör okunamadı")
                    MetricRow(title: "Boş RAM", value: health.memoryFreePercent.map { "%\($0)" } ?? "Telemetri bekleniyor")
                    MetricRow(title: "Canlı ekran", value: node.isOnline ? "ADB · bağlanılabilir" : "Bağlantı bekleniyor")
                }
            }

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

            Button {
                Task { await node.setPhoneExitNode(enabled: !node.isUsingPhoneExitNode) }
            } label: {
                Label(
                    node.isUsingPhoneExitNode ? "Vaytniga çıkışını kapat" : "Mac’i Vaytniga üzerinden çıkar",
                    systemImage: node.isUsingPhoneExitNode ? "network.slash" : "shield.lefthalf.filled"
                )
            }
            .buttonStyle(.bordered)
            .disabled(!node.isPhoneExitNodeAvailable || node.isSettingExitNode)

            Text(
                node.isUsingPhoneExitNode
                    ? "Açık · IP tabanlı konum S9’un internet çıkışını kullanıyor."
                    : "Kapalı · VPN/exit node yalnızca istediğinde açılır."
            )
            .font(.caption2)
            .foregroundStyle(.secondary)

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
                Text("Vaytniga · Tailscale IP")
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
    @EnvironmentObject private var myaL11: MYAL11Monitor
    @EnvironmentObject private var separation: SeparationMonitor
    @EnvironmentObject private var mail: MailAccountMonitor
    @EnvironmentObject private var updater: UpdateMonitor
    @EnvironmentObject private var localMac: LocalMacMonitor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
                Text("\([relay.isConnected, myaL11.isOnline, node.isOnline].filter { $0 }.count)/3 bağlı")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            DAAKPanelPicker(selection: $selection)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)

            Divider()

            ZStack {
                switch selection {
                case .devices:
                    DeviceOverviewView(selection: $selection)
                case .operations:
                    OperationsView()
                case .lolile:
                    ScrollView {
                        RelayMenuView()
                    }
                    .frame(maxHeight: 690)
                case .myaL11:
                    MYAL11MenuView()
                case .node:
                    NodeMenuView()
                }
            }
            .id(selection)
            .transition(reduceMotion ? .opacity : .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.985, anchor: .top)),
                removal: .opacity
            ))
            .animation(
                reduceMotion ? .easeOut(duration: 0.14) : .interactiveSpring(response: 0.34, dampingFraction: 1),
                value: selection
            )

            Divider()

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("DAAK NODE \(updater.versionLabel)")
                        .font(.caption2.monospacedDigit())
                    Text(updater.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if updater.isWorking {
                    ProgressView().controlSize(.small)
                } else if updater.updateAvailable {
                    Button("Güncelle") { Task { await updater.installNow() } }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else {
                    Button("Kontrol et") { Task { await updater.checkNow() } }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
        }
        .frame(width: 460)
        .background(reduceTransparency ? AnyShapeStyle(Color(nsColor: .windowBackgroundColor)) : AnyShapeStyle(.ultraThinMaterial))
        .onReceive(node.$location) { location in
            separation.updatePhoneLocation(location)
        }
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

                Button {
                    monitor.openRemoteDesktop()
                } label: {
                    Label("Windows App", systemImage: "display")
                }

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

@MainActor
private final class DAAKStatusBarController: NSObject, NSApplicationDelegate {
    private let relay = RelayMonitor()
    private let node = NodeMonitor()
    private let myaL11 = MYAL11Monitor()
    private let separation = SeparationMonitor()
    private let mail = MailAccountMonitor()
    private let updater = UpdateMonitor()
    private let localMac = LocalMacMonitor()

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let rootView = DAAKDevicesMenuView()
            .environmentObject(relay)
            .environmentObject(node)
            .environmentObject(myaL11)
            .environmentObject(separation)
            .environmentObject(mail)
            .environmentObject(updater)
            .environmentObject(localMac)

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 460, height: 720)
        popover.contentViewController = NSHostingController(rootView: rootView)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp])
            button.toolTip = "DAAK NODE cihaz merkezi"
            button.setAccessibilityLabel("DAAK NODE cihaz merkezi")
        }
        updateStatusIcon()

        myaL11.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &subscriptions)
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(sender)
            return
        }

        // The sync agent writes this tiny local JSON independently of the UI.
        // Reload it before drawing so power changes never wait for the timer.
        myaL11.reloadCachedTelemetry()
        Task { await myaL11.refresh() }

        // NSPopover is physically anchored to the status item. This keeps the
        // panel directly below the DAAK icon even when menu-bar items move.
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        DispatchQueue.main.async { [weak self, weak sender] in
            guard let self, let sender else { return }
            self.reanchorPopoverIfNeeded(to: sender)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self, weak sender] in
            guard let self, let sender else { return }
            self.reanchorPopoverIfNeeded(to: sender)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    private func reanchorPopoverIfNeeded(to sender: NSStatusBarButton) {
        guard popover.isShown,
              let buttonWindow = sender.window,
              let popoverWindow = popover.contentViewController?.view.window else { return }

        let buttonRectInWindow = sender.convert(sender.bounds, to: nil)
        let buttonRectOnScreen = buttonWindow.convertToScreen(buttonRectInWindow)
        let horizontalDrift = abs(popoverWindow.frame.midX - buttonRectOnScreen.midX)
        guard horizontalDrift > 2 else { return }

        // Menu-bar items can be reflowed immediately after launch. Showing an
        // already-visible NSPopover again updates its positioning association
        // without closing it or interrupting the user's interaction.
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
    }

    private func updateStatusIcon() {
        let symbol = myaL11.isOnBattery ? "exclamationmark.triangle.fill" : "circle.grid.2x2.fill"
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "DAAK NODE cihaz merkezi")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }
}

@main
struct daakLOLILEApp: App {
    @NSApplicationDelegateAdaptor(DAAKStatusBarController.self) private var statusBarController

    var body: some Scene {
        Settings { EmptyView() }
    }
}
