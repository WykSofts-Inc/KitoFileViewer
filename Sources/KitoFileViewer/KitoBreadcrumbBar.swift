//
//  KitoBreadcrumbBar.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A tappable folder path: "Documents › School › 2026". Earlier steps go back; the last is the current folder.
/// Long paths collapse their middle into "…", which goes back to the last hidden folder.
///
/// ```swift
/// KitoBreadcrumbBar(model.breadcrumbs) { crumb in model.goTo(crumb) }
/// ```
public struct KitoBreadcrumbBar: View {
    private let items: [KitoBreadcrumbItem]
    private let maxVisible: Int
    private let tint: Color?
    private let onSelect: (KitoBreadcrumbItem) -> Void

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var namespace

    public init(_ items: [KitoBreadcrumbItem], maxVisible: Int = 4, tint: Color? = nil,
                onSelect: @escaping (KitoBreadcrumbItem) -> Void) {
        self.items = items
        self.maxVisible = maxVisible
        self.tint = tint
        self.onSelect = onSelect
    }

    public var body: some View {
        let visible = KitoBreadcrumb.collapsed(items, maxVisible: maxVisible)
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: theme.spacing.xxs) {
                    ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.compact.right")
                                .flipsForRightToLeftLayoutDirection(true)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(theme.colors.secondary.opacity(0.6))
                                .accessibilityHidden(true)
                        }
                        crumb(item, isLast: index == visible.count - 1)
                            .id(item.id)
                            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                                    removal: .opacity))
                    }
                }
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.xxs)
            }
            .onChange(of: items.last?.id) { _, last in
                guard let last else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo(last, anchor: .trailing) }
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: items)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Folder path")
    }

    @ViewBuilder
    private func crumb(_ item: KitoBreadcrumbItem, isLast: Bool) -> some View {
        let accent = tint ?? theme.colors.primary
        Button { onSelect(item) } label: {
            HStack(spacing: theme.spacing.xxs) {
                if item.depth == 0, !item.isEllipsis {
                    Image(systemName: "folder.fill").font(.caption)
                }
                Text(item.title)
                    .font(isLast ? theme.typography.label.weight(.semibold) : theme.typography.label)
                    .lineLimit(1)
            }
            .padding(.horizontal, theme.spacing.sm)
            .padding(.vertical, theme.spacing.xxs + 2)
            .foregroundStyle(isLast ? theme.colors.onPrimary : theme.colors.onSurface)
            .background {
                if isLast {
                    Capsule().fill(accent).matchedGeometryEffect(id: "current", in: namespace)
                } else {
                    Capsule().fill(theme.colors.surfaceMuted)
                }
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isLast)
        .accessibilityLabel(item.isEllipsis ? "Hidden folders" : item.title)
        .accessibilityHint(isLast ? "Current folder" : "Goes back to this folder")
    }
}
