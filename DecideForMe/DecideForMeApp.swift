//
//  DecideForMeApp.swift
//  DecideForMe
//

import SwiftUI
import UIKit

@main
struct DecideForMeApp: App {
    init() {
        if let url = URL(string: "https://smolkapps.com/api/versions/decide-for-me.json") {
            VersionEnforcer.shared.configure(policyURL: url)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .enforceAppVersion()
        }
    }
}

// MARK: - Startup Version Enforcement

public struct VersionPolicy: Codable, Equatable {
    public let minSupportedVersion: String
    public let latestVersion: String
    public let blockedVersions: [String]?
    public let maintenanceMode: Bool?
    public let maintenanceTitle: String?
    public let maintenanceMessage: String?
    public let storeUrlIos: String?
    public let storeUrlFallback: String?
    public let hardUpdateTitle: String?
    public let hardUpdateMessage: String?
    public let softUpdateTitle: String?
    public let softUpdateMessage: String?

    enum CodingKeys: String, CodingKey {
        case minSupportedVersion = "min_supported_version"
        case latestVersion = "latest_version"
        case blockedVersions = "blocked_versions"
        case maintenanceMode = "maintenance_mode"
        case maintenanceTitle = "maintenance_title"
        case maintenanceMessage = "maintenance_message"
        case storeUrlIos = "store_url_ios"
        case storeUrlFallback = "store_url_fallback"
        case hardUpdateTitle = "hard_update_title"
        case hardUpdateMessage = "hard_update_message"
        case softUpdateTitle = "soft_update_title"
        case softUpdateMessage = "soft_update_message"
    }
}

public enum EnforcementAction: Equatable {
    case none
    case maintenance(title: String, message: String)
    case hardUpdate(title: String, message: String, url: URL)
    case softUpdate(title: String, message: String, url: URL, version: String)
}

@MainActor
public final class VersionEnforcer: ObservableObject {
    public static let shared = VersionEnforcer()

    @Published public private(set) var activeAction: EnforcementAction = .none

    private var policyURL: URL?
    private var lastCheckTime: Date?
    private let throttleInterval: TimeInterval = 900
    private var dismissedSoftVersion: String?
    private let fallbackStoreURL = URL(string: "https://apps.apple.com/app/id6785593979")!
    private var foregroundObserver: NSObjectProtocol?

