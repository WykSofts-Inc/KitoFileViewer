//
//  KitoFileList.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Files and folders as a list, with sort, grouping, search, breadcrumbs, swipe actions,
/// a context menu and selection mode with a bottom action bar.
///
/// ```swift
/// @State private var files = KitoFileBrowserModel(root: folder, grouping: .kind)
///
/// KitoFileList(model: files) { file in preview = file }
///     .fullScreenCover(item: $preview) { KitoFilePreview($0) }
/// ```
///
/// Swipe left on a file to share or delete it; long-press for Open, Share, Move and Delete.
public struct KitoFileList: View {
    @Bindable private var model: KitoFileBrowserModel
    private let options: KitoFileBrowserOptions
    private let tint: Color?
    private let onOpen: (KitoFileItem) -> Void

    @State private var sharing: KitoShareRequest?
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - model: The files, folder path, sort, grouping, search and selection.
    ///   - options: Which parts of the header and which actions to show.
    ///   - tint: Accent for the current breadcrumb, selection and actions. Defaults to the theme's primary.
    ///   - onOpen: Called when a file is tapped outside selection mode.
    public init(model: KitoFileBrowserModel, options: KitoFileBrowserOptions = .init(), tint: Color? = nil,
                onOpen: @escaping (KitoFileItem) -> Void) {
        self.model = model
        self.options = options
        self.tint = tint
        self.onOpen = onOpen
    }

