//
//  KitoFileRow.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A file row: badge or thumbnail, name, "240 KB · 12 Sep 2026", and a checkmark in selection mode.
///
/// ```swift
/// KitoFileRow(file, isSelecting: selecting, isSelected: picked.contains(file.id))
/// ```
public struct KitoFileRow: View {
    private let file: KitoFileItem
    private let isSelecting: Bool
    private let isSelected: Bool
    private let showsThumbnail: Bool
    private let subtitle: String?
    private let tint: Color?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameter subtitle: Replaces the size and date line, e.g. with the folder a search result is in.
    public init(_ file: KitoFileItem, isSelecting: Bool = false, isSelected: Bool = false,
                showsThumbnail: Bool = true, subtitle: String? = nil, tint: Color? = nil) {
        self.file = file
        self.isSelecting = isSelecting
        self.isSelected = isSelected
        self.showsThumbnail = showsThumbnail
        self.subtitle = subtitle
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: theme.spacing.md) {
            if isSelecting {
                KitoSelectionMark(isSelected: isSelected, tint: tint ?? theme.colors.primary)
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            KitoFileIcon(file, size: 44, showsThumbnail: showsThumbnail)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(file.name)
                    .font(theme.typography.bodyEmphasized)
                    .foregroundStyle(theme.colors.onSurface)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle ?? file.detailText())
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, theme.spacing.xs)
        .contentShape(Rectangle())
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: isSelecting)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.name), \(file.kind.singularTitle)")
        .accessibilityValue(file.detailText())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// A folder row with its item count and a chevron.
public struct KitoFolderRow: View {
    private let folder: KitoFolder
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    public init(_ folder: KitoFolder, tint: Color? = nil) {
        self.folder = folder
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: theme.spacing.md) {
            KitoFolderIcon(size: 40, tint: tint)
                .frame(width: 48)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(folder.name)
                    .font(theme.typography.bodyEmphasized)
                    .foregroundStyle(theme.colors.onSurface)
                    .lineLimit(1)
                Text(folder.itemCountText)
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.colors.secondary.opacity(0.7))
        }
        .padding(.vertical, theme.spacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.name), folder, \(folder.itemCountText)")
        .accessibilityAddTraits(.isButton)
    }
}

/// A round checkmark that pops when selected.
struct KitoSelectionMark: View {
    let isSelected: Bool
    let tint: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(theme.colors.border, lineWidth: 1.5)
                .opacity(isSelected ? 0 : 1)
            Circle()
                .fill(tint)
                .scaleEffect(isSelected ? 1 : 0.3)
                .opacity(isSelected ? 1 : 0)
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(theme.colors.onPrimary)
                .scaleEffect(isSelected ? 1 : 0.2)
                .opacity(isSelected ? 1 : 0)
        }
        .frame(width: 24, height: 24)
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
        .accessibilityHidden(true)
    }
}

/// A grid tile: a large badge or thumbnail over the name and size.
struct KitoFileTile: View {
    let file: KitoFileItem
    let isSelecting: Bool
    let isSelected: Bool
    let tint: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            KitoFileIcon(file, size: 76, showsThumbnail: true)
                .frame(height: 84)
                .scaleEffect(isSelected ? 0.92 : 1)
                .overlay(alignment: .topTrailing) {
                    if isSelecting {
                        KitoSelectionMark(isSelected: isSelected, tint: tint)
                            .background(Circle().fill(theme.colors.surface))
                            .offset(x: 6, y: -6)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
            Text(file.name)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
            Text(file.size.map(KitoByteCount.string) ?? " ")
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .padding(theme.spacing.sm)
        .frame(maxWidth: .infinity)
        .background(tileBackground)
        .contentShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
        .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.75), value: isSelected)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(file.name), \(file.kind.singularTitle)")
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
            .fill(isSelected ? tint.opacity(0.12) : theme.colors.surfaceMuted.opacity(0.5))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                .strokeBorder(isSelected ? tint.opacity(0.6) : .clear, lineWidth: 1.5))
    }
}

/// A folder tile for the grid.
struct KitoFolderTile: View {
    let folder: KitoFolder
    let tint: Color?
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.xs) {
            KitoFolderIcon(size: 72, tint: tint)
                .frame(height: 84)
            Text(folder.name)
                .font(theme.typography.label)
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            Text(folder.itemCountText)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.secondary)
        }
        .padding(theme.spacing.sm)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
            .fill(theme.colors.surfaceMuted.opacity(0.5)))
        .contentShape(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(folder.name), folder, \(folder.itemCountText)")
        .accessibilityAddTraits(.isButton)
    }
}
