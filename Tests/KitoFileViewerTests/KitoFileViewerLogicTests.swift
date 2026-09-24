//
//  KitoFileViewerLogicTests.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
@testable import KitoFileViewer

// MARK: - Breadcrumbs

final class KitoBreadcrumbTests: XCTestCase {
    func testPathInsideRootStartsAtRootTitle() {
        let root = URL(fileURLWithPath: "/var/mobile/Documents")
        let target = URL(fileURLWithPath: "/var/mobile/Documents/School/2026")
        let items = KitoBreadcrumb.items(for: target, root: root, rootTitle: "My Files")
        XCTAssertEqual(items.map(\.title), ["My Files", "School", "2026"])
        XCTAssertEqual(items.map(\.depth), [0, 1, 2])
        XCTAssertEqual(items.last?.id, "/var/mobile/Documents/School/2026")
        XCTAssertEqual(items.first?.id, "/var/mobile/Documents")
    }

    func testPathOutsideRootUsesWholePath() {
        let items = KitoBreadcrumb.items(for: URL(fileURLWithPath: "/tmp/a"), root: URL(fileURLWithPath: "/var"))
        XCTAssertEqual(items.map(\.title), ["tmp", "a"])
    }

    func testSlashPathAndFolders() {
        XCTAssertEqual(KitoBreadcrumb.items(forPath: "Documents/School/2026").map(\.id),
                       ["Documents", "Documents/School", "Documents/School/2026"])
        let folders = [KitoFolder(name: "Documents"), KitoFolder(name: "School")]
        XCTAssertEqual(KitoBreadcrumb.items(for: folders).map(\.title), ["Documents", "School"])
    }

    func testCollapsingKeepsRootAndTail() {
        let items = KitoBreadcrumb.items(forPath: "A/B/C/D/E/F")
        let collapsed = KitoBreadcrumb.collapsed(items, maxVisible: 4)
        XCTAssertEqual(collapsed.map(\.title), ["A", "…", "E", "F"])
        XCTAssertEqual(collapsed[1].id, "A/B/C/D")
        XCTAssertTrue(collapsed[1].isEllipsis)
        XCTAssertEqual(KitoBreadcrumb.collapsed(items, maxVisible: 10), items)
        XCTAssertEqual(KitoBreadcrumb.collapsed(items, maxVisible: 1).count, 3)
    }
}

// MARK: - Search cursor and pages

final class KitoDocumentSearchCursorTests: XCTestCase {
    func testWrapsBothWays() {
        var cursor = KitoDocumentSearchCursor(count: 3)
        XCTAssertEqual(cursor.label, "1 of 3")
        cursor.next(); cursor.next(); cursor.next()
        XCTAssertEqual(cursor.index, 0)
        cursor.previous()
        XCTAssertEqual(cursor.label, "3 of 3")
    }

    func testEmptyAndClamping() {
        var cursor = KitoDocumentSearchCursor(count: 0)
        cursor.next()
        XCTAssertNil(cursor.index)
        XCTAssertEqual(cursor.label, "No results")
        cursor.reset(count: 5)
        cursor.select(99)
        XCTAssertEqual(cursor.index, 4)
        XCTAssertEqual(KitoDocumentSearchCursor(count: 2, index: -3).index, 0)
    }

    func testPaging() {
        var cursor = KitoDocumentSearchCursor(count: 45)
        cursor.select(23)
        XCTAssertEqual(cursor.pageStart(pageSize: 20), 20)
        XCTAssertEqual(cursor.pageRange(pageSize: 20), 20..<40)
        cursor.select(44)
        XCTAssertEqual(cursor.pageRange(pageSize: 20), 40..<45)
        XCTAssertEqual(KitoDocumentSearchCursor().pageRange(pageSize: 20), 0..<0)
    }

    func testPageIndicator() {
        XCTAssertEqual(KitoPDFPageIndicator.label(pageIndex: 2, pageCount: 12), "3 / 12")
        XCTAssertEqual(KitoPDFPageIndicator.label(pageIndex: 40, pageCount: 12), "12 / 12")
        XCTAssertEqual(KitoPDFPageIndicator.label(pageIndex: 0, pageCount: 0), "")
    }
}

// MARK: - Transfers

