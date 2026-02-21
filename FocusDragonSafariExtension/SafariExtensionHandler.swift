import SafariServices

final class SafariExtensionHandler: SFSafariExtensionHandler {
    private let appGroupID = "group.com.focusdragon.shared"
    private let blockedDomainsKey = "blockedDomains"
    private let isBlockingKey = "isBlocking"
    private let urlExceptionsKey = "urlExceptions"
    private let heartbeatKey = "safariExtensionHeartbeat"
    private let heartbeatInterval: TimeInterval = 2.0

    private var blockedDomains: Set<String> = []
    private var isBlocking: Bool = false
    private struct LocalURLException: Codable {
        let domain: String
        let allowedPaths: [String]
    }

    private var urlExceptions: [LocalURLException] = []
    private var heartbeatTimer: Timer?

    override init() {
        super.init()
        loadBlockedDomains()
        startHeartbeat()
    }

    deinit {
        heartbeatTimer?.invalidate()
    }

    private func loadBlockedDomains() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else {
            blockedDomains = []
            isBlocking = false
            return
        }

        let domains = sharedDefaults.array(forKey: blockedDomainsKey) as? [String] ?? []
        isBlocking = sharedDefaults.bool(forKey: isBlockingKey)
        blockedDomains = Set(domains.map { $0.lowercased() })

        if let data = sharedDefaults.data(forKey: urlExceptionsKey),
           let decoded = try? JSONDecoder().decode([LocalURLException].self, from: data) {
            urlExceptions = decoded
        } else {
            urlExceptions = []
        }
    }

    override func validateToolbarItem(
        in window: SFSafariWindow,
        validationHandler: @escaping ((Bool, String) -> Void)
    ) {
        validationHandler(true, "")
    }

    override func popoverViewController() -> SFSafariExtensionViewController {
        SafariExtensionViewController.shared
    }

    override func page(
        _ page: SFSafariPage,
        willNavigateTo url: URL?
    ) {
        guard let url = url,
              let host = url.host?.lowercased() else {
            return
        }

        loadBlockedDomains()
        recordHeartbeat()

        guard isBlocking, !blockedDomains.isEmpty else { return }

        if isIPAddress(host) {
            page.getContainingTab { tab in
                tab.navigate(to: self.blockedPageURL())
            }
            return
        }

        if shouldBlockDomain(host) {
            if isAllowedByException(host: host, path: url.path) {
                return
            }
            page.getContainingTab { tab in
                tab.navigate(to: self.blockedPageURL())
            }
        }
    }

    private func shouldBlockDomain(_ host: String) -> Bool {
        if blockedDomains.contains(host) { return true }

        if host.hasPrefix("www.") {
            let withoutWWW = String(host.dropFirst(4))
            if blockedDomains.contains(withoutWWW) { return true }
        }

        for domain in blockedDomains {
            if host == domain { return true }
            if host.hasSuffix("." + domain) { return true }
        }

        return false
    }

    private func isAllowedByException(host: String, path: String) -> Bool {
        guard !urlExceptions.isEmpty else { return false }

        for exception in urlExceptions {
            let domain = exception.domain.lowercased()

            let hostMatches =
                host == domain ||
                host == "www.\(domain)" ||
                host.hasSuffix("." + domain)

            if !hostMatches { continue }

            for rawPath in exception.allowedPaths {
                let normalized = rawPath.hasPrefix("/") ? rawPath : "/" + rawPath
                if path.hasPrefix(normalized) {
                    return true
                }
            }
        }

        return false
    }

    private func isIPAddress(_ host: String) -> Bool {
        let pattern = "^\\d{1,3}(\\.\\d{1,3}){3}$"
        return host.range(of: pattern, options: .regularExpression) != nil
    }

    private func blockedPageURL() -> URL {
        guard let url = Bundle.main.url(forResource: "blocked", withExtension: "html") else {
            return URL(string: "about:blank")!
        }
        return url
    }

    private func startHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: heartbeatInterval, repeats: true) { [weak self] _ in
            self?.recordHeartbeat()
        }
        if let timer = heartbeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
        recordHeartbeat()
    }

    private func recordHeartbeat() {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupID) else { return }
        sharedDefaults.set(Date().timeIntervalSince1970, forKey: heartbeatKey)
    }
}
