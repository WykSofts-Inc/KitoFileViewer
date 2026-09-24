//
//  KitoFileViewerTests.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import XCTest
import UniformTypeIdentifiers
@testable import KitoFileViewer

// MARK: - Byte counts

final class KitoByteCountTests: XCTestCase {
    func testSmallCountsUseBytes() {
        XCTAssertEqual(KitoByteCount.string(0), "0 bytes")
        XCTAssertEqual(KitoByteCount.string(1), "1 byte")
        XCTAssertEqual(KitoByteCount.string(999), "999 bytes")
        XCTAssertEqual(KitoByteCount.string(-5), "0 bytes")
    }

    func testDecimalUnitsWithOneDecimalUnderTen() {
        XCTAssertEqual(KitoByteCount.string(1_000), "1 KB")
        XCTAssertEqual(KitoByteCount.string(1_500), "1.5 KB")
        XCTAssertEqual(KitoByteCount.string(240_000), "240 KB")
        XCTAssertEqual(KitoByteCount.string(2_400_000), "2.4 MB")
        XCTAssertEqual(KitoByteCount.string(18_400_000), "18 MB")
        XCTAssertEqual(KitoByteCount.string(3_000_000_000), "3 GB")
    }

    func testRoundingUpCrossesIntoTheNextUnit() {
        XCTAssertEqual(KitoByteCount.string(999_600), "1 MB")
        XCTAssertEqual(KitoByteCount.string(9_960), "10 KB")
    }

    func testRateProgressAndTimeLeft() {
        XCTAssertEqual(KitoByteCount.rate(1_300_000), "1.3 MB/s")
        XCTAssertEqual(KitoByteCount.rate(0), "0 KB/s")
        XCTAssertEqual(KitoByteCount.rate(500), "500 B/s")
        XCTAssertEqual(KitoByteCount.progress(4_200_000, of: 18_000_000), "4.2 MB of 18 MB")
        XCTAssertEqual(KitoByteCount.progress(4_200_000, of: nil), "4.2 MB")
        XCTAssertEqual(KitoByteCount.timeLeft(0.4), "Almost done")
        XCTAssertEqual(KitoByteCount.timeLeft(11.2), "12 s left")
        XCTAssertEqual(KitoByteCount.timeLeft(185), "3 min left")
        XCTAssertEqual(KitoByteCount.timeLeft(3_900), "1 h 5 min left")
        XCTAssertEqual(KitoByteCount.timeLeft(7_200), "2 h left")
        XCTAssertEqual(KitoByteCount.timeLeft(.infinity), "")
    }
}

// MARK: - Kind detection

final class KitoFileKindTests: XCTestCase {
    func testExtensions() {
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "PDF"), .pdf)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "docx"), .doc)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "xlsx"), .sheet)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "csv"), .sheet)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "key"), .slides)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "zip"), .archive)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "swift"), .code)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "md"), .text)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "heic"), .image)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "m4a"), .audio)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "mov"), .video)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "qqq"), .other)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: nil), .other)
        XCTAssertEqual(KitoFileKind.detect(fileName: "Invoice.final.PDF"), .pdf)
    }

    func testContentTypesByConformance() {
        XCTAssertEqual(KitoFileKind.detect(contentType: .pdf), .pdf)
        XCTAssertEqual(KitoFileKind.detect(contentType: .png), .image)
        XCTAssertEqual(KitoFileKind.detect(contentType: .mpeg4Movie), .video)
        XCTAssertEqual(KitoFileKind.detect(contentType: .mp3), .audio)
        XCTAssertEqual(KitoFileKind.detect(contentType: .zip), .archive)
        XCTAssertEqual(KitoFileKind.detect(contentType: .swiftSource), .code)
        XCTAssertEqual(KitoFileKind.detect(contentType: .plainText), .text)
        XCTAssertEqual(KitoFileKind.detect(contentType: .data), .other)
    }

    func testUnknownExtensionFallsBackToContentType() {
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "", contentType: .jpeg), .image)
        XCTAssertEqual(KitoFileKind.detect(pathExtension: "blob", contentType: .pdf), .pdf)
    }

    func testItemsDetectTheirKindAndText() {
        let item = KitoFileItem(name: "Invoice.pdf", size: 240_000)
        XCTAssertEqual(item.kind, .pdf)
        XCTAssertEqual(item.pathExtension, "pdf")
        XCTAssertEqual(item.baseName, "Invoice")
        XCTAssertFalse(item.isLocal)
        XCTAssertEqual(item.detailText(), "240 KB")
    }
}

