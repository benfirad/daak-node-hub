import SwiftUI
import AppKit
import CoreGraphics
import Combine
import Foundation
@preconcurrency import CoreLocation
import UserNotifications
import LocalAuthentication
import UniformTypeIdentifiers

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
    let thunderboltHost: String?
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

private struct OpportunityHealth: Decodable, Identifiable {
    struct Counts: Decodable {
        let events: Int
        let dossiers: Int
        let queuedOrRejected: Int
    }

    struct Source: Decodable, Identifiable {
        struct Detail: Decodable {
            let researchScope: String?
        }

        let sourceId: String
        let status: String
        let detail: Detail?

        var id: String { sourceId }
        var scope: String { detail?.researchScope?.uppercased() ?? "LOCAL" }
    }

    struct Worker: Decodable {
        let workerId: String
        let status: String
    }

    let status: String
    let service: String
    let nodeId: String
    let authority: String
    let externalActions: Bool
    let counts: Counts
    let scopeCounts: [String: Counts]?
    let sources: [Source]
    let workers: [Worker]

    var id: String { nodeId }
}

private struct OpportunityDossierList: Decodable {
    let items: [OpportunityDossier]
}

private struct OpportunityDossier: Decodable, Identifiable {
    struct Judge: Decodable {
        let requiredNextEvidence: [String]?
    }

    struct FounderPriority: Decodable {
        let score: Int
        let labels: [String]
        let startupSupportSourceCount: Int
        let canadaOfficialPathwaySourceCount: Int
        let supportIsNotImmigration: Bool
        let citizenshipGuaranteed: Bool
    }

    let opportunityId: String
    let status: String
    let score: Int
    let title: String
    let problem: String
    let whyNow: String
    let locality: String
    let researchScope: String?
    let topic: String
    let updatedAt: String
    let judge: Judge?
    let founderPriority: FounderPriority?

    var id: String { opportunityId }
    var isPublished: Bool { status == "PUBLISHED" }
    var scope: String { researchScope?.uppercased() ?? (locality == "SPAIN" ? "SPAIN" : "LOCAL") }
    var nextEvidence: [String] { Array((judge?.requiredNextEvidence ?? []).prefix(3)) }
}

