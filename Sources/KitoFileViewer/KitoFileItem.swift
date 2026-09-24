//
//  KitoFileItem.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation
import UniformTypeIdentifiers

/// A file shown in a list, grid, preview, transfer row or attachment chip.
///
/// ```swift
/// KitoFileItem(name: "Invoice.pdf", url: localURL, size: 240_000, modified: .now)
/// KitoFileItem(contentsOf: url)      // reads size, date and type from disk
/// ```
public struct KitoFileItem: Identifiable, Hashable, Sendable {
    public var id: String
    /// The display name, including its extension.
    public var name: String
    /// Where the file is. A file URL can be previewed and shared; a remote URL can be downloaded.
    public var url: URL?
    /// Size in bytes, if known.
    public var size: Int64?
    /// Last modified, if known.
    public var modified: Date?
    /// What sort of file it is, for its badge and viewer.
    public var kind: KitoFileKind

    /// - Parameters:
    ///   - kind: Worked out from the name's extension when `nil`.
    ///   - id: Defaults to the URL, or the name when there is no URL.
    public init(name: String, url: URL? = nil, size: Int64? = nil, modified: Date? = nil,
                kind: KitoFileKind? = nil, id: String? = nil) {
        self.id = id ?? url?.absoluteString ?? name
        self.name = name
        self.url = url
        self.size = size
        self.modified = modified
        self.kind = kind ?? KitoFileKind.detect(fileName: name)
    }

    /// Reads a local file's size, modification date and content type.
    public init(contentsOf url: URL) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .contentTypeKey]
        let values = try? url.resourceValues(forKeys: keys)
        let kind = KitoFileKind.detect(pathExtension: url.pathExtension, contentType: values?.contentType)
        self.init(name: url.lastPathComponent, url: url, size: values?.fileSize.map(Int64.init),
                  modified: values?.contentModificationDate, kind: kind)
    }

    /// The extension without the dot, e.g. "pdf".
    public var pathExtension: String { (name as NSString).pathExtension }

    /// The name without its extension, e.g. "Invoice".
    public var baseName: String { (name as NSString).deletingPathExtension }

    /// Whether the file is on this device, so it can be previewed and shared.
    public var isLocal: Bool { url?.isFileURL ?? false }

    /// The content type from the extension.
    public var contentType: UTType? { UTType(filenameExtension: pathExtension.lowercased()) }

    /// "240 KB · 12 Sep 2026", or whichever parts are known.
    public func detailText(dateStyle: Date.FormatStyle = .dateTime.day().month(.abbreviated).year()) -> String {
        var parts: [String] = []
        if let size { parts.append(KitoByteCount.string(size)) }
        if let modified { parts.append(modified.formatted(dateStyle)) }
        return parts.joined(separator: " · ")
    }
}

/// A folder of files and subfolders.
public struct KitoFolder: Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var url: URL?
    public var files: [KitoFileItem]
    public var folders: [KitoFolder]
    public var modified: Date?

    public init(name: String, url: URL? = nil, files: [KitoFileItem] = [], folders: [KitoFolder] = [],
                modified: Date? = nil, id: String? = nil) {
        self.id = id ?? url?.absoluteString ?? name
        self.name = name
        self.url = url
        self.files = files
        self.folders = folders
        self.modified = modified
    }

    /// Reads a folder from disk, skipping hidden files.
    /// - Parameter depth: How many levels of subfolders to read; 0 reads only this folder's files.
    public static func load(from url: URL, depth: Int = 4) -> KitoFolder {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [.isDirectoryKey, .contentModificationDateKey]
        let contents = (try? manager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys,
                                                        options: [.skipsHiddenFiles])) ?? []
        var files: [KitoFileItem] = []
        var folders: [KitoFolder] = []
        for child in contents {
            let isDirectory = (try? child.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
            if isDirectory {
                if depth > 0 { folders.append(load(from: child, depth: depth - 1)) }
            } else {
                files.append(KitoFileItem(contentsOf: child))
            }
        }
        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
        return KitoFolder(name: url.lastPathComponent, url: url, files: files,
                          folders: folders.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending },
                          modified: modified)
    }

    /// Files and folders directly inside.
    public var itemCount: Int { files.count + folders.count }

    /// "4 items", "1 item", "Empty".
    public var itemCountText: String {
        switch itemCount {
        case 0: "Empty"
        case 1: "1 item"
        default: "\(itemCount) items"
        }
    }

    /// Every file in this folder and all its subfolders.
    public var allFiles: [KitoFileItem] {
        files + folders.flatMap(\.allFiles)
    }

    /// The total size of every file inside, counting subfolders.
    public var totalSize: Int64 {
        allFiles.reduce(0) { $0 + ($1.size ?? 0) }
    }

    /// The folder with this id, searching subfolders.
    public func folder(withID id: String) -> KitoFolder? {
        if self.id == id { return self }
        for child in folders {
            if let match = child.folder(withID: id) { return match }
        }
        return nil
    }

    /// The chain of folders from this one down to the folder with `id`, or `nil` if it isn't inside.
    public func path(to id: String) -> [KitoFolder]? {
        if self.id == id { return [self] }
        for child in folders {
            if let rest = child.path(to: id) { return [self] + rest }
        }
        return nil
    }

    /// A copy with these files and folders removed, at any depth.
    public func removing(_ ids: Set<String>) -> KitoFolder {
        var copy = self
        copy.files.removeAll { ids.contains($0.id) }
        copy.folders = folders.filter { !ids.contains($0.id) }.map { $0.removing(ids) }
        return copy
    }

    /// A copy with `newFiles` appended to the folder with `folderID`.
    public func inserting(_ newFiles: [KitoFileItem], into folderID: String) -> KitoFolder {
        var copy = self
        if id == folderID {
            copy.files.append(contentsOf: newFiles)
            return copy
        }
        copy.folders = folders.map { $0.inserting(newFiles, into: folderID) }
        return copy
    }

    /// A copy with the files in `ids` moved into the folder with `folderID`.
    public func moving(_ ids: Set<String>, to folderID: String) -> KitoFolder {
        let moved = allFiles.filter { ids.contains($0.id) }
        guard !moved.isEmpty, folder(withID: folderID) != nil else { return self }
        return removing(ids).inserting(moved, into: folderID)
    }

    /// Every folder inside, at any depth, with its depth (0 for direct children).
    public func descendantFolders(depth: Int = 0) -> [(folder: KitoFolder, depth: Int)] {
        folders.flatMap { [($0, depth)] + $0.descendantFolders(depth: depth + 1) }
    }
}
