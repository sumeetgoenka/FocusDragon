//
//  Helpers.swift
//  FocusDragon
//
//  Created by Anay Goenka on 17/02/2026.
//

import Foundation

/// Collection of utility functions and extensions

// MARK: - String Extensions

extension String {
    /// Validates if a string is a valid domain or URL
    var isValidDomain: Bool {
        let pattern = "^([a-zA-Z0-9]([a-zA-Z0-9\\-]{0,61}[a-zA-Z0-9])?\\.)+[a-zA-Z]{2,}$"
        return self.range(of: pattern, options: .regularExpression) != nil
    }
    
    /// Cleans a URL to extract just the domain
    var cleanDomain: String {
        var cleaned = self.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "https://", with: "")
        cleaned = cleaned.replacingOccurrences(of: "http://", with: "")
        cleaned = cleaned.replacingOccurrences(of: "www.", with: "")
        if let slashIndex = cleaned.firstIndex(of: "/") {
            cleaned = String(cleaned[..<slashIndex])
        }
        return cleaned
    }
}

// MARK: - Date Extensions

extension Date {
    /// Returns a formatted string for display
    var formattedForDisplay: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - Error Types

enum FocusDragonError: LocalizedError {
    case permissionDenied
    case invalidDomain
    case hostsFileNotAccessible
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Permission denied. Administrator privileges required."
        case .invalidDomain:
            return "Invalid domain or URL format."
        case .hostsFileNotAccessible:
            return "Cannot access the hosts file."
        case .unknown(let error):
            return "An error occurred: \(error.localizedDescription)"
        }
    }
}