private enum OpportunityResearchScope: String, CaseIterable, Identifiable {
    case local = "LOCAL"
    case spain = "SPAIN"
    case world = "WORLD"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .local: "Granada / Andalucía"
        case .spain: "Tüm İspanya"
        case .world: "Dünya · AB öncelikli"
        }
    }
    var subtitle: String {
        switch self {
        case .local: "Yerel problem, alıcı ve destek sinyalleri"
        case .spain: "Ulusal problem, alıcı, ihale ve dönüşüm sinyalleri"
        case .world: "Sevilla Üniversitesi ve AB önce · Kanada resmî yolları ayrı izlenir"
        }
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
            "PATH": "\(NSHomeDirectory())/bin:\(NSHomeDirectory())/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin",
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
        await run(executable, arguments, inputData: Data(input.utf8))
    }

    static func run(_ executable: String, _ arguments: [String], inputData: Data) async -> CommandResult {
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
                stdin.fileHandleForWriting.write(inputData)
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
        Task {
            try? await Task.sleep(for: .seconds(15))
            await checkIfDue()
        }
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
            state = installWhenAvailable ? "Hazır" : "Hata"
            message = installWhenAvailable
                ? "Çevrimdışı · yerel sürüm korunuyor."
                : (command.output.isEmpty ? "Güncelleme aracı yanıt vermedi." : command.output)
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
        default:
            if installWhenAvailable {
                state = "Hazır"
                message = "Yerel sürüm aktif · GitHub bağlantısı bekleniyor."
            } else {
                state = "Hata"
            }
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
        case thunderbolt = "Thunderbolt · 40 Gb/sn"
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
        if let error = fastDrop.lastError, !error.isEmpty {
            let cleaned = error
                .replacingOccurrences(of: #"<[^>]+>"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: "_x000D__x000A_", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return "Hata · \(String(cleaned.prefix(90)))"
        }
        if fastDrop.state == "uploading", let file = fastDrop.currentFile {
            return "Aktarılıyor · \(file)"
        }
        if fastDrop.state == "queued" && fastDrop.incomingFiles > 0 {
            return "LOLİLE uykuda · \(fastDrop.incomingFiles) dosya kuyrukta"
        }
        let available = ByteCountFormatter.string(fromByteCount: fastDrop.availableBytes, countStyle: .file)
        if fastDrop.incomingFiles > 0 { return "\(fastDrop.incomingFiles) dosya sırada · \(available) boş" }
        return "Hazır · \(available) boş · \(fastDrop.retainedFiles) dosya 72 saat korunuyor"
    }

    private func refreshRoute() async {
        if FileManager.default.isExecutableFile(atPath: routeSelectorPath) {
            let selected = await LocalCommand.run("/bin/zsh", [routeSelectorPath, "status"])
            switch selected.output.trimmingCharacters(in: .whitespacesAndNewlines) {
            case "thunderbolt":
                route = .thunderbolt
                return
            case "cable":
                route = .cable
                return
            case "tailscale":
                route = .tailscale
                return
            case "offline":
                route = isFresh ? .tailscale : .offline
                return
            default:
                break
            }
        }

        // Keep the configuration probes as a compatibility fallback for older
        // installations that do not have the shared route selector yet.
        if let thunderboltHost = configuration?.thunderboltHost, !thunderboltHost.isEmpty {
            let thunderbolt = await LocalCommand.run("/usr/bin/nc", ["-z", "-G", "1", thunderboltHost, "22"])
            if thunderbolt.exitCode == 0 {
                route = .thunderbolt
                return
            }
        }
        if let directHost = configuration?.directHost, !directHost.isEmpty {
            let cable = await LocalCommand.run("/usr/bin/nc", ["-6", "-z", "-G", "1", directHost, "22"])
            if cable.exitCode == 0 {
                route = .cable
                return
            }
        }
        guard let tailHost = configuration?.tailHost, !tailHost.isEmpty else {
            route = isFresh ? .tailscale : .offline
            return
        }
        let tail = await LocalCommand.run("/usr/bin/nc", ["-z", "-G", "2", tailHost, "22"])
        route = (tail.exitCode == 0 || isFresh) ? .tailscale : .offline
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
        switch route {
        case .thunderbolt: return "mya-l11-thunderbolt"
        case .cable: return "mya-l11-direct"
        case .tailscale, .offline: return "mya-l11-tail"
        }
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
    func openCampaigns() {
        Task { await openCampaignsSecurely() }
    }
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

    private func openCampaignsSecurely() async {
        guard let value = configuration?.campaignsURL,
              let remoteURL = URL(string: value) else {
            actionMessage = "Kampanya servisi için node-config.json ayarı gerekli."
            return
        }

        // Public campaign URLs should open normally. The private MYA-L11 URL is
        // deliberately kept on loopback and reached through an on-demand SSH
        // tunnel so Listmonk is never exposed to the LAN or the internet.
        guard remoteURL.host == configuration?.tailHost else {
            openURL(value)
            return
        }

        let remotePort = remoteURL.port ?? (remoteURL.scheme == "https" ? 443 : 80)
        guard (1...65_535).contains(remotePort) else {
            actionMessage = "Kampanya servisi port ayarı geçerli değil."
            return
        }

        let localPort = 39_000
        let localURL = "http://127.0.0.1:\(localPort)/"
        if await campaignTunnelIsReady(localURL) {
            openURL(localURL)
            return
        }

        let tunnel = await LocalCommand.run(
            "/usr/bin/ssh",
            [
                "-f", "-N",
                "-o", "ControlMaster=no",
                "-o", "ControlPath=none",
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=5",
                "-o", "ExitOnForwardFailure=yes",
                "-L", "127.0.0.1:\(localPort):127.0.0.1:\(remotePort)",
                "mya-l11-tail"
            ]
        )
        guard tunnel.exitCode == 0 else {
            actionMessage = "Kampanya paneli için güvenli tünel açılamadı."
            return
        }

        try? await Task.sleep(nanoseconds: 500_000_000)
        guard await campaignTunnelIsReady(localURL) else {
            actionMessage = "Kampanya paneli tünele rağmen yanıt vermedi."
            return
        }
        openURL(localURL)
    }

    private func campaignTunnelIsReady(_ localURL: String) async -> Bool {
        let result = await LocalCommand.run(
            "/usr/bin/curl",
            ["-fsS", "--max-time", "3", "--output", "/dev/null", localURL]
        )
        return result.exitCode == 0
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
private final class OpportunityMonitor: ObservableObject {
    @Published private(set) var healthNodes: [OpportunityHealth] = []
    @Published private(set) var opportunities: [OpportunityDossier] = []
    @Published private(set) var isRefreshing = false
    @Published private(set) var isOpeningDashboard = false
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var actionMessage: String?

    private let localDashboardURL = "http://127.0.0.1:5070/"
    private var timer: Timer?
    private var retryTask: Task<Void, Never>?

    init() {
        timer = Timer(timeInterval: 300, repeats: true) { _ in
            Task { @MainActor [weak self] in await self?.refresh() }
        }
        timer?.tolerance = 30
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        Task { await refresh() }
    }

    deinit {
        timer?.invalidate()
        retryTask?.cancel()
    }

    func sourceCoverage(for scope: OpportunityResearchScope) -> (live: Int, total: Int) {
        var all = Set<String>()
        var live = Set<String>()
        for node in healthNodes {
            for source in node.sources where source.scope == scope.rawValue {
                all.insert(source.sourceId)
                if source.status.uppercased() == "LIVE" { live.insert(source.sourceId) }
            }
        }
        return (live.count, all.count)
    }

    var fabricReady: Bool {
        let coverage = sourceCoverage(for: .local)
        return coverage.total > 0 && coverage.live > 0 && !healthNodes.isEmpty
    }

    func fabricReady(for scope: OpportunityResearchScope) -> Bool {
        let coverage = sourceCoverage(for: scope)
        return coverage.total > 0 && coverage.live > 0 && !healthNodes.isEmpty
    }

    func counts(for scope: OpportunityResearchScope) -> OpportunityHealth.Counts? {
        healthNodes.compactMap { $0.scopeCounts?[scope.rawValue] }.max { left, right in
            left.events < right.events
        }
    }

    func events(for scope: OpportunityResearchScope) -> Int {
        counts(for: scope)?.events ?? (scope == .local ? healthNodes.map(\.counts.events).max() ?? 0 : 0)
    }

    func publishedCount(for scope: OpportunityResearchScope) -> Int {
        counts(for: scope)?.dossiers ?? 0
    }

    func reviewedCount(for scope: OpportunityResearchScope) -> Int {
        counts(for: scope)?.queuedOrRejected ?? 0
    }
    var aiReady: Bool {
        healthNodes.contains { node in
            node.workers.contains { $0.status.uppercased() == "READY" }
        }
    }

    func validationCount(for scope: OpportunityResearchScope) -> Int {
        opportunities.filter { $0.scope == scope.rawValue && !$0.isPublished }.count
    }

    func opportunities(for scope: OpportunityResearchScope) -> [OpportunityDossier] {
        opportunities.filter { $0.scope == scope.rawValue }.sorted { left, right in
            if left.isPublished != right.isPublished { return left.isPublished }
            if scope == .world {
                let leftPriority = left.founderPriority?.score ?? 0
                let rightPriority = right.founderPriority?.score ?? 0
                if leftPriority != rightPriority { return leftPriority > rightPriority }
            }
            return left.score > right.score
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let myaHealth = Self.fetchHealth(host: "mya-l11-tail", windows: false)
        async let lolileHealth = Self.fetchHealth(host: "lolile-openclaw", windows: true)
        async let lolileDossiers = Self.fetchDossiers(host: "lolile-openclaw", windows: true)
        async let myaDossiers = Self.fetchDossiers(host: "mya-l11-tail", windows: false)

        let (mya, lolile, lolileIdeas, myaIdeas) = await (
            myaHealth, lolileHealth, lolileDossiers, myaDossiers
        )
        let healthy = [mya, lolile].compactMap { $0 }
        guard !healthy.isEmpty else {
            lastError = "MYA-L11 ve LOLILE araştırma düğümlerine ulaşılamadı; son doğrulanmış görünüm korunuyor."
            scheduleRetry()
            return
        }

        healthNodes = healthy.sorted { $0.nodeId < $1.nodeId }
        if lolileIdeas != nil || myaIdeas != nil {
            var mergedById: [String: OpportunityDossier] = [:]
            for item in (myaIdeas?.items ?? []) + (lolileIdeas?.items ?? []) where Self.isUseful(item) {
                if let existing = mergedById[item.opportunityId] {
                    if item.updatedAt >= existing.updatedAt {
                        mergedById[item.opportunityId] = item
                    }
                } else {
                    mergedById[item.opportunityId] = item
                }
            }
            opportunities = mergedById.values
                .sorted {
                    if $0.isPublished != $1.isPublished { return $0.isPublished }
                    return $0.score > $1.score
                }
        }
        lastUpdated = Date()
        if lolileIdeas == nil && myaIdeas == nil {
            lastError = "Fikir dosyaları okunamadı; önceki liste korunuyor."
            scheduleRetry()
        } else if healthy.count < 2 {
            // Do not trigger an aggressive 20-second retry storm when LOLILE is
            // sleeping/hibernating while MYA-L11 is healthy; wait for the 300s timer.
            lastError = lolile == nil
                ? "LOLİLE uykuda/hibernasyonda · MYA-L11 araştırma düğümü aktif."
                : "Araştırma düğümlerinden biri çevrimdışı; mevcut düğümün verisi gösteriliyor."
            retryTask?.cancel()
            retryTask = nil
        } else {
            lastError = nil
            retryTask?.cancel()
            retryTask = nil
        }
    }

    private func scheduleRetry() {
        guard retryTask == nil else { return }
        retryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 45_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.retryTask = nil
            await self.refresh()
        }
    }

    func openDashboard() async {
        guard !isOpeningDashboard else { return }
        isOpeningDashboard = true
        defer { isOpeningDashboard = false }

        if await Self.localDashboardReady(localDashboardURL) {
            NSWorkspace.shared.open(URL(string: localDashboardURL)!)
            return
        }

        let targets: [(host: String, windows: Bool)] = [
            ("lolile-openclaw", true),
            ("mya-l11-tail", false),
        ]
        for target in targets {
            guard await Self.fetchHealth(host: target.host, windows: target.windows) != nil else { continue }
            let tunnel = await LocalCommand.run(
                "/usr/bin/ssh",
                [
                    "-f", "-N",
                    "-o", "ControlMaster=no",
                    "-o", "ControlPath=none",
                    "-o", "BatchMode=yes",
                    "-o", "ConnectTimeout=8",
                    "-o", "ConnectionAttempts=1",
                    "-o", "ExitOnForwardFailure=yes",
                    "-L", "127.0.0.1:5070:127.0.0.1:5070",
                    target.host,
                ]
            )
            guard tunnel.exitCode == 0 else { continue }
            try? await Task.sleep(nanoseconds: 600_000_000)
            if await Self.localDashboardReady(localDashboardURL) {
                NSWorkspace.shared.open(URL(string: localDashboardURL)!)
                actionMessage = "Fırsat paneli güvenli loopback tünelinden açıldı."
                return
            }
        }
        actionMessage = "Fırsat paneli için güvenli tünel açılamadı."
    }

    private static func fetchHealth(host: String, windows: Bool) async -> OpportunityHealth? {
        let endpoint = "http://127.0.0.1:5070/healthz"
        let command = windows
            ? "curl.exe --fail --silent --show-error --max-time 8 \"\(endpoint)\""
            : "curl --fail --silent --show-error --max-time 8 '\(endpoint)'"
        guard let value: OpportunityHealth = await fetchJSON(host: host, command: command),
              value.service == "DAAK Opportunity Intelligence",
              value.authority == "RESEARCH_ONLY",
              value.externalActions == false else { return nil }
        return value
    }

    private static func fetchDossiers(host: String, windows: Bool) async -> OpportunityDossierList? {
        let endpoint = "http://127.0.0.1:5070/api/opportunities?include_rejected=true&limit=1000&slim=true"
        let command = windows
            ? "curl.exe --fail --silent --show-error --max-time 8 \"\(endpoint)\""
            : "curl --fail --silent --show-error --max-time 8 '\(endpoint)'"
        return await fetchJSON(host: host, command: command)
    }

    private static func fetchJSON<T: Decodable>(host: String, command: String) async -> T? {
        let result = await LocalCommand.run(
            "/usr/bin/ssh",
            [
                "-C",
                "-o", "BatchMode=yes",
                "-o", "ConnectTimeout=8",
                "-o", "ConnectionAttempts=1",
                "-o", "ServerAliveInterval=10",
                host,
                command,
            ]
        )
        guard result.exitCode == 0 else { return nil }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try? decoder.decode(T.self, from: Data(result.output.utf8))
    }

    private static func localDashboardReady(_ baseURL: String) async -> Bool {
        let result = await LocalCommand.run(
            "/usr/bin/curl",
            ["-fsS", "--max-time", "3", baseURL + "healthz"]
        )
        guard result.exitCode == 0 else { return false }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let health = try? decoder.decode(OpportunityHealth.self, from: Data(result.output.utf8)) else {
            return false
        }
        return health.service == "DAAK Opportunity Intelligence"
            && health.authority == "RESEARCH_ONLY"
            && health.externalActions == false
    }

    private static func isUseful(_ item: OpportunityDossier) -> Bool {
        if item.isPublished { return true }
        guard item.score >= 50 else { return false }
        let title = item.title.lowercased()
        let genericPrefixes = [
            "no defensible", "no supportable", "no falsifiable", "no publishable", "insufficient evidence",
        ]
        return !genericPrefixes.contains { title.hasPrefix($0) }
    }
}

private struct DeckTile: Identifiable, Hashable {
    let tag: String
    let title: String
    let action: String
    let protected: Bool

    var id: String { action }

    static let all: [DeckTile] = [
        .init(tag: "VOL-", title: "SES AZALT", action: "volume-down", protected: false),
        .init(tag: "MUTE", title: "SESSİZ", action: "volume-mute", protected: false),
        .init(tag: "VOL+", title: "SES ARTIR", action: "volume-up", protected: false),
        .init(tag: "PREV", title: "ÖNCEKİ", action: "music-previous", protected: false),
        .init(tag: "PLAY", title: "OYNAT / DURAKLAT", action: "music-playpause", protected: false),
        .init(tag: "NEXT", title: "SONRAKİ", action: "music-next", protected: false),
        .init(tag: "FILE", title: "FINDER", action: "open-finder", protected: false),
        .init(tag: "WEB", title: "SAFARI", action: "open-browser", protected: false),
        .init(tag: "CODEX", title: "CODEX", action: "open-codex", protected: false),
        .init(tag: "DAAK", title: "DAAK LOLILE", action: "open-daak", protected: false),
        .init(tag: "DESK", title: "MASAÜSTÜ", action: "show-desktop", protected: false),
        .init(tag: "VIEW", title: "MISSION CONTROL", action: "mission-control", protected: false),
        .init(tag: "TERM", title: "TERMINAL", action: "open-terminal", protected: false),
        .init(tag: "OLED", title: "EKRANI UYUT", action: "display-sleep", protected: true),
        .init(tag: "LOCK", title: "MAC'İ KİLİTLE", action: "lock-screen", protected: true)
    ]
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
    @Published private(set) var deckImageRevision = 0
    @Published private(set) var isDeckSyncing = false
    @Published var host: String

    private let hostKey = "daakNodeHost"
    private let sshPort = "8022"
    private let adbPort = "5555"
    private let usbSerial = "24285f7d0f037ece"
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

    var isOnline: Bool { status != nil || deviceHealth != nil }
    var hasLocation: Bool { (status?.lastSuccessAt ?? 0) > 0 || location != nil }

    var stateLabel: String {
        guard let status else {
            return deviceHealth != nil ? "ADB bağlı · Konum servisi uyuyor" : "Bağlantı bekleniyor"
        }
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
        let timestamp = (status?.lastSuccessAt ?? 0) > 0 ? status?.lastSuccessAt : location?.capturedAt
        guard let timestamp, timestamp > 0 else {
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
        deviceHealth = nil
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
            deviceHealth = nil
            lastError = "DAAK NODE Tailscale IP’si geçerli değil."
            return
        }

        var result = await LocalCommand.run("/usr/bin/ssh", sshArguments(remoteCommand: ".local/bin/daak-find status"))
        if result.exitCode != 0 {
            try? await Task.sleep(for: .seconds(1))
            result = await LocalCommand.run("/usr/bin/ssh", sshArguments(remoteCommand: ".local/bin/daak-find status"))
        }

        if result.exitCode == 0,
           let data = result.output.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(NodeStatus.self, from: data) {
            status = decoded
            lastError = nil
        } else {
            status = nil
        }

        await refreshDeviceHealth()
        if status == nil && deviceHealth == nil {
            lastError = "Vaytniga’ya ulaşılamadı. Tailscale ve Termux SSH bağlantısını kontrol et."
        } else {
            lastError = nil
        }
    }

    private func resolveActiveADBSerial() async -> String? {
        let usbCheck = await LocalCommand.run("/opt/homebrew/bin/adb", ["-s", usbSerial, "get-state"])
        if usbCheck.exitCode == 0 && usbCheck.output == "device" {
            return usbSerial
        }
        guard Self.isSafeHost(host) else { return nil }
        let tcpSerial = "\(host):\(adbPort)"
        let currentCheck = await LocalCommand.run("/opt/homebrew/bin/adb", ["-s", tcpSerial, "get-state"])
        if currentCheck.exitCode == 0 && currentCheck.output == "device" {
            return tcpSerial
        }
        _ = await LocalCommand.run("/opt/homebrew/bin/adb", ["connect", tcpSerial])
        let afterConnect = await LocalCommand.run("/opt/homebrew/bin/adb", ["-s", tcpSerial, "get-state"])
        if afterConnect.exitCode == 0 && afterConnect.output == "device" {
            return tcpSerial
        }
        return nil
    }

    private func refreshDeviceHealth() async {
        guard let serial = await resolveActiveADBSerial() else {
            deviceHealth = nil
            return
        }
        async let batteryResult = LocalCommand.run("/opt/homebrew/bin/adb", ["-s", serial, "shell", "dumpsys", "battery"])
        async let thermalResult = LocalCommand.run("/opt/homebrew/bin/adb", ["-s", serial, "shell", "dumpsys", "thermalservice"])
        async let memoryResult = LocalCommand.run("/opt/homebrew/bin/adb", ["-s", serial, "shell", "cat", "/proc/meminfo"])
        let (battery, thermal, memory) = await (batteryResult, thermalResult, memoryResult)
        guard battery.exitCode == 0 else {
            deviceHealth = nil
            return
        }
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
        actionMessage = "Vaytniga ekranına bağlanılıyor…"
        guard let serial = await resolveActiveADBSerial() else {
            actionMessage = "ADB bağlantısı hazır değil. Vaytniga kablosuz hata ayıklama / Tailscale açık olmalı."
            return
        }
        do {
            try LocalCommand.launch(
                "/opt/homebrew/bin/scrcpy",
                [
                    "--serial", serial,
                    "--no-audio",
                    "--stay-awake",
                    "--max-fps=45",
                    "--video-bit-rate=12M",
                    "--window-title", "DAAK NODE · Vaytniga"
                ]
            )
            actionMessage = serial == usbSerial
                ? "Canlı ekran USB üzerinden açıldı."
                : "Canlı ekran Tailscale üzerinden açıldı."
        } catch {
            actionMessage = "Canlı ekran açılamadı: \(error.localizedDescription)"
        }
    }

    func openSSH() {
        guard Self.isSafeHost(host), let url = URL(string: "ssh://\(host):\(sshPort)") else { return }
        NSWorkspace.shared.open(url)
        actionMessage = "Vaytniga terminali açılıyor."
    }

    func deckImage(for action: String) -> NSImage? {
        guard DeckTile.all.contains(where: { $0.action == action }) else { return nil }
        return NSImage(contentsOf: deckImageURL(for: action))
    }

    func installDeckImage(from sourceURL: URL, for action: String) async {
        guard DeckTile.all.contains(where: { $0.action == action }) else {
            actionMessage = "Deck görseli reddedildi: geçersiz eylem."
            return
        }
        guard Self.isSafeHost(host) else {
            actionMessage = "Önce Vaytniga Tailnet adresini doğrula."
            return
        }
        guard let source = NSImage(contentsOf: sourceURL),
              let png = Self.squarePNG(from: source, pixels: 640) else {
            actionMessage = "Fotoğraf okunamadı. PNG, JPEG veya HEIC seç."
            return
        }

        isDeckSyncing = true
        defer { isDeckSyncing = false }
        let localURL = deckImageURL(for: action)
        do {
            try FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try png.write(to: localURL, options: .atomic)
            deckImageRevision &+= 1
        } catch {
            actionMessage = "M3 önizlemesi kaydedilemedi: \(error.localizedDescription)"
            return
        }

        let directory = "storage/shared/Download/DAAK/ControlDeck"
        let remote = "\(directory)/\(action).png"
        let temporary = "\(directory)/.\(action).png.uploading"
        let remoteCommand = "mkdir -p \(directory) && cat > \(temporary) && test -s \(temporary) && mv -f \(temporary) \(remote)"
        let upload = await LocalCommand.run(
            "/usr/bin/ssh",
            sshArguments(remoteCommand: remoteCommand),
            inputData: png
        )
        actionMessage = upload.exitCode == 0
            ? "\(action) görseli M3 önizlemesine ve Vaytniga’ya aktarıldı."
            : "M3 önizlemesi hazır; telefon aktarımı başarısız: \(upload.output)"
    }

    func removeDeckImage(for action: String) async {
        guard DeckTile.all.contains(where: { $0.action == action }) else { return }
        try? FileManager.default.removeItem(at: deckImageURL(for: action))
        deckImageRevision &+= 1
        guard Self.isSafeHost(host) else {
            actionMessage = "Görsel M3 önizlemesinden kaldırıldı."
            return
        }
        isDeckSyncing = true
        defer { isDeckSyncing = false }
        let result = await LocalCommand.run(
            "/usr/bin/ssh",
            sshArguments(remoteCommand: "rm -f -- storage/shared/Download/DAAK/ControlDeck/\(action).png")
        )
        actionMessage = result.exitCode == 0
            ? "\(action) görseli M3 ve Vaytniga’dan kaldırıldı."
            : "M3 görseli kaldırıldı; telefon temizlenemedi: \(result.output)"
    }

    private func deckImageURL(for action: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/DAAK/ControlDeck", isDirectory: true)
            .appendingPathComponent(action + ".png")
    }

    private static func squarePNG(from source: NSImage, pixels: CGFloat) -> Data? {
        let sourceSize = source.size
        guard sourceSize.width > 0, sourceSize.height > 0 else { return nil }
        let output = NSImage(size: NSSize(width: pixels, height: pixels))
        output.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let scale = max(pixels / sourceSize.width, pixels / sourceSize.height)
        let size = NSSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let rect = NSRect(x: (pixels - size.width) / 2, y: (pixels - size.height) / 2,
                          width: size.width, height: size.height)
        source.draw(in: rect, from: .zero, operation: .copy, fraction: 1)
        output.unlockFocus()
        guard let tiff = output.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }

    private func sshArguments(remoteCommand: String) -> [String] {
        [
            "-p", sshPort,
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=6",
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
            status = nil
            lastError = host.isEmpty ? "Önce Windows PC’nin Tailscale IP’sini yaz." : "IP adresi geçerli değil."
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let url = baseURL.appendingPathComponent("api/status")
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.timeoutInterval = 6
        request.setValue("daakLOLILEMenu/2.1", forHTTPHeaderField: "User-Agent")

        for attempt in 1...2 {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                    throw MonitorError.badResponse
                }
                let decoded = try JSONDecoder().decode(RelayStatus.self, from: data)
                status = decoded
                lastError = nil
                return
            } catch {
                if attempt == 1 {
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }

        status = nil
        lastError = "LOLİLE uykuda veya hibernasyonda · RM-OS MYA-L11 üzerinde aktif."
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
    var onlineText: String = "PC bağlı"
    var offlineText: String = "Bağlantı bekleniyor"

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(online ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(online ? onlineText : offlineText)
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
    case smartHome
    case study
    case operations
    case opportunities
    case broadcast
    case lolile
    case myaL11
    case node
    case deck

    var id: String { rawValue }

    var title: String {
        switch self {
        case .devices: return "Merkez"
        case .smartHome: return "Ev & TV"
        case .study: return "Dersler"
        case .operations: return "Servisler"
        case .opportunities: return "Fırsatlar"
        case .broadcast: return "Yayın"
        case .lolile: return "LOLİLE"
        case .myaL11: return "MYA-L11"
        case .node: return "Vaytniga"
        case .deck: return "Deck"
        }
    }

    var symbol: String {
        switch self {
        case .devices: return "square.grid.2x2.fill"
        case .smartHome: return "lightbulb.led.wide.fill"
        case .study: return "graduationcap.fill"
        case .operations: return "server.rack"
        case .opportunities: return "scope"
        case .broadcast: return "dot.radiowaves.left.and.right"
        case .lolile: return "desktopcomputer"
        case .myaL11: return "laptopcomputer"
        case .node: return "iphone"
        case .deck: return "rectangle.grid.3x2.fill"
        }
    }
}

private struct BroadcastStatus: Decodable {
    let route: String
    let sender: String
    let receiver: String
    let ready: Bool
    let streaming: Bool
    let quality: String?
    let effectiveQuality: String?
    let layout: String?
    let verticalLayout: String?
    let captureMode: String?
    let studioReady: Bool?
    let cameraReady: Bool?
    let privacyReady: Bool?
    let captureWindowID: Int?
    let captureWindowOwner: String?
}

private enum BroadcastCaptureMode: String, CaseIterable, Identifiable {
    case window
    case display

    var id: String { rawValue }

    var title: String {
        switch self {
        case .window: return "Tek pencere"
        case .display: return "Tüm ekran"
        }
    }
}

private enum BroadcastQuality: String, CaseIterable, Identifiable {
    case fullHD = "1080p60"
    case quadHD = "1440p60"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fullHD: return "1080p60"
        case .quadHD: return "1440p60"
        }
    }

    var specification: String {
        switch self {
        case .fullHD: return "40 Mb/sn ara akış · 30 Mb/sn Intel master"
        case .quadHD: return "80 Mb/sn ara akış · 50 Mb/sn Intel master"
        }
    }
}

private enum BroadcastLayout: String, CaseIterable, Identifiable {
    case screen
    case studio
    case phone
    case mac

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screen: return "Ekran"
        case .studio: return "Stüdyo"
        case .phone: return "Telefon"
        case .mac: return "M3 kamera"
        }
    }
}

private enum BroadcastVerticalLayout: String, CaseIterable, Identifiable {
    case screenPhone = "screen-phone"
    case screenMac = "screen-mac"
    case triple

    var id: String { rawValue }

    var title: String {
        switch self {
        case .screenPhone: return "Ekran + telefon"
        case .screenMac: return "Ekran + webcam"
        case .triple: return "Üçlü"
        }
    }
}

private struct BroadcastWindowOption: Identifiable, Hashable {
    let id: Int
    let owner: String
    let title: String

    var label: String { "\(owner) · \(title)" }
}

@MainActor
private final class BroadcastMonitor: ObservableObject {
    @Published private(set) var status: BroadcastStatus?
    @Published private(set) var isWorking = false
    @Published private(set) var message = "Yayın yolu denetleniyor."
    @Published private(set) var selectedQuality: BroadcastQuality = .quadHD
    @Published private(set) var selectedLayout: BroadcastLayout = .studio
    @Published private(set) var selectedVerticalLayout: BroadcastVerticalLayout = .screenPhone
    @Published private(set) var selectedCaptureMode: BroadcastCaptureMode = .window
    @Published private(set) var selectedWindowID: Int?
    @Published private(set) var availableWindows: [BroadcastWindowOption] = []

    private var script: String {
        Bundle.main.path(forResource: "daak-broadcast-control", ofType: "zsh")
            ?? NSHomeDirectory() + "/Library/Application Support/DAAK/Broadcast/daak-broadcast-control.zsh"
    }

    init() {
        Task { await refresh() }
    }

    func refresh() async {
        guard !isWorking else { return }
        let result = await LocalCommand.run(script, ["status"])
        guard result.exitCode == 0,
              let data = result.output.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(BroadcastStatus.self, from: data) else {
            status = nil
            message = result.output.isEmpty ? "Yayın denetleyicisi bulunamadı." : result.output
            return
        }
        status = decoded
        if let quality = decoded.quality,
           let selected = BroadcastQuality(rawValue: quality) {
            selectedQuality = selected
        }
        if let layout = decoded.layout,
           let selected = BroadcastLayout(rawValue: layout) {
            selectedLayout = selected
        }
        if let layout = decoded.verticalLayout,
           let selected = BroadcastVerticalLayout(rawValue: layout) {
            selectedVerticalLayout = selected
        }
        if let mode = decoded.captureMode,
           let selected = BroadcastCaptureMode(rawValue: mode) {
            selectedCaptureMode = selected
        }
        selectedWindowID = decoded.captureWindowID
        refreshWindows()
        message = decoded.streaming ? "Canlı SRT akışı Intel Mac'e ulaşıyor." : routeMessage(decoded)
    }

    func start() async { await perform("start", progress: "Yayın yolu başlatılıyor…") }
    func stop() async { await perform("stop", progress: "Yayın durduruluyor…") }
    func openLocal() async { await perform("local", progress: "M3 OBS açılıyor…") }
    func setQuality(_ quality: BroadcastQuality) async {
        guard status?.streaming != true else { return }
        await perform(
            "quality",
            arguments: [quality.rawValue],
            progress: "\(quality.title) profili uygulanıyor…"
        )
    }

    func setLayout(_ layout: BroadcastLayout) async {
        guard status?.streaming != true else { return }
        await perform(
            "layout",
            arguments: [layout.rawValue],
            progress: "\(layout.title) düzeni kaydediliyor…"
        )
    }

    func setVerticalLayout(_ layout: BroadcastVerticalLayout) async {
        guard status?.streaming != true else { return }
        await perform(
            "vertical",
            arguments: [layout.rawValue],
            progress: "\(layout.title) dikey düzeni kaydediliyor…"
        )
    }

    func setCaptureMode(_ mode: BroadcastCaptureMode) async {
        guard status?.streaming != true else { return }
        await perform(
            "capture",
            arguments: [mode.rawValue],
            progress: "\(mode.title) yakalama modu hazırlanıyor…"
        )
    }

    func setCaptureWindow(_ window: BroadcastWindowOption) async {
        guard status?.streaming != true else { return }
        await perform(
            "window",
            arguments: [String(window.id), window.owner, window.title],
            progress: "Güvenli yayın penceresi seçiliyor…"
        )
    }

    private func refreshWindows() {
        let ignoredOwners: Set<String> = [
            "OBS", "Window Server", "WindowManager", "Dock", "Finder", "SystemUIServer", "loginwindow",
            "Control Center", "Notification Center", "Centro de control", "Centro de notificaciones",
            "Fondo de pantalla", "NotchNook", "ClockScrambler",
            "daakLOLILE"
        ]
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] ?? []
        availableWindows = rawWindows.compactMap { entry in
            guard let owner = entry[kCGWindowOwnerName as String] as? String,
                  !ignoredOwners.contains(owner),
                  let rawTitle = entry[kCGWindowName as String] as? String,
                  let number = entry[kCGWindowNumber as String] as? NSNumber,
                  let layer = entry[kCGWindowLayer as String] as? NSNumber,
                  layer.intValue == 0,
                  let sharing = entry[kCGWindowSharingState as String] as? NSNumber,
                  sharing.intValue != 0,
                  let bounds = entry[kCGWindowBounds as String] as? [String: Any],
                  let width = bounds["Width"] as? NSNumber,
                  let height = bounds["Height"] as? NSNumber,
                  width.doubleValue >= 320,
                  height.doubleValue >= 180 else { return nil }
            let title = rawTitle
                .replacingOccurrences(of: "\r", with: " ")
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            return BroadcastWindowOption(id: number.intValue, owner: owner, title: title)
        }
        .sorted {
            $0.owner.localizedCaseInsensitiveCompare($1.owner) == .orderedAscending ||
                ($0.owner == $1.owner && $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending)
        }
    }

    private func perform(_ action: String, arguments: [String] = [], progress: String) async {
        guard !isWorking else { return }
        isWorking = true
        message = progress
        let result = await LocalCommand.run(script, [action] + arguments)
        isWorking = false
        if result.exitCode != 0 {
            message = result.output.isEmpty ? "Yayın komutu çalışmadı." : result.output
            return
        }
        try? await Task.sleep(for: .seconds(1))
        await refresh()
    }

    private func routeMessage(_ value: BroadcastStatus) -> String {
        if value.privacyReady != true {
            return value.captureMode == BroadcastCaptureMode.display.rawValue
                ? "Tüm ekran hedefi hazır değil."
                : "Önce yalnız yayında görünecek güvenli pencereyi seç."
        }
        if value.route == "offline" { return "Intel erişilemiyor; yerel OBS kullanılabilir." }
        if value.receiver == "unreachable" || value.receiver == "unknown" {
            return "Intel yayın denetleyicisine ulaşılamadı; Thunderbolt ve Tailscale yeniden denenecek."
        }
        if value.receiver == "idle" { return "Intel alıcısı henüz hazır değil." }
        if value.receiver == "receiving" { return "Intel alıyor ve VideoToolbox ile işliyor." }
        if value.receiver == "listening" { return "Intel alıcı hazır; yayın başlatılabilir." }
        if value.sender == "idle" { return "M3 OBS açık; ara akış beklemede." }
        return "Yayın beklemede."
    }
}

private struct BroadcastView: View {
    @EnvironmentObject private var monitor: BroadcastMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAAK YAYIN").font(.headline)
                    Text(monitor.message).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Circle()
                    .fill(monitor.status?.streaming == true ? Color.green : Color.secondary.opacity(0.45))
                    .frame(width: 10, height: 10)
            }

            if let status = monitor.status {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow { Text("Rota").foregroundStyle(.secondary); Text(routeLabel(status.route)).bold() }
                    GridRow { Text("M3 gönderici").foregroundStyle(.secondary); Text(stateLabel(status.sender)) }
                    GridRow { Text("Intel alıcı").foregroundStyle(.secondary); Text(stateLabel(status.receiver)) }
                    GridRow { Text("Açık kaynak stüdyo").foregroundStyle(.secondary); Text(status.studioReady == true ? "Aitum hazır" : "Eklenti eksik") }
                    GridRow { Text("Kameralar").foregroundStyle(.secondary); Text(status.cameraReady == true ? "M3 + telefon hazır" : "Yapılandırılmadı") }
                    GridRow {
                        Text("Yakalama").foregroundStyle(.secondary)
                        if status.captureMode == BroadcastCaptureMode.display.rawValue {
                            Text(status.privacyReady == true ? "Tüm ekran · dikkat" : "Tüm ekran hedefi eksik")
                                .foregroundStyle(Color.orange)
                        } else {
                            Text(status.privacyReady == true ? "Tek pencere · hazır" : "Pencere seçilmeli")
                                .foregroundStyle(status.privacyReady == true ? Color.green : Color.orange)
                        }
                    }
                }
                .font(.callout)
            }

            HStack(spacing: 8) {
                Button("Başlat") { Task { await monitor.start() } }
                    .buttonStyle(.borderedProminent)
                    .disabled(monitor.isWorking || monitor.status?.streaming == true || monitor.status?.privacyReady != true)
                Button("Durdur") { Task { await monitor.stop() } }
                    .buttonStyle(.bordered)
                    .disabled(monitor.isWorking)
                Button("OBS Stüdyo") { Task { await monitor.openLocal() } }
                    .buttonStyle(.bordered)
                Button("Companion") {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Companion.app"))
                }
                .buttonStyle(.bordered)
                .help("Açık kaynak Bitfocus Companion kontrol yüzeyini aç")
                Spacer()
                Button { Task { await monitor.refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(monitor.isWorking)
                .accessibilityLabel("Yayın durumunu yenile")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Ekran yakalama")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(
                    "Ekran yakalama modu",
                    selection: Binding(
                        get: { monitor.selectedCaptureMode },
                        set: { mode in Task { await monitor.setCaptureMode(mode) } }
                    )
                ) {
                    ForEach(BroadcastCaptureMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(monitor.isWorking || monitor.status?.streaming == true)

                if monitor.selectedCaptureMode == .window {
                    Picker(
                        "Güvenli yayın penceresi",
                        selection: Binding<Int?>(
                            get: { monitor.selectedWindowID },
                            set: { windowID in
                                guard let windowID,
                                      let window = monitor.availableWindows.first(where: { $0.id == windowID }) else { return }
                                Task { await monitor.setCaptureWindow(window) }
                            }
                        )
                    ) {
                        Text("Pencere seç").tag(Int?.none)
                        ForEach(monitor.availableWindows) { window in
                            Text(window.label).lineLimit(1).tag(Optional(window.id))
                        }
                    }
                    .labelsHidden()
                    .disabled(monitor.isWorking || monitor.status?.streaming == true)
                } else {
                    Label(
                        "Tüm ekran menü barını, Dock'u, masaüstü dosyalarını ve bildirimleri gösterebilir.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .font(.caption)
                    .foregroundStyle(Color.orange)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Text("Yayın düzeni")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(
                    "Yayın düzeni",
                    selection: Binding(
                        get: { monitor.selectedLayout },
                        set: { layout in Task { await monitor.setLayout(layout) } }
                    )
                ) {
                    ForEach(BroadcastLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(monitor.isWorking || monitor.status?.streaming == true)

                Text("Dikey 9:16 düzeni")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(
                    "Dikey 9:16 düzeni",
                    selection: Binding(
                        get: { monitor.selectedVerticalLayout },
                        set: { layout in Task { await monitor.setVerticalLayout(layout) } }
                    )
                ) {
                    ForEach(BroadcastVerticalLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(monitor.isWorking || monitor.status?.streaming == true)

                Text("Yayın kalitesi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Picker(
                    "Yayın kalitesi",
                    selection: Binding(
                        get: { monitor.selectedQuality },
                        set: { quality in Task { await monitor.setQuality(quality) } }
                    )
                ) {
                    ForEach(BroadcastQuality.allCases) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .disabled(monitor.isWorking || monitor.status?.streaming == true)
            }

            Label(profileSummary, systemImage: "bolt.horizontal.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(monitor.status?.route == "direct" ? Color.green : Color.secondary)

            Text("Tek pencere güvenli varsayılandır; hedef kapanırsa görüntü siyaha düşer. Tüm ekran yalnız sen seçtiğinde açılır. Yatayda ekran, telefon veya M3 kamera sahnesine geçtiğinde dikey yayın da aynı kaynağa geçer; stüdyo sahnesi kayıtlı ikili/üçlü dikey düzeni kullanır.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 620, alignment: .topLeading)
        .task { await monitor.refresh() }
    }

    private var profileSummary: String {
        if monitor.status?.route == "tailscale" {
            return "Tailscale · 1080p30 · 8 Mb/sn ara akış"
        }
        return "Thunderbolt · \(monitor.selectedQuality.title) · \(monitor.selectedQuality.specification) · MTU 9000"
    }

    private func routeLabel(_ value: String) -> String {
        switch value {
        case "direct": return "Thunderbolt"
        case "tailscale": return "Tailscale"
        default: return "Yerel / çevrimdışı"
        }
    }

    private func stateLabel(_ value: String) -> String {
        switch value {
        case "streaming": return "Akışta"
        case "listening": return "Hazır"
        case "receiving": return "Alıyor"
        case "idle": return "Beklemede"
        case "stopped": return "Kapalı"
        case "unreachable", "unknown": return "Erişilemiyor"
        case "offline": return "Çevrimdışı"
        default: return value.capitalized
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
                    Image(systemName: panel.symbol)
                        .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selection == panel ? Color.primary : Color.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
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
                .help(panel.title)
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
    @EnvironmentObject private var smartHome: SmartHomeMonitor
    @EnvironmentObject private var study: UniversityStudyMonitor
    @Binding var selection: DevicePanel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("SUNUCU & EV DURUMU").font(.caption.weight(.bold))
                        Text("Güç, sıcaklık, aydınlatma, TV ve sınavlar tek bakışta")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        smartHome.openCommandCenterWindow?()
                    } label: {
                        Label("Komuta Merkezi", systemImage: "macwindow.badge.plus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)
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

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Button {
                            selection = .smartHome
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "lightbulb.led.wide.fill")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(smartHome.anyLightOn ? Color.yellow : Color.orange)
                                    .frame(width: 36, height: 36)
                                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PHILIPS HUE & TCL 4K TV")
                                        .font(.subheadline.weight(.bold))
                                    Text(smartHome.quickSummary)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Circle()
                                    .fill(smartHome.hueOnline ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(DAAKPressStyle())
                    }

                    HStack(spacing: 6) {
                        Button {
                            Task { await smartHome.setAllLights(on: true) }
                        } label: {
                            Label("Işık Aç", systemImage: "sun.max.fill")
                        }
                        Button {
                            Task { await smartHome.setAllLights(on: false) }
                        } label: {
                            Label("Kapat", systemImage: "moon.fill")
                        }
                        Button {
                            Task { await smartHome.startCinemaMode(app: "stremio") }
                        } label: {
                            Label("Sinema", systemImage: "film.fill")
                        }
                        .tint(.purple)
                        Button {
                            Task { await smartHome.tvArtMode() }
                        } label: {
                            Label("Tablo", systemImage: "photo.artframe")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.07), lineWidth: 0.5)
                }

                // Upcoming Exams & Course Notes Quick Card
                Button {
                    selection = .study
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.mint)
                            .frame(width: 36, height: 36)
                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("DERS NOTLARI & YAKLAŞAN SINAVLAR")
                                .font(.subheadline.weight(.bold))
                            Text(study.nextExamBannerText)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("%\(study.overallReadinessPercent) hazır")
                            .font(.caption2.monospacedDigit().weight(.bold))
                            .foregroundStyle(.mint)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(.white.opacity(0.07), lineWidth: 0.5)
                    }
                }
                .buttonStyle(DAAKPressStyle())

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
                            async let homeRefresh: Void = smartHome.refresh()
                            _ = await (relayRefresh, nodeRefresh, myaRefresh, homeRefresh)
                        }
                    } label: {
                        Label("Tümünü yenile", systemImage: "arrow.clockwise")
                    }
                    .disabled(relay.isRefreshing || node.isRefreshing || myaL11.isRefreshing || smartHome.isRefreshing)

                    Spacer()

                    Button("Çıkış") {
                        NSApplication.shared.terminate(nil)
                    }
                }
                .buttonStyle(.borderless)
            }
            .padding(16)
        }
        .frame(maxHeight: 690)
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

private struct OpportunityMetricCard: View {
    let title: String
    let value: String
    let detail: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.monospacedDigit().weight(.semibold))
                .foregroundStyle(tint)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 11))
    }
}

private struct OpportunityDossierCard: View {
    let item: OpportunityDossier
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.isPublished ? "YAYINLANAN FİKİR" : "SAHADA DOĞRULA")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(item.isPublished ? Color.green : Color.orange)
                    Text(item.title)
                        .font(.callout.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(item.locality) · \(item.topic)")
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    if let priority = item.founderPriority, priority.score > 0 {
                        Text("KURUCU ÖNCELİĞİ \(priority.score) · \(priority.labels.prefix(2).joined(separator: " · "))")
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.blue)
                    }
                }
                Spacer(minLength: 8)
                Text("\(item.score)")
                    .font(.title2.monospacedDigit().weight(.bold))
                    .foregroundStyle(item.isPublished ? Color.green : Color.orange)
                    .frame(minWidth: 42)
                    .padding(.vertical, 5)
                    .background(
                        (item.isPublished ? Color.green : Color.orange).opacity(0.1),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("KANITLANAN PROBLEM")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(item.problem)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(expanded ? nil : 3)
            }

            if expanded {
                if let priority = item.founderPriority,
                   priority.canadaOfficialPathwaySourceCount > 0 {
                    Text("Kanada resmî yol sinyali var; startup desteği, oturum ve vatandaşlık ayrı doğrulanır.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.blue)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("NEDEN ŞİMDİ")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(item.whyNow)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !item.nextEvidence.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("BELEDİYEDE SORULACAK EKSİK KANIT")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                        ForEach(Array(item.nextEvidence.enumerated()), id: \.offset) { index, evidence in
                            Text("\(index + 1). \(evidence)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            Button(expanded ? "Daralt" : "Eksik kanıtı göster") {
                expanded.toggle()
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.medium))
        }
        .padding(12)
        .background(.quaternary.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(item.isPublished ? Color.green : Color.orange)
                .frame(width: 3)
                .padding(.vertical, 1)
        }
    }
}

