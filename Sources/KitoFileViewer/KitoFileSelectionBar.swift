//
//  KitoFileSelectionBar.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// The floating bar shown in selection mode: select all, share, move and delete.
struct KitoFileSelectionBar: View {
    @Bindable var model: KitoFileBrowserModel
    let allowsMove: Bool
    let allowsDelete: Bool
    let tint: Color

    @State private var confirmingDelete = false
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            action(model.allSelected ? "Deselect" : "All",
                   systemImage: model.allSelected ? "circle.dashed" : "checkmark.circle") {
                if model.allSelected { model.selection.removeAll() } else { model.selectAll() }
            }
            shareAction
            if allowsMove { moveMenu }
            if allowsDelete {
                action("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    .disabled(model.selection.isEmpty)
            }
        }
        .padding(.horizontal, theme.spacing.sm)
        .padding(.vertical, theme.spacing.xs)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(theme.colors.border.opacity(0.6), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
        .padding(.horizontal, theme.spacing.lg)
        .padding(.bottom, theme.spacing.sm)
        .confirmationDialog(deleteTitle, isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { model.deleteSelection() }
        }
    }

    private var deleteTitle: String {
        model.selection.count == 1 ? "Delete 1 file?" : "Delete \(model.selection.count) files?"
    }

    @ViewBuilder
    private var shareAction: some View {
        let urls = model.selectedURLs
        if urls.isEmpty {
            action("Share", systemImage: "square.and.arrow.up") {}
                .disabled(true)
        } else {
            ShareLink(items: urls) {
                KitoBarLabel(title: "Share", systemImage: "square.and.arrow.up", color: tint)
            }
            .buttonStyle(.plain)
        }
    }

    private var moveMenu: some View {
        Menu {
            ForEach(model.moveDestinations, id: \.folder.id) { destination in
                Button {
                    withAnimation { model.move(model.selectedFiles, to: destination.folder) }
                } label: {
                    Label(indented(destination.folder.name, depth: destination.depth), systemImage: "folder")
                }
            }
        } label: {
            KitoBarLabel(title: "Move", systemImage: "folder", color: tint)
        }
        .disabled(model.selection.isEmpty || model.moveDestinations.isEmpty)
    }

    private func indented(_ name: String, depth: Int) -> String {
        String(repeating: "   ", count: depth) + name
    }

    private func action(_ title: String, systemImage: String, role: ButtonRole? = nil,
                        perform: @escaping () -> Void) -> some View {
        Button(role: role, action: perform) {
            KitoBarLabel(title: title, systemImage: systemImage,
                         color: role == .destructive ? theme.colors.danger : tint)
        }
        .buttonStyle(.plain)
    }
}

/// An icon over a caption, used in the selection bar.
struct KitoBarLabel: View {
    let title: String
    let systemImage: String
    let color: Color
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage).font(.system(size: 18, weight: .semibold))
            Text(title).font(theme.typography.caption.weight(.medium))
        }
        .foregroundStyle(color)
        .opacity(isEnabled ? 1 : 0.35)
        .frame(maxWidth: .infinity, minHeight: 44)
        .contentShape(Rectangle())
    }
}

/// What to show when a folder or search has nothing in it.
///
/// ```swift
/// KitoFileEmptyState(title: "No downloads yet", message: "Files you save appear here.")
/// ```
public struct KitoFileEmptyState: View {
    private let title: String
    private let message: String
    private let tint: Color?
    @State private var floating = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(title: String = "No files", message: String = "Files you add appear here.", tint: Color? = nil) {
        self.title = title
        self.message = message
        self.tint = tint
    }

    public var body: some View {
        VStack(spacing: theme.spacing.md) {
            stack
                .frame(height: 110)
            Text(title)
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onBackground)
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .onAppear { floating = !reduceMotion }
    }

    private var stack: some View {
        ZStack {
            Circle()
                .fill((tint ?? theme.colors.primary).opacity(0.08))
                .frame(width: 120, height: 120)
            KitoFileBadge(kind: .sheet, label: "", color: KitoFileKind.sheet.color.opacity(0.9), size: 54)
                .rotationEffect(.degrees(-14))
                .offset(x: -30, y: floating ? 4 : 10)
            KitoFileBadge(kind: .doc, label: "", color: KitoFileKind.doc.color.opacity(0.9), size: 54)
                .rotationEffect(.degrees(12))
                .offset(x: 30, y: floating ? 2 : 8)
            KitoFileBadge(kind: .pdf, label: "PDF", color: KitoFileKind.pdf.color, size: 66)
                .offset(y: floating ? -8 : 0)
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: floating)
        .accessibilityHidden(true)
    }
}
