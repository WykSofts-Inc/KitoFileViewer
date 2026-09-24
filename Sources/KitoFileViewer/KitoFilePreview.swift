//
//  KitoFilePreview.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Which viewer `KitoFilePreview` uses.
public enum KitoPreviewMode: Hashable, Sendable {
    /// The package's PDF viewer.
    case pdf
    /// The zoomable image viewer.
    case image
    /// The line-numbered text and code viewer.
    case text
    /// QuickLook.
    case quickLook
    /// Nothing can show it (for example a remote file that hasn't been downloaded).
    case unavailable

    /// Picks a viewer: native ones for PDF, images, text, code and CSV; QuickLook for everything else it supports.
    @MainActor
    public static func mode(for file: KitoFileItem, preferQuickLook: Bool = false,
                            canQuickLook: @MainActor (URL) -> Bool = KitoQuickLookPreview.canPreview) -> KitoPreviewMode {
        guard file.isLocal, let url = file.url else { return .unavailable }
        let ext = file.pathExtension.lowercased()
        if !preferQuickLook {
            switch file.kind {
            case .pdf: return .pdf
            case .image where ext != "svg": return .image
            case .text, .code: return .text
            case .sheet where ext == "csv" || ext == "tsv": return .text
            default: break
            }
        }
        return canQuickLook(url) ? .quickLook : .unavailable
    }
}

/// A full-screen preview for any file: a header with the name, size, Share and Close, and the best
/// viewer for it — the PDF viewer, the image viewer, the text/code viewer, or QuickLook.
///
/// ```swift
/// .fullScreenCover(item: $preview) { file in
///     KitoFilePreview(file)
/// }
/// ```
public struct KitoFilePreview: View {
    private let file: KitoFileItem
    private let preferQuickLook: Bool
    private let tint: Color?
    private let onClose: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.kitoTheme) private var theme

    /// - Parameters:
    ///   - preferQuickLook: Uses QuickLook even for PDFs, images and text.
    ///   - onClose: Called by Close; defaults to dismissing the presentation.
    public init(_ file: KitoFileItem, preferQuickLook: Bool = false, tint: Color? = nil,
                onClose: (() -> Void)? = nil) {
        self.file = file
        self.preferQuickLook = preferQuickLook
        self.tint = tint
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            viewer
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(theme.colors.background)
    }

    private var mode: KitoPreviewMode { KitoPreviewMode.mode(for: file, preferQuickLook: preferQuickLook) }

    private var header: some View {
        HStack(spacing: theme.spacing.sm) {
            Button { close() } label: {
                KitoControlIcon(systemImage: "xmark", isOn: false, tint: tint ?? theme.colors.primary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            KitoFileIcon(file, size: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text(file.name)
                    .font(theme.typography.bodyEmphasized)
                    .foregroundStyle(theme.colors.onBackground)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(file.detailText())
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            Spacer(minLength: 0)
            if file.isLocal, let url = file.url {
                ShareLink(item: url) {
                    KitoControlIcon(systemImage: "square.and.arrow.up", isOn: false, tint: tint ?? theme.colors.primary)
                }
                .accessibilityLabel("Share")
            }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.sm)
        .background(.bar)
    }

    @ViewBuilder
    private var viewer: some View {
        switch (mode, file.url) {
        case let (.pdf, url?):
            KitoPDFViewer(url: url, showsShareButton: false, tint: tint)
        case let (.image, url?):
            KitoImageViewer(url: url)
                .background(Color.black.opacity(0.92))
        case let (.text, url?):
            KitoTextViewer(url: url, tint: tint)
        case let (.quickLook, url?):
            KitoQuickLookPreview(url: url)
        default:
            KitoFilePreviewUnavailable(title: "No preview", message: unavailableMessage)
        }
    }

    private var unavailableMessage: String {
        file.isLocal ? "This kind of file can't be shown here." : "Download the file to preview it."
    }

    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }
}
