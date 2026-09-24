//
//  KitoPDFViewer.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import PDFKit
import KitoCore

/// A PDF viewer built on PDFKit: continuous pages, a "3 / 12" page indicator, a strip of page
/// thumbnails, search with every match highlighted and a result stepper, zoom and share.
///
/// ```swift
/// KitoPDFViewer(url: invoiceURL)
///
/// @State private var pdf = KitoPDFViewerModel(url: reportURL)
/// KitoPDFViewer(model: pdf, showsThumbnails: false, tint: .red)
/// ```
public struct KitoPDFViewer: View {
    @State private var model: KitoPDFViewerModel
    private let showsThumbnails: Bool
    private let showsShareButton: Bool
    private let tint: Color?

    @State private var searchVisible = false
    @State private var stripVisible = true
    @FocusState private var searchFocused: Bool
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(url: URL, showsThumbnails: Bool = true, showsShareButton: Bool = true, tint: Color? = nil) {
        self.init(model: KitoPDFViewerModel(url: url), showsThumbnails: showsThumbnails,
                  showsShareButton: showsShareButton, tint: tint)
    }

    public init(model: KitoPDFViewerModel, showsThumbnails: Bool = true, showsShareButton: Bool = true,
                tint: Color? = nil) {
        self._model = State(initialValue: model)
        self.showsThumbnails = showsThumbnails
        self.showsShareButton = showsShareButton
        self.tint = tint
    }

    public var body: some View {
        let accent = tint ?? theme.colors.primary
        VStack(spacing: 0) {
            if searchVisible {
                KitoPDFSearchBar(model: model, focused: $searchFocused, tint: accent) { closeSearch() }
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            if model.document == nil {
                KitoFilePreviewUnavailable(title: "Can't open this PDF",
                                           message: "The file is missing or damaged.")
            } else {
                pages(accent: accent)
            }
            if showsThumbnails, stripVisible, model.pageCount > 1 {
                KitoPDFThumbnailStrip(model: model, tint: accent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            controls(accent: accent)
        }
        .background(theme.colors.surfaceMuted.opacity(0.6))
        .animation(animation, value: searchVisible)
        .animation(animation, value: stripVisible)
    }

    private var animation: Animation? {
        reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85)
    }

    private func pages(accent: Color) -> some View {
        KitoPDFKitView(model: model)
            .overlay(alignment: .top) {
                if model.pageCount > 0 {
                    Text(model.pageLabel)
                        .font(theme.typography.label.weight(.semibold).monospacedDigit())
                        .contentTransition(.numericText())
                        .foregroundStyle(.white)
                        .padding(.horizontal, theme.spacing.sm)
                        .padding(.vertical, theme.spacing.xxs + 2)
                        .background(Capsule().fill(.black.opacity(0.65)))
                        .padding(.top, theme.spacing.sm)
                        .animation(animation, value: model.pageIndex)
                        .accessibilityLabel("Page \(model.pageIndex + 1) of \(model.pageCount)")
                }
            }
    }

    private func controls(accent: Color) -> some View {
        HStack(spacing: theme.spacing.xs) {
            KitoControlButton(systemImage: "magnifyingglass", label: "Search", isOn: searchVisible, tint: accent) {
                if searchVisible { closeSearch() } else { openSearch() }
            }
            if showsThumbnails, model.pageCount > 1 {
                KitoControlButton(systemImage: "rectangle.grid.1x2", label: "Page thumbnails",
                                  isOn: stripVisible, tint: accent) { stripVisible.toggle() }
            }
            Spacer(minLength: 0)
            zoomControls
            Spacer(minLength: 0)
            if showsShareButton, let url = model.url {
                ShareLink(item: url) {
                    KitoControlIcon(systemImage: "square.and.arrow.up", isOn: false, tint: accent)
                }
                .accessibilityLabel("Share")
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .background(.bar)
    }

    private var zoomControls: some View {
        HStack(spacing: 0) {
            Button { model.zoomOut() } label: {
                Image(systemName: "minus").frame(width: 36, height: 34)
            }
            .accessibilityLabel("Zoom out")
            Button { model.resetZoom() } label: {
                Text(model.zoomLabel)
                    .font(theme.typography.caption.weight(.semibold).monospacedDigit())
                    .frame(minWidth: 48, minHeight: 34)
            }
            .accessibilityLabel("Zoom \(model.zoomLabel), reset")
            Button { model.zoomIn() } label: {
                Image(systemName: "plus").frame(width: 36, height: 34)
            }
            .accessibilityLabel("Zoom in")
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(theme.colors.onSurface)
        .buttonStyle(.plain)
        .background(Capsule().fill(theme.colors.surfaceMuted))
    }

    private func openSearch() {
        searchVisible = true
        searchFocused = true
    }

    private func closeSearch() {
        searchFocused = false
        searchVisible = false
        model.endSearch()
    }
}

/// Hosts the model's PDFView.
struct KitoPDFKitView: UIViewRepresentable {
    let model: KitoPDFViewerModel

    func makeUIView(context: Context) -> PDFView { model.pdfView }
    func updateUIView(_ view: PDFView, context: Context) {}
}

/// A round toolbar icon that fills with the tint when on.
struct KitoControlIcon: View {
    let systemImage: String
    let isOn: Bool
    let tint: Color
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .frame(width: 36, height: 36)
            .foregroundStyle(isOn ? theme.colors.onPrimary : theme.colors.onSurface)
            .background(Circle().fill(isOn ? tint : theme.colors.surfaceMuted))
    }
}

struct KitoControlButton: View {
    let systemImage: String
    let label: String
    let isOn: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            KitoControlIcon(systemImage: systemImage, isOn: isOn, tint: tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
