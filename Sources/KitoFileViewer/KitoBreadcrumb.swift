//
//  KitoBreadcrumb.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// One step in a folder path: "Documents › School › 2026".
public struct KitoBreadcrumbItem: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    /// How far down the path this step is; 0 is the root.
    public var depth: Int
    /// `true` for the "…" step that stands in for folders hidden by `KitoBreadcrumb.collapsed(maxVisible:)`.
    public var isEllipsis: Bool

    public init(id: String, title: String, depth: Int, isEllipsis: Bool = false) {
        self.id = id
        self.title = title
        self.depth = depth
        self.isEllipsis = isEllipsis
    }
}

/// Builds breadcrumb paths from folders or URLs.
///
/// ```swift
/// KitoBreadcrumb.items(for: school2026URL, root: documentsURL, rootTitle: "Documents")
/// // Documents › School › 2026
/// KitoBreadcrumb.collapsed(items, maxVisible: 3)
/// // Documents › … › 2026
/// ```
public enum KitoBreadcrumb {
    /// A step for each folder, root first.
    public static func items(for folders: [KitoFolder]) -> [KitoBreadcrumbItem] {
        folders.enumerated().map { KitoBreadcrumbItem(id: $1.id, title: $1.name, depth: $0) }
    }

    /// Steps from `root` down to `url`. If `url` isn't inside `root` the path starts at the filesystem root.
    /// Each step's id is the standardized path of that folder.
    public static func items(for url: URL, root: URL? = nil, rootTitle: String? = nil) -> [KitoBreadcrumbItem] {
        let target = url.standardizedFileURL.pathComponents.filter { $0 != "/" }
        let base = root?.standardizedFileURL.pathComponents.filter { $0 != "/" } ?? []
        let inside = !base.isEmpty && target.count >= base.count && Array(target.prefix(base.count)) == base
        let start = inside ? base.count : 0
        var items: [KitoBreadcrumbItem] = []
        if inside {
            let title = rootTitle ?? base.last ?? "/"
            items.append(KitoBreadcrumbItem(id: "/" + base.joined(separator: "/"), title: title, depth: 0))
        } else if let rootTitle {
            items.append(KitoBreadcrumbItem(id: "/", title: rootTitle, depth: 0))
        }
        for index in start..<target.count {
            let path = "/" + target[0...index].joined(separator: "/")
            items.append(KitoBreadcrumbItem(id: path, title: target[index], depth: items.count))
        }
        return items
    }

    /// Steps from a slash-separated path such as "Documents/School/2026".
    public static func items(forPath path: String) -> [KitoBreadcrumbItem] {
        let parts = path.split(separator: "/").map(String.init)
        return parts.indices.map { index in
            KitoBreadcrumbItem(id: parts[0...index].joined(separator: "/"), title: parts[index], depth: index)
        }
    }

    /// Keeps the root and the last `maxVisible - 2` steps, replacing the middle with a single "…".
    /// Paths that already fit are returned unchanged. `maxVisible` below 3 is treated as 3.
    public static func collapsed(_ items: [KitoBreadcrumbItem], maxVisible: Int) -> [KitoBreadcrumbItem] {
        let limit = max(maxVisible, 3)
        guard items.count > limit, let first = items.first else { return items }
        let tail = Array(items.suffix(limit - 2))
        let hidden = items.dropFirst().dropLast(tail.count)
        let ellipsis = KitoBreadcrumbItem(id: hidden.last?.id ?? "ellipsis", title: "…",
                                          depth: hidden.last?.depth ?? 1, isEllipsis: true)
        return [first, ellipsis] + tail
    }
}
