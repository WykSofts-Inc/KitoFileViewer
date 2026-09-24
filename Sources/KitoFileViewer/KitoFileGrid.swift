//
//  KitoFileGrid.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Files and folders as a grid of large badges and thumbnails, with the same header, grouping,
/// search, context menu and selection bar as `KitoFileList`.
///
/// ```swift
/// KitoFileGrid(model: files, minimumTileWidth: 104) { file in preview = file }
/// ```
public struct KitoFileGrid: View {
    @Bindable private var model: KitoFileBrowserModel
    private let options: KitoFileBrowserOptions
    private let minimumTileWidth: CGFloat
    private let tint: Color?
    private let onOpen: (KitoFileItem) -> Void

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: KitoFileBrowserModel, options: KitoFileBrowserOptions = .init(),
                minimumTileWidth: CGFloat = 100, tint: Color? = nil,
                onOpen: @escaping (KitoFileItem) -> Void) {
        self.model = model
        self.options = options
        self.minimumTileWidth = minimumTileWidth
        self.tint = tint
        self.onOpen = onOpen
    }

    public var body: some View {
        let accent = tint ?? theme.colors.primary
        ScrollView {
            VStack(spacing: 0) {
                if options.showsHeader {
                    KitoFileBrowserHeader(model: model, showsBreadcrumbs: options.showsBreadcrumbs,
                                          showsSearch: options.showsSearch,
                                          showsLayoutToggle: options.showsLayoutToggle, tint: accent)
                }
                if model.isEmpty {
                    emptyState.padding(.top, theme.spacing.xl)
                } else {
                    content(accent: accent)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.colors.background)
        .safeAreaInset(edge: .bottom) {
            if model.isSelecting {
                KitoFileSelectionBar(model: model, allowsMove: options.allowsMove,
                                     allowsDelete: options.allowsDelete, tint: accent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(animation, value: model.isSelecting)
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: minimumTileWidth), spacing: theme.spacing.sm)]
    }

    @ViewBuilder
    private var emptyState: some View {
        if model.isSearching {
            KitoFileEmptyState(title: "No results", message: "Nothing matches “\(model.query)”.", tint: tint)
        } else {
            KitoFileEmptyState(title: options.emptyTitle, message: options.emptyMessage, tint: tint)
        }
    }

    private func content(accent: Color) -> some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: theme.spacing.sm,
                  pinnedViews: [.sectionHeaders]) {
            if !model.visibleFolders.isEmpty {
                Section {
                    ForEach(model.visibleFolders) { folder in
                        Button { withAnimation(animation) { model.open(folder) } } label: {
                            KitoFolderTile(folder: folder, tint: options.folderTint)
                        }
                        .buttonStyle(KitoPressableStyle())
                    }
                } header: {
                    header(KitoGroupHeader(title: "Folders", count: model.visibleFolders.count, kind: nil))
                }
            }
            ForEach(model.groups) { group in
                Section {
                    ForEach(group.files) { file in
                        tile(file, accent: accent)
                    }
                } header: {
                    if !group.title.isEmpty {
                        header(KitoGroupHeader(title: group.title, count: group.files.count, kind: group.kind))
                    }
                }
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.bottom, theme.spacing.lg)
        .animation(animation, value: model.sort)
        .animation(animation, value: model.grouping)
    }

    private func header(_ content: KitoGroupHeader) -> some View {
        content
            .padding(.vertical, theme.spacing.xs)
            .background(theme.colors.background.opacity(0.95))
    }

    private func tile(_ file: KitoFileItem, accent: Color) -> some View {
        Button {
            if model.isSelecting { model.toggleSelection(file) } else { onOpen(file) }
        } label: {
            KitoFileTile(file: file, isSelecting: model.isSelecting, isSelected: model.isSelected(file), tint: accent)
        }
        .buttonStyle(KitoPressableStyle())
        .contextMenu { KitoFileContextMenu(file: file, model: model, options: options, onOpen: onOpen) }
    }
}

/// Shrinks slightly while pressed.
struct KitoPressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// A list or grid you can switch between from the header, with everything `KitoFileList` has.
///
/// ```swift
/// KitoFileBrowser(model: files) { file in preview = file }
///     .fullScreenCover(item: $preview) { KitoFilePreview($0) }
/// ```
public struct KitoFileBrowser: View {
    @Bindable private var model: KitoFileBrowserModel
    private let options: KitoFileBrowserOptions
    private let tint: Color?
    private let onOpen: (KitoFileItem) -> Void

    public init(model: KitoFileBrowserModel, options: KitoFileBrowserOptions = .init(), tint: Color? = nil,
                onOpen: @escaping (KitoFileItem) -> Void) {
        self.model = model
        var options = options
        options.showsLayoutToggle = true
        self.options = options
        self.tint = tint
        self.onOpen = onOpen
    }

    public var body: some View {
        Group {
            switch model.layout {
            case .list:
                KitoFileList(model: model, options: options, tint: tint, onOpen: onOpen)
            case .grid:
                KitoFileGrid(model: model, options: options, tint: tint, onOpen: onOpen)
            }
        }
        .transition(.opacity)
    }
}
