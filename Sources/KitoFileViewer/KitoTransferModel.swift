//
//  KitoTransferModel.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import Observation

/// Runs downloads and uploads and keeps their progress, speed and time left up to date for
/// `KitoTransferList` and `KitoDownloadRow`. It can drive real `URLSession` tasks, or simulate a
/// transfer for demos and previews.
///
/// ```swift
/// @State private var transfers = KitoTransferModel()
///
/// transfers.download(URL(string: "https://example.com/report.pdf")!)
/// transfers.upload(fileURL, to: URLRequest(url: uploadURL))
/// transfers.simulate(name: "Site plan.pdf", size: 18_400_000, duration: 8)
///
/// KitoTransferList(model: transfers)
/// ```
///
/// Downloads are saved to `destination` (Caches/KitoDownloads by default). Pausing a download keeps
/// its resume data so it continues where it stopped when the server supports it.
@Observable
@MainActor
public final class KitoTransferModel {
    public private(set) var transfers: [KitoTransfer] = []
    /// Where finished downloads are saved.
    public let destination: URL
    /// Called when a transfer finishes successfully.
    @ObservationIgnored public var onComplete: ((KitoTransfer) -> Void)?

    @ObservationIgnored private let configuration: URLSessionConfiguration
    @ObservationIgnored private var sessionStore: URLSession?
    @ObservationIgnored private var bridge: KitoURLSessionBridge?
    @ObservationIgnored private var taskOwners: [Int: UUID] = [:]

    public init(destination: URL? = nil, configuration: URLSessionConfiguration = .default) {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.destination = destination ?? caches.appendingPathComponent("KitoDownloads", isDirectory: true)
        self.configuration = configuration
    }

    // MARK: Summary

    /// Transfers that are waiting, running or paused.
    public var activeCount: Int { transfers.filter { $0.phase.isActive }.count }

    /// Progress across everything that's active, 0…1.
    public var overallFraction: Double {
        let active = transfers.filter { $0.phase.isActive }
        let total = active.reduce(Int64(0)) { $0 + ($1.totalBytes ?? 0) }
        guard total > 0 else { return 0 }
        let done = active.reduce(Int64(0)) { $0 + $1.completedBytes }
        return min(Double(done) / Double(total), 1)
    }

    // MARK: Starting

    /// Downloads a file with `URLSession`.
    @discardableResult
    public func download(_ url: URL, name: String? = nil, expectedSize: Int64? = nil) -> KitoTransfer {
        let transfer = KitoTransfer(name: name ?? url.lastPathComponent, direction: .download,
                                    totalBytes: expectedSize, source: .download(url))
        transfers.insert(transfer, at: 0)
        start(transfer)
        return transfer
    }

