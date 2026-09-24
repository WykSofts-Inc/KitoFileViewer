//
//  KitoFileSorting.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// How files are ordered.
public struct KitoFileSort: Hashable, Sendable {
    public enum Field: String, CaseIterable, Hashable, Sendable {
        case name, date, size, kind

        public var title: String {
            switch self {
            case .name: "Name"
            case .date: "Date"
            case .size: "Size"
            case .kind: "Kind"
            }
        }

        public var systemImage: String {
            switch self {
            case .name: "textformat"
            case .date: "calendar"
            case .size: "externaldrive"
            case .kind: "square.grid.2x2"
            }
        }

        /// Name and kind read A→Z; date and size read newest or largest first.
        public var defaultAscending: Bool { self == .name || self == .kind }
    }

    public var field: Field
    public var ascending: Bool

    public init(_ field: Field, ascending: Bool? = nil) {
        self.field = field
        self.ascending = ascending ?? field.defaultAscending
    }

    public static let name = KitoFileSort(.name)
    public static let newest = KitoFileSort(.date)
    public static let largest = KitoFileSort(.size)
    public static let kind = KitoFileSort(.kind)

    /// The files in this order. Ties fall back to the name, so the order never jumps around.
    public func sorted(_ files: [KitoFileItem]) -> [KitoFileItem] {
        files.sorted { lhs, rhs in
            let order = compare(lhs, rhs)
            if order != .orderedSame { return ascending ? order == .orderedAscending : order == .orderedDescending }
            let byName = lhs.name.localizedStandardCompare(rhs.name)
            return byName == .orderedSame ? lhs.id < rhs.id : byName == .orderedAscending
        }
    }