private struct OpportunityView: View {
    @EnvironmentObject private var monitor: OpportunityMonitor
    @State private var selectedScope: OpportunityResearchScope = .local
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 2)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FIRSATLAR // RESEARCH")
                            .font(.headline)
                        Text("\(selectedScope.title) · kanıt öncelikli startup araştırması")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if monitor.isRefreshing {
                        ProgressView().controlSize(.small)
                    } else {
                        StatusPill(online: monitor.fabricReady(for: selectedScope))
                    }
                }

                Picker("Araştırma kapsamı", selection: $selectedScope) {
                    ForEach(OpportunityResearchScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text(selectedScope.subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.green)
                    Text("RESEARCH_ONLY · Sistem başvuru yapamaz, kurumla iletişime geçemez ve resmî işlem başlatamaz.")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 11))

                LazyVGrid(columns: columns, spacing: 8) {
                    let coverage = monitor.sourceCoverage(for: selectedScope)
                    OpportunityMetricCard(
                        title: "Kaynak fabric",
                        value: "\(coverage.live)/\(coverage.total)",
                        detail: monitor.fabricReady(for: selectedScope)
                            ? (coverage.live == coverage.total ? "Seçili kapsam canlı" : "\(coverage.live) kaynak aktif")
                            : "Düğümler tamamlıyor",
                        tint: monitor.fabricReady(for: selectedScope) ? .green : .orange
                    )
                    OpportunityMetricCard(
                        title: "Kanıt olayı",
                        value: "\(monitor.events(for: selectedScope))",
                        detail: "Tekilleştirilmiş kayıt",
                        tint: .blue
                    )
                    OpportunityMetricCard(
                        title: "İncelenen",
                        value: "\(monitor.reviewedCount(for: selectedScope))",
                        detail: "Bağımsız AI + kapı",
                        tint: .purple
                    )
                    OpportunityMetricCard(
                        title: "Yayınlanan",
                        value: "\(monitor.publishedCount(for: selectedScope))",
                        detail: "Doğrulama adayı \(monitor.validationCount(for: selectedScope))",
                        tint: monitor.publishedCount(for: selectedScope) > 0 ? .green : .orange
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("ARAŞTIRMA DÜĞÜMLERİ")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    ForEach(monitor.healthNodes) { node in
                        let sources = node.sources.filter { $0.scope == selectedScope.rawValue }
                        let liveCount = sources.filter { $0.status == "LIVE" }.count
                        HStack(spacing: 8) {
                            Circle()
                                .fill((node.status == "ok" || liveCount > 0) ? Color.green : Color.orange)
                                .frame(width: 7, height: 7)
                            Text(node.nodeId).font(.caption.weight(.semibold))
                            Spacer()
                            Text("\(liveCount)/\(sources.count) kaynak")
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                            if node.workers.contains(where: { $0.status == "READY" }) {
                                Text("AI READY")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.purple)
                            }
                        }
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))

                HStack {
                    Text("DOĞRULAMA ADAYLARI")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Puan tek başına yayınlatmaz")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }

                let scopedOpportunities = monitor.opportunities(for: selectedScope)
                if scopedOpportunities.isEmpty {
                    Text("\(selectedScope.title) kapsamında şu an sahaya sorulmaya değer, jenerik olmayan bir hipotez yok. Sistem yeni problem ve alıcı kanıtlarını taramayı sürdürüyor.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 11))
                } else {
                    ForEach(scopedOpportunities) { item in
                        OpportunityDossierCard(item: item)
                    }
                }

                if let error = monitor.lastError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let message = monitor.actionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.contains("açılamadı") ? Color.orange : Color.secondary)
                }

                HStack {
                    Button {
                        Task { await monitor.refresh() }
                    } label: {
                        Label("Yenile", systemImage: "arrow.clockwise")
                    }
                    .disabled(monitor.isRefreshing)

                    Button {
                        Task { await monitor.openDashboard() }
                    } label: {
                        Label("Paneli aç", systemImage: "safari")
                    }
                    .disabled(monitor.isOpeningDashboard)

                    Spacer()
                    if let updated = monitor.lastUpdated {
                        Text(updated.formatted(date: .omitted, time: .shortened))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.borderless)
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
                Text("Fırsatlar").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Divider().padding(.top, 10)

            if section == 0 {
                ServerServicesView()
            } else if section == 1 {
                MailAccountsView()
            } else {
                OpportunityView()
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
                Image(systemName: monitor.route == .thunderbolt ? "bolt.horizontal.fill" : (monitor.route == .cable ? "cable.connector" : "network"))
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

private struct DeckManagerView: View {
    @EnvironmentObject private var node: NodeMonitor
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 7), count: 5)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("DECK // M3 MAC")
                            .font(.headline)
                        Text("Telefonun yatay 5×3 düzeninde önizle · Vaytniga’ya aktar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if node.isDeckSyncing { ProgressView().controlSize(.small) }
                }

                Text("Fotoğraf kare PNG’ye yeniden kodlanır; konum ve kamera metadata’sı taşınmaz. Aktarım yalnız özel Tailnet/SSH hattından ve sabit Deck adlarıyla yapılır.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: columns, spacing: 7) {
                    ForEach(DeckTile.all) { tile in
                        Button {
                            chooseImage(for: tile)
                        } label: {
                            deckPreview(tile)
                        }
                        .buttonStyle(DAAKPressStyle())
                        .contextMenu {
                            Button("Fotoğraf seç…") { chooseImage(for: tile) }
                            if node.deckImage(for: tile.action) != nil {
                                Button("Görseli kaldır", role: .destructive) {
                                    Task { await node.removeDeckImage(for: tile.action) }
                                }
                            }
                        }
                        .help("\(tile.title) için fotoğraf seç")
                    }
                }

                if let message = node.actionMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(message.contains("başarısız") || message.contains("açılamadı") ? Color.orange : Color.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(16)
        }
        .frame(maxHeight: 690)
    }

    @ViewBuilder
    private func deckPreview(_ tile: DeckTile) -> some View {
        let image = node.deckImage(for: tile.action)
        ZStack(alignment: .topTrailing) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(Color.black.opacity(0.36))
            } else {
                LinearGradient(
                    colors: tile.protected
                        ? [Color.purple.opacity(0.34), Color.black.opacity(0.78)]
                        : [Color(nsColor: .controlBackgroundColor), Color.black.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(tile.tag)
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(image == nil ? Color.purple : Color.white)
                Spacer(minLength: 2)
                Text(tile.title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(image == nil ? "FOTOĞRAF SEÇ" : "M3 PREVIEW")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.68))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .padding(10)

            Image(systemName: image == nil ? "photo.badge.plus" : "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(image == nil ? Color.secondary : Color.green)
                .padding(8)
        }
        .frame(height: 86)
        .clipped()
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(tile.protected ? Color.purple.opacity(0.7) : Color.primary.opacity(0.12), lineWidth: 1)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .id("\(tile.action)-\(node.deckImageRevision)")
    }

    private func chooseImage(for tile: DeckTile) {
        let panel = NSOpenPanel()
        panel.title = "\(tile.title) için Deck fotoğrafı seç"
        panel.prompt = "Seç ve aktar"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await node.installDeckImage(from: url, for: tile.action) }
    }
}

struct HueLight: Identifiable, Equatable {
    let id: String
    var name: String
    var modelID: String
    var on: Bool
    var bri: Int
    var reachable: Bool

    var brightnessPercent: Int {
        max(1, min(100, Int((Double(bri) / 254.0 * 100.0).rounded())))
    }
}

struct TVTelemetry: Equatable {
    var online: Bool
    var serial: String
    var model: String
    var android: String
    var ip: String
    var wakefulness: String
    var dreaming: Bool
    var volume: Int
    var focus: String

    var isAwake: Bool {
        online && wakefulness.localizedCaseInsensitiveContains("Awake")
    }

    var activeAppLabel: String {
        if !online { return "Çevrimdışı" }
        if dreaming || focus.contains("dream") { return "The Frame Art" }
        if !isAwake { return "Uyku modunda" }
        if focus.contains("stremio") { return "Stremio" }
        if focus.contains("nuvio") { return "Nuvio" }
        if focus.contains("youtube") { return "YouTube" }
        if focus.contains("disney") { return "Disney+" }
        if focus.contains("digiturk") || focus.contains("tod") { return "TOD" }
        if focus.contains("turkcell") || focus.contains("tvplus") { return "TV+" }
        if focus.contains("launcher") || focus.contains("tvlauncher") { return "Ana Ekran" }
        return "Açık · \(model)"
    }
}

struct ModemTelemetry: Equatable {
    var online: Bool
    var serial: String
    var upstream: String
    var wanIP: String
    var operatorName: String
    var netType: String
    var hotspot5GHz: Bool
    var eth0IP: String
    var battery: Int
    var tempTenths: Int
    var totalGB: String
    var clients: Int

    var temperatureCelsius: Double {
        Double(tempTenths) / 10.0
    }

    var hueEthernetHealthy: Bool {
        !eth0IP.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

@MainActor
final class SmartHomeMonitor: ObservableObject {
    @Published var hueOnline = false
    @Published var bridgeIP = "192.168.236.62"
    @Published var bridgeName = "Hue Bridge"
    @Published var bridgeSWVersion = ""
    @Published var lights: [HueLight] = []
    @Published var tv: TVTelemetry?
    @Published var modem: ModemTelemetry?
    @Published var isRefreshing = false
    @Published var isWorking = false
    @Published var actionMessage: String?
    @Published var tvBrightness: Double = 0.75
    @Published var rmosStatus: String = "LOLİLE + MYA-L11 senkron"

    var openCommandCenterWindow: (() -> Void)?
    private var timer: Timer?

    var anyLightOn: Bool {
        lights.contains(where: \.on)
    }

    var masterBrightness: Double {
        guard !lights.isEmpty else { return 200 }
        let sum = lights.reduce(0) { $0 + $1.bri }
        return Double(sum) / Double(lights.count)
    }

    var quickSummary: String {
        let huePart: String
        if hueOnline {
            let onCount = lights.filter(\.on).count
            huePart = "Hue \(onCount)/\(lights.count) açık"
        } else {
            huePart = "Hue bekleniyor"
        }
        let tvPart = tv?.activeAppLabel ?? "TV bekleniyor"
        return "\(huePart) · TV: \(tvPart)"
    }

    init() {
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: 18, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.refresh()
            }
        }
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let hueResult = LocalCommand.run("/Users/kai/bin/daak-hue", ["json"])
        async let tvResult = LocalCommand.run("/Users/kai/bin/daak-tv", ["json"])
        async let modemResult = LocalCommand.run("/Users/kai/bin/daak-modem", ["json"])

        let (hueOut, tvOut, modemOut) = await (hueResult, tvResult, modemResult)
        parseHueJSON(hueOut.output)
        parseTVJSON(tvOut.output)
        parseModemJSON(modemOut.output)
    }

    private func parseHueJSON(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            hueOnline = false
            return
        }
        if let ip = root["bridge_ip"] as? String, !ip.isEmpty {
            bridgeIP = ip
        }
        if let config = root["config"] as? [String: Any] {
            bridgeName = (config["name"] as? String) ?? "Hue Bridge"
            bridgeSWVersion = (config["swversion"] as? String) ?? ""
        }
        guard let lightsDict = root["lights"] as? [String: Any], !lightsDict.isEmpty else {
            hueOnline = false
            return
        }
        var parsed: [HueLight] = []
        for (id, value) in lightsDict {
            guard let item = value as? [String: Any] else { continue }
            let name = (item["name"] as? String) ?? "Işık \(id)"
            let modelID = (item["modelid"] as? String) ?? "Hue"
            let state = (item["state"] as? [String: Any]) ?? [:]
            let isOn = (state["on"] as? Bool) ?? false
            let bri = (state["bri"] as? Int) ?? 200
            let reachable = (state["reachable"] as? Bool) ?? true
            parsed.append(HueLight(id: id, name: name, modelID: modelID, on: isOn, bri: bri, reachable: reachable))
        }
        parsed.sort { (Int($0.id) ?? 999) < (Int($1.id) ?? 999) }
        lights = parsed
        hueOnline = true
    }

    private func parseTVJSON(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        let online = (root["online"] as? Bool) ?? false
        tv = TVTelemetry(
            online: online,
            serial: (root["serial"] as? String) ?? "192.168.34.182:5555",
            model: (root["model"] as? String) ?? "Smart TV Pro",
            android: (root["android"] as? String) ?? "12",
            ip: (root["ip"] as? String) ?? "192.168.34.182",
            wakefulness: (root["wakefulness"] as? String) ?? "Asleep",
            dreaming: (root["dreaming"] as? Bool) ?? false,
            volume: (root["volume"] as? Int) ?? 15,
            focus: (root["focus"] as? String) ?? ""
        )
    }

    private func parseModemJSON(_ raw: String) {
        guard let data = raw.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        let online = (root["online"] as? Bool) ?? false
        modem = ModemTelemetry(
            online: online,
            serial: (root["serial"] as? String) ?? "192.168.34.12:5555",
            upstream: (root["upstream"] as? String) ?? "",
            wanIP: (root["wan_ip"] as? String) ?? "",
            operatorName: (root["operator"] as? String) ?? "Vodafone",
            netType: (root["net_type"] as? String) ?? "LTE",
            hotspot5GHz: (root["hotspot_5ghz"] as? Bool) ?? true,
            eth0IP: (root["eth0_ip"] as? String) ?? "",
            battery: (root["battery"] as? Int) ?? 100,
            tempTenths: (root["temp_tenths"] as? Int) ?? 340,
            totalGB: (root["total_gb"] as? String) ?? "0",
            clients: (root["clients"] as? Int) ?? 0
        )
    }

    private func performAction(_ label: String, command: String, arguments: [String]) async {
        isWorking = true
        actionMessage = "\(label) uygulanıyor…"
        let res = await LocalCommand.run(command, arguments)
        isWorking = false
        let trimmed = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if res.exitCode == 0 {
            actionMessage = trimmed.isEmpty ? "\(label) tamamlandı." : "\(label): \(trimmed.components(separatedBy: .newlines).last ?? trimmed)"
        } else {
            actionMessage = "\(label) hatası: \(trimmed)"
        }
        await refresh()
    }

    func toggleLight(id: String, on: Bool) async {
        if let idx = lights.firstIndex(where: { $0.id == id }) {
            lights[idx].on = on
        }
        await performAction("Işık \(id) \(on ? "açıldı" : "kapatıldı")", command: "/Users/kai/bin/daak-hue", arguments: [on ? "on" : "off", id])
    }

    func setLightBrightness(id: String, bri: Int) async {
        let clamped = max(1, min(254, bri))
        if let idx = lights.firstIndex(where: { $0.id == id }) {
            lights[idx].on = true
            lights[idx].bri = clamped
        }
        await performAction("Işık \(id) parlaklık", command: "/Users/kai/bin/daak-hue", arguments: ["bri", id, "\(clamped)"])
    }

    func setAllLights(on: Bool) async {
        for idx in lights.indices {
            lights[idx].on = on
        }
        await performAction(on ? "Tüm ışıklar açıldı" : "Tüm ışıklar kapatıldı", command: "/Users/kai/bin/daak-hue", arguments: [on ? "all-on" : "all-off"])
    }

    func setAllBrightness(_ bri: Int) async {
        let clamped = max(1, min(254, bri))
        for idx in lights.indices {
            lights[idx].on = true
            lights[idx].bri = clamped
        }
        await performAction("Genel parlaklık", command: "/Users/kai/bin/daak-hue", arguments: ["all-bri", "\(clamped)"])
    }

    func applyScene(_ scene: String) async {
        await performAction("Hue sahnesi (\(scene))", command: "/Users/kai/bin/daak-hue", arguments: ["scene", scene])
    }

    func repairHueBridge() async {
        isWorking = true
        actionMessage = "Vaytniga eth0 Ethernet Tethering ve Hue Bridge onarılıyor…"
        _ = await LocalCommand.run("/Users/kai/bin/daak-modem", ["ethernet", "on"])
        let hueRes = await LocalCommand.run("/Users/kai/bin/daak-hue", ["status"])
        isWorking = false
        let summary = hueRes.output.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: .newlines).first ?? "Hue Bridge kontrol edildi"
        actionMessage = summary
        await refresh()
    }

    func tvWake() async {
        await performAction("TV uyandırıldı", command: "/Users/kai/bin/daak-tv", arguments: ["wake"])
    }

    func tvSleep() async {
        await performAction("TV uykuya alındı", command: "/Users/kai/bin/daak-tv", arguments: ["sleep"])
    }

    func tvArtMode() async {
        await performAction("The Frame Art Modu", command: "/Users/kai/bin/daak-tv", arguments: ["art"])
    }

    func setTVBrightness(_ value: Double) async {
        let clamped = max(0.05, min(1.0, value))
        tvBrightness = clamped
        let formatted = String(format: "%.2f", clamped)
        await performAction("TV panel parlaklığı", command: "/Users/kai/bin/daak-tv", arguments: ["brightness", formatted])
    }

    func launchTVApp(_ app: String) async {
        await performAction("TV uygulaması (\(app.uppercased()))", command: "/Users/kai/bin/daak-tv", arguments: ["launch", app])
    }

    func sendTVKey(_ key: String) async {
        _ = await LocalCommand.run("/Users/kai/bin/daak-tv", ["key", key])
        await refresh()
    }

    func startCinemaMode(app: String) async {
        isWorking = true
        actionMessage = "Sinema modu hazırlanıyor (Hue loş + TV \(app.uppercased()))…"
        async let hueTask = LocalCommand.run("/Users/kai/bin/daak-hue", ["scene", "cinema"])
        async let tvWakeTask = LocalCommand.run("/Users/kai/bin/daak-tv", ["wake"])
        _ = await (hueTask, tvWakeTask)
        _ = await LocalCommand.run("/Users/kai/bin/daak-tv", ["brightness", "0.35"])
        _ = await LocalCommand.run("/Users/kai/bin/daak-tv", ["launch", app])
        isWorking = false
        actionMessage = "Sinema modu aktif: Şömine ışıkları %25 ve TV'de \(app.uppercased()) açıldı."
        await refresh()
    }

    func openHotspotSettings() async {
        await performAction("Vaytniga 5GHz Hotspot ekranı", command: "/Users/kai/bin/daak-modem", arguments: ["hotspot"])
    }

    func runModemSpeedtest() async {
        await performAction("Vaytniga hız testi", command: "/Users/kai/bin/daak-modem", arguments: ["speedtest"])
    }

    func syncRMOS() async {
        isWorking = true
        actionMessage = "RM-OS LOLİLE <-> MYA-L11 senkronizasyonu başlatıldı…"
        let res = await LocalCommand.run("/Users/kai/.local/bin/rmos-remote", ["sync"])
        isWorking = false
        let out = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        rmosStatus = res.exitCode == 0 ? "Senkron tamamlandı (\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .short)))" : "Senkron uyarısı"
        actionMessage = out.isEmpty ? rmosStatus : out.components(separatedBy: .newlines).last ?? rmosStatus
    }

    func syncUniversityCourses() async {
        isWorking = true
        actionMessage = "US Enseñanza Virtual dersleri senkronize ediliyor…"
        let res = await LocalCommand.run("/Users/kai/.local/bin/ev-sync", [])
        isWorking = false
        let out = res.output.trimmingCharacters(in: .whitespacesAndNewlines)
        actionMessage = out.isEmpty ? "US Enseñanza Virtual senkronizasyonu tamamlandı." : (out.components(separatedBy: .newlines).last ?? "US Enseñanza Virtual senkronlandı.")
    }
}

