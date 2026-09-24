//
//  KitoDocumentSearchCursor.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Steps through search results in a document: next and previous wrap around, and the label reads "3 of 12".
public struct KitoDocumentSearchCursor: Hashable, Sendable {
    /// How many results there are.
    public private(set) var count: Int
    /// The selected result, or `nil` when there are none.
    public private(set) var index: Int?

    public init(count: Int = 0, index: Int? = nil) {
        self.count = max(count, 0)
        if self.count == 0 {
            self.index = nil
        } else {
            self.index = min(max(index ?? 0, 0), self.count - 1)
        }
    }

    /// Selects the next result, wrapping to the first.
    public mutating func next() {
        guard count > 0 else { return }
        index = ((index ?? -1) + 1) % count
    }

    /// Selects the previous result, wrapping to the last.
    public mutating func previous() {
        guard count > 0 else { return }
        index = ((index ?? 0) - 1 + count) % count
    }

    /// Selects a result, clamped to the valid range.
    public mutating func select(_ newIndex: Int) {
        guard count > 0 else { return }
        index = min(max(newIndex, 0), count - 1)
    }

    /// Replaces the results (after the query changes), selecting the first.
    public mutating func reset(count newCount: Int) {
        self = KitoDocumentSearchCursor(count: newCount)
    }

    /// "3 of 12", or "No results".
    public var label: String {
        guard let index else { return "No results" }
        return "\(index + 1) of \(count)"
    }

    /// The first index of the page of `pageSize` results holding the selection, for paging long result lists.
    public func pageStart(pageSize: Int) -> Int {
        guard let index, pageSize > 0 else { return 0 }
        return (index / pageSize) * pageSize
    }

    /// The range of result indices in the page holding the selection.
    public func pageRange(pageSize: Int) -> Range<Int> {
        guard count > 0, pageSize > 0 else { return 0..<0 }
        let start = pageStart(pageSize: pageSize)
        return start..<min(start + pageSize, count)
    }
}

/// Page indicator text.
public enum KitoPageIndicator {
    /// "3 / 12" for a zero-based page index. Returns "" when there are no pages.
    public static func label(pageIndex: Int, pageCount: Int) -> String {
        guard pageCount > 0 else { return "" }
        let page = min(max(pageIndex, 0), pageCount - 1) + 1
        return "\(page) / \(pageCount)"
    }
}
