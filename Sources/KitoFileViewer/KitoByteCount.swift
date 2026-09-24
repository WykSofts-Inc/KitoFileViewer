//
//  KitoByteCount.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Byte counts and durations as short, predictable text: "240 KB", "2.4 MB", "1.3 MB/s", "12 s left".
///
/// Uses decimal units (1 KB = 1,000 bytes) like Files and Finder. Values under ten keep one decimal;
/// larger values are whole numbers, and a trailing ".0" is dropped.
public enum KitoByteCount {
    private static let units = ["KB", "MB", "GB", "TB", "PB"]

    /// "0 bytes", "1 byte", "512 bytes", "240 KB", "2.4 MB", "12 GB".
    public static func string(_ bytes: Int64) -> String {
        let value = max(bytes, 0)
        if value < 1_000 { return value == 1 ? "1 byte" : "\(value) bytes" }
        var amount = Double(value) / 1_000
        var index = 0
        while rounded(amount) >= 1_000, index < units.count - 1 {
            amount /= 1_000
            index += 1
        }
        return "\(number(amount)) \(units[index])"
    }

    /// A transfer rate: "820 KB/s", "1.3 MB/s". Negative or zero shows "0 KB/s".
    public static func rate(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond >= 1_000 else {
            return bytesPerSecond >= 1 ? "\(Int(bytesPerSecond)) B/s" : "0 KB/s"
        }
        return string(Int64(bytesPerSecond)) + "/s"
    }

    /// Progress text: "4.2 MB of 18 MB". Without a total: "4.2 MB".
    public static func progress(_ completed: Int64, of total: Int64?) -> String {
        guard let total, total > 0 else { return string(completed) }
        return "\(string(completed)) of \(string(total))"
    }

    /// Time remaining: "Almost done", "12 s left", "3 min left", "1 h 5 min left".
    public static func timeLeft(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "" }
        if seconds < 1 { return "Almost done" }
        let whole = Int(seconds.rounded(.up))
        if whole < 60 { return "\(whole) s left" }
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(minutes) min left" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours) h left" : "\(hours) h \(rest) min left"
    }

    private static func rounded(_ amount: Double) -> Double {
        amount < 10 ? (amount * 10).rounded() / 10 : amount.rounded()
    }

    private static func number(_ amount: Double) -> String {
        let value = rounded(amount)
        if value < 10, value != value.rounded() {
            return String(format: "%.1f", value)
        }
        return String(Int(value))
    }
}
