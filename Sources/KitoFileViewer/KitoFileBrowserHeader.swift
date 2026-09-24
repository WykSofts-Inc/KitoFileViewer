//
//  KitoFileBrowserHeader.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Breadcrumbs, a search field and a toolbar with sort, grouping, layout and Select.
struct KitoFileBrowserHeader: View {
    @Bindable var model: KitoFileBrowserModel
    let showsBreadcrumbs: Bool
    let showsSearch: Bool
    let showsLayoutToggle: Bool
    let tint: Color

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.sm) {
            if showsBreadcrumbs, model.path.count > 1 || model.root.folders.count > 0 {
                KitoBreadcrumbBar(model.breadcrumbs, tint: tint) { crumb in
                    withAnimation(animation) { model.goTo(crumb) }
                }
                .padding(.horizontal, -theme.spacing.md)
            }
            if showsSearch {
                KitoFileSearchField(text: $model.query, tint: tint)
            }
            toolbar
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.top, theme.spacing.sm)
        .padding(.bottom, theme.spacing.xs)
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    private var toolbar: some View {
        HStack(spacing: theme.spacing.sm) {
            Text(summary)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
                .contentTransition(.numericText())
            Spacer(minLength: 0)
            sortMenu
            if showsLayoutToggle { layoutToggle }
            selectButton
        }
    }

    private var summary: String {
        let files = model.visibleFiles.count
        let folders = model.visibleFolders.count
        if model.isSearching { return files == 1 ? "1 result" : "\(files) results" }
        if model.isSelecting { return "\(model.selection.count) selected" }
        var parts: [String] = []
        if folders > 0 { parts.append(folders == 1 ? "1 folder" : "\(folders) folders") }
        parts.append(files == 1 ? "1 file" : "\(files) files")
        return parts.joined(separator: ", ")
    }

    private var sortMenu: some View {
        Menu {
            Section("Sort by") {
                ForEach(KitoFileSort.Field.allCases, id: \.self) { field in
                    Button { chooseSort(field) } label: {
                        if model.sort.field == field {
                            Label(field.title, systemImage: model.sort.ascending ? "chevron.up" : "chevron.down")
                        } else {
                            Text(field.title)
                        }
                    }
                }
            }
            Section("Group by") {
                Picker("Group by", selection: $model.grouping) {
                    ForEach(KitoFileGrouping.allCases, id: \.self) { Text($0.title).tag($0) }
                }
            }
        } label: {
            KitoHeaderChip(title: model.sort.field.title, systemImage: "arrow.up.arrow.down", tint: tint)
        }
        .accessibilityLabel("Sort and group, sorted by \(model.sort.field.title)")
    }

    private func chooseSort(_ field: KitoFileSort.Field) {
        withAnimation(animation) {
            if model.sort.field == field {
                model.sort.ascending.toggle()
            } else {
                model.sort = KitoFileSort(field)
            }
        }
    }

    private var layoutToggle: some View {
        Button {
            withAnimation(animation) { model.layout = model.layout == .list ? .grid : .list }
        } label: {
            Image(systemName: model.layout == .list ? KitoFileLayout.grid.systemImage : KitoFileLayout.list.systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(width: 32, height: 32)
                .foregroundStyle(theme.colors.onSurface)
                .background(Circle().fill(theme.colors.surfaceMuted))
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(model.layout == .list ? "Show as grid" : "Show as list")
    }

    private var selectButton: some View {
        Button {
            withAnimation(animation) { model.isSelecting.toggle() }
        } label: {
            Text(model.isSelecting ? "Done" : "Select")
                .font(theme.typography.label.weight(.semibold))
                .padding(.horizontal, theme.spacing.sm)
                .frame(height: 32)
                .foregroundStyle(model.isSelecting ? theme.colors.onPrimary : theme.colors.onSurface)
                .background(Capsule().fill(model.isSelecting ? tint : theme.colors.surfaceMuted))
        }
        .buttonStyle(.plain)
        .disabled(model.visibleFiles.isEmpty && !model.isSelecting)
    }
}

/// A small capsule used in the header toolbar.
struct KitoHeaderChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        HStack(spacing: theme.spacing.xxs) {
            Image(systemName: systemImage).font(.caption.weight(.bold))
            Text(title).font(theme.typography.label.weight(.semibold))
        }
        .padding(.horizontal, theme.spacing.sm)
        .frame(height: 32)
        .foregroundStyle(theme.colors.onSurface)
        .background(Capsule().fill(theme.colors.surfaceMuted))
    }
}

/// The search field above files: a filled capsule that lights up with the tint when focused.
public struct KitoFileSearchField: View {
    @Binding private var text: String
    private let prompt: String
    private let tint: Color?
    @FocusState private var focused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(text: Binding<String>, prompt: String = "Search files", tint: Color? = nil) {
        self._text = text
        self.prompt = prompt
        self.tint = tint
    }

    public var body: some View {
        let accent = tint ?? theme.colors.primary
        return HStack(spacing: theme.spacing.xs) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(focused ? accent : theme.colors.secondary)
            TextField(prompt, text: $text)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .foregroundStyle(theme.colors.onSurface)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(theme.colors.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .font(theme.typography.body)
        .padding(.horizontal, theme.spacing.md)
        .frame(height: 42)
        .background(Capsule().fill(theme.colors.surfaceMuted))
        .overlay(Capsule().strokeBorder(focused ? accent.opacity(0.7) : .clear, lineWidth: 1.5))
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: focused)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: text.isEmpty)
    }
}