    public var body: some View {
        let accent = tint ?? theme.colors.primary
        VStack(spacing: 0) {
            if options.showsHeader {
                KitoFileBrowserHeader(model: model, showsBreadcrumbs: options.showsBreadcrumbs,
                                      showsSearch: options.showsSearch, showsLayoutToggle: options.showsLayoutToggle,
                                      tint: accent)
            }
            if model.isEmpty {
                emptyState
                    .frame(maxHeight: .infinity)
            } else {
                list(accent: accent)
            }
        }
        .background(theme.colors.background)
        .safeAreaInset(edge: .bottom) {
            if model.isSelecting {
                KitoFileSelectionBar(model: model, allowsMove: options.allowsMove,
                                     allowsDelete: options.allowsDelete, tint: accent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(animation, value: model.isSelecting)
        .sheet(item: $sharing) { request in
            KitoActivitySheet(items: request.urls)
                .presentationDetents([.medium, .large])
                .ignoresSafeArea()
        }
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.isSearching {
            KitoFileEmptyState(title: "No results", message: "Nothing matches “\(model.query)”.", tint: tint)
        } else {
            KitoFileEmptyState(title: options.emptyTitle, message: options.emptyMessage, tint: tint)
        }
    }

    private func list(accent: Color) -> some View {
        List {
            if !model.visibleFolders.isEmpty {
                Section {
                    ForEach(model.visibleFolders) { folder in
                        Button { withAnimation(animation) { model.open(folder) } } label: {
                            KitoFolderRow(folder, tint: options.folderTint)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    KitoGroupHeader(title: "Folders", count: model.visibleFolders.count, kind: nil)
                }
            }
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.files) { file in
                        fileRow(file, accent: accent)
                    }
                } header: {
                    if !group.title.isEmpty {
                        KitoGroupHeader(title: group.title, count: group.files.count, kind: group.kind)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .animation(animation, value: model.sort)
        .animation(animation, value: model.grouping)
    }

    private func fileRow(_ file: KitoFileItem, accent: Color) -> some View {
        Button { tap(file) } label: {
            KitoFileRow(file, isSelecting: model.isSelecting, isSelected: model.isSelected(file),
                        showsThumbnail: options.showsThumbnails, subtitle: searchSubtitle(file), tint: accent)
        }
        .buttonStyle(.plain)
        .listRowBackground(model.isSelected(file) ? accent.opacity(0.08) : Color.clear)
        .swipeActions(edge: .trailing, allowsFullSwipe: options.allowsDelete) {
            if options.allowsDelete {
                Button(role: .destructive) { withAnimation(animation) { model.delete([file]) } } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            if file.isLocal, let url = file.url {
                Button { sharing = KitoShareRequest(urls: [url]) } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .tint(accent)
            }
        }
        .contextMenu { KitoFileContextMenu(file: file, model: model, options: options, onOpen: onOpen) }
    }

    private func tap(_ file: KitoFileItem) {
        if model.isSelecting {
            model.toggleSelection(file)
        } else {
            onOpen(file)
        }
    }

    private func searchSubtitle(_ file: KitoFileItem) -> String? {
        guard model.isSearching, !model.currentFolder.files.contains(where: { $0.id == file.id }) else { return nil }
        let folderName = model.currentFolder.descendantFolders()
            .first { $0.folder.files.contains { $0.id == file.id } }?.folder.name
        guard let folderName else { return nil }
        return "In \(folderName) · \(file.detailText())"
    }
}

/// Which parts of `KitoFileList`, `KitoFileGrid` and `KitoFileBrowser` to show.
public struct KitoFileBrowserOptions: Sendable {
    public var showsHeader: Bool
    public var showsBreadcrumbs: Bool
    public var showsSearch: Bool
    public var showsLayoutToggle: Bool
    public var showsThumbnails: Bool
    public var allowsDelete: Bool
    public var allowsMove: Bool
    public var emptyTitle: String
    public var emptyMessage: String
    public var folderTint: Color?

    public init(showsHeader: Bool = true, showsBreadcrumbs: Bool = true, showsSearch: Bool = true,
                showsLayoutToggle: Bool = false, showsThumbnails: Bool = true, allowsDelete: Bool = true,
                allowsMove: Bool = true, emptyTitle: String = "This folder is empty",
                emptyMessage: String = "Files you add appear here.", folderTint: Color? = nil) {
        self.showsHeader = showsHeader
        self.showsBreadcrumbs = showsBreadcrumbs
        self.showsSearch = showsSearch
        self.showsLayoutToggle = showsLayoutToggle
        self.showsThumbnails = showsThumbnails
        self.allowsDelete = allowsDelete
        self.allowsMove = allowsMove
        self.emptyTitle = emptyTitle
        self.emptyMessage = emptyMessage
        self.folderTint = folderTint
    }
}

/// A section header: kind badge, title and count.
struct KitoGroupHeader: View {
    let title: String
    let count: Int
    let kind: KitoFileKind?
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xs) {
            if let kind {
                Circle().fill(kind.color).frame(width: 8, height: 8)
            }
            Text(title)
                .font(theme.typography.label.weight(.semibold))
                .foregroundStyle(theme.colors.onBackground)
            Text("\(count)")
                .font(theme.typography.caption.weight(.semibold))
                .foregroundStyle(theme.colors.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Capsule().fill(theme.colors.surfaceMuted))
            Spacer(minLength: 0)
        }
        .textCase(nil)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Open, Share, Move to and Delete, shared by the list and the grid.
struct KitoFileContextMenu: View {
    let file: KitoFileItem
    let model: KitoFileBrowserModel
    let options: KitoFileBrowserOptions
    let onOpen: (KitoFileItem) -> Void

    var body: some View {
        Button { onOpen(file) } label: { Label("Open", systemImage: "eye") }
        if file.isLocal, let url = file.url {
            ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
        }
        if options.allowsMove, !model.moveDestinations.isEmpty {
            Menu {
                ForEach(model.moveDestinations, id: \.folder.id) { destination in
                    Button(destination.folder.name) { withAnimation { model.move([file], to: destination.folder) } }
                }
            } label: {
                Label("Move to", systemImage: "folder")
            }
        }
        if options.allowsDelete {
            Divider()
            Button(role: .destructive) { withAnimation { model.delete([file]) } } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// URLs waiting to be shared from a swipe action.
struct KitoShareRequest: Identifiable {
    let id = UUID()
    let urls: [URL]
}

/// The system share sheet.
struct KitoActivitySheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