final class KitoTransferPhaseTests: XCTestCase {
    func testHappyPath() {
        var phase = KitoTransferPhase.waiting
        for event: KitoTransferEvent in [.start, .progress, .pause, .resume, .progress, .complete] {
            phase = phase.applying(event) ?? phase
        }
        XCTAssertEqual(phase, .completed)
        XCTAssertTrue(phase.isFinished)
    }

    func testInvalidTransitionsReturnNil() {
        XCTAssertNil(KitoTransferPhase.completed.applying(.pause))
        XCTAssertNil(KitoTransferPhase.completed.applying(.retry))
        XCTAssertNil(KitoTransferPhase.paused.applying(.complete))
        XCTAssertNil(KitoTransferPhase.waiting.applying(.resume))
        XCTAssertNil(KitoTransferPhase.cancelled.applying(.start))
    }

    func testFailureAndRetry() {
        let failed = KitoTransferPhase.running.applying(.fail("Offline"))
        XCTAssertEqual(failed, .failed("Offline"))
        XCTAssertEqual(failed?.failureMessage, "Offline")
        XCTAssertEqual(failed?.applying(.retry), .waiting)
        XCTAssertEqual(failed?.applying(.cancel), .cancelled)
        XCTAssertEqual(KitoTransferPhase.cancelled.applying(.retry), .waiting)
    }

    func testRateSmoothingAndETA() throws {
        var rate = KitoTransferRate(smoothing: 0.5, minimumInterval: 0.25)
        rate.record(totalBytes: 0, at: 0)
        XCTAssertNil(rate.bytesPerSecond)
        rate.record(totalBytes: 1_000_000, at: 1)
        XCTAssertEqual(try XCTUnwrap(rate.bytesPerSecond), 1_000_000, accuracy: 0.1)
        rate.record(totalBytes: 1_100_000, at: 1.1)          // too soon: ignored
        XCTAssertEqual(try XCTUnwrap(rate.bytesPerSecond), 1_000_000, accuracy: 0.1)
        rate.record(totalBytes: 4_000_000, at: 2)            // 3 MB/s instant, smoothed to 2 MB/s
        XCTAssertEqual(try XCTUnwrap(rate.bytesPerSecond), 2_000_000, accuracy: 0.1)
        XCTAssertEqual(try XCTUnwrap(rate.secondsLeft(remaining: 10_000_000)), 5, accuracy: 0.001)
        rate.reset(keepingSpeed: true)
        XCTAssertNotNil(rate.bytesPerSecond)
        rate.reset()
        XCTAssertNil(rate.secondsLeft(remaining: 100))
    }

    @MainActor
    func testSimulatedTransferStartsPausedAndResumes() {
        let model = KitoTransferModel()
        let transfer = model.simulate(name: "Plan.pdf", size: 1_000_000, startsPaused: true)
        XCTAssertEqual(transfer.phase, .paused)
        XCTAssertEqual(transfer.kind, .pdf)
        XCTAssertEqual(transfer.statusText, "Paused · 420 KB of 1 MB")
        model.resume(transfer)
        XCTAssertEqual(transfer.phase, .running)
        model.cancel(transfer)
        XCTAssertEqual(transfer.phase, .cancelled)
        model.clearFinished()
        XCTAssertTrue(model.transfers.isEmpty)
    }
}

// MARK: - Code highlighting