private struct StudyChecklistItem: Identifiable, Hashable {
    let id: String
    let topic: String
    let detail: String
    let priority: String // "KRİTİK", "YÜKSEK", "NORMAL"
}

private struct CourseFileItem: Identifiable, Hashable {
    let id: String
    let name: String
    let relativePath: String
    let fullPath: String
    let isMarkdown: Bool
    let isSimulation: Bool
    let sizeLabel: String
}

private struct UniversityCourse: Identifiable, Hashable {
    let id: String
    let code: String
    let shortName: String
    let titleTR: String
    let titleES: String
    let folderName: String
    let semester: String
    let professor: String
    let examDateISO: String? // yyyy-MM-dd HH:mm
    let examDateLabel: String
    let examLocation: String
    let convocatoria: String
    let examFormat: String
    let passRule: String
    let accentColorName: String
    let whatWillBeAsked: [String]
    let formulasAndTraps: [String]
    let checklist: [StudyChecklistItem]

    var folderPath: String {
        "/Users/kai/Documents/antigravity/focused-volta/\(folderName)"
    }

    var examDate: Date? {
        guard let iso = examDateISO else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.date(from: iso)
    }

    func daysUntilExam(from now: Date = Date()) -> Int? {
        guard let target = examDate else { return nil }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)
        let startOfExam = cal.startOfDay(for: target)
        return cal.dateComponents([.day], from: startOfToday, to: startOfExam).day
    }

    func countdownBadge(from now: Date = Date()) -> String {
        guard let days = daysUntilExam(from: now) else { return semester }
        if days < 0 {
            return "Tamamlandı"
        } else if days == 0 {
            return "BUGÜN!"
        } else if days == 1 {
            return "YARIN!"
        } else {
            return "\(days) GÜN KALDI"
        }
    }

    var isUrgentExam: Bool {
        guard let days = daysUntilExam() else { return false }
        return days >= 0 && days <= 21
    }
}

@MainActor
private final class UniversityStudyMonitor: ObservableObject {
    @Published var courses: [UniversityCourse] = []
    @Published var selectedCourseID: String = "01_Derecho_Privado"
    @Published var completedChecklistIDs: Set<String> = []
    @Published var courseFiles: [String: [CourseFileItem]] = [:]
    @Published var selectedMarkdownTitle: String = "Çalışma Rehberi & Özet"
    @Published var selectedMarkdownContent: String = ""
    @Published var selectedMarkdownPath: String = ""
    @Published var personalNoteDraft: String = ""
    @Published var isSyncingEV: Bool = false
    @Published var syncStatusMessage: String?
    @Published var searchFilter: String = ""

    private let checklistDefaultsKey = "daak.study.completedChecklist.v1"
    private let notesDefaultsPrefix = "daak.study.personalNotes.v1."
    let rootPath = "/Users/kai/Documents/antigravity/focused-volta"

    init() {
        if let saved = UserDefaults.standard.array(forKey: checklistDefaultsKey) as? [String] {
            completedChecklistIDs = Set(saved)
        }
        courses = Self.buildCatalog()
        scanAllCourseFiles()
        selectCourse("01_Derecho_Privado")
    }

    var selectedCourse: UniversityCourse {
        courses.first(where: { $0.id == selectedCourseID }) ?? courses[0]
    }

    var upcomingExams: [UniversityCourse] {
        courses
            .filter { ($0.daysUntilExam() ?? -1) >= 0 }
            .sorted { ($0.examDate ?? .distantFuture) < ($1.examDate ?? .distantFuture) }
    }

    var nextExamSummary: String {
        guard let next = upcomingExams.first else {
            return "12 US ADE dersi yüklü"
        }
        return "İlk Sınav: \(next.shortName) · \(next.examDateLabel) (\(next.countdownBadge()))"
    }

    var nextExamBannerText: String {
        nextExamSummary
    }

    func progress(for course: UniversityCourse) -> Double {
        guard !course.checklist.isEmpty else { return 0 }
        let done = course.checklist.filter { completedChecklistIDs.contains($0.id) }.count
        return Double(done) / Double(course.checklist.count)
    }

    var overallReadinessPercent: Int {
        let urgent = upcomingExams.prefix(7)
        let allItems = urgent.flatMap(\.checklist)
        guard !allItems.isEmpty else { return 0 }
        let done = allItems.filter { completedChecklistIDs.contains($0.id) }.count
        return Int((Double(done) / Double(allItems.count) * 100).rounded())
    }

    func isCompleted(_ item: StudyChecklistItem) -> Bool {
        completedChecklistIDs.contains(item.id)
    }

    func toggleChecklist(_ item: StudyChecklistItem) {
        if completedChecklistIDs.contains(item.id) {
            completedChecklistIDs.remove(item.id)
        } else {
            completedChecklistIDs.insert(item.id)
        }
        UserDefaults.standard.set(Array(completedChecklistIDs), forKey: checklistDefaultsKey)
    }

    func selectCourse(_ id: String) {
        selectedCourseID = id
        personalNoteDraft = UserDefaults.standard.string(forKey: notesDefaultsPrefix + id) ?? ""
        let files = courseFiles[id] ?? []
        if let guide = files.first(where: { $0.isMarkdown && !$0.isSimulation }) ?? files.first(where: { $0.isMarkdown }) {
            loadMarkdownFile(guide)
        } else {
            selectedMarkdownTitle = selectedCourse.titleTR
            selectedMarkdownPath = ""
            selectedMarkdownContent = "Bu ders için çalışma rehberi hazırlanıyor."
        }
    }

    func savePersonalNote() {
        UserDefaults.standard.set(personalNoteDraft, forKey: notesDefaultsPrefix + selectedCourseID)
        syncStatusMessage = "\(selectedCourse.shortName) kişisel ders notu kaydedildi."
    }

    func loadMarkdownFile(_ item: CourseFileItem) {
        selectedMarkdownTitle = item.name
        selectedMarkdownPath = item.fullPath
        if let text = try? String(contentsOfFile: item.fullPath, encoding: .utf8) {
            selectedMarkdownContent = text
        } else {
            selectedMarkdownContent = "Dosya okunamadı: \(item.fullPath)"
        }
    }

    func loadMasterStudyPlan() {
        let planPath = "\(rootPath)/MUFREDAT_VE_CALISMA_PLANI.md"
        selectedMarkdownTitle = "MUFREDAT_VE_CALISMA_PLANI.md"
        selectedMarkdownPath = planPath
        if let text = try? String(contentsOfFile: planPath, encoding: .utf8) {
            selectedMarkdownContent = text
        }
    }

    func openInPreviewOrFinder(_ path: String) {
        let url = URL(fileURLWithPath: path)
        NSWorkspace.shared.open(url)
    }

