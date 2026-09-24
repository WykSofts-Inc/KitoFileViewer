//
//  KitoFileBrowserModel.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import Observation

/// List or grid.
public enum KitoFileLayout: String, CaseIterable, Hashable, Sendable {
    case list, grid

    public var systemImage: String { self == .list ? "list.bullet" : "square.grid.2x2" }
    public var title: String { self == .list ? "List" : "Grid" }
}

/// The state behind `KitoFileList`, `KitoFileGrid` and `KitoFileBrowser`: the folder tree, where you
/// are in it, sort, grouping, search and selection.
///
/// ```swift
/// @State private var files = KitoFileBrowserModel(root: KitoFolder.load(from: documentsURL))
///
/// KitoFileBrowser(model: files) { file in preview = file }
/// files.sort = KitoFileSort(.size)
/// files.grouping = .kind
/// files.open(folder)                 // pushes onto the breadcrumb path
/// ```
@Observable
@MainActor
public final class KitoFileBrowserModel {
    /// The whole tree. Edits (delete, move) replace it with an updated copy.
    public var root: KitoFolder
    /// Folder ids from the root down to the folder being shown.
    public private(set) var pathIDs: [String]
    public var sort: KitoFileSort
    public var grouping: KitoFileGrouping
    public var layout: KitoFileLayout
    /// The search text. While it isn't empty, results come from the current folder and everything inside it.
    public var query: String = ""
    /// Whether rows show checkmarks and the bottom action bar is up.
    public var isSelecting: Bool = false {
        didSet { if !isSelecting { selection.removeAll() } }
    }
    public var selection: Set<String> = []

    /// Called after files are deleted from the tree, so you can remove them from disk or your server.
    @ObservationIgnored public var onDelete: (([KitoFileItem]) -> Void)?
    /// Called after files are moved, with the destination folder.
    @ObservationIgnored public var onMove: (([KitoFileItem], KitoFolder) -> Void)?

    public init(root: KitoFolder, sort: KitoFileSort = .name, grouping: KitoFileGrouping = .none,
                layout: KitoFileLayout = .list) {
        self.root = root
        self.pathIDs = [root.id]
        self.sort = sort
        self.grouping = grouping
        self.layout = layout
    }

    /// A model for a flat list of files with no folders.
    public convenience init(files: [KitoFileItem], title: String = "Files", sort: KitoFileSort = .name,
                            grouping: KitoFileGrouping = .none, layout: KitoFileLayout = .list) {
        self.init(root: KitoFolder(name: title, files: files), sort: sort, grouping: grouping, layout: layout)
    }

    // MARK: Reading

    /// The folders from the root to the one shown.
    public var path: [KitoFolder] {
        root.path(to: pathIDs.last ?? root.id) ?? [root]
    }

    /// The folder being shown.
    public var currentFolder: KitoFolder { path.last ?? root }

    /// The breadcrumb for the path.
    public var breadcrumbs: [KitoBreadcrumbItem] { KitoBreadcrumb.items(for: path) }

    public var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    /// Subfolders to show (none while searching).
    public var visibleFolders: [KitoFolder] {
        isSearching ? [] : sort.sorted(currentFolder.folders)
    }

    /// The files to show: the current folder's, or search results from it and its subfolders.
    public var visibleFiles: [KitoFileItem] {
        isSearching ? KitoFileFilter.filter(currentFolder.allFiles, query: query) : currentFolder.files
    }

    /// The visible files sorted and grouped.
    public var groups: [KitoFileGroup] {
        KitoFileGroup.make(visibleFiles, sort: sort, grouping: grouping)
    }

    /// Whether there is nothing at all to show.
    public var isEmpty: Bool { visibleFolders.isEmpty && visibleFiles.isEmpty }

    public var selectedFiles: [KitoFileItem] {
        currentFolder.allFiles.filter { selection.contains($0.id) }
    }

    /// Local URLs of the selected files, for sharing.
    public var selectedURLs: [URL] {
        selectedFiles.compactMap { $0.isLocal ? $0.url : nil }
    }

    /// Every folder except the current one, for a "Move to" menu.
    public var moveDestinations: [(folder: KitoFolder, depth: Int)] {
        let all = [(folder: root, depth: 0)] + root.descendantFolders(depth: 1)
        return all.filter { $0.folder.id != currentFolder.id }
    }

    // MARK: Navigation

    /// Shows a subfolder of the current folder (or any folder in the tree).
    public func open(_ folder: KitoFolder) {
        guard let newPath = root.path(to: folder.id) else { return }
        pathIDs = newPath.map(\.id)
        query = ""
        isSelecting = false
    }

    /// Goes back to a folder on the breadcrumb path.
    public func goTo(_ crumb: KitoBreadcrumbItem) {
        guard let index = pathIDs.firstIndex(of: crumb.id) else { return }
        pathIDs = Array(pathIDs.prefix(index + 1))
        isSelecting = false
    }

    /// Goes up one folder. Returns `false` at the root.
    @discardableResult
    public func goUp() -> Bool {
        guard pathIDs.count > 1 else { return false }
        pathIDs.removeLast()
        isSelecting = false
        return true
    }

    public var canGoUp: Bool { pathIDs.count > 1 }

    // MARK: Selection

    public func toggleSelection(_ file: KitoFileItem) {
        if selection.contains(file.id) { selection.remove(file.id) } else { selection.insert(file.id) }
    }

    public func isSelected(_ file: KitoFileItem) -> Bool { selection.contains(file.id) }

    public func selectAll() { selection = Set(visibleFiles.map(\.id)) }

    public var allSelected: Bool { !visibleFiles.isEmpty && selection.count == visibleFiles.count }

    // MARK: Editing

    /// Removes files from the tree and calls `onDelete`.
    public func delete(_ files: [KitoFileItem]) {
        let ids = Set(files.map(\.id))
        guard !ids.isEmpty else { return }
        root = root.removing(ids)
        selection.subtract(ids)
        if selection.isEmpty { isSelecting = false }
        onDelete?(files)
    }

    /// Deletes the selected files.
    public func deleteSelection() { delete(selectedFiles) }

    /// Moves files into another folder and calls `onMove`.
    public func move(_ files: [KitoFileItem], to folder: KitoFolder) {
        let ids = Set(files.map(\.id))
        guard !ids.isEmpty else { return }
        root = root.moving(ids, to: folder.id)
        selection.subtract(ids)
        if selection.isEmpty { isSelecting = false }
        onMove?(files, folder)
    }

    /// Adds files to the current folder.
    public func add(_ files: [KitoFileItem]) {
        root = root.inserting(files, into: currentFolder.id)
    }

    /// Replaces the tree (e.g. after reloading from disk), keeping as much of the path as still exists.
    public func reload(_ newRoot: KitoFolder) {
        root = newRoot
        let kept = pathIDs.filter { newRoot.folder(withID: $0) != nil }
        pathIDs = kept.isEmpty ? [newRoot.id] : kept
    }
}