// MARK: - Sorting and grouping

final class KitoFileSortingTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_790_000_000)   // Sep 2026
    var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    func file(_ name: String, size: Int64? = nil, daysAgo: Double? = nil) -> KitoFileItem {
        KitoFileItem(name: name, size: size, modified: daysAgo.map { now.addingTimeInterval(-$0 * 86_400) })
    }

    func testNameSortIsNaturalAndStable() {
        let files = [file("Report 10.pdf"), file("report 2.pdf"), file("Budget.xlsx")]
        XCTAssertEqual(KitoFileSort.name.sorted(files).map(\.name), ["Budget.xlsx", "report 2.pdf", "Report 10.pdf"])
        let descending = KitoFileSort(.name, ascending: false).sorted(files).map(\.name)
        XCTAssertEqual(descending, ["Report 10.pdf", "report 2.pdf", "Budget.xlsx"])
    }

    func testDateAndSizeDefaultToNewestAndLargest() {
        let files = [file("a.txt", size: 10, daysAgo: 3), file("b.txt", size: 300, daysAgo: 1),
                     file("c.txt", daysAgo: nil), file("d.txt", size: 300, daysAgo: 9)]
        XCTAssertEqual(KitoFileSort.newest.sorted(files).map(\.name), ["b.txt", "a.txt", "d.txt", "c.txt"])
        XCTAssertEqual(KitoFileSort.largest.sorted(files).map(\.name), ["b.txt", "d.txt", "a.txt", "c.txt"])
        XCTAssertFalse(KitoFileSort.newest.ascending)
        XCTAssertTrue(KitoFileSort.name.ascending)
    }

    func testKindSortFollowsKindOrderThenName() {
        let files = [file("z.zip"), file("b.pdf"), file("a.png"), file("a.pdf")]
        XCTAssertEqual(KitoFileSort.kind.sorted(files).map(\.name), ["a.pdf", "b.pdf", "a.png", "z.zip"])
    }

    func testGroupByKindKeepsKindOrderAndSkipsEmpty() {
        let files = [file("z.zip"), file("b.pdf"), file("notes.txt"), file("a.pdf")]
        let groups = KitoFileGroup.make(files, sort: .name, grouping: .kind)
        XCTAssertEqual(groups.map(\.title), ["PDFs", "Archives", "Text"])
        XCTAssertEqual(groups.first?.files.map(\.name), ["a.pdf", "b.pdf"])
    }

    func testGroupByDateBuckets() {
        let files = [file("today.txt", daysAgo: 0.1), file("yesterday.txt", daysAgo: 1),
                     file("week.txt", daysAgo: 4), file("month.txt", daysAgo: 20),
                     file("june.txt", daysAgo: 90), file("may.txt", daysAgo: 120), file("undated.txt")]
        let locale = Locale(identifier: "en_US_POSIX")
        let groups = KitoFileGroup.make(files, sort: .newest, grouping: .date, now: now,
                                        calendar: calendar, locale: locale)
        XCTAssertEqual(groups.map(\.title),
                       ["Today", "Yesterday", "Previous 7 Days", "Previous 30 Days", "June 2026", "May 2026", "No Date"])
    }

    func testNoGroupingIsOneUntitledGroupOrNone() {
        XCTAssertEqual(KitoFileGroup.make([file("a.txt")], sort: .name, grouping: .none).map(\.title), [""])
        XCTAssertTrue(KitoFileGroup.make([], sort: .name, grouping: .none).isEmpty)
    }

    func testSearchFilterMatchesAllWordsIgnoringCaseAndAccents() {
        let files = [file("Café menu.pdf"), file("Invoice Baobab.pdf"), file("Budget.xlsx")]
        XCTAssertEqual(KitoFileFilter.filter(files, query: "cafe").map(\.name), ["Café menu.pdf"])
        XCTAssertEqual(KitoFileFilter.filter(files, query: "baobab pdf").map(\.name), ["Invoice Baobab.pdf"])
        XCTAssertEqual(KitoFileFilter.filter(files, query: "spreadsheet").map(\.name), ["Budget.xlsx"])
        XCTAssertEqual(KitoFileFilter.filter(files, query: "  ").count, 3)
        XCTAssertTrue(KitoFileFilter.filter(files, query: "invoice xlsx").isEmpty)
    }
}