    func revealCourseFolder(_ course: UniversityCourse) {
        let url = URL(fileURLWithPath: course.folderPath)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    func openEnseñanzaVirtual() {
        if let url = URL(string: "https://ev.us.es/ultra/course") {
            NSWorkspace.shared.open(url)
        }
    }

    func syncEnseñanzaVirtual() async {
        isSyncingEV = true
        syncStatusMessage = "Universidad de Sevilla Enseñanza Virtual (Blackboard Ultra) senkronize ediliyor…"
        let res = await LocalCommand.run("/Users/kai/.local/bin/ev-sync", [])
        isSyncingEV = false
        scanAllCourseFiles()
        let lines = res.output
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        syncStatusMessage = lines.last ?? (res.exitCode == 0 ? "Enseñanza Virtual senkronu tamamlandı." : "Senkron tamamlandı (Uyarı kodu: \(res.exitCode))")
    }

    func scanAllCourseFiles() {
        let fm = FileManager.default
        var map: [String: [CourseFileItem]] = [:]
        let byteFormatter = ByteCountFormatter()
        byteFormatter.countStyle = .file

        for course in courses {
            var items: [CourseFileItem] = []
            if let enumerator = fm.enumerator(atPath: course.folderPath) {
                while let rel = enumerator.nextObject() as? String {
                    if rel.hasPrefix(".") || rel.contains("/.") { continue }
                    let full = "\(course.folderPath)/\(rel)"
                    var isDir: ObjCBool = false
                    guard fm.fileExists(atPath: full, isDirectory: &isDir), !isDir.boolValue else { continue }
                    let ext = (rel as NSString).pathExtension.lowercased()
                    guard ["md", "pdf", "docx", "xlsx", "pptx", "txt"].contains(ext) else { continue }
                    let attrs = try? fm.attributesOfItem(atPath: full)
                    let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                    let isMD = ext == "md"
                    let isSim = rel.uppercased().contains("SIMULASYON") || rel.uppercased().contains("EXAMEN")
                    items.append(
                        CourseFileItem(
                            id: "\(course.id):\(rel)",
                            name: (rel as NSString).lastPathComponent,
                            relativePath: rel,
                            fullPath: full,
                            isMarkdown: isMD,
                            isSimulation: isSim,
                            sizeLabel: byteFormatter.string(fromByteCount: size)
                        )
                    )
                }
            }
            items.sort { a, b in
                if a.isMarkdown != b.isMarkdown { return a.isMarkdown }
                return a.relativePath < b.relativePath
            }
            map[course.id] = items
        }
        courseFiles = map
    }

    static func buildCatalog() -> [UniversityCourse] {
        [
            UniversityCourse(
                id: "01_Derecho_Privado",
                code: "1530002",
                shortName: "Derecho Privado",
                titleTR: "Özel Hukuk (Medeni & Ticaret Hukuku)",
                titleES: "Elementos de Derecho Privado",
                folderName: "01_Derecho_Privado",
                semester: "1. Dönem + Ekim 3ª Conv.",
                professor: "Prof. Dra. María del Rosario Sánchez Valle",
                examDateISO: "2026-10-19 13:40",
                examDateLabel: "19 Ekim 2026 Pzt · 13:40",
                examLocation: "Aula 44 (FCEE)",
                convocatoria: "3ª Convocatoria (Ekim)",
                examFormat: "30 Test Sorusu (4 şıklı, tek doğru) · Süre: 50 dk",
                passRule: "YANLIŞ DOĞRUYU GÖTÜRMÜYOR! Geçmek için en az 15 doğru (5.0/10) şart. Boş bırakmak yasak!",
                accentColorName: "red",
                whatWillBeAsked: [
                    "Norma Jurídica & Fuentes del Derecho (Art. 1.1 CC): Ley → Costumbre → Principios Generales del Derecho sıralaması ve 20 günlük vacatio legis.",
                    "Leyes Orgánicas (Art. 81 CE - tam üye salt çoğunluğu) vs. Decreto-Ley (Art. 86 CE - olağanüstü ve acil ihtiyaç, 30 günde Meclis onayı) vs. Decreto Legislativo.",
                    "Capacidad Jurídica (doğumla başlar, Art. 29-30 CC) ve Ejercicio de la Capacidad (8/2021 reformu sonrası engellilerde Curatela destek sistemi).",
                    "Temsil Hukuku (Representación): Falsus procurator (yetkisiz temsilcinin işlemi Askıda Hükümsüz / Nulidad (Art. 1259 CC) — temsil edilenin Ratificación onayıyla geçerli olur).",
                    "Obligaciones Mancomunadas (Medeni Hukukta genel kural, Art. 1137 CC — borç bölünür) vs. Solidarias (Ticaret Hukukunda sık, alacaklı tek borçludan %100'ü isteyebilir).",
                    "Sözleşmenin 3 Esaslı Unsuru (Art. 1261 CC): Consentimiento + Objeto + Causa. Eksikse Nulidad Absoluta (kesin hükümsüz, süre sınırı yok); hata/hile/tehdit varsa Anulabilidad (4 yıl hak düşürücü süre / caducidad).",
                    "Art. 1124 CC Karşılıklı Borçlarda İfa Engeli: İfaya zorlama (Cumplimiento) veya Sözleşmeyi Fesih (Resolución) + Tazminat.",
                    "Art. 1911 CC Sınırsız Malvarlığı Sorumluluğu: Borçlu tüm şimdiki ve gelecekteki malvarlığıyla sorumludur."
                ],
                formulasAndTraps: [
                    "TUZAK 1: İspanyol Medeni Kanunu'nda (Art. 1.6 CC) Jurisprudencia (Yargıtay/Tribunal Supremo içtihadı) resmi hukuk kaynağı DEĞİLDİR; hukuk düzenini tamamlar.",
                    "TUZAK 2: Borçlarda aksine açık hüküm yoksa kural Solidaridad değil MANCOMUNIDAD'dır (Art. 1137 CC).",
                    "TUZAK 3: Prescripción (zamanaşımı — ihtarname/mahkeme dışı taleple kesilir ve sıfırlanır) vs. Caducidad (hak düşürücü süre — kesilmez, hakim re'sen dikkate alır).",
                    "SINAV STRATEJİSİ: Yanlış doğruyu götürmediği için 30 sorunun tamamını işaretle! 01_SINAV_SIMULASYONU_30_SORU.md içindeki 30 soruyu mutlaka çöz."
                ],
                checklist: [
                    StudyChecklistItem(id: "dp_1", topic: "Tema 1-2: Hukuk Kaynakları, Kanun Türleri, Kişilik & Temsil", detail: "Ley Orgánica / Decreto-Ley / Vacatio Legis (20 gün) / Falsus Procurator (Art. 1259 CC)", priority: "KRİTİK"),
                    StudyChecklistItem(id: "dp_2", topic: "Tema 3-4: Borçlar Hukuku, Mancomunada vs Solidaria, Art. 1124 & 1911", detail: "Kusurlu temerrüt (Mora), Dación en pago vs Pago por cesión de bienes farkı", priority: "KRİTİK"),
                    StudyChecklistItem(id: "dp_3", topic: "Tema 5-6: Sözleşme Unsurları (Art. 1261), Nulidad vs Anulabilidad (4 yıl)", detail: "Tüketici cayma hakkı (Desistimiento: 14 takvim günü), Satım & Kira sözleşmeleri", priority: "KRİTİK"),
                    StudyChecklistItem(id: "dp_4", topic: "Tema 7: Ticari İşletme (Empresario), S.A. (60.000€) vs S.L. (3.000€/1€)", detail: "Registro Mercantil zorunluluğu, Concursal (İflas) ve kambiyo senetleri", priority: "YÜKSEK"),
                    StudyChecklistItem(id: "dp_5", topic: "30 Soruluk Gerçek Sınav Simülasyonunu Çöz (01_SINAV_SIMULASYONU_30_SORU.md)", detail: "En az 22/30 doğru hedefiyle tüm şıkları ve açıklamaları kontrol et", priority: "KRİTİK")
                ]
            ),
            UniversityCourse(
                id: "02_Contabilidad",
                code: "1530001",
                shortName: "Contabilidad Financiera",
                titleTR: "Finansal Muhasebe I",
                titleES: "Contabilidad Financiera I",
                folderName: "02_Contabilidad",
                semester: "1. Dönem + Ekim 3ª Conv.",
                professor: "Departamento de Contabilidad y Economía Financiera",
                examDateISO: "2026-10-20 13:30",
                examDateLabel: "20 Ekim 2026 Sal · 13:30",
                examLocation: "Aula 03 (G1 - FCEE)",
                convocatoria: "3ª Convocatoria (Ekim)",
                examFormat: "Teorik-Pratik Yazılı Sınav (Bilanço Sınıflandırması + Libro Diario Yevmiye + Regularización)",
                passRule: "NIE/Pasaport ve normal hesap makinesi zorunlu! Aktif = Pasif + Özkaynak eşitliği ve yevmiye dengesi tam olmalı.",
                accentColorName: "blue",
                whatWillBeAsked: [
                    "Bölüm 1 — Masas Patrimoniales & Balance de Situación: Verilen hesapları ANC (Duran Varlık), AC (Dönen Varlık: Existencias, Realizable, Disponible), PN (Özkaynak), PNC (Uzun Vadeli Borç) ve PC (Kısa Vadeli Borç) olarak sınıflandırma.",
                    "Bölüm 2 — Libro Diario (Yevmiye Kayıtları): Ticari mal alış/satışı, iskonto, müşteriden senet/çek alma, banka kredisi, personel maaşı ve kira/fatura kayıtları.",
                    "Bölüm 3 — Variación de Existencias (Stok Değişimi): Dönem başı stokları (Existencias Iniciales) kapatıp dönem sonu stoklarını (Existencias Finales) kaydetme.",
                    "Bölüm 4 — Ajustes de Periodificación & Amortización: Peşin ödenen giderler (Gastos anticipados), maddi duran varlık amortisman kaydı (Amortización del Inmovilizado → Amortización Acumulada).",
                    "Bölüm 5 — Regularización (31/12 Kâr/Zarar Hesaplaması) ve Asiento de Cierre: Grup 6 (Giderler) ve Grup 7 (Gelirler) hesaplarını 129 Resultado del Ejercicio hesabına devretme."
                ],
                formulasAndTraps: [
                    "ALTIN DENKLEM: Activo (ANC + AC) = Patrimonio Neto (PN) + Pasivo (PNC + PC)",
                    "BORÇ / ALACAK KURALI (Debe / Haber): Varlık (Activo) ve Gider (Gasto - Grup 6) artışları DEBE (Sol); Borç (Pasivo), Özkaynak (PN) ve Gelir (Ingreso - Grup 7) artışları HABER (Sağ).",
                    "TUZAK: Amortización Acumulada del Inmovilizado (281) Pasif değildir! Aktifte (ANC altında) eksi (-) işaretli düzenleyici hesaptır.",
                    "TUZAK: Dönem sonu stok kaydında önce başlangıç stoku (Debe: 610 Variación / Haber: 300 Mercaderías) kapatılır, sonra bitiş stoku (Debe: 300 Mercaderías / Haber: 610 Variación) açılır."
                ],
                checklist: [
                    StudyChecklistItem(id: "cf_1", topic: "Blok I (Tema 1-2): Masas Patrimoniales (ANC, AC, PN, PNC, PC) & Bilanço", detail: "SUPUESTOS 1.1–2.10 alıştırmalarındaki hesap sınıflandırmalarını çöz", priority: "KRİTİK"),
                    StudyChecklistItem(id: "cf_2", topic: "Blok II (Tema 3-4): Libro Diario, Mayor & Ticari Mal (Mercaderías) İşlemleri", detail: "Alış, satış, iade, iskonto ve stok değişimi (Variación de Existencias)", priority: "KRİTİK"),
                    StudyChecklistItem(id: "cf_3", topic: "Blok III (Tema 5-6): Amortisman, Karşılıklar (Deterioro), Regularización 31/12", detail: "Supuestos 6.1–6.5 tam muhasebe döngüsü (Ciclo Contable Completo) çözümü", priority: "KRİTİK"),
                    StudyChecklistItem(id: "cf_4", topic: "PGC (Plan General de Contabilidad) Hesap Grupları (Grup 1–7) Tekrarı", detail: "Özellikle Grup 2 (Duran), 3 (Stok), 4 (Alacak/Borç), 5 (Finansal), 6 (Gider), 7 (Gelir)", priority: "YÜKSEK")
                ]
            ),
            UniversityCourse(
                id: "03_Estadistica",
                code: "1530005",
                shortName: "Estadística I",
                titleTR: "İstatistik I",
                titleES: "Estadística I",
                folderName: "03_Estadistica",
                semester: "1. Dönem + Ekim 3ª Conv.",
                professor: "Departamento de Economía Aplicada I",
                examDateISO: "2026-10-22 13:35",
                examDateLabel: "22 Ekim 2026 Per · 13:35",
                examLocation: "Aula 27 (2ª Planta - G1)",
                convocatoria: "3ª Convocatoria (Ekim) + 20 Ocak 2027 (1ª Conv.)",
                examFormat: "1. Kısım (%40): Test (Hesap makinesiz, +1 / -0.25) + 2. Kısım (%60): Problemler (Hesap makineli)",
                passRule: "Her iki kısımdan da EN AZ 3.0 / 10 barajı var! Genel ağırlıklı ortalama (0.4×Test + 0.6×Problem) ≥ 5.0 olmalı.",
                accentColorName: "purple",
                whatWillBeAsked: [
                    "Problem 1 — Tek Değişkenli Dağılım & Eşitsizlik: Ortalama, Medyan, Mod, Kartiller, Varyans, Standart Sapma, Değişim Katsayısı (CV = s / |x̄|) ve Gini / Lorenz Yoğunlaşma İndeksi.",
                    "Problem 2 — İki Değişkenli Regresyon & Korelasyon: Kovaryans (Sxy), Doğrusal Regresyon Doğrusu (Y/X ve X/Y), Belirlilik Katsayısı (R² = S²xy / (S²x · S²y)) ve tahmin güvenilirliği.",
                    "Problem 3 — İndeks Sayıları & Enflasyon (IPC): Laspeyres (sabit baz dönem ağırlıklı), Paasche (cari dönem ağırlıklı), Fisher, Zincirleme İndeks ve Nominal maaşı Reel maaşa çevirme (Deflaktör).",
                    "Problem 4 — Olasılık & Dağılım Modelleri: Bayes Teoremi / Tam Olasılık, Binom B(n,p), Poisson P(λ) ve Normal Dağılım N(μ, σ²) standartlaştırma (Z = (X - μ)/σ).",
                    "Test Kısmı (%40, Hesap Makinesiz!): R², CV, doğrusal dönüşüm özellikleri (Y = a + bX olduğunda varyans b² katına çıkar, CV ve R² işaret dışında değişmez) ve Poisson/Binom özellikleri."
                ],
                formulasAndTraps: [
                    "DEĞİŞİM KATSAYISI (Temsil Gücü): CV = s / |x̄|. CV küçüldükçe aritmetik ortalamanın temsil gücü ARTAR (CV < 0.5 ise homojen).",
                    "REGRESYON EĞİMLERİ İLİŞKİSİ: b(Y/X) × b(X/Y) = r² = R². İki regresyon eğimi ve korelasyon katsayısı r her zaman AYNI İŞARETLİDİR!",
                    "ENFLASYON & REEL DEĞER: Reel Değer = (Nominal Değer / IPC) × 100. Alım gücü korunması için maaş artış oranı ≥ Enflasyon oranı olmalı.",
                    "TEST TUZAĞI: Test kısmında yanlışlar 0.25 götürüyor ve hesap makinesi YASAK! Sadece teorik özelliklerden emin olduklarını işaretle."
                ],
                checklist: [
                    StudyChecklistItem(id: "est_1", topic: "Tema 1-3: Tek Değişkenli İstatistik, CV, Asimetri & Gini/Lorenz", detail: "Varyans kısayol formülü (s² = a₂ - x̄²) ve doğrusal dönüşüm kuralları", priority: "KRİTİK"),
                    StudyChecklistItem(id: "est_2", topic: "Tema 4-5: İki Değişkenli Dağılımlar, Kovaryans, Regresyon & R²", detail: "Y'nin X üzerine regresyonu (b = Sxy / S²x) ve R² yorumu", priority: "KRİTİK"),
                    StudyChecklistItem(id: "est_3", topic: "Tema 6-7: Zaman Serileri, Laspeyres/Paasche İndeksleri & IPC Deflaktör", detail: "Baz değişimi (enlace de series) ve reel gelir hesaplama", priority: "KRİTİK"),
                    StudyChecklistItem(id: "est_4", topic: "Tema 8-10: Olasılık (Bayes), Rassal Değişken, Binom, Poisson & Normal", detail: "Beklenen değer E(X), Varyans V(X) ve Normal tablo okuma", priority: "KRİTİK")
                ]
            ),
            UniversityCourse(
                id: "04_Finanzas_I",
                code: "1530004",
                shortName: "Finanzas I",
                titleTR: "Finans I (İşletme Finansı Temelleri)",
                titleES: "Fundamentos de Economía Financiera / Finanzas I",
                folderName: "04_Finanzas_I",
                semester: "1. Dönem + Ekim 3ª Conv.",
                professor: "Dra. María Dolores Oliver Alfonso (Koordinatör)",
                examDateISO: "2026-10-23 13:40",
                examDateLabel: "23 Ekim 2026 Cum · 13:40",
                examLocation: "Aula 26-27 (FCEE)",
                convocatoria: "3ª Convocatoria (Ekim)",
                examFormat: "1. Kısım (%30): 40 Test (+0.25 / -0.05, 50 dk) + 2. Kısım (%70): Caso Práctico (90 dk)",
                passRule: "Her iki kısımdan da EN AZ 3.5 / 10 barajı var! Toplam ağırlıklı puan ≥ 5.0 olmalı.",
                accentColorName: "green",
                whatWillBeAsked: [
                    "Caso Práctico Soru 1 — Fondo de Maniobra (FM) & PMM (Ortalama Olgunlaşma Süresi): Bilançodan FM = AC - PC = (PN + PNC) - ANC hesaplama ve PMMe / PMMf (Stok + Alacak - Tedarikçi vadesi) analizi.",
                    "Caso Práctico Soru 2 — Yatırım Değerlendirme (VAN & TIR): Başlangıç maliyeti (-A) ve yıllık nakit akışları (Q₁, Q₂, Q₃) verilen projede VAN (Net Bugünkü Değer) ve TIR (İç Verim Oranı) hesabı.",
                    "Caso Práctico Soru 3 — Ekonomik ve Finansal Kârlılık (ROI / ROE) & Kaldıraç: RE (ROA) = BAIT / Activo Total; RF (ROE) = BN / Recursos Propios; borç maliyetinin (ki) ROE'ye etkisi.",
                    "Caso Práctico Soru 4 — Sermaye Maliyeti (WACC / CMP): Özsermaye maliyeti (ke) ve vergi kalkanlı yabancı kaynak maliyeti ki·(1-t) ile ağırlıklı ortalama sermaye maliyeti.",
                    "40 Soruluk Test (%30): Finansal amaç (hissedar/işletme piyasa değerini maksimize etmek, kâr maksimizasyonu DEĞİL!), likidite vs ödeme gücü, sistemik vs spesifik risk."
                ],
                formulasAndTraps: [
                    "FONDO DE MANIOBRA: FM = AC - PC = Recursos Permanentes (PN + PNC) - ANC. FM > 0 ise kısa vadeli finansal denge vardır.",
                    "VAN (NPV): VAN = -A + Σ [ Qₜ / (1 + k)ᵗ ]. Karar Kuralı: VAN > 0 ve TIR > k ise yatırım KABUL edilir!",
                    "FİNANSAL KALDIRAÇ (Apalancamiento): RF = RE + (RE - ki) × (D / RP) × (1 - t). Eğer RE > ki ise borçlanmak özsermaye kârlılığını (RF) artırır (Pozitif Kaldıraç).",
                    "TEST STRATEJİSİ: 40 soruda doğru +0.25, yanlış -0.05 (yani 5 yanlış 1 doğruyu götürüyor). 2 şıkka indirdiğin sorularda mutlaka işaretle!"
                ],
                checklist: [
                    StudyChecklistItem(id: "fin_1", topic: "Tema 1-3: İşletme Finansı Amacı, Bilanço Dengesi, FM & PMM", detail: "00_CALISMA_REHBERI_VE_FORMULLER.md içindeki tüm FM ve PMM formüllerini ezberle", priority: "KRİTİK"),
                    StudyChecklistItem(id: "fin_2", topic: "Tema 4-5: Yatırım Projeleri, Nakit Akışı (Cash-Flow), VAN & TIR", detail: "2 ve 3 yıllık projelerde VAN=0 eşitlemesiyle TIR bulma pratiği", priority: "KRİTİK"),
                    StudyChecklistItem(id: "fin_3", topic: "Tema 6-8: RE (ROI), RF (ROE), Finansal Kaldıraç & WACC (Sermaye Maliyeti)", detail: "Vergi öncesi ve vergi sonrası kârlılık + borçlanma etkisi", priority: "KRİTİK"),
                    StudyChecklistItem(id: "fin_4", topic: "01_SINAV_SIMULASYONU_VE_VAKA.md Çözümü", detail: "Tam vaka analizi ve test sorularını süre tutarak çöz", priority: "KRİTİK")
                ]
            ),
            UniversityCourse(
                id: "07_Economia_Empresa_IEE",
                code: "1530006",
                shortName: "Economía Empresa (IEE)",
                titleTR: "İşletme Ekonomisine Giriş (IEE)",
                titleES: "Introducción a la Economía de la Empresa",
                folderName: "07_Economia_Empresa_IEE",
                semester: "1. Dönem Sürekli Değerlendirme",
                professor: "Prof. María Ángeles Montoro Sánchez",
                examDateISO: "2026-10-26 10:30",
                examDateLabel: "26 Ekim Pzt (Práctica 3) · 11 Aralık Final",
                examLocation: "FCEE G1 Sınıfı",
                convocatoria: "Evaluación Continua (%30 Prácticas + %70 Prueba 11 Aralık)",
                examFormat: "26 Ekim Práctica 3 (Stok Wilson/EOQ & PERT) · 9 Kasım P4 · 23 Kasım P5 · 3 Aralık P6 · 11 Aralık Prueba",
                passRule: "Sürekli değerlendirmede Prácticas %30 + 11 Aralık Sınavı %70. Dersi ocak sınavına kalmadan Aralık'ta geçme fırsatı!",
                accentColorName: "orange",
                whatWillBeAsked: [
                    "26 Ekim Práctica 3 (Üretim, Stok & PERT): Başabaş Noktası (Punto Muerto Q* = CF / (P - CVu)), Wilson Optimal Sipariş Miktarı (EOQ) ve PERT-CPM Kritik Yol / Bolluk (Holgura) hesabı.",
                    "09 Kasım Práctica 4 (Marketing): Pazar payı, talep esnekliği ve fiyatlandırma problemleri.",
                    "23 Kasım Práctica 5 (Rentabilidad): Ekonomik Kârlılık (RE = BAIT / AT) ve Finansal Kârlılık (RF = BN / RP) + Kaldıraç etkisi.",
                    "03 Aralık Práctica 6 (Inversión): Payback (Geri Ödeme Süresi), VAN ve TIR hesaplaması.",
                    "11 Aralık Prueba Final: Temas 1–8 Teori + Problem kombinasyonu."
                ],
                formulasAndTraps: [
                    "PUNTO MUERTO (Başabaş Noktası): Q* = CF / (P - CVu). (P - CVu) = Birim Katkı Payı (Margen de Contribución Unitario).",
                    "FAALİYET KALDIRACI (Grado de Apalancamiento Operativo): GAO = [Q · (P - CVu)] / [Q · (P - CVu) - CF].",
                    "WILSON STOK MODELİ (EOQ): Q* = √( (2 · D · s) / g ). Toplam sipariş sayısı N = D / Q*, siparişler arası süre T = 360 / N.",
                    "PERT KRİTİK YOL: Erken zaman (Te) = max(önceki + süre); Geç zaman (Tl) = min(sonraki - süre). Holgura H = Tl - Te - d = 0 olan faaliyetler KRİTİK YOLDUR."
                ],
                checklist: [
                    StudyChecklistItem(id: "iee_1", topic: "26 Ekim Práctica 3 Hazırlığı: Punto Muerto, Wilson (EOQ) & PERT", detail: "Cuaderno de Prácticas içindeki Üretim, Stok ve PERT sorularını çöz", priority: "KRİTİK"),
                    StudyChecklistItem(id: "iee_2", topic: "Tema 1-3: İşletme, Girişimci, Stratejik Yönetim (PESTEL, Porter 5 Güç, SWOT)", detail: "Organizasyon yapıları (Mintzberg) ve büyüme stratejileri (Ansoff)", priority: "YÜKSEK"),
                    StudyChecklistItem(id: "iee_3", topic: "9 Kasım & 23 Kasım Prácticas (Marketing + RE/RF Rentabilidad)", detail: "Finanzas I ile ortak olan RE, RF, VAN ve TIR formüllerini pekiştir", priority: "YÜKSEK")
                ]
            ),
            UniversityCourse(
                id: "05_Microeconomia",
                code: "1530008",
                shortName: "Microeconomía",
                titleTR: "Mikroekonomi",
                titleES: "Microeconomía",
                folderName: "05_Microeconomia",
                semester: "2. Dönem + Ekim 3ª Conv.",
                professor: "Dr. Jesús Manuel Artero López / Dra. Rocío Yñiguez Ovando",
                examDateISO: "2026-10-29 13:40",
                examDateLabel: "29 Ekim 2026 Per · 13:40",
                examLocation: "Aula 31-33 (FCEE)",
                convocatoria: "3ª Convocatoria (Ekim)",
                examFormat: "3 Teori Sorusu (%75 - grafik ve analizli) + 1 Problem (%25) · Süre: 2 Saat",
                passRule: "Temas 1–8 tam kapsam. Grafik çizimi (Tüketici dengesi, Maliyet eğrileri, Rekabet vs Tekel) puanın belkemiğidir!",
                accentColorName: "teal",
                whatWillBeAsked: [
                    "Problem (%25) Tip A — Tüketici Dengesi & Slutsky: Fayda fonksiyonu U(X,Y) (Cobb-Douglas, Tam Tamamlayıcı min{aX,bY} veya Tam İkame aX+bY) ve bütçe kısıtından optimal sepet, ardından fiyat değişiminde İkame Etkisi (ES) ve Gelir Etkisi (ER).",
                    "Problem (%25) Tip B — Firma Maliyetleri & Piyasa Dengesi: CT(Q) maliyet fonksiyonundan CMg, CMe, CVMe, Kapanma Noktası (Min CVMe) ve Tam Rekabet (P = CMg) veya Tekel (IMg = CMg) denge miktarı/kârı.",
                    "Teori 1 — Tüketici Teorisi (Temas 1-2): Farksızlık eğrilerinin özellikleri, RMS = UMgX / UMgY = Px / Py, Normal / Düşük (Inferior) / Giffen mal grafiksel ayrımı.",
                    "Teori 2 — Üretim & Maliyetler (Temas 3-4): Kısa dönemde Azalan Verimler Kanunu (PMg ve PMe ilişkisi), Uzun dönemde Ölçeğe Göre Getiri (Rendimientos a escala) ve Kısa/Uzun dönem maliyet zarf eğrisi.",
                    "Teori 3 — Piyasa Yapıları (Temas 5-8): Tam Rekabet kısa ve uzun dönem dengesi (sıfır ekonomik kâr, P = min CMeL), Tekelde Fiyat Farklılaştırması (1., 2., 3. derece) ve Sosyal Refah Kaybı (Pérdida Irrecuperable de Eficiencia), Oligopol (Cournot, Stackelberg, Bertrand)."
                ],
                formulasAndTraps: [
                    "TÜKETİCİ DENGESİ (İç Çözüm): RMS = UMgX / UMgY = Px / Py ve Px·X + Py·Y = R. Tam tamamlayıcılarda türev alınmaz: aX = bY eşitliği kullanılır!",
                    "TAM REKABET KISA DÖNEM ARZ: P ≥ min CVMe olduğu sürece P = CMg (artan kol). P < min CVMe ise firma üretimi durdurur (Q = 0, zarar = -CF).",
                    "TEKEL DENGESİ & LERNER İNDEKSİ: IMg = CMg → P > CMg. Lerner İndeksi L = (P - CMg) / P = 1 / |εd|.",
                    "GRAFİK KURALI: Her teorik soruda eksen isimlerini (P, Q, CMg, CMe, CVMe, IMg) mutlaka yaz ve denge noktasını işaretleyerek açıkla."
                ],
                checklist: [
                    StudyChecklistItem(id: "mic_1", topic: "Tema 1-2: Tüketici Dengesi (Cobb-Douglas, İkame, Tamamlayıcı) & Slutsky", detail: "Ejercicios T1-T8 içindeki tüketici optimizasyonu ve ikame/gelir etkisi soruları", priority: "KRİTİK"),
                    StudyChecklistItem(id: "mic_2", topic: "Tema 3-4: Üretim Fonksiyonu, Azalan Verimler, RTS & Maliyet Fonksiyonları", detail: "CT, CF, CV, CMe, CVMe, CMg türevleri ve ölçeğe göre getiri", priority: "KRİTİK"),
                    StudyChecklistItem(id: "mic_3", topic: "Tema 5-6: Tam Rekabet (Kısa/Uzun Dönem) & Tekel (IMg=CMg, Refah Kaybı)", detail: "Kapanma noktası (Punto de cierre) ve 1./2./3. derece fiyat farklılaştırması", priority: "KRİTİK"),
                    StudyChecklistItem(id: "mic_4", topic: "Tema 7-8: Monopolcü Rekabet & Oligopol (Cournot, Stackelberg, Nash)", detail: "Tepki fonksiyonları (Funciones de reacción) ve kartel dengesi", priority: "YÜKSEK")
                ]
            ),
            UniversityCourse(
                id: "06_Introduccion_Economia",
                code: "1530003",
                shortName: "Intro. Economía",
                titleTR: "Ekonomiye Giriş",
                titleES: "Introducción a la Economía",
                folderName: "06_Introduccion_Economia",
                semester: "1. Dönem + Ekim 3ª Conv.",
                professor: "Prof. Helena Domínguez Torres",
                examDateISO: "2026-10-30 10:00",
                examDateLabel: "30 Ekim 2026 Cum (3ª Conv.) · 03 Aralık (EC Final)",
                examLocation: "FCEE",
                convocatoria: "3ª Convocatoria (30 Ekim) & Evaluación Continua (3 Aralık)",
                examFormat: "3 Teori Sorusu + 1 Problem (Her biri 2.5 puan = 10 puan) · Süre: 90 dk",
                passRule: "Sürekli değerlendirmede 3 Aralık kontrolünden min 5.0 alırsan Ocak finaline girmeden dersi geçiyorsun!",
                accentColorName: "indigo",
                whatWillBeAsked: [
                    "Tema 1 — FPP (Üretim İmkanları Sınırı) & Fırsat Maliyeti: Etkin/etkinsiz/ulaşılamaz noktalar, artan fırsat maliyeti (içbükey FPP) ve ekonomik büyüme kaymaları.",
                    "Tema 2-3 — Arz, Talep, Piyasa Dengesi & Esneklik: Tavan fiyat (Precio máximo → kıtlık/escasez) ve Taban fiyat (Precio mínimo → arz fazlası/excedente) grafik analizi; Talep Fiyat Esnekliği (εp) ile Toplam Gelir (IT = P·Q) ilişkisi.",
                    "Tema 5 — Milli Gelir Muhasebesi (PIB / GSYİH): Harcama Yöntemi (PIBpm = C + I + G + X - M), Gelir Yöntemi ve Katma Değer Yöntemi; PIB Nominal vs PIB Real ve GSYİH Deflaktörü.",
                    "Tema 6-7 — Keynesyen Çarpan, Maliye Politikası & Para Politikası (IS-LM temeli): Kamu harcaması çarpanı k = 1 / (1 - c·(1-t)), para çarpanı ve Merkez Bankası'nın faiz/para arzı müdahalesinin AD-AS üzerindeki etkisi."
                ],
                formulasAndTraps: [
                    "ESNEKLİK & TOPLAM GELİR (IT = P×Q): Talep esnekse (|ε| > 1) fiyat düşürüldüğünde Toplam Gelir ARTAR! Talep inelastikse (|ε| < 1) fiyat artırıldığında Toplam Gelir ARTAR.",
                    "MİLLİ GELİR GEÇİŞLERİ: PNB (GNP) = PIB + RRN - RRE. PNN = PNB - Amortisman. RN (Milli Gelir - Faktör Fiyatlarıyla) = PNNpm - Ti (Dolaylı Vergiler) + Subvenciones (Sübvansiyonlar).",
                    "KEYNESYEN ÇARPAN: Vergisiz kapalı ekonomide k = 1 / (1 - PMC). Vergili ekonomide k = 1 / [1 - PMC·(1 - t)].",
                    "PARA ÇARPANI: mm = (1 + e) / (e + r) (e: nakit/mevduat oranı, r: zorunlu karşılık oranı)."
                ],
                checklist: [
                    StudyChecklistItem(id: "eco_1", topic: "Tema 1-3: FPP, Arz-Talep Kaymaları, Tavan/Taban Fiyat & Esneklik", detail: "Esneklik-Toplam Gelir (IT) grafiği ve tüketici/üretici rantı", priority: "KRİTİK"),
                    StudyChecklistItem(id: "eco_2", topic: "Tema 4: Mikro Piyasa Dengesi ve Devlet Müdahalesi (Vergi/Sübvansiyon)", detail: "Vergi yükünün esnekliğe göre alıcı ve satıcı arasında paylaşımı", priority: "YÜKSEK"),
                    StudyChecklistItem(id: "eco_3", topic: "Tema 5-6: Makroekonomik Büyüklükler (PIB, PNB, RN, IPC, İşsizlik Oranı)", detail: "Aktif nüfus, işsizlik oranı (Tasa de paro) ve GSYİH hesaplama problemleri", priority: "KRİTİK"),
                    StudyChecklistItem(id: "eco_4", topic: "Tema 7-8: Maliye Politikası, Para Politikası, Çarpan & Dış Açık", detail: "Genişletici ve daraltıcı politikaların üretim ve fiyatlar genel seviyesine etkisi", priority: "KRİTİK")
                ]
            ),
            UniversityCourse(
                id: "08_Matematicas_I",
                code: "1530007",
                shortName: "Matemáticas I",
                titleTR: "Matematik I (Çok Değişkenli Analiz, İntegral & Lineer Cebir)",
                titleES: "Matemáticas I",
                folderName: "08_Matematicas_I",
                semester: "1. Dönem (Ocak 2027 Final)",
                professor: "Departamento de Economía Aplicada III",
                examDateISO: "2027-01-15 09:00",
                examDateLabel: "Ocak 2027 · 1. Dönem Finali",
                examLocation: "FCEE",
                convocatoria: "1ª Convocatoria (Ocak 2027)",
                examFormat: "Teori/Yorum + Uygulamalı Problem Çözümü (Blok I Türev, Blok II İntegral, Blok III Matris/Cebir)",
                passRule: "Klasörde 26 adet TAM ÇÖZÜMLÜ çıkmış sınav (Examenes Resueltos) ve 17 İntegral Bölgesi (Recintos) rehberi mevcut!",
                accentColorName: "mint",
                whatWillBeAsked: [
                    "Blok I (Çok Değişkenli Türev): Tanım kümesi (Dominio) ve Seviye Eğrileri (Curvas de nivel), Kısmi Türevler, Gradyan Vektörü ∇f, Hessian Matrisi Hf, Zincir Kuralı (Bileşke fonksiyon türevi), Kapalı Fonksiyon Türevi ve Homojen Fonksiyonlar (Euler Teoremi: x·fx + y·fy = m·f).",
                    "Blok II (Çok Katlı İntegral): Belirsiz/Belirli integral (Kısmi integrasyon, rasyonel fonksiyonlar), Genelleştirilmiş İntegraller (Impropias) ve Çift Katlı İntegral ∬ D f(x,y) dxdy (Fubini Teoremi ile integrasyon sırası değiştirme).",
                    "Blok III (Lineer Cebir & Kuadratik Formlar): Parametreli doğrusal denklem sistemlerinde Rouché-Frobenius Teoremi (SCD, SCI, SI), Özdeğerler (Autovalores |A - λI| = 0), Özvektörler (Autovectores), Matris Köşegenleştirme (Diagonalización) ve Kuadratik Formların İşareti (Başkemer minörleri / özdeğerler ile Definida Positiva, Negativa, Indefinida)."
                ],
                formulasAndTraps: [
                    "EULER TEOREMİ (Homojen Fonksiyon): f(λx, λy) = λᵐ·f(x,y) ise x·(∂f/∂x) + y·(∂f/∂y) = m·f(x,y) ve Hessian determinantı; m=1 ise |Hf| = 0.",
                    "EN BÜYÜK ARTIŞ YÖNÜ: Fonksiyonun bir P noktasında en hızlı arttığı yön Gradyan ∇f(P) yönüdür; maksimum değişim hızı ||∇f(P)|| normudur.",
                    "ROUCHÉ-FROBENIUS: rg(A) = rg(A|b) = n ise Tek Çözüm (SCD); rg(A) = rg(A|b) < n ise Sonsuz Çözüm (SCI); rg(A) ≠ rg(A|b) ise Çözüm Yok (SI).",
                    "KUADRATİK FORM İŞARETİ: Tüm özdeğerler λᵢ > 0 (veya Δ₁ > 0, Δ₂ > 0, Δ₃ > 0) ise Kesin Pozitif (Definida Positiva)."
                ],
                checklist: [
                    StudyChecklistItem(id: "mat_1", topic: "Blok I: Kısmi Türev, Gradyan, Hessian, Zincir Kuralı & Euler Teoremi", detail: "Lecciones 1-2 alıştırmaları ve çıkmış sınav türev soruları", priority: "KRİTİK"),
                    StudyChecklistItem(id: "mat_2", topic: "Blok II: Çift Katlı İntegral & 17 Klasik Recinto (Bölge) Çizimi", detail: "Recinto 1-17 PDF dosyalarındaki sınır belirleme ve Fubini değişimi", priority: "KRİTİK"),
                    StudyChecklistItem(id: "mat_3", topic: "Blok III: Rouché-Frobenius, Özdeğer/Köşegenleştirme & Kuadratik Formlar", detail: "Parametreli matris tartışması (a, b parametrelerine göre sistem çözümü)", priority: "KRİTİK"),
                    StudyChecklistItem(id: "mat_4", topic: "26 Çözümlü Çıkmış Sınavdan (Examenes Resueltos) En Az 5 Tanesini Çöz", detail: "Soru kalıpları her yıl birebir tekrar ediyor", priority: "YÜKSEK")
                ]
            ),
            UniversityCourse(
                id: "09_Historia_Economica",
                code: "1530009",
                shortName: "Historia Económica",
                titleTR: "İktisat Tarihi",
                titleES: "Historia Económica",
                folderName: "09_Historia_Economica",
                semester: "2. Dönem",
                professor: "Departamento de Economía e Historia Económica",
                examDateISO: nil,
                examDateLabel: "2. Dönem (Bahar)",
                examLocation: "FCEE",
                convocatoria: "%40 Seminer/Prácticas + %60 Final Sınavı",
                examFormat: "1 Uzun Kompozisyon Sorusu + 2 Kısa Kavram/Grafik Analiz Sorusu",
                passRule: "Final sınavından en az 4.0/10 almak şarttır; seminer puanıyla ağırlıklı ortalama ≥ 5.0 olmalıdır.",
                accentColorName: "brown",
                whatWillBeAsked: [
                    "Tema 1-2: Sanayi Öncesi Ekonomi, Malthus Tuzağı (Tavanı) ve Demografik Geçiş Modeli.",
                    "Tema 3-4: İngiliz Sanayi Devrimi'nin Nedenleri (Tarım devrimi, çitleme/enclosures, kömür ve kurumsal yapı) ve Sanayileşmenin Yayılması (ABD, Almanya, Japonya Meiji).",
                    "Tema 5: I. Küreselleşme (1870-1914), Uluslararası Altın Standardı (Patrón Oro) mekanizması ve II. Sanayi Devrimi (Taylorizm/Fordizm).",
                    "Tema 6: İki Savaş Arası Dönem, 1929 Büyük Buhranı'nın nedenleri, yayılması ve New Deal / Keynesyen çıkış politikaları.",
                    "Tema 7: Bretton Woods Sistemi (1944 - IMF, Dünya Bankası, GATT), Kapitalizmin Altın Çağı (1950-1973) ve 1973/1979 Petrol Krizleri (Stagflasyon)."
                ],
                formulasAndTraps: [
                    "MALTHUS TUZAĞI: Nüfus geometrik, gıda üretimi aritmetik artar; azalan verimler yüzünden reel ücretler geçimlik düzeye geri döner.",
                    "ALTIN STANDARDI (Hume Fiyat-Altın Akım Mekanizması): Dış açık → altın çıkışı → para arzı daralması → iç fiyatların düşmesi → rekabet gücünün artması (otomatik denge, ama iç işsizlik pahasına!).",
                    "STAGFLASYON (1970'ler): Durgunluk (işsizlik) + Yüksek Enflasyonun aynı anda görülmesi; klasik Phillips eğrisinin kırılması."
                ],
                checklist: [
                    StudyChecklistItem(id: "his_1", topic: "Tema 1-4: Malthus Modeli, 1. Sanayi Devrimi & Takipçi Ülkeler", detail: "00_CALISMA_REHBERI_VE_OZET.md özetini oku", priority: "NORMAL"),
                    StudyChecklistItem(id: "his_2", topic: "Tema 5-7: Altın Standardı, 1929 Buhranı, Bretton Woods & 1973 Krizi", detail: "Seminer metinleri ve grafik yorumları", priority: "NORMAL")
                ]
            ),
            UniversityCourse(
                id: "10_Marketing",
                code: "1530010",
                shortName: "Marketing",
                titleTR: "Pazarlama Yönetimi I (Temeller)",
                titleES: "Dirección Comercial I / Fundamentos de Marketing",
                folderName: "10_Marketing",
                semester: "2. Dönem",
                professor: "Departamento de Administración de Empresas y Marketing",
                examDateISO: nil,
                examDateLabel: "2. Dönem (Bahar)",
                examLocation: "FCEE",
                convocatoria: "Sürekli Değerlendirme + Final",
                examFormat: "Çoktan Seçmeli Test + Pazarlama Karması (4P) Vaka Analizi",
                passRule: "Temas 1–8 teorik kavramlar ve ürün/fiyat/dağıtım vaka kararları.",
                accentColorName: "pink",
                whatWillBeAsked: [
                    "Tema 1-2: Pazarlama kavramı, İhtiyaç (Necesidad) vs İstek (Deseo) vs Talep (Demanda) ve Makro/Mikro Çevre (PESTEL).",
                    "Tema 3-4: Tüketici Davranışı (Satın alma karar süreci) ve Pazarlama Bilgi Sistemi / Araştırması.",
                    "Tema 5: Pazar Bölümlendirme (Segmentación), Hedef Pazar Seçimi (Indiferenciada, Diferenciada, Concentrada) ve Konumlandırma (Posicionamiento).",
                    "Tema 6-8: 4P Pazarlama Karması — Ürün (Yaşam Eğrisi: Giriş, Büyüme, Olgunluk, Düşüş), Fiyat (Maliyet, Rekabet, Değer bazlı; Kaymağını Alma vs Nüfuz Etme), Dağıtım Kanalları (Yoğun, Seçici, Münhasır) ve İletişim (Tutundurma)."
                ],
                formulasAndTraps: [
                    "KAYMAĞINI ALMA (Desnatado / Skimming) vs NÜFUZ ETME (Penetración): Yenilikçi/patentli üründe yüksek fiyatla başlayıp kademeli indirmek Desnatado; düşük fiyatla hızlı pazar payı kapmak Penetración.",
                    "İHTİYAÇ PAZARLAMACI TARAFINDAN YARATILMAZ: Pazarlama ihtiyacı (necesidad) yaratmaz, ihtiyacın belirli bir markaya yönelik isteğe (deseo) dönüşmesini etkiler."
                ],
                checklist: [
                    StudyChecklistItem(id: "mkt_1", topic: "Tema 1-5: Çevre Analizi, Tüketici Davranışı & STP (Segmentasyon-Konumlandırma)", detail: "Tema 1-5 slayt ve çalışma rehberi tekrarı", priority: "NORMAL"),
                    StudyChecklistItem(id: "mkt_2", topic: "Tema 6-8: 4P (Ürün, Fiyat, Dağıtım, İletişim) Kararları", detail: "Ürün yaşam seyri ve fiyatlandırma stratejileri", priority: "NORMAL")
                ]
            ),
            UniversityCourse(
                id: "11_Espanol_A1",
                code: "IDIOMAS-A1",
                shortName: "Español A1",
                titleTR: "İspanyolca A1 (Instituto de Idiomas)",
                titleES: "Español A1 Cuatrimestre 1",
                folderName: "11_Espanol_A1",
                semester: "1. Dönem (Instituto de Idiomas)",
                professor: "Instituto de Idiomas - Universidad de Sevilla",
                examDateISO: nil,
                examDateLabel: "1. Dönem · Instituto de Idiomas",
                examLocation: "Instituto de Idiomas (Reina Mercedes)",
                convocatoria: "Sürekli Değerlendirme & Dönem Sonu Sınavı",
                examFormat: "Comprensión Lectora + Comprensión Auditiva + Expresión Escrita + Expresión Oral",
                passRule: "Dört temel dil becerisinde (Okuma, Dinleme, Yazma, Konuşma) A1 yeterliliği.",
                accentColorName: "yellow",
                whatWillBeAsked: [
                    "Gramer: Ser vs Estar vs Hay farkı, Presente de Indicativo (düzenli ve düzensiz fiiller: tener, ir, hacer, querer, poder), Gustar/Encantar yapısı (me gusta / me gustan).",
                    "Kelime & İletişim: Kendini tanıtma, aile, günlük rutin (verbo reflexivo: levantarse, ducharse), saatler, alışveriş, yön tarif etme.",
                    "Yazma & Konuşma: 60-80 kelimelik kısa e-posta/kartpostal yazımı ve 3-4 dakikalık kişisel tanıtım & günlük hayat diyaloğu."
                ],
                formulasAndTraps: [
                    "SER vs ESTAR vs HAY: Kimlik/milliyet/meslek/karakter için SER; konum ve geçici durum için ESTAR; 'var' anlamında belirsiz nesnelerle (un/una/muchos) HAY kullanılır ('Está una farmacia' YANLIŞ → 'Hay una farmacia' DOĞRU)."
                ],
                checklist: [
                    StudyChecklistItem(id: "esp_1", topic: "Ser / Estar / Hay + Presente de Indicativo Düzensiz Fiiller", detail: "00_CALISMA_REHBERI_VE_OZET.md gramer tablolarını çalış", priority: "YÜKSEK"),
                    StudyChecklistItem(id: "esp_2", topic: "Sözlü & Yazılı Kendini Tanıtma Şablonunu Ezberle", detail: "Günlük rutin, Sevilla'daki öğrenci hayatı ve hobiler", priority: "NORMAL")
                ]
            ),
            UniversityCourse(
                id: "12_CODIUS",
                code: "CODIUS",
                shortName: "CODIUS",
                titleTR: "Dijital Yetkinlikler (CODIUS)",
                titleES: "Competencias Digitales para Estudiantes Universitarios",
                folderName: "12_CODIUS",
                semester: "1. Dönem (%100 Online)",
                professor: "Biblioteca & SOS Alumnado US",
                examDateISO: nil,
                examDateLabel: "Online Modüller (Enseñanza Virtual)",
                examLocation: "ev.us.es (Online)",
                convocatoria: "Enseñanza Virtual Online Testler",
                examFormat: "Modül sonu kısa online testler (Cuestionarios)",
                passRule: "Enseñanza Virtual üzerindeki tüm modül testlerini tamamlayarak sertifika/kredi onayı almak.",
                accentColorName: "cyan",
                whatWillBeAsked: [
                    "Modül 1: UVUS kullanıcı kimliği, 2FA (İki Faktörlü Doğrulama), SEVIUS ve kurumsal Office 365 / OneDrive kullanımı.",
                    "Modül 2: Catálogo Fama (US Kütüphane arama motoru), akademik veri tabanları (Dialnet, Scopus, Web of Science).",
                    "Modül 3: Akademik dürüstlük, telif hakları (Creative Commons) ve APA 7 kaynakça gösterimi."
                ],
                formulasAndTraps: [
                    "PRATİK İPUCU: 00_CALISMA_REHBERI_VE_OZET.md dosyasını yanında açık tutarak ev.us.es üzerindeki tüm CODIUS modül testlerini 15 dakikada %100 ile bitirebilirsin."
                ],
                checklist: [
                    StudyChecklistItem(id: "cod_1", topic: "Enseñanza Virtual Üzerinden CODIUS Online Testlerini Tamamla", detail: "Catálogo Fama, UVUS ve APA 7 sorularını rehberden kontrol et", priority: "NORMAL")
                ]
            )
        ]
    }
}

private struct UniversityStudyPopoverView: View {
    @EnvironmentObject private var study: UniversityStudyMonitor
    @EnvironmentObject private var smartHome: SmartHomeMonitor
    @State private var activeSection: String = "sinav" // "sinav", "checklist", "rehber"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Image(systemName: "graduationcap.fill")
                                .foregroundStyle(Color.mint)
                            Text("Universidad de Sevilla · ADE")
                                .font(.headline)
                        }
                        Text("\(study.nextExamSummary) · Genel Hazırlık %\(study.overallReadinessPercent)")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                    Spacer()
                    Button {
                        smartHome.openCommandCenterWindow?()
                    } label: {
                        Label("Tam Ekran", systemImage: "macwindow")
                            .font(.caption2.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .controlSize(.small)

                    Button {
                        Task { await study.syncEnseñanzaVirtual() }
                    } label: {
                        if study.isSyncingEV {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Enseñanza Virtual (ev.us.es) derslerini senkronize et")
                }

                if let msg = study.syncStatusMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                // Upcoming Exams Timeline Strip
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("YAKLAŞAN SINAV TAKVİMİ (EKİM 3ª CONVOCATORIA & ARALIK)", systemImage: "calendar.badge.clock")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.orange)
                        Spacer()
                        Button("ev.us.es") {
                            study.openEnseñanzaVirtual()
                        }
                        .buttonStyle(.borderless)
                        .font(.caption2)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(study.upcomingExams) { exam in
                                let selected = study.selectedCourseID == exam.id
                                Button {
                                    study.selectCourse(exam.id)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack(spacing: 4) {
                                            Text(exam.shortName)
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(Color.primary)
                                            Spacer(minLength: 4)
                                            Text(exam.countdownBadge())
                                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(exam.isUrgentExam ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.2), in: Capsule())
                                                .foregroundStyle(exam.isUrgentExam ? Color.orange : Color.secondary)
                                        }
                                        Text(exam.examDateLabel)
                                            .font(.caption2)
                                            .foregroundStyle(Color.secondary)
                                        HStack(spacing: 4) {
                                            Text(exam.examLocation)
                                                .font(.system(size: 10))
                                                .foregroundStyle(Color.secondary)
                                            Spacer()
                                            Text("%\(Int((study.progress(for: exam) * 100).rounded()))")
                                                .font(.system(size: 10, weight: .bold).monospacedDigit())
                                                .foregroundStyle(Color.mint)
                                        }
                                    }
                                    .padding(8)
                                    .frame(width: 178, alignment: .leading)
                                    .background(
                                        selected ? Color.mint.opacity(0.18) : Color.secondary.opacity(0.10),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(selected ? Color.mint : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // All 12 Courses Selector Pills
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        ForEach(study.courses) { course in
                            Button {
                                study.selectCourse(course.id)
                            } label: {
                                Text(course.shortName)
                                    .font(.caption2.weight(study.selectedCourseID == course.id ? .bold : .medium))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        study.selectedCourseID == course.id ? Color.mint.opacity(0.24) : Color.secondary.opacity(0.12),
                                        in: Capsule()
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // Selected Course Card
                let course = study.selectedCourse
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(course.titleTR) (\(course.code))")
                                .font(.subheadline.weight(.bold))
                            Text("\(course.examDateLabel) · \(course.examLocation) · \(course.professor)")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                        }
                        Spacer()
                        Button {
                            study.revealCourseFolder(course)
                        } label: {
                            Image(systemName: "folder.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .help("Ders klasörünü Finder'da aç")
                    }

                    // Exam Rule Banner
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 5) {
                            Image(systemName: "exclamationmark.shield.fill")
                                .foregroundStyle(Color.orange)
                            Text(course.examFormat)
                                .font(.caption2.weight(.bold))
                        }
                        Text(course.passRule)
                            .font(.caption2)
                            .foregroundStyle(Color.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    // Sub-section switcher
                    HStack(spacing: 6) {
                        sectionButton("Sorulacaklar & Tuzaklar", id: "sinav", icon: "target")
                        sectionButton("Çalışma Checklist (%\(Int((study.progress(for: course) * 100).rounded())))", id: "checklist", icon: "checklist")
                        sectionButton("Notlar & PDF'ler", id: "rehber", icon: "doc.text.fill")
                    }

                    if activeSection == "sinav" {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("SINAVDA KESİN SORULACAK KONULAR")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.mint)

                            ForEach(Array(course.whatWillBeAsked.enumerated()), id: \.offset) { idx, item in
                                HStack(alignment: .top, spacing: 6) {
                                    Text("\(idx + 1).")
                                        .font(.caption2.weight(.bold).monospacedDigit())
                                        .foregroundStyle(Color.mint)
                                    Text(item)
                                        .font(.caption2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Divider()

                            Text("KRİTİK FORMÜLLER & SINAV TUZAKLARI")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Color.orange)

                            ForEach(Array(course.formulasAndTraps.enumerated()), id: \.offset) { _, trap in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 9))
                                        .foregroundStyle(Color.orange)
                                        .padding(.top, 2)
                                    Text(trap)
                                        .font(.caption2)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    } else if activeSection == "checklist" {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(course.checklist) { item in
                                let done = study.isCompleted(item)
                                Button {
                                    study.toggleChecklist(item)
                                } label: {
                                    HStack(alignment: .top, spacing: 8) {
                                        Image(systemName: done ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(done ? Color.green : Color.secondary)
                                            .padding(.top, 1)
                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(item.topic)
                                                    .font(.caption.weight(.semibold))
                                                    .strikethrough(done)
                                                    .foregroundStyle(done ? Color.secondary : Color.primary)
                                                Spacer()
                                                Text(item.priority)
                                                    .font(.system(size: 9, weight: .bold))
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 1)
                                                    .background(
                                                        item.priority == "KRİTİK" ? Color.red.opacity(0.2) : Color.mint.opacity(0.2),
                                                        in: Capsule()
                                                    )
                                            }
                                            Text(item.detail)
                                                .font(.caption2)
                                                .foregroundStyle(Color.secondary)
                                        }
                                    }
                                    .padding(7)
                                    .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            let files = study.courseFiles[course.id] ?? []
                            ForEach(files.prefix(8)) { file in
                                HStack {
                                    Image(systemName: file.isMarkdown ? "doc.richtext.fill" : "doc.fill")
                                        .foregroundStyle(file.isMarkdown ? Color.mint : Color.orange)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(file.name)
                                            .font(.caption.weight(.medium))
                                            .lineLimit(1)
                                        Text("\(file.relativePath) · \(file.sizeLabel)")
                                            .font(.caption2)
                                            .foregroundStyle(Color.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Button("Aç") {
                                        study.openInPreviewOrFinder(file.fullPath)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.mini)
                                }
                                .padding(6)
                                .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                            }

                            if !study.selectedMarkdownContent.isEmpty {
                                Divider()
                                Text(study.selectedMarkdownTitle)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Color.mint)
                                Text(String(study.selectedMarkdownContent.prefix(1600)))
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(Color.primary)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
        }
        .frame(maxHeight: 690)
    }

    private func sectionButton(_ title: String, id: String, icon: String) -> some View {
        Button {
            activeSection = id
        } label: {
            Label(title, systemImage: icon)
                .font(.caption2.weight(activeSection == id ? .bold : .regular))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(activeSection == id ? .mint : .secondary)
        .controlSize(.small)
    }
}

private struct UniversityCommandCenterView: View {
    @EnvironmentObject private var study: UniversityStudyMonitor

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // LEFT COLUMN: Upcoming Exam Countdowns + 12 Course Selector
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Yaklaşan Sınavlar & 12 Ders", systemImage: "calendar.badge.exclamationmark")
                        .font(.headline)
                        .foregroundStyle(Color.mint)
                    Spacer()
                    Text("Hazırlık %\(study.overallReadinessPercent)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.mint.opacity(0.2), in: Capsule())
                }

                HStack(spacing: 6) {
                    Button {
                        Task { await study.syncEnseñanzaVirtual() }
                    } label: {
                        Label(study.isSyncingEV ? "Senkronize…" : "EV Sync", systemImage: "arrow.triangle.2.circlepath")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.mint)
                    .controlSize(.small)
                    .disabled(study.isSyncingEV)

                    Button {
                        study.openEnseñanzaVirtual()
                    } label: {
                        Label("ev.us.es", systemImage: "safari")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button {
                        study.loadMasterStudyPlan()
                    } label: {
                        Label("Genel Plan", systemImage: "list.clipboard.fill")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let msg = study.syncStatusMessage {
                    Text(msg)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)
                        .lineLimit(2)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 7) {
                        ForEach(study.courses) { course in
                            let isSelected = study.selectedCourseID == course.id
                            let pct = Int((study.progress(for: course) * 100).rounded())
                            Button {
                                study.selectCourse(course.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(course.shortName)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(Color.primary)
                                        Spacer()
                                        Text(course.countdownBadge())
                                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                course.isUrgentExam ? Color.orange.opacity(0.25) : Color.secondary.opacity(0.16),
                                                in: Capsule()
                                            )
                                            .foregroundStyle(course.isUrgentExam ? Color.orange : Color.secondary)
                                    }

                                    Text(course.titleTR)
                                        .font(.caption2)
                                        .foregroundStyle(Color.secondary)
                                        .lineLimit(1)

                                    HStack {
                                        Label(course.examDateLabel, systemImage: "clock")
                                            .font(.caption2)
                                            .foregroundStyle(Color.secondary)
                                        Spacer()
                                        Text("%\(pct)")
                                            .font(.caption2.weight(.bold).monospacedDigit())
                                            .foregroundStyle(pct >= 80 ? Color.green : Color.mint)
                                    }
                                }
                                .padding(10)
                                .background(
                                    isSelected ? Color.mint.opacity(0.18) : Color.secondary.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(isSelected ? Color.mint : Color.clear, lineWidth: 1.5)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: 300)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            // CENTER COLUMN: What Will Be Asked, Exam Rules, Formulas & Interactive Study Checklist
            let course = study.selectedCourse
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Course Header Banner
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 8) {
                                    Text(course.titleTR)
                                        .font(.title3.weight(.bold))
                                    Text(course.code)
                                        .font(.caption.monospaced())
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: Capsule())
                                }
                                Text("\(course.titleES) · \(course.professor)")
                                    .font(.caption)
                                    .foregroundStyle(Color.secondary)
                            }
                            Spacer()
                            Button {
                                study.revealCourseFolder(course)
                            } label: {
                                Label("Klasörü Aç", systemImage: "folder.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        HStack(spacing: 12) {
                            Label(course.examDateLabel, systemImage: "calendar")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.orange)
                            Label(course.examLocation, systemImage: "mappin.and.ellipse")
                                .font(.caption.weight(.semibold))
                            Label(course.convocatoria, systemImage: "award.fill")
                                .font(.caption)
                                .foregroundStyle(Color.secondary)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("SINAV FORMATI: \(course.examFormat)")
                                .font(.caption.weight(.bold))
                            Text("GEÇME KURALI & BARAJ: \(course.passRule)")
                                .font(.caption)
                                .foregroundStyle(Color.orange)
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // What Will Be Asked on the Exam
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Sınavda Kesin Sorulacaklar (Bölüm & Soru Dağılımı)", systemImage: "target")
                            .font(.headline)
                            .foregroundStyle(Color.mint)

                        ForEach(Array(course.whatWillBeAsked.enumerated()), id: \.offset) { idx, question in
                            HStack(alignment: .top, spacing: 10) {
                                Text("\(idx + 1)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .frame(width: 22, height: 22)
                                    .background(Color.mint.opacity(0.2), in: Circle())
                                    .foregroundStyle(Color.mint)
                                Text(question)
                                    .font(.callout)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Critical Formulas & Exam Traps
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Kritik Formüller, Püf Noktalar & Sınav Tuzakları", systemImage: "bolt.shield.fill")
                            .font(.headline)
                            .foregroundStyle(Color.orange)

                        ForEach(Array(course.formulasAndTraps.enumerated()), id: \.offset) { _, formula in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(Color.orange)
                                    .padding(.top, 2)
                                Text(formula)
                                    .font(.callout)
                                    .textSelection(.enabled)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    // Interactive Study Checklist
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Çalışman Gerekenler Checklist", systemImage: "checklist.checked")
                                .font(.headline)
                                .foregroundStyle(Color.green)
                            Spacer()
                            Text("%\(Int((study.progress(for: course) * 100).rounded())) Tamamlandı")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(Color.green)
                        }

                        ForEach(course.checklist) { item in
                            let done = study.isCompleted(item)
                            Button {
                                study.toggleChecklist(item)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: done ? "checkmark.square.fill" : "square")
                                        .font(.title3)
                                        .foregroundStyle(done ? Color.green : Color.secondary)
                                    VStack(alignment: .leading, spacing: 3) {
                                        HStack {
                                            Text(item.topic)
                                                .font(.subheadline.weight(.semibold))
                                                .strikethrough(done)
                                                .foregroundStyle(done ? Color.secondary : Color.primary)
                                            Spacer()
                                            Text(item.priority)
                                                .font(.caption2.weight(.bold))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(
                                                    item.priority == "KRİTİK" ? Color.red.opacity(0.22) : Color.mint.opacity(0.2),
                                                    in: Capsule()
                                                )
                                                .foregroundStyle(item.priority == "KRİTİK" ? Color.orange : Color.mint)
                                        }
                                        Text(item.detail)
                                            .font(.caption)
                                            .foregroundStyle(Color.secondary)
                                    }
                                }
                                .padding(10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            .frame(minWidth: 420, maxWidth: .infinity)

            // RIGHT COLUMN: Built-in Markdown Study Guide / Exam Simulation Reader + Course PDFs + Personal Notes
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Ders Notları, Rehber & Simülasyon", systemImage: "book.pages.fill")
                        .font(.headline)
                        .foregroundStyle(Color.cyan)
                    Spacer()
                    if !study.selectedMarkdownPath.isEmpty {
                        Button("Dışarıda Aç") {
                            study.openInPreviewOrFinder(study.selectedMarkdownPath)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Quick Markdown & PDF File Bar
                let files = study.courseFiles[course.id] ?? []
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(files) { file in
                            Button {
                                if file.isMarkdown {
                                    study.loadMarkdownFile(file)
                                } else {
                                    study.openInPreviewOrFinder(file.fullPath)
                                }
                            } label: {
                                Label(
                                    file.name,
                                    systemImage: file.isSimulation ? "checkmark.seal.fill" : (file.isMarkdown ? "doc.richtext.fill" : "doc.fill")
                                )
                                .font(.caption2.weight(study.selectedMarkdownPath == file.fullPath ? .bold : .regular))
                            }
                            .buttonStyle(.bordered)
                            .tint(file.isSimulation ? .orange : (file.isMarkdown ? .cyan : .secondary))
                            .controlSize(.small)
                        }
                    }
                }

                // Markdown Reader
                ScrollView {
                    Text(study.selectedMarkdownContent)
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundStyle(Color.primary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                Divider()

                // Personal Notes Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("\(course.shortName) Kişisel Çalışma Notlarım", systemImage: "square.and.pencil")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.mint)
                        Spacer()
                        Button("Notu Kaydet") {
                            study.savePersonalNote()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.mint)
                        .controlSize(.mini)
                    }

                    TextEditor(text: $study.personalNoteDraft)
                        .font(.system(size: 12))
                        .frame(height: 84)
                        .padding(4)
                        .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
            .padding(14)
            .frame(minWidth: 380, maxWidth: .infinity)
            .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
    }
}

private struct SmartHomeView: View {
    @EnvironmentObject private var smartHome: SmartHomeMonitor
    @State private var masterBriDraft: Double = 200

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Akıllı Ev, TV & Modem")
                            .font(.headline)
                        Text(smartHome.quickSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        smartHome.openCommandCenterWindow?()
                    } label: {
                        Label("Komuta Merkezi", systemImage: "macwindow.badge.plus")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.indigo)
                    .controlSize(.small)

                    Button {
                        Task { await smartHome.refresh() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(smartHome.isRefreshing)
                }

                if let msg = smartHome.actionMessage {
                    HStack(spacing: 8) {
                        if smartHome.isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        }
                        Text(msg)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        Spacer()
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }

                // Philips Hue Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Philips Hue · Şömine Işıkları", systemImage: "lightbulb.led.wide.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.yellow)
                        Spacer()
                        StatusPill(
                            online: smartHome.hueOnline,
                            onlineText: smartHome.bridgeIP,
                            offlineText: "Köprü Yok"
                        )
                    }

                    HStack(spacing: 6) {
                        Button {
                            Task { await smartHome.setAllLights(on: true) }
                        } label: {
                            Label("Tümünü Aç", systemImage: "sun.max.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.amberHue)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.setAllLights(on: false) }
                        } label: {
                            Label("Kapat", systemImage: "moon.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.repairHueBridge() }
                        } label: {
                            Label("Onar", systemImage: "wrench.and.screwdriver.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Vaytniga eth0 Ethernet Tethering ve Hue Bridge bağlantısını onarır")
                    }

                    HStack(spacing: 6) {
                        hueSceneButton("Sinema", scene: "cinema", icon: "film.fill")
                        hueSceneButton("Gece", scene: "night", icon: "moon.stars.fill")
                        hueSceneButton("Okuma", scene: "reading", icon: "book.fill")
                        hueSceneButton("Tam", scene: "full", icon: "sun.max.trianglebadge.exclamationmark.fill")
                    }

                    ForEach(smartHome.lights) { light in
                        HueLightRow(light: light)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // TCL 4K Smart TV Pro Card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("TCL 4K Smart TV Pro", systemImage: "tv.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.cyan)
                        Spacer()
                        StatusPill(
                            online: smartHome.tv?.online == true,
                            onlineText: smartHome.tv?.activeAppLabel ?? "Açık",
                            offlineText: "Kapalı"
                        )
                    }

                    HStack(spacing: 6) {
                        Button {
                            Task { await smartHome.tvWake() }
                        } label: {
                            Label("Uyandır", systemImage: "power")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.tvArtMode() }
                        } label: {
                            Label("The Frame Art", systemImage: "photo.artframe")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.tvSleep() }
                        } label: {
                            Label("Uyut", systemImage: "moon.zzz.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text("Uygulama Başlatıcı & Sinema Modu")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        tvAppButton("Stremio", app: "stremio", icon: "play.tv.fill")
                        tvAppButton("Nuvio", app: "nuvio", icon: "sparkles.tv.fill")
                        tvAppButton("YouTube", app: "youtube", icon: "play.rectangle.fill")
                        tvAppButton("Disney+", app: "disney", icon: "film.stack.fill")
                        tvAppButton("TOD", app: "tod", icon: "sportscourt.fill")
                        tvAppButton("TV+", app: "tvplus", icon: "antenna.radiowaves.left.and.right")
                    }

                    HStack(spacing: 6) {
                        Button {
                            Task { await smartHome.startCinemaMode(app: "stremio") }
                        } label: {
                            Label("Sinema + Stremio", systemImage: "popcorn.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.startCinemaMode(app: "nuvio") }
                        } label: {
                            Label("Sinema + Nuvio", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.indigo)
                        .controlSize(.small)
                    }

                    Divider()

                    // Remote & Brightness
                    HStack(spacing: 6) {
                        tvKeyButton("Geri", key: "KEYCODE_BACK", icon: "arrow.uturn.backward")
                        tvKeyButton("Ana Ekran", key: "KEYCODE_HOME", icon: "house.fill")
                        tvKeyButton("Oynat/Dur", key: "KEYCODE_MEDIA_PLAY_PAUSE", icon: "playpause.fill")
                        tvKeyButton("Ses -", key: "KEYCODE_VOLUME_DOWN", icon: "speaker.minus.fill")
                        tvKeyButton("Ses +", key: "KEYCODE_VOLUME_UP", icon: "speaker.plus.fill")
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "sun.min.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(
                            value: Binding(
                                get: { smartHome.tvBrightness },
                                set: { smartHome.tvBrightness = $0 }
                            ),
                            in: 0.05...1.0
                        ) { editing in
                            if !editing {
                                Task { await smartHome.setTVBrightness(smartHome.tvBrightness) }
                            }
                        }
                        Text("%\(Int((smartHome.tvBrightness * 100).rounded()))")
                            .font(.caption2.monospacedDigit())
                            .frame(width: 34, alignment: .trailing)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                // Vaytniga S9+ Modem & RM-OS Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Vaytniga S9+ Modem & RM-OS", systemImage: "antenna.radiowaves.left.and.right.circle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.green)
                        Spacer()
                        StatusPill(
                            online: smartHome.modem?.online == true,
                            onlineText: "\(smartHome.modem?.operatorName ?? "LTE") · \(smartHome.modem?.clients ?? 0) cihaz",
                            offlineText: "Modem Yok"
                        )
                    }

                    if let modem = smartHome.modem {
                        HStack(spacing: 10) {
                            Text("Pil %\(modem.battery) · \(String(format: "%.1f°C", modem.temperatureCelsius))")
                            Text("·")
                            Text("Hue eth0: \(modem.hueEthernetHealthy ? modem.eth0IP : "Kapalı")")
                                .foregroundStyle(modem.hueEthernetHealthy ? Color.secondary : Color.orange)
                            Spacer()
                            Text("\(modem.totalGB) GB")
                                .monospacedDigit()
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 6) {
                        Button {
                            Task { await smartHome.repairHueBridge() }
                        } label: {
                            Label("eth0 Onar", systemImage: "cable.connector.horizontal")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.openHotspotSettings() }
                        } label: {
                            Label("5GHz Hotspot", systemImage: "wifi")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.syncRMOS() }
                        } label: {
                            Label("RM-OS Sync", systemImage: "externaldrive.badge.icloud")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            Task { await smartHome.syncUniversityCourses() }
                        } label: {
                            Label("US Ders Sync", systemImage: "graduationcap.fill")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(16)
        }
        .frame(maxHeight: 690)
    }

    private func hueSceneButton(_ title: String, scene: String, icon: String) -> some View {
        Button {
            Task { await smartHome.applyScene(scene) }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func tvAppButton(_ title: String, app: String, icon: String) -> some View {
        Button {
            Task { await smartHome.launchTVApp(app) }
        } label: {
            Label(title, systemImage: icon)
                .font(.caption2.weight(.medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func tvKeyButton(_ title: String, key: String, icon: String) -> some View {
        Button {
            Task { await smartHome.sendTVKey(key) }
        } label: {
            Label(title, systemImage: icon)
                .labelStyle(.iconOnly)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .help(title)
    }
}

private struct HueLightRow: View {
    @EnvironmentObject private var smartHome: SmartHomeMonitor
    let light: HueLight
    @State private var sliderValue: Double = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button {
                    Task { await smartHome.toggleLight(id: light.id, on: !light.on) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: light.on ? "lightbulb.fill" : "lightbulb")
                            .foregroundStyle(light.on ? Color.yellow : Color.secondary)
                        Text(light.name)
                            .font(.caption.weight(.semibold))
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Text(light.on ? "%\(light.brightnessPercent)" : "Kapalı")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(light.on ? .primary : .secondary)

                Toggle("", isOn: Binding(
                    get: { light.on },
                    set: { newValue in
                        Task { await smartHome.toggleLight(id: light.id, on: newValue) }
                    }
                ))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.mini)
            }

            HStack(spacing: 8) {
                Image(systemName: "sun.min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Slider(value: $sliderValue, in: 1...254) { editing in
                    if !editing {
                        Task { await smartHome.setLightBrightness(id: light.id, bri: Int(sliderValue.rounded())) }
                    }
                }
                Image(systemName: "sun.max.fill")
                    .font(.caption2)
                    .foregroundStyle(.yellow)
            }
        }
        .padding(8)
        .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onAppear {
            sliderValue = Double(light.bri)
        }
        .onChange(of: light.bri) { newBri in
            sliderValue = Double(newBri)
        }
    }
}

private extension ShapeStyle where Self == Color {
    static var amberHue: Color {
        Color(red: 0.96, green: 0.68, blue: 0.14)
    }
}

private enum CommandCenterTab: String, CaseIterable, Identifiable {
    case all = "Genel Komuta"
    case study = "Dersler & Sınavlar"
    case smartHome = "Ev, Hue & TV"
    case opportunities = "Fırsatlar"
    case operations = "Operasyon & Mail"
    case lolile = "LOLİLE PC"
    case myaL11 = "MYA-L11 Sunucu"
    case node = "Vaytniga & Deck"
    case broadcast = "Yayın Merkezi"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .all: return "square.grid.3x2.fill"
        case .study: return "graduationcap.fill"
        case .smartHome: return "lightbulb.led.wide.fill"
        case .opportunities: return "sparkles.rectangle.stack.fill"
        case .operations: return "bolt.shield.fill"
        case .lolile: return "desktopcomputer"
        case .myaL11: return "server.rack"
        case .node: return "iphone.gen3"
        case .broadcast: return "dot.radiowaves.left.and.right"
        }
    }
}

private struct DAAKCommandCenterView: View {
    @EnvironmentObject private var relay: RelayMonitor
    @EnvironmentObject private var node: NodeMonitor
    @EnvironmentObject private var myaL11: MYAL11Monitor
    @EnvironmentObject private var separation: SeparationMonitor
    @EnvironmentObject private var mail: MailAccountMonitor
    @EnvironmentObject private var updater: UpdateMonitor
    @EnvironmentObject private var localMac: LocalMacMonitor
    @EnvironmentObject private var opportunity: OpportunityMonitor
    @EnvironmentObject private var broadcast: BroadcastMonitor
    @EnvironmentObject private var smartHome: SmartHomeMonitor
    @EnvironmentObject private var study: UniversityStudyMonitor

    @State private var selectedTab: CommandCenterTab = .all

    var body: some View {
        VStack(spacing: 0) {
            // Top Unified Command Bar
            headerBar
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)

            Divider()

            // Quick Action Ribbon
            quickActionRibbon
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))

            Divider()

            // Main Content Area
            Group {
                switch selectedTab {
                case .all:
                    allInOneBentoDashboard
                case .study:
                    UniversityCommandCenterView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .smartHome:
                    ScrollView {
                        HStack(alignment: .top, spacing: 18) {
                            hueFullColumn
                            tvFullColumn
                            modemAndRmosColumn
                        }
                        .padding(20)
                    }
                case .opportunities:
                    OpportunityView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .operations:
                    OperationsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .lolile:
                    ScrollView {
                        RelayMenuView()
                            .frame(maxWidth: 640)
                            .padding(20)
                    }
                case .myaL11:
                    MYAL11MenuView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .node:
                    HStack(alignment: .top, spacing: 16) {
                        NodeMenuView()
                        Divider()
                        DeckManagerView()
                    }
                    .padding(12)
                case .broadcast:
                    BroadcastView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 1120, minHeight: 760)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var headerBar: some View {
        HStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("DAAK KOMUTA MERKEZİ")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text("RM-OS · US Ders & Sınavlar · Akıllı Ev · LOLİLE · MYA-L11 · Vaytniga · Fırsatlar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Live System Status Pills
            HStack(spacing: 8) {
                systemBadge("US Sınav", online: true, detail: study.upcomingExams.first.map { "\($0.shortName) (\($0.countdownBadge()))" } ?? "12 Ders")
                systemBadge("Hue", online: smartHome.hueOnline, detail: smartHome.anyLightOn ? "Açık" : "Kapalı")
                systemBadge("TV 4K", online: smartHome.tv?.online == true, detail: smartHome.tv?.activeAppLabel ?? "Kapalı")
                systemBadge("Vaytniga", online: smartHome.modem?.online == true || node.isOnline, detail: smartHome.modem?.netType ?? "LTE")
                systemBadge("LOLİLE", online: relay.isConnected, detail: relay.status?.hardware?.power?.wallEstimateWatts.map { String(format: "%.0fW", $0) } ?? "PC")
                systemBadge("MYA-L11", online: myaL11.isOnline, detail: myaL11.isOnBattery ? "Pilde!" : "AC 7/24")
            }

            Button {
                Task {
                    async let a: Void = smartHome.refresh()
                    async let b: Void = relay.refresh()
                    async let c: Void = myaL11.refresh()
                    async let d: Void = node.refresh()
                    async let e: Void = opportunity.refresh()
                    _ = await (a, b, c, d, e)
                }
            } label: {
                Label("Tümünü Yenile", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .controlSize(.small)
        }
    }

    private var quickActionRibbon: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ForEach(CommandCenterTab.allCases) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        Label(tab.rawValue, systemImage: tab.symbol)
                            .font(.caption.weight(selectedTab == tab ? .semibold : .regular))
                    }
                    .buttonStyle(.bordered)
                    .tint(selectedTab == tab ? .indigo : .secondary)
                    .controlSize(.small)
                }

                Spacer()

                // One-Click Global Macros
                Button {
                    Task { await smartHome.startCinemaMode(app: "stremio") }
                } label: {
                    Label("Sinema + Stremio", systemImage: "popcorn.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.small)

                Button {
                    Task {
                        await smartHome.applyScene("night")
                        await smartHome.tvArtMode()
                    }
                } label: {
                    Label("Gece + The Frame", systemImage: "photo.artframe")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task {
                        await smartHome.setAllLights(on: false)
                        await smartHome.tvSleep()
                    }
                } label: {
                    Label("Ev Uyku Modu", systemImage: "moon.zzz.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if let msg = smartHome.actionMessage {
                HStack(spacing: 8) {
                    if smartHome.isWorking {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "bolt.horizontal.circle.fill")
                            .foregroundStyle(.indigo)
                    }
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var allInOneBentoDashboard: some View {
        ScrollView {
            HStack(alignment: .top, spacing: 16) {
                // COLUMN 1: Akıllı Ev (Philips Hue + TCL 4K Smart TV)
                VStack(alignment: .leading, spacing: 16) {
                    hueFullColumn
                    tvFullColumn
                }
                .frame(maxWidth: .infinity)

                // COLUMN 2: Altyapı & Cihazlar (Vaytniga Modem, LOLİLE PC, MYA-L11, RM-OS)
                VStack(alignment: .leading, spacing: 16) {
                    modemAndRmosColumn
                    lolileSummaryCard
                    myaL11AndKaiCard
                }
                .frame(maxWidth: .infinity)

                // COLUMN 3: Üniversite Sınavları, Fırsat İstihbaratı, Yayın, Mail & M3 Deck
                VStack(alignment: .leading, spacing: 16) {
                    universityExamsSummaryCard
                    opportunitiesSummaryCard
                    broadcastAndMailCard
                    deckQuickCard
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
        }
    }

    private var universityExamsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("US ADE · Yaklaşan Sınavlar & Notlar", systemImage: "graduationcap.fill")
                    .font(.headline)
                    .foregroundStyle(Color.mint)
                Spacer()
                StatusPill(
                    online: true,
                    onlineText: "Hazırlık %\(study.overallReadinessPercent)",
                    offlineText: "12 Ders"
                )
            }

            ForEach(Array(study.upcomingExams.prefix(5))) { exam in
                Button {
                    study.selectCourse(exam.id)
                    selectedTab = .study
                } label: {
                    HStack(spacing: 8) {
                        Text(exam.countdownBadge())
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(exam.isUrgentExam ? Color.orange.opacity(0.24) : Color.mint.opacity(0.18), in: Capsule())
                            .foregroundStyle(exam.isUrgentExam ? Color.orange : Color.mint)

                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(exam.shortName) — \(exam.titleTR)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                            Text("\(exam.examDateLabel) · \(exam.examLocation)")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("%\(Int((study.progress(for: exam) * 100).rounded()))")
                            .font(.caption2.weight(.bold).monospacedDigit())
                            .foregroundStyle(Color.mint)
                    }
                    .padding(6)
                    .background(.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            HStack {
                Button {
                    Task { await study.syncEnseñanzaVirtual() }
                } label: {
                    Label("EV Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    study.openEnseñanzaVirtual()
                } label: {
                    Label("ev.us.es", systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Ders Notları & Sorulacaklar →") {
                    selectedTab = .study
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var hueFullColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Philips Hue · Aydınlatma", systemImage: "lightbulb.led.wide.fill")
                    .font(.headline)
                    .foregroundStyle(.yellow)
                Spacer()
                StatusPill(
                    online: smartHome.hueOnline,
                    onlineText: "Köprü \(smartHome.bridgeIP)",
                    offlineText: "Köprü Yok"
                )
            }

            HStack(spacing: 8) {
                Button {
                    Task { await smartHome.setAllLights(on: true) }
                } label: {
                    Label("Tümünü Aç", systemImage: "sun.max.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.amberHue)

                Button {
                    Task { await smartHome.setAllLights(on: false) }
                } label: {
                    Label("Tümünü Kapat", systemImage: "moon.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await smartHome.repairHueBridge() }
                } label: {
                    Label("Köprü Onar", systemImage: "wrench.and.screwdriver.fill")
                }
                .buttonStyle(.bordered)
                .help("Vaytniga S9+ eth0 Ethernet Tethering servisini ve Hue Bridge IP adresini otomatik onarır")
            }

            HStack(spacing: 6) {
                ForEach([
                    ("Sinema %25", "cinema", "film.fill"),
                    ("Gece %10", "night", "moon.stars.fill"),
                    ("Okuma %80", "reading", "book.fill"),
                    ("Tam %100", "full", "sun.max.fill")
                ], id: \.1) { title, scene, icon in
                    Button {
                        Task { await smartHome.applyScene(scene) }
                    } label: {
                        Label(title, systemImage: icon)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if smartHome.lights.isEmpty {
                Text("Hue ışık listesi bekleniyor… 'Köprü Onar' ile eth0 bağlantısını tetikleyebilirsin.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(smartHome.lights) { light in
                    HueLightRow(light: light)
                }
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var tvFullColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("TCL 4K Smart TV Pro", systemImage: "tv.fill")
                    .font(.headline)
                    .foregroundStyle(.cyan)
                Spacer()
                StatusPill(
                    online: smartHome.tv?.online == true,
                    onlineText: smartHome.tv?.activeAppLabel ?? "Açık",
                    offlineText: "Kapalı"
                )
            }

            HStack(spacing: 8) {
                Button {
                    Task { await smartHome.tvWake() }
                } label: {
                    Label("Uyandır", systemImage: "power")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)

                Button {
                    Task { await smartHome.tvArtMode() }
                } label: {
                    Label("One Piece 4K Art", systemImage: "photo.artframe")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await smartHome.tvSleep() }
                } label: {
                    Label("Uyut", systemImage: "moon.zzz.fill")
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach([
                    ("Stremio", "stremio", "play.tv.fill"),
                    ("Nuvio", "nuvio", "sparkles.tv.fill"),
                    ("YouTube", "youtube", "play.rectangle.fill"),
                    ("Disney+", "disney", "film.stack.fill"),
                    ("TOD", "tod", "sportscourt.fill"),
                    ("TV+", "tvplus", "antenna.radiowaves.left.and.right")
                ], id: \.1) { title, app, icon in
                    Button {
                        Task { await smartHome.launchTVApp(app) }
                    } label: {
                        Label(title, systemImage: icon)
                            .font(.caption.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            // D-Pad & Media Controls
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    remoteBtn("Geri", key: "KEYCODE_BACK", icon: "arrow.uturn.backward")
                    remoteBtn("▲", key: "KEYCODE_DPAD_UP", icon: "chevron.up")
                    remoteBtn("Ana Ekran", key: "KEYCODE_HOME", icon: "house.fill")
                    remoteBtn("Ses -", key: "KEYCODE_VOLUME_DOWN", icon: "speaker.minus.fill")
                }
                HStack(spacing: 6) {
                    remoteBtn("◀", key: "KEYCODE_DPAD_LEFT", icon: "chevron.left")
                    remoteBtn("OK", key: "KEYCODE_DPAD_CENTER", icon: "circle.inset.filled")
                    remoteBtn("▶", key: "KEYCODE_DPAD_RIGHT", icon: "chevron.right")
                    remoteBtn("Ses +", key: "KEYCODE_VOLUME_UP", icon: "speaker.plus.fill")
                }
                HStack(spacing: 6) {
                    remoteBtn("Sessiz", key: "KEYCODE_VOLUME_MUTE", icon: "speaker.slash.fill")
                    remoteBtn("▼", key: "KEYCODE_DPAD_DOWN", icon: "chevron.down")
                    remoteBtn("Oynat/Dur", key: "KEYCODE_MEDIA_PLAY_PAUSE", icon: "playpause.fill")
                    remoteBtn("Menü", key: "KEYCODE_MENU", icon: "list.bullet")
                }
            }

            HStack(spacing: 8) {
                Text("Panel Parlaklığı")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { smartHome.tvBrightness },
                        set: { smartHome.tvBrightness = $0 }
                    ),
                    in: 0.05...1.0
                ) { editing in
                    if !editing {
                        Task { await smartHome.setTVBrightness(smartHome.tvBrightness) }
                    }
                }
                Text("%\(Int((smartHome.tvBrightness * 100).rounded()))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 38, alignment: .trailing)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var modemAndRmosColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Vaytniga S9+ Modem & RM-OS", systemImage: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                StatusPill(
                    online: smartHome.modem?.online == true,
                    onlineText: "\(smartHome.modem?.operatorName ?? "Vodafone") · \(smartHome.modem?.netType ?? "LTE")",
                    offlineText: "ADB Bekleniyor"
                )
            }

            if let modem = smartHome.modem {
                VStack(spacing: 6) {
                    MetricRow(title: "Ethernet Tethering (Hue)", value: modem.hueEthernetHealthy ? modem.eth0IP : "Devre dışı (Onar'a bas)")
                    MetricRow(title: "5GHz Wi-Fi Hotspot", value: "\(modem.hotspot5GHz ? "Aktif" : "Kapalı") · \(modem.clients) istemci")
                    MetricRow(title: "Pil & Sıcaklık", value: "%\(modem.battery) · \(String(format: "%.1f°C", modem.temperatureCelsius))")
                    MetricRow(title: "Toplam Trafik", value: "\(modem.totalGB) GB · WAN \(modem.wanIP.isEmpty ? modem.upstream : modem.wanIP)")
                }
            }

            HStack(spacing: 6) {
                Button {
                    Task { await smartHome.repairHueBridge() }
                } label: {
                    Label("eth0 Hue Onar", systemImage: "cable.connector.horizontal")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.small)

                Button {
                    Task { await smartHome.openHotspotSettings() }
                } label: {
                    Label("Hotspot", systemImage: "wifi")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task { await smartHome.runModemSpeedtest() }
                } label: {
                    Label("Hız Testi", systemImage: "speedometer")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("RM-OS & Üniversite Senkronu")
                        .font(.caption.weight(.semibold))
                    Text(smartHome.rmosStatus)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    Task { await smartHome.syncRMOS() }
                } label: {
                    Label("RM-OS Sync", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task { await smartHome.syncUniversityCourses() }
                } label: {
                    Label("US Dersler", systemImage: "graduationcap.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var lolileSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("LOLİLE · Windows 11 Master", systemImage: "desktopcomputer")
                    .font(.headline)
                    .foregroundStyle(.purple)
                Spacer()
                StatusPill(online: relay.isConnected)
            }

            if let status = relay.status, let hw = status.hardware {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(String(format: "%.0f W", hw.power?.wallEstimateWatts ?? 0))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.purple)
                    Text("CPU \(RelayMonitor.formatPercent(hw.cpu?.loadPercent)) · GPU \(RelayMonitor.formatPercent(hw.gpu?.loadPercent)) · RAM \(RelayMonitor.formatPercent(hw.memory?.loadPercent))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let power = status.power, power.available {
                    HStack(spacing: 6) {
                        ForEach([
                            ("Oto", "auto"),
                            ("Eko", "eco"),
                            ("Denge", "balanced"),
                            ("Hız", "performance")
                        ], id: \.1) { label, mode in
                            Button(label) {
                                Task { await relay.setPowerMode(mode) }
                            }
                            .buttonStyle(.bordered)
                            .tint(power.controlMode == mode ? .green : .purple)
                            .controlSize(.small)
                        }
                        Spacer()
                        Button("RAM Bakımı") {
                            Task { await relay.maintainMemory() }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            } else {
                Text(relay.lastError ?? "LOLİLE telemetrisi alınıyor…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    relay.openRemoteDesktop()
                } label: {
                    Label("Windows App (RDP)", systemImage: "display")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    relay.openDashboard()
                } label: {
                    Label("Web Paneli", systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Detaylar →") {
                    selectedTab = .lolile
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var myaL11AndKaiCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("MYA-L11 Sunucu & kAI MacBook", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                StatusPill(
                    online: myaL11.isOnline,
                    onlineText: myaL11.isOnBattery ? "Pilde" : "7/24 AC",
                    offlineText: "Çevrimdışı"
                )
            }

            MetricRow(title: "MYA-L11 Güç & UPS", value: myaL11.upsSummary)
            MetricRow(title: "MYA-L11 Sistem", value: myaL11.overviewSummary)
            MetricRow(title: "Docker & FastDrop", value: "\(myaL11.dockerSummary) · \(myaL11.fastDropSummary)")
            MetricRow(title: "kAI (Bu Mac)", value: localMac.summary)

            HStack(spacing: 8) {
                Button {
                    myaL11.openScreen()
                } label: {
                    Label("Ekran", systemImage: "rectangle.on.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    myaL11.openDisk()
                } label: {
                    Label("Disk", systemImage: "externaldrive")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("MYA-L11 Detayları →") {
                    selectedTab = .myaL11
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var opportunitiesSummaryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Fırsat İstihbaratı", systemImage: "sparkles.rectangle.stack.fill")
                    .font(.headline)
                    .foregroundStyle(.orange)
                Spacer()
                StatusPill(
                    online: opportunity.fabricReady || !opportunity.opportunities.isEmpty,
                    onlineText: "\(opportunity.opportunities.count) fırsat",
                    offlineText: "Bekleniyor"
                )
            }

            ForEach(Array(opportunity.opportunities.prefix(4))) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(item.score)")
                        .font(.caption.monospacedDigit().weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.orange.opacity(0.2), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(item.problem)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(6)
                .background(.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                Button {
                    Task { await opportunity.refresh() }
                } label: {
                    Label("Yenile", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    Task { await opportunity.openDashboard() }
                } label: {
                    Label("Web Paneli", systemImage: "safari")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Tüm Fırsatları Aç →") {
                    selectedTab = .opportunities
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var broadcastAndMailCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Yayın Merkezi & E-Posta", systemImage: "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .foregroundStyle(.pink)
                Spacer()
                StatusPill(
                    online: (mail.data?.accounts.count ?? 0) > 0,
                    onlineText: "\(mail.data?.accounts.count ?? 0) Mail Hesabı",
                    offlineText: "Mail Kontrol"
                )
            }

            MetricRow(title: "Seçili E-Posta", value: mail.selectedAddress)
            MetricRow(title: "Mail Sunucusu", value: mail.data?.server.imap.host ?? "MYA-L11 Stalwart")

            HStack {
                Button("Yayın Merkezi →") {
                    selectedTab = .broadcast
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    myaL11.openWebmail()
                } label: {
                    Label("Webmail", systemImage: "envelope.fill")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Button("Mail & Operasyon →") {
                    selectedTab = .operations
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var deckQuickCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("M3 Deck & Vaytniga Kumanda", systemImage: "square.grid.3x2.fill")
                    .font(.headline)
                    .foregroundStyle(.teal)
                Spacer()
                Button("Vaytniga & Deck →") {
                    selectedTab = .node
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            MetricRow(title: "Vaytniga Sağlık", value: node.healthSummary)
            MetricRow(title: "Konum & Ayrılma", value: separation.statusLabel)

            HStack(spacing: 8) {
                Button {
                    Task { await node.openLiveScreen() }
                } label: {
                    Label("Vaytniga Canlı Ekran", systemImage: "iphone.gen3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .controlSize(.small)

                Button {
                    selectedTab = .node
                } label: {
                    Label("15 Deck Tuşu", systemImage: "square.grid.3x2")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(14)
        .background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func remoteBtn(_ title: String, key: String, icon: String) -> some View {
        Button {
            Task { await smartHome.sendTVKey(key) }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption2.weight(.medium))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func systemBadge(_ name: String, online: Bool, detail: String) -> some View {
        HStack(spacing: 5) {
            Circle()
                .fill(online ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
            Text(name)
                .font(.caption2.weight(.bold))
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(.quaternary.opacity(0.45), in: Capsule())
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
    @EnvironmentObject private var opportunity: OpportunityMonitor
    @EnvironmentObject private var broadcast: BroadcastMonitor
    @EnvironmentObject private var smartHome: SmartHomeMonitor
    @EnvironmentObject private var study: UniversityStudyMonitor
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
                    Text("Cihaz & Ev Komuta Merkezi")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    smartHome.openCommandCenterWindow?()
                } label: {
                    Label("Tam Ekran Panel", systemImage: "macwindow")
                        .font(.caption2.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .controlSize(.mini)

                Text("\([relay.isConnected, myaL11.isOnline, node.isOnline, smartHome.hueOnline].filter { $0 }.count)/4 bağlı")
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
                case .smartHome:
                    SmartHomeView()
                case .study:
                    UniversityStudyPopoverView()
                case .operations:
                    OperationsView()
                case .opportunities:
                    OpportunityView()
                case .broadcast:
                    BroadcastView()
                case .lolile:
                    ScrollView {
                        RelayMenuView()
                    }
                    .frame(maxHeight: 690)
                case .myaL11:
                    MYAL11MenuView()
                case .node:
                    NodeMenuView()
                case .deck:
                    DeckManagerView()
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
    private let opportunity = OpportunityMonitor()
    private let broadcast = BroadcastMonitor()
    private let smartHome = SmartHomeMonitor()
    private let study = UniversityStudyMonitor()

    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var commandCenterWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        smartHome.openCommandCenterWindow = { [weak self] in
            self?.openCommandCenterWindow()
        }

        let rootView = DAAKDevicesMenuView()
            .environmentObject(relay)
            .environmentObject(node)
            .environmentObject(myaL11)
            .environmentObject(separation)
            .environmentObject(mail)
            .environmentObject(updater)
            .environmentObject(localMac)
            .environmentObject(opportunity)
            .environmentObject(broadcast)
            .environmentObject(smartHome)
            .environmentObject(study)

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 460, height: 720)
        popover.contentViewController = NSHostingController(rootView: rootView)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "DAAK NODE · Sol tık: hızlı menü · Sağ tık: Komuta Merkezi"
            button.setAccessibilityLabel("DAAK NODE cihaz merkezi")
        }
        updateStatusIcon()

        myaL11.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusIcon() }
            .store(in: &subscriptions)

        if CommandLine.arguments.contains("--command-center") ||
            !UserDefaults.standard.bool(forKey: "daak.commandCenterShown.v1") {
            UserDefaults.standard.set(true, forKey: "daak.commandCenterShown.v1")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                self?.openCommandCenterWindow()
            }
        }
    }

    func openCommandCenterWindow() {
        if popover.isShown {
            popover.performClose(nil)
        }

        if let window = commandCenterWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let commandCenterView = DAAKCommandCenterView()
            .environmentObject(relay)
            .environmentObject(node)
            .environmentObject(myaL11)
            .environmentObject(separation)
            .environmentObject(mail)
            .environmentObject(updater)
            .environmentObject(localMac)
            .environmentObject(opportunity)
            .environmentObject(broadcast)
            .environmentObject(smartHome)
            .environmentObject(study)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1240, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "DAAK KOMUTA MERKEZİ"
        window.subtitle = "Akıllı Ev · Hue · TCL 4K TV · Vaytniga · LOLİLE · MYA-L11 · Fırsat İstihbaratı"
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.fullScreenPrimary, .managed]
        window.minSize = NSSize(width: 1080, height: 720)
        window.contentViewController = NSHostingController(rootView: commandCenterView)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        commandCenterWindow = window
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            openCommandCenterWindow()
            return
        }

        if popover.isShown {
            popover.performClose(sender)
            return
        }

        // The sync agent writes this tiny local JSON independently of the UI.
        // Reload it before drawing so power changes never wait for the timer.
        myaL11.reloadCachedTelemetry()
        Task {
            await myaL11.refresh()
            await smartHome.refresh()
        }

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
