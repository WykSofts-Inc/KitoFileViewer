//
//  KitoTransfer.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import Observation

/// One download or upload, observed by `KitoDownloadRow`. Create them with `KitoTransferModel`.
@Observable
@MainActor
public final class KitoTransfer: Identifiable {
    public nonisolated let id: UUID
    public let name: String
    public let kind: KitoFileKind
    public let direction: KitoTransferDirection
    /// The size, once known.
    public internal(set) var totalBytes: Int64?
    public internal(set) var completedBytes: Int64 = 0
    public internal(set) var phase: KitoTransferPhase = .waiting
    /// Smoothed speed, while running.
    public internal(set) var bytesPerSecond: Double?
    /// Estimated time left, while running.
    public internal(set) var secondsLeft: TimeInterval?
    /// Where a finished download was saved, or the file being uploaded.
    public internal(set) var fileURL: URL?

    @ObservationIgnored var rate = KitoTransferRate()
    @ObservationIgnored let source: Source
    @ObservationIgnored var resumeData: Data?
    @ObservationIgnored var task: URLSessionTask?
    @ObservationIgnored var simulation: Task<Void, Never>?
    @ObservationIgnored var simulatedFailure: Double?

    enum Source {
        case download(URL)
        case upload(URLRequest, URL)
        case simulated(speed: Double)
    }

    init(name: String, kind: KitoFileKind? = nil, direction: KitoTransferDirection, totalBytes: Int64?,
         source: Source, fileURL: URL? = nil) {
        self.id = UUID()
        self.name = name
        self.kind = kind ?? KitoFileKind.detect(fileName: name)
        self.direction = direction
        self.totalBytes = totalBytes
        self.source = source
        self.fileURL = fileURL
    }

    var isSimulated: Bool {
        if case .simulated = source { return true }
        return false
    }

    /// 0…1, or `nil` while the size is unknown.
    public var fraction: Double? {
        guard let totalBytes, totalBytes > 0 else { return phase == .completed ? 1 : nil }
        return min(max(Double(completedBytes) / Double(totalBytes), 0), 1)
    }

    /// "4.2 MB of 18 MB · 1.3 MB/s · 12 s left", "Paused · 4.2 MB of 18 MB", "Failed: No connection".
    public var statusText: String {
        let progress = KitoByteCount.progress(completedBytes, of: totalBytes)
        switch phase {
        case .waiting:
            return "Waiting…"
        case .running:
            var parts = [progress]
            if let bytesPerSecond { parts.append(KitoByteCount.rate(bytesPerSecond)) }
            if let secondsLeft { parts.append(KitoByteCount.timeLeft(secondsLeft)) }
            return parts.joined(separator: " · ")
        case .paused:
            return "Paused · \(progress)"
        case .completed:
            let size = KitoByteCount.string(totalBytes ?? completedBytes)
            return direction == .download ? "Downloaded · \(size)" : "Uploaded · \(size)"
        case let .failed(message):
            return "Failed · \(message)"
        case .cancelled:
            return "Cancelled"
        }
    }

    /// A shorter status for accessibility and compact rows.
    public var shortStatus: String {
        switch phase {
        case .waiting: "Waiting"
        case .running: fraction.map { "\(Int(($0 * 100).rounded()))%" } ?? "In progress"
        case .paused: "Paused"
        case .completed: direction == .download ? "Downloaded" : "Uploaded"
        case .failed: "Failed"
        case .cancelled: "Cancelled"
        }
    }

    /// The finished file as an item, for previewing or sharing.
    public var fileItem: KitoFileItem? {
        guard phase == .completed, let fileURL else { return nil }
        return KitoFileItem(contentsOf: fileURL)
    }

    @discardableResult
    func apply(_ event: KitoTransferEvent) -> Bool {
        guard let next = phase.applying(event) else { return false }
        phase = next
        if !next.isActive || next == .paused {
            bytesPerSecond = nil
            secondsLeft = nil
            rate.reset(keepingSpeed: next == .paused)
        }
        return true
    }

    func record(completed: Int64, total: Int64?, at time: TimeInterval) {
        if let total, total > 0 { totalBytes = total }
        completedBytes = completed
        rate.record(totalBytes: completed, at: time)
        bytesPerSecond = rate.bytesPerSecond
        let remaining = (totalBytes ?? 0) - completed
        secondsLeft = totalBytes == nil ? nil : rate.secondsLeft(remaining: remaining)
    }
}
