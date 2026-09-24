//
//  KitoPDFSearchBar.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Search in a PDF: the field, "2 of 7", previous and next, and the words around the match.
struct KitoPDFSearchBar: View {
    @Bindable var model: KitoPDFViewerModel
    var focused: FocusState<Bool>.Binding
    let tint: Color
    let onDone: () -> Void

    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xs) {
            HStack(spacing: theme.spacing.xs) {
                field
                stepper
                Button("Done", action: onDone)
                    .font(theme.typography.label.weight(.semibold))
                    .foregroundStyle(tint)
            }
            if let result = model.currentResult {
                Text("Page \(result.pageIndex + 1)  ").font(theme.typography.caption.weight(.semibold))
                    .foregroundStyle(tint)
                + Text(result.snippet).font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
            }
        }
        .lineLimit(1)
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(.bar)
    }

    private var field: some View {
        HStack(spacing: theme.spacing.xs) {
            Image(systemName: "magnifyingglass").foregroundStyle(theme.colors.secondary)
            TextField("Find in document", text: $model.searchQuery)
                .focused(focused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { model.nextResult() }
            if model.isSearching {
                ProgressView().controlSize(.small)
            } else if !model.searchQuery.isEmpty {
                Text(model.cursor.label)
                    .font(theme.typography.caption.monospacedDigit())
                    .foregroundStyle(theme.colors.secondary)
                    .contentTransition(.numericText())
                    .fixedSize()
            }
        }
        .font(theme.typography.body)
        .padding(.horizontal, theme.spacing.sm)
        .frame(height: 38)
        .background(Capsule().fill(theme.colors.surfaceMuted))
    }

    private var stepper: some View {
        HStack(spacing: 2) {
            Button { model.previousResult() } label: {
                Image(systemName: "chevron.up").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Previous match")
            Button { model.nextResult() } label: {
                Image(systemName: "chevron.down").frame(width: 32, height: 32)
            }
            .accessibilityLabel("Next match")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(theme.colors.onSurface)
        .buttonStyle(.plain)
        .disabled(model.results.isEmpty)
        .opacity(model.results.isEmpty ? 0.4 : 1)
    }
}

/// A row of page thumbnails; the current page is outlined and kept in view.
struct KitoPDFThumbnailStrip: View {
    let model: KitoPDFViewerModel
    let tint: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: theme.spacing.sm) {
                    ForEach(0..<model.pageCount, id: \.self) { index in
                        Button { model.go(toPage: index) } label: {
                            KitoPDFThumbnail(model: model, index: index, isCurrent: index == model.pageIndex,
                                             hasMatch: pagesWithMatches.contains(index), tint: tint)
                        }
                        .buttonStyle(.plain)
                        .id(index)
                    }
                }
                .padding(.horizontal, theme.spacing.md)
                .padding(.vertical, theme.spacing.sm)
            }
            .frame(height: 112)
            .onChange(of: model.pageIndex) { _, index in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.25)) { proxy.scrollTo(index, anchor: .center) }
            }
        }
        .background(.bar)
    }

    private var pagesWithMatches: Set<Int> { Set(model.results.map(\.pageIndex)) }
}

struct KitoPDFThumbnail: View {
    let model: KitoPDFViewerModel
    let index: Int
    let isCurrent: Bool
    let hasMatch: Bool
    let tint: Color

    @State private var image: UIImage?
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                RoundedRectangle(cornerRadius: 4).fill(Color.white)
                if let image {
                    Image(uiImage: image).resizable().scaledToFit()
                }
            }
            .frame(width: 54, height: 70)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(isCurrent ? tint : theme.colors.border,
                                                                   lineWidth: isCurrent ? 2.5 : 0.5))
            .overlay(alignment: .topTrailing) {
                if hasMatch {
                    Circle().fill(Color.yellow).frame(width: 9, height: 9)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .offset(x: 3, y: -3)
                }
            }
            .shadow(color: .black.opacity(isCurrent ? 0.2 : 0.08), radius: isCurrent ? 6 : 2, y: 2)
            .scaleEffect(isCurrent ? 1.06 : 1)
            Text("\(index + 1)")
                .font(theme.typography.caption.weight(isCurrent ? .bold : .regular).monospacedDigit())
                .foregroundStyle(isCurrent ? tint : theme.colors.secondary)
        }
        .animation(.easeOut(duration: 0.2), value: isCurrent)
        .task { image = model.thumbnail(forPage: index) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(index + 1)")
        .accessibilityAddTraits(isCurrent ? [.isSelected, .isButton] : .isButton)
    }
}

/// Shown when a file can't be previewed.
struct KitoFilePreviewUnavailable: View {
    let title: String
    let message: String
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        VStack(spacing: theme.spacing.sm) {
            Image(systemName: "eye.slash")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(theme.colors.secondary)
            Text(title)
                .font(theme.typography.titleMedium)
                .foregroundStyle(theme.colors.onBackground)
            Text(message)
                .font(theme.typography.body)
                .foregroundStyle(theme.colors.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(theme.spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