final class KitoCodeHighlighterTests: XCTestCase {
    func testKeywordsStringsNumbersAndComments() {
        let keywords = KitoCodeHighlighter.keywords(forExtension: "swift")
        let tokens = KitoCodeHighlighter.tokens(in: #"let total = 42 // "sum""#, keywords: keywords)
        XCTAssertEqual(tokens.map(\.kind), [.keyword, .number, .comment])
        XCTAssertEqual(tokens.map(\.range), [0..<3, 12..<14, 15..<23])
        let string = KitoCodeHighlighter.tokens(in: #"print("a \"b\"") "#, keywords: keywords)
        XCTAssertEqual(string.map(\.kind), [.string])
        XCTAssertEqual(string.first?.range, 6..<15)
    }

    func testIdentifiersContainingNumbersAreNotNumbers() {
        let tokens = KitoCodeHighlighter.tokens(in: "var x2 = v1", keywords: ["var"])
        XCTAssertEqual(tokens.map(\.kind), [.keyword])
    }

    func testHashCommentsOnlyWhenAsked() {
        XCTAssertTrue(KitoCodeHighlighter.tokens(in: "#if DEBUG", keywords: []).isEmpty)
        XCTAssertEqual(KitoCodeHighlighter.tokens(in: "# note", keywords: [], hashComments: true).map(\.kind), [.comment])
        XCTAssertTrue(KitoCodeHighlighter.usesHashComments(extension: "py"))
        XCTAssertTrue(KitoCodeHighlighter.highlights(extension: "swift"))
        XCTAssertFalse(KitoCodeHighlighter.highlights(extension: "txt"))
    }
}

// MARK: - Folders and the browser model

final class KitoFolderTests: XCTestCase {
    func tree() -> KitoFolder {
        let invoice = KitoFileItem(name: "Invoice.pdf", size: 240_000, id: "invoice")
        let report = KitoFileItem(name: "Report.pdf", size: 1_000_000, id: "report")
        let photo = KitoFileItem(name: "Photo.png", size: 3_000_000, id: "photo")
        let school = KitoFolder(name: "School", files: [report], id: "school")
        let photos = KitoFolder(name: "Photos", files: [photo], id: "photos")
        return KitoFolder(name: "Documents", files: [invoice], folders: [school, photos], id: "root")
    }

    func testPathsAndTotals() {
        let root = tree()
        XCTAssertEqual(root.path(to: "photos")?.map(\.name), ["Documents", "Photos"])
        XCTAssertNil(root.path(to: "missing"))
        XCTAssertEqual(root.allFiles.count, 3)
        XCTAssertEqual(root.totalSize, 4_240_000)
        XCTAssertEqual(root.itemCountText, "3 items")
        XCTAssertEqual(KitoFolder(name: "Empty").itemCountText, "Empty")
    }

    func testRemovingAndMoving() {
        let root = tree()
        XCTAssertEqual(root.removing(["report"]).folder(withID: "school")?.files.count, 0)
        let moved = root.moving(["invoice"], to: "school")
        XCTAssertTrue(moved.files.isEmpty)
        XCTAssertEqual(moved.folder(withID: "school")?.files.map(\.id), ["report", "invoice"])
        XCTAssertEqual(root.moving(["invoice"], to: "nowhere"), root)
    }

    @MainActor
    func testBrowserNavigationSearchAndSelection() {
        let model = KitoFileBrowserModel(root: tree())
        XCTAssertEqual(model.visibleFolders.map(\.name), ["Photos", "School"])
        model.open(KitoFolder(name: "School", id: "school"))
        XCTAssertEqual(model.breadcrumbs.map(\.title), ["Documents", "School"])
        XCTAssertTrue(model.goUp())
        XCTAssertFalse(model.goUp())
        model.query = "photo"
        XCTAssertEqual(model.visibleFiles.map(\.id), ["photo"])
        XCTAssertTrue(model.visibleFolders.isEmpty)
        model.query = ""
        model.isSelecting = true
        model.selectAll()
        XCTAssertTrue(model.allSelected)
        var deleted: [String] = []
        model.onDelete = { deleted = $0.map(\.id) }
        model.deleteSelection()
        XCTAssertEqual(deleted, ["invoice"])
        XCTAssertFalse(model.isSelecting)
        XCTAssertEqual(model.root.allFiles.count, 2)
    }

    @MainActor
    func testPreviewModes() {
        let local = URL(fileURLWithPath: "/tmp/x")
        func mode(_ name: String) -> KitoPreviewMode {
            KitoPreviewMode.mode(for: KitoFileItem(name: name, url: local.appendingPathComponent(name)),
                                 canQuickLook: { _ in true })
        }
        XCTAssertEqual(mode("a.pdf"), .pdf)
        XCTAssertEqual(mode("a.png"), .image)
        XCTAssertEqual(mode("a.swift"), .text)
        XCTAssertEqual(mode("a.csv"), .text)
        XCTAssertEqual(mode("a.docx"), .quickLook)
        XCTAssertEqual(KitoPreviewMode.mode(for: KitoFileItem(name: "a.pdf")), .unavailable)
    }
}
