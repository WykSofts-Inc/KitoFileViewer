//
//  KitoDocumentPickerButton.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import KitoCore

/// How `KitoDocumentPickerButton` and `KitoShareButton` look.
public enum KitoFileButtonStyle: Sendable {
    /// A filled capsule in the tint.
    case filled
    /// A tinted outline capsule.
    case outlined
    /// A soft tinted capsule.
    case tonal
}

/// A button that opens the Files picker and hands back the chosen files as `KitoFileItem`s.
///
/// ```swift
/// KitoDocumentPickerButton("Attach files", allowedContentTypes: [.pdf, .image],
///                          allowsMultipleSelection: true) { files in
///     attachments += files
/// }
/// ```
///
/// Picked files are outside your app's sandbox. By default each one is copied into a temporary folder
/// while access is granted, so the returned URLs keep working; set `copiesToTemporaryDirectory` to `false`
/// to get the original security-scoped URLs and call `startAccessingSecurityScopedResource()` yourself.
public struct KitoDocumentPickerButton: View {
    private let title: String
    private let systemImage: String
    private let allowedContentTypes: [UTType]
    private let allowsMultipleSelection: Bool
    private let copiesToTemporaryDirectory: Bool
    private let style: KitoFileButtonStyle
    private let tint: Color?
    private let onPick: ([KitoFileItem]) -> Void
    private let onError: ((Error) -> Void)?

    @State private var presenting = false
    @Environment(\.kitoTheme) private var theme

    public init(_ title: String = "Choose files", systemImage: String = "paperclip",
                allowedContentTypes: [UTType] = [.item], allowsMultipleSelection: Bool = true,
                copiesToTemporaryDirectory: Bool = true, style: KitoFileButtonStyle = .filled,
                tint: Color? = nil, onError: ((Error) -> Void)? = nil,
                onPick: @escaping ([KitoFileItem]) -> Void) {
        self.title = title
        self.systemImage = systemImage
        self.allowedContentTypes = allowedContentTypes
        self.allowsMultipleSelection = allowsMultipleSelection
        self.copiesToTemporaryDirectory = copiesToTemporaryDirectory
        self.style = style
        self.tint = tint
        self.onError = onError
        self.onPick = onPick
    }

    public var body: some View {
        Button { presenting = true } label: {
            Label(title, systemImage: systemImage)
        }
        .buttonStyle(KitoCapsuleButtonStyle(style: style, tint: tint ?? theme.colors.primary))
        .fileImporter(isPresented: $presenting, allowedContentTypes: allowedContentTypes,
                      allowsMultipleSelection: allowsMultipleSelection) { result in
            handle(result)
        }
    }

    private func handle(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            let items = urls.map { copiesToTemporaryDirectory ? KitoDocumentImport.copy($0) : KitoFileItem(contentsOf: $0) }
            if !items.isEmpty { onPick(items) }
        case let .failure(error):
            onError?(error)
        }
    }
}

/// Copies picked files into the app's temporary folder.
enum KitoDocumentImport {
    static func copy(_ url: URL) -> KitoFileItem {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("KitoImports", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let target = folder.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: url, to: target)
            return KitoFileItem(contentsOf: target)
        } catch {
            return KitoFileItem(contentsOf: url)
        }
    }
}

/// A share button for one or more local files, using the system share sheet.
///
/// ```swift
/// KitoShareButton(urls: [invoiceURL])
/// KitoShareButton("Send report", items: [report], style: .outlined)
/// ```
public struct KitoShareButton: View {
    private let title: String
    private let urls: [URL]
    private let style: KitoFileButtonStyle
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    public init(_ title: String = "Share", urls: [URL], style: KitoFileButtonStyle = .filled, tint: Color? = nil) {
        self.title = title
        self.urls = urls
        self.style = style
        self.tint = tint
    }

    /// Shares the local files among `items`; remote ones are skipped.
    public init(_ title: String = "Share", items: [KitoFileItem], style: KitoFileButtonStyle = .filled,
                tint: Color? = nil) {
        self.init(title, urls: items.compactMap { $0.isLocal ? $0.url : nil }, style: style, tint: tint)
    }

    public var body: some View {
        ShareLink(items: urls) {
            Label(title, systemImage: "square.and.arrow.up")
        }
        .buttonStyle(KitoCapsuleButtonStyle(style: style, tint: tint ?? theme.colors.primary))
        .disabled(urls.isEmpty)
    }
}

/// The capsule look shared by the picker and share buttons.
struct KitoCapsuleButtonStyle: ButtonStyle {
    let style: KitoFileButtonStyle
    let tint: Color
    @Environment(\.kitoTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.typography.button)
            .padding(.horizontal, theme.spacing.lg)
            .frame(minHeight: 46)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(Capsule().strokeBorder(style == .outlined ? tint : .clear, lineWidth: 1.5))
            .shadow(color: style == .filled ? tint.opacity(0.3) : .clear, radius: 10, y: 5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var foreground: Color {
        style == .filled ? theme.colors.onPrimary : tint
    }

    @ViewBuilder
    private var background: some View {
        switch style {
        case .filled:
            Capsule().fill(LinearGradient(colors: [tint.opacity(0.88), tint], startPoint: .top, endPoint: .bottom))
        case .outlined:
            Capsule().fill(Color.clear)
        case .tonal:
            Capsule().fill(tint.opacity(0.12))
        }
    }
}
