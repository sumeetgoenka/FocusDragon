import Foundation

class BootDetector {
    static let shared = BootDetector()

    private init() {}

    func getBootTime() -> Date? {
        var mib = [CTL_KERN, KERN_BOOTTIME]
        var bootTime = timeval()
        var size = MemoryLayout<timeval>.stride

        let result = sysctl(&mib, UInt32(mib.count), &bootTime, &size, nil, 0)

        guard result == 0 else {
            return nil
        }

        let timeInterval = Double(bootTime.tv_sec) + Double(bootTime.tv_usec) / 1_000_000.0
        return Date(timeIntervalSince1970: timeInterval)
    }

    func getUptime() -> TimeInterval? {
        guard let bootTime = getBootTime() else {
            return nil
        }

        return Date().timeIntervalSince(bootTime)
    }

    func didRebootSince(_ date: Date) -> Bool {
        guard let bootTime = getBootTime() else {
            return false
        }

        return bootTime > date
    }
}
