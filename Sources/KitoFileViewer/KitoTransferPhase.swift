//
//  KitoTransferPhase.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Where a download or upload is.
public enum KitoTransferPhase: Hashable, Sendable {
    /// Queued, not started.
    case waiting
    /// Moving bytes.
    case running
    /// Stopped by the user; can resume.
    case paused
    /// Finished successfully.
    case completed
    /// Stopped by an error; can retry.
    case failed(String)
    /// Stopped by the user for good.
    case cancelled

    /// Whether the transfer can still move forward (waiting, running or paused).
    public var isActive: Bool {
        switch self {
        case .waiting, .running, .paused: true
        default: false
        }
    }

    /// Whether the transfer is over (completed, failed or cancelled).
    public var isFinished: Bool { !isActive }

    /// The failure message, if it failed.
    public var failureMessage: String? {
        if case let .failed(message) = self { return message }
        return nil
    }

    /// Applies an event and returns the new phase, or `nil` if the event makes no sense now
    /// (for example pausing something that already finished).
    public func applying(_ event: KitoTransferEvent) -> KitoTransferPhase? {
        switch (self, event) {
        case (.waiting, .start), (.paused, .resume):
            return .running
        case (.running, .progress):
            return .running
        case (.waiting, .pause), (.running, .pause):
            return .paused
        case (.running, .complete):
            return .completed
        case (.waiting, .fail(let message)), (.running, .fail(let message)), (.paused, .fail(let message)):
            return .failed(message)
        case (.waiting, .cancel), (.running, .cancel), (.paused, .cancel), (.failed, .cancel):
            return .cancelled
        case (.failed, .retry), (.cancelled, .retry):
            return .waiting
        default:
            return nil
        }
    }
}

/// Something that happens to a transfer.
public enum KitoTransferEvent: Hashable, Sendable {
    case start, progress, pause, resume, complete, cancel, retry
    case fail(String)
}

/// Which way the bytes go.
public enum KitoTransferDirection: String, Hashable, Sendable {
    case download, upload

    public var systemImage: String {
        self == .download ? "arrow.down" : "arrow.up"
    }
}

/// Smooths the speed of a transfer so the numbers don't jitter, and estimates the time left.
///
/// ```swift
/// var rate = KitoTransferRate()
/// rate.record(totalBytes: 1_200_000, at: 1.0)
/// rate.record(totalBytes: 2_600_000, at: 2.0)
/// rate.bytesPerSecond                // smoothed
/// rate.secondsLeft(remaining: 8_000_000)
/// ```
public struct KitoTransferRate: Hashable, Sendable {
    /// How much each new sample counts, 0…1. Lower is smoother but slower to react.
    public var smoothing: Double
    /// Samples closer together than this are merged, so tiny intervals don't spike the speed.
    public var minimumInterval: TimeInterval
    /// The smoothed speed, or `nil` before there is enough data.
    public private(set) var bytesPerSecond: Double?

    private var lastBytes: Int64?
    private var lastTime: TimeInterval?

    public init(smoothing: Double = 0.3, minimumInterval: TimeInterval = 0.25) {
        self.smoothing = min(max(smoothing, 0.01), 1)
        self.minimumInterval = max(minimumInterval, 0)
    }

    /// Records how many bytes have moved in total at a moment in seconds (any fixed clock).
    public mutating func record(totalBytes: Int64, at time: TimeInterval) {
        guard let lastBytes, let lastTime else {
            self.lastBytes = totalBytes
            self.lastTime = time
            return
        }
        let elapsed = time - lastTime
        guard elapsed >= minimumInterval, elapsed > 0 else { return }
        let instant = Double(max(totalBytes - lastBytes, 0)) / elapsed
        if let current = bytesPerSecond {
            bytesPerSecond = current + smoothing * (instant - current)
        } else {
            bytesPerSecond = instant
        }
        self.lastBytes = totalBytes
        self.lastTime = time
    }

    /// Forgets the history, e.g. after a pause, so the first sample after resuming isn't skewed.
    public mutating func reset(keepingSpeed: Bool = false) {
        lastBytes = nil
        lastTime = nil
        if !keepingSpeed { bytesPerSecond = nil }
    }

    /// Estimated seconds until `remaining` bytes have moved, or `nil` if the speed is unknown or zero.
    public func secondsLeft(remaining: Int64) -> TimeInterval? {
        guard let speed = bytesPerSecond, speed > 0 else { return nil }
        return Double(max(remaining, 0)) / speed
    }
}