    /// Folders in this order. Folders have no size or kind, so those fall back to the name.
    public func sorted(_ folders: [KitoFolder]) -> [KitoFolder] {
        folders.sorted { lhs, rhs in
            if field == .date, let left = lhs.modified, let right = rhs.modified, left != right {
                return ascending ? left < right : left > right
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func compare(_ lhs: KitoFileItem, _ rhs: KitoFileItem) -> ComparisonResult {
        switch field {
        case .name:
            return lhs.name.localizedStandardCompare(rhs.name)
        case .date:
            return Self.compare(lhs.modified ?? .distantPast, rhs.modified ?? .distantPast)
        case .size:
            return Self.compare(lhs.size ?? -1, rhs.size ?? -1)
        case .kind:
            return Self.compare(Self.kindIndex(lhs.kind), Self.kindIndex(rhs.kind))
        }
    }

    static func kindIndex(_ kind: KitoFileKind) -> Int {
        KitoFileKind.allCases.firstIndex(of: kind) ?? 0
    }

    private static func compare<T: Comparable>(_ lhs: T, _ rhs: T) -> ComparisonResult {
        lhs < rhs ? .orderedAscending : (lhs > rhs ? .orderedDescending : .orderedSame)
    }
}

/// How files are split into sections.
public enum KitoFileGrouping: String, CaseIterable, Hashable, Sendable {
    case none, kind, date

    public var title: String {
        switch self {
        case .none: "None"
        case .kind: "Kind"
        case .date: "Date"
        }
    }
}

/// A section of files under a header.
public struct KitoFileGroup: Identifiable, Hashable, Sendable {
    public var id: String
    /// The header, e.g. "PDFs" or "Yesterday". Empty when grouping is off.
    public var title: String
    public var kind: KitoFileKind?
    public var files: [KitoFileItem]

    public init(id: String, title: String, kind: KitoFileKind? = nil, files: [KitoFileItem]) {
        self.id = id
        self.title = title
        self.kind = kind
        self.files = files
    }

    /// Sorts, then groups files.
    ///
    /// Kind groups follow `KitoFileKind` order. Date groups are Today, Yesterday, Previous 7 Days,
    /// Previous 30 Days, then one per month ("August 2026") newest first, then "No Date".
    public static func make(_ files: [KitoFileItem], sort: KitoFileSort, grouping: KitoFileGrouping,
                            now: Date = .now, calendar: Calendar = .current,
                            locale: Locale = .current) -> [KitoFileGroup] {
        let sorted = sort.sorted(files)
        switch grouping {
        case .none:
            return sorted.isEmpty ? [] : [KitoFileGroup(id: "all", title: "", files: sorted)]
        case .kind:
            return KitoFileKind.allCases.compactMap { kind in
                let matching = sorted.filter { $0.kind == kind }
                return matching.isEmpty ? nil : KitoFileGroup(id: kind.rawValue, title: kind.title, kind: kind, files: matching)
            }
        case .date:
            return dateGroups(sorted, now: now, calendar: calendar, locale: locale)
        }
    }

    private static func dateGroups(_ files: [KitoFileItem], now: Date, calendar: Calendar,
                                   locale: Locale) -> [KitoFileGroup] {
        var buckets: [KitoDateBucket: [KitoFileItem]] = [:]
        for file in files {
            let bucket = KitoDateBucket.bucket(for: file.modified, now: now, calendar: calendar)
            buckets[bucket, default: []].append(file)
        }
        return buckets.keys.sorted().map { bucket in
            KitoFileGroup(id: bucket.id, title: bucket.title(calendar: calendar, locale: locale),
                          files: buckets[bucket] ?? [])
        }
    }
}

/// The date sections used when grouping by date.
enum KitoDateBucket: Hashable, Comparable {
    case today, yesterday, week, month
    case monthOf(year: Int, month: Int)
    case undated

    static func bucket(for date: Date?, now: Date, calendar: Calendar) -> KitoDateBucket {
        guard let date else { return .undated }
        let startOfToday = calendar.startOfDay(for: now)
        let startOfDay = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startOfDay, to: startOfToday).day ?? 0
        switch days {
        case ..<1: return .today
        case 1: return .yesterday
        case 2...7: return .week
        case 8...30: return .month
        default:
            let parts = calendar.dateComponents([.year, .month], from: date)
            return .monthOf(year: parts.year ?? 0, month: parts.month ?? 0)
        }
    }

    var id: String {
        switch self {
        case .today: "today"
        case .yesterday: "yesterday"
        case .week: "week"
        case .month: "month"
        case let .monthOf(year, month): "\(year)-\(month)"
        case .undated: "undated"
        }
    }

    private var rank: Int {
        switch self {
        case .today: 0
        case .yesterday: 1
        case .week: 2
        case .month: 3
        case .monthOf: 4
        case .undated: 5
        }
    }

    static func < (lhs: KitoDateBucket, rhs: KitoDateBucket) -> Bool {
        if case let .monthOf(y1, m1) = lhs, case let .monthOf(y2, m2) = rhs {
            return y1 != y2 ? y1 > y2 : m1 > m2
        }
        return lhs.rank < rhs.rank
    }

    func title(calendar: Calendar, locale: Locale) -> String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .week: return "Previous 7 Days"
        case .month: return "Previous 30 Days"
        case .undated: return "No Date"
        case let .monthOf(year, month):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.calendar = calendar
            formatter.timeZone = calendar.timeZone
            formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
            let date = calendar.date(from: DateComponents(year: year, month: month, day: 15)) ?? .now
            return formatter.string(from: date)
        }
    }
}

/// Matches files against a search query.
public enum KitoFileFilter {
    /// Whether every word of `query` appears in the file's name, extension or kind, ignoring case
    /// and accents. An empty query matches everything.
    public static func matches(_ file: KitoFileItem, query: String) -> Bool {
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty else { return true }
        let haystack = "\(file.name) \(file.kind.title) \(file.kind.singularTitle)"
        return words.allSatisfy { haystack.range(of: $0, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    /// The files that match, in their original order.
    public static func filter(_ files: [KitoFileItem], query: String) -> [KitoFileItem] {
        files.filter { matches($0, query: query) }
    }
}