    public init() {
        foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.checkForUpdates(force: false)
            }
        }
    }

    deinit {
        if let foregroundObserver {
            NotificationCenter.default.removeObserver(foregroundObserver)
        }
    }

    public func configure(policyURL: URL) {
        self.policyURL = policyURL
        Task { [weak self] in
            await self?.checkForUpdates(force: true)
        }
    }

    public func checkForUpdates(force: Bool = false) async {
        guard NSClassFromString("XCTestCase") == nil,
              !CommandLine.arguments.contains(where: { $0.lowercased() == "-uitesting" }),
              let url = policyURL else { return }
        if !force, let last = lastCheckTime, Date().timeIntervalSince(last) < throttleInterval {
            return
        }
        lastCheckTime = Date()

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 3.0)
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return }
            let policy = try JSONDecoder().decode(VersionPolicy.self, from: data)
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
            activeAction = evaluate(policy: policy, currentVersion: current)
        } catch {
            // Fail-open when offline or timed out.
        }
    }

    public func evaluate(policy: VersionPolicy, currentVersion: String) -> EnforcementAction {
        if policy.maintenanceMode == true {
            return .maintenance(
                title: policy.maintenanceTitle ?? "Scheduled Maintenance",
                message: policy.maintenanceMessage ?? "Decide For Me is undergoing scheduled maintenance."
            )
        }

        let targetURL = URL(string: policy.storeUrlIos ?? "")
            ?? URL(string: policy.storeUrlFallback ?? "")
            ?? fallbackStoreURL

        if let blocked = policy.blockedVersions, blocked.contains(currentVersion) {
            return .hardUpdate(
                title: policy.hardUpdateTitle ?? "Update Required",
                message: policy.hardUpdateMessage ?? "This version of Decide For Me is no longer supported. Please update to continue.",
                url: targetURL
            )
        }

        if compareSemVer(currentVersion, policy.minSupportedVersion) == .orderedAscending {
            return .hardUpdate(
                title: policy.hardUpdateTitle ?? "Update Required",
                message: policy.hardUpdateMessage ?? "A newer version of Decide For Me is required to continue.",
                url: targetURL
            )
        }

        if compareSemVer(currentVersion, policy.latestVersion) == .orderedAscending,
           dismissedSoftVersion != policy.latestVersion {
            return .softUpdate(
                title: policy.softUpdateTitle ?? "New Version Available",
                message: policy.softUpdateMessage ?? "A newer version of Decide For Me (\(policy.latestVersion)) is available.",
                url: targetURL,
                version: policy.latestVersion
            )
        }

        return .none
    }

    public func dismissSoftUpdate() {
        if case .softUpdate(_, _, _, let version) = activeAction {
            dismissedSoftVersion = version
        }
        activeAction = .none
    }

    public func compareSemVer(_ v1: String, _ v2: String) -> ComparisonResult {
        let trim = CharacterSet(charactersIn: "vV ")
        let p1 = v1.trimmingCharacters(in: trim).split(separator: ".").compactMap { Int($0) }
        let p2 = v2.trimmingCharacters(in: trim).split(separator: ".").compactMap { Int($0) }
        let maxCount = max(p1.count, p2.count)
        for i in 0..<maxCount {
            let a = i < p1.count ? p1[i] : 0
            let b = i < p2.count ? p2[i] : 0
            if a < b { return .orderedAscending }
            if a > b { return .orderedDescending }
        }
        return .orderedSame
    }
}

public struct VersionEnforcementModifier: ViewModifier {
    @ObservedObject var enforcer = VersionEnforcer.shared

    public func body(content: Content) -> some View {
        ZStack {
            content
                .allowsHitTesting(!isBlocking)

            switch enforcer.activeAction {
            case .hardUpdate(let title, let message, let url):
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(.blue)
                        Text(title)
                            .font(.title2.bold())
                        Text(message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                        Button {
                            UIApplication.shared.open(url)
                        } label: {
                            Text("Update Now")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(.blue, in: RoundedRectangle(cornerRadius: 14))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 36)
                    }
                }
                .zIndex(100)
            case .maintenance(let title, let message):
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.orange)
                        Text(title)
                            .font(.title2.bold())
                        Text(message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                    }
                }
                .zIndex(100)
            case .softUpdate, .none:
                EmptyView()
            }
        }
        .alert(
            softTitle,
            isPresented: Binding(
                get: { if case .softUpdate = enforcer.activeAction { return true }; return false },
                set: { if !$0 { enforcer.dismissSoftUpdate() } }
            ),
            actions: {
                if case .softUpdate(_, _, let url, _) = enforcer.activeAction {
                    Button("Update") {
                        UIApplication.shared.open(url)
                        enforcer.dismissSoftUpdate()
                    }
                    Button("Not Now", role: .cancel) {
                        enforcer.dismissSoftUpdate()
                    }
                }
            },
            message: {
                Text(softMessage)
            }
        )
    }

    private var isBlocking: Bool {
        switch enforcer.activeAction {
        case .hardUpdate, .maintenance: return true
        case .softUpdate, .none: return false
        }
    }

    private var softTitle: String {
        if case .softUpdate(let t, _, _, _) = enforcer.activeAction { return t }
        return ""
    }

    private var softMessage: String {
        if case .softUpdate(_, let m, _, _) = enforcer.activeAction { return m }
        return ""
    }
}

public extension View {
    func enforceAppVersion() -> some View {
        modifier(VersionEnforcementModifier())
    }
}