    /// Uploads a local file with `URLSession`.
    @discardableResult
    public func upload(_ fileURL: URL, to request: URLRequest, name: String? = nil) -> KitoTransfer {
        let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init)
        let transfer = KitoTransfer(name: name ?? fileURL.lastPathComponent, direction: .upload, totalBytes: size,
                                    source: .upload(request, fileURL), fileURL: fileURL)
        transfers.insert(transfer, at: 0)
        start(transfer)
        return transfer
    }

    /// A pretend transfer that moves `size` bytes in about `duration` seconds, with a realistic,
    /// uneven speed. Set `failsAt` (0…1) to fail part-way; retrying it then succeeds.
    @discardableResult
    public func simulate(name: String, size: Int64, direction: KitoTransferDirection = .download,
                         duration: TimeInterval = 6, failsAt: Double? = nil, startsPaused: Bool = false,
                         fileURL: URL? = nil) -> KitoTransfer {
        let speed = Double(size) / max(duration, 0.5)
        let transfer = KitoTransfer(name: name, direction: direction, totalBytes: size,
                                    source: .simulated(speed: speed), fileURL: fileURL)
        transfer.simulatedFailure = failsAt
        transfers.append(transfer)
        if startsPaused {
            transfer.completedBytes = Int64(Double(size) * 0.42)
            transfer.apply(.pause)
        } else {
            start(transfer)
        }
        return transfer
    }

    // MARK: Controls

    public func pause(_ transfer: KitoTransfer) {
        guard transfer.apply(.pause) else { return }
        transfer.simulation?.cancel()
        switch transfer.source {
        case .download:
            guard let task = transfer.task as? URLSessionDownloadTask else { return }
            task.cancel { [weak self, id = transfer.id] data in
                Task { @MainActor in self?.transfer(id)?.resumeData = data }
            }
        case .upload:
            transfer.task?.suspend()
        case .simulated:
            break
        }
    }

    public func resume(_ transfer: KitoTransfer) {
        guard transfer.phase == .paused else { return }
        if case .upload = transfer.source, let task = transfer.task {
            transfer.apply(.resume)
            transfer.rate.reset()
            task.resume()
            return
        }
        transfer.apply(.resume)
        transfer.rate.reset(keepingSpeed: true)
        run(transfer)
    }

    public func cancel(_ transfer: KitoTransfer) {
        guard transfer.apply(.cancel) else { return }
        transfer.simulation?.cancel()
        transfer.task?.cancel()
        transfer.resumeData = nil
    }

    /// Starts a failed or cancelled transfer again, from where it stopped when possible.
    public func retry(_ transfer: KitoTransfer) {
        guard transfer.apply(.retry) else { return }
        transfer.simulatedFailure = nil
        if !transfer.isSimulated, transfer.resumeData == nil {
            transfer.completedBytes = 0
        }
        start(transfer)
    }

    /// Removes a transfer from the list, cancelling it first if it is still going.
    public func remove(_ transfer: KitoTransfer) {
        if transfer.phase.isActive { cancel(transfer) }
        transfers.removeAll { $0.id == transfer.id }
    }

    /// Removes finished, failed and cancelled transfers.
    public func clearFinished() {
        transfers.removeAll { $0.phase.isFinished }
    }

    public func transfer(_ id: UUID) -> KitoTransfer? {
        transfers.first { $0.id == id }
    }

    // MARK: Running

    private func start(_ transfer: KitoTransfer) {
        guard transfer.apply(.start) else { return }
        transfer.rate.reset()
        run(transfer)
    }

    private func run(_ transfer: KitoTransfer) {
        switch transfer.source {
        case let .download(url):
            let session = session()
            let task = transfer.resumeData.map { session.downloadTask(withResumeData: $0) } ?? session.downloadTask(with: url)
            transfer.resumeData = nil
            begin(task, for: transfer)
        case let .upload(request, fileURL):
            let task = session().uploadTask(with: request, fromFile: fileURL)
            begin(task, for: transfer)
        case let .simulated(speed):
            transfer.simulation = Task { [weak self] in await self?.simulate(transfer, speed: speed) }
        }
    }

    private func begin(_ task: URLSessionTask, for transfer: KitoTransfer) {
        if let old = transfer.task { taskOwners[old.taskIdentifier] = nil }
        transfer.task = task
        taskOwners[task.taskIdentifier] = transfer.id
        bridge?.setDestination(downloadDestination(for: transfer), for: task.taskIdentifier)
        task.resume()
    }

    private func simulate(_ transfer: KitoTransfer, speed: Double) async {
        let total = transfer.totalBytes ?? 1
        var generator = SystemRandomNumberGenerator()
        while !Task.isCancelled, transfer.phase == .running {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled, transfer.phase == .running else { return }
            let jitter = Double.random(in: 0.55...1.45, using: &generator)
            let step = Int64(speed * 0.12 * jitter)
            let next = min(transfer.completedBytes + max(step, 1), total)
            transfer.record(completed: next, total: total, at: Self.now)
            if let failure = transfer.simulatedFailure, Double(next) / Double(total) >= failure {
                transfer.apply(.fail("The network connection was lost."))
                return
            }
            if next >= total {
                finish(transfer)
                return
            }
        }
    }

    private func finish(_ transfer: KitoTransfer) {
        guard transfer.apply(.complete) else { return }
        if let total = transfer.totalBytes { transfer.completedBytes = total }
        onComplete?(transfer)
    }

    private static var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    // MARK: URLSession

    private func session() -> URLSession {
        if let sessionStore { return sessionStore }
        let bridge = KitoURLSessionBridge()
        bridge.onEvent = { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        let session = URLSession(configuration: configuration, delegate: bridge, delegateQueue: nil)
        self.bridge = bridge
        self.sessionStore = session
        return session
    }

    private func downloadDestination(for transfer: KitoTransfer) -> URL? {
        guard transfer.direction == .download else { return nil }
        return destination.appendingPathComponent(transfer.name)
    }

    private func handle(_ event: KitoSessionEvent) {
        guard let id = taskOwners[event.taskID], let transfer = transfer(id) else { return }
        switch event.kind {
        case let .progress(done, total):
            guard transfer.phase == .running else { return }
            transfer.record(completed: done, total: total > 0 ? total : nil, at: Self.now)
        case let .saved(url):
            transfer.fileURL = url
        case let .finished(error, resumeData):
            taskOwners[event.taskID] = nil
            if let resumeData { transfer.resumeData = resumeData }
            guard transfer.phase == .running else { return }
            if let error {
                transfer.apply(.fail(error))
            } else {
                finish(transfer)
            }
        }
    }
}

/// What the session delegate reports, carried to the main actor.
struct KitoSessionEvent: Sendable {
    enum Kind: Sendable {
        case progress(Int64, Int64)
        case saved(URL)
        case finished(String?, resumeData: Data?)
    }

    let taskID: Int
    let kind: Kind
}

/// The `URLSession` delegate. Moves finished downloads into place before the temporary file goes away.
final class KitoURLSessionBridge: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    var onEvent: (@Sendable (KitoSessionEvent) -> Void)?
    private let lock = NSLock()
    private var destinations: [Int: URL] = [:]

    func setDestination(_ url: URL?, for taskID: Int) {
        lock.lock()
        destinations[taskID] = url
        lock.unlock()
    }

    private func destination(for taskID: Int) -> URL? {
        lock.lock()
        defer { lock.unlock() }
        return destinations[taskID]
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        onEvent?(KitoSessionEvent(taskID: downloadTask.taskIdentifier,
                                  kind: .progress(totalBytesWritten, totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        onEvent?(KitoSessionEvent(taskID: task.taskIdentifier, kind: .progress(totalBytesSent, totalBytesExpectedToSend)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        if let status = (downloadTask.response as? HTTPURLResponse)?.statusCode, status >= 400 { return }
        guard let target = destination(for: downloadTask.taskIdentifier) else { return }
        let manager = FileManager.default
        do {
            try manager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if manager.fileExists(atPath: target.path) { try manager.removeItem(at: target) }
            try manager.moveItem(at: location, to: target)
            onEvent?(KitoSessionEvent(taskID: downloadTask.taskIdentifier, kind: .saved(target)))
        } catch {
            return
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        setDestination(nil, for: task.taskIdentifier)
        var message: String?
        if let error {
            message = (error as NSError).code == NSURLErrorCancelled ? "Cancelled" : error.localizedDescription
        } else if let status = (task.response as? HTTPURLResponse)?.statusCode, status >= 400 {
            message = "Server error \(status)"
        }
        let resumeData = (error as NSError?)?.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        onEvent?(KitoSessionEvent(taskID: task.taskIdentifier, kind: .finished(message, resumeData: resumeData)))
    }
}
