//
//  InternetBlocker.swift
//  FocusDragonDaemon
//
//  Blocks all outbound internet traffic using PF, with a domain whitelist.
//  This is best-effort and requires PF to be enabled on the system.
//

import Foundation
import SystemConfiguration

final class InternetBlocker {
    private let pfConfPath = "/etc/pf.conf"
    private let anchorPath = "/etc/pf.anchors/focusdragon"
    private let markerStart = "# FocusDragon PF Start"
    private let markerEnd = "# FocusDragon PF End"
    private let anchorName = "focusdragon"
    private let whitelistTable = "fd_whitelist"

    private var isActive = false
    private var lastSignature: String?

    func update(config: InternetBlockConfig?, isBlocking: Bool) {
        let enabled = (config?.isEnabled ?? false) && isBlocking
        if !enabled {
            disable()
            return
        }

        let domains = (config?.whitelistDomains ?? [])
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
            .sorted()

        let signature = domains.joined(separator: ",")
        if isActive, signature == lastSignature {
            return
        }

        apply(whitelistDomains: domains)
        lastSignature = signature
    }

    private func apply(whitelistDomains: [String]) {
        ensureAnchorInPfConf()

        let ips = resolveDomains(whitelistDomains)
        writeAnchorFile(whitelistIPs: ips)

        reloadPf()
        isActive = true
    }

    private func disable() {
        guard isActive else { return }
        flushAnchor()
        isActive = false
        lastSignature = nil
    }

    private func ensureAnchorInPfConf() {
        guard let content = try? String(contentsOfFile: pfConfPath, encoding: .utf8) else {
            return
        }

        if content.contains(markerStart) && content.contains(markerEnd) {
            return
        }

        let anchorLines = """
\n\(markerStart)
anchor \"\(anchorName)\"
load anchor \"\(anchorName)\" from \"\(anchorPath)\"
\(markerEnd)
"""

        let backupPath = pfConfPath + ".focusdragon.bak"
        if !FileManager.default.fileExists(atPath: backupPath) {
            try? content.write(toFile: backupPath, atomically: true, encoding: .utf8)
        }

        let updated = content + anchorLines
        try? updated.write(toFile: pfConfPath, atomically: true, encoding: .utf8)
    }

    private func writeAnchorFile(whitelistIPs: [String]) {
        var rules: [String] = []
        rules.append("# FocusDragon internet blocking")
        rules.append("set block-policy drop")
        rules.append("table <\(whitelistTable)> persist { \(whitelistIPs.joined(separator: ", ")) }")
        rules.append("pass out on lo0 all")
        rules.append("pass out to { 127.0.0.1, ::1 }")
        rules.append("pass out to { 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 }")
        rules.append("pass out to <\(whitelistTable)>")
        rules.append("block out all")

        let content = rules.joined(separator: "\n") + "\n"
        try? content.write(toFile: anchorPath, atomically: true, encoding: .utf8)
    }

    private func reloadPf() {
        _ = runTask("/sbin/pfctl", ["-f", pfConfPath])
        _ = runTask("/sbin/pfctl", ["-E"])
    }

    private func flushAnchor() {
        _ = runTask("/sbin/pfctl", ["-a", anchorName, "-F", "all"])
    }

    private func resolveDomains(_ domains: [String]) -> [String] {
        var results: Set<String> = []
        for domain in domains {
            for ip in resolveDomain(domain) {
                results.insert(ip)
            }
        }
        return Array(results).sorted()
    }

    private func resolveDomain(_ domain: String) -> [String] {
        var results: [String] = []
        var hints = addrinfo(
            ai_flags: AI_DEFAULT,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(domain, nil, &hints, &res)
        guard status == 0, let first = res else {
            return results
        }

        var ptr: UnsafeMutablePointer<addrinfo>? = first
        while let info = ptr {
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let result = getnameinfo(info.pointee.ai_addr, socklen_t(info.pointee.ai_addrlen),
                                     &host, socklen_t(host.count),
                                     nil, 0, NI_NUMERICHOST)
            if result == 0 {
                results.append(String(cString: host))
            }
            ptr = info.pointee.ai_next
        }

        freeaddrinfo(first)
        return results
    }

    private func runTask(_ path: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardOutput = Pipe()
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return -1
        }

        task.waitUntilExit()
        return task.terminationStatus
    }
}
