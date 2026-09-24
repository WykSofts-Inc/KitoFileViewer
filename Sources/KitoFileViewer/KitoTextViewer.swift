//
//  KitoTextViewer.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Plain text and code in a monospaced font with line numbers, light syntax colouring for code,
/// optional wrapping and adjustable text size.
///
/// ```swift
/// KitoTextViewer(url: swiftFileURL)
/// KitoTextViewer(text: csv, fileExtension: "csv", wraps: false)
/// ```
public struct KitoTextViewer: View {
    private let url: URL?
    private let fileExtension: String
    private let tint: Color?

    @State private var lines: [String]?
    @State private var failed = false
    @State private var wraps: Bool
    @State private var fontSize: CGFloat = 13
    @Environment(\.kitoTheme) private var theme
    @Environment(\.colorScheme) private var colorScheme

    public init(url: URL, wraps: Bool = false, tint: Color? = nil) {
        self.url = url
        self.fileExtension = url.pathExtension
        self.tint = tint
        self._wraps = State(initialValue: wraps)
    }

    public init(text: String, fileExtension: String = "txt", wraps: Bool = false, tint: Color? = nil) {
        self.url = nil
        self.fileExtension = fileExtension
        self.tint = tint
        self._wraps = State(initialValue: wraps)
        self._lines = State(initialValue: KitoTextViewer.split(text))
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let lines {
                content(lines)
            } else if failed {
                KitoFilePreviewUnavailable(title: "Can't read this file", message: "It isn't text, or it's damaged.")
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            controls
        }
        .background(background)
        .task { await load() }
    }

    private var background: Color {
        colorScheme == .dark ? Color(red: 0.09, green: 0.10, blue: 0.12) : Color(red: 0.98, green: 0.98, blue: 0.97)
    }

    private var palette: KitoCodePalette { KitoCodePalette(dark: colorScheme == .dark) }

    private var numberWidth: CGFloat {
        let digits = String(lines?.count ?? 1).count
        return CGFloat(max(digits, 2)) * fontSize * 0.62 + 12
    }

    @ViewBuilder
    private func content(_ lines: [String]) -> some View {
        let highlighted = KitoCodeHighlighter.highlights(extension: fileExtension)
        let keywords = KitoCodeHighlighter.keywords(forExtension: fileExtension)
        let hash = KitoCodeHighlighter.usesHashComments(extension: fileExtension)
        ScrollView(wraps ? .vertical : [.vertical, .horizontal]) {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(lines.indices, id: \.self) { index in
                    KitoTextLine(number: index + 1, text: lines[index], numberWidth: numberWidth,
                                 fontSize: fontSize, wraps: wraps,
                                 tokens: highlighted ? KitoCodeHighlighter.tokens(in: lines[index], keywords: keywords,
                                                                                  hashComments: hash) : [],
                                 palette: palette)
                }
            }
            .padding(.vertical, theme.spacing.sm)
            .textSelection(.enabled)
        }
    }

    private var controls: some View {
        HStack(spacing: theme.spacing.sm) {
            Text("\(lines?.count ?? 0) lines")
                .font(theme.typography.caption.monospacedDigit())
                .foregroundStyle(theme.colors.secondary)
            Spacer()
            KitoControlButton(systemImage: "text.word.spacing", label: "Wrap lines", isOn: wraps,
                              tint: tint ?? theme.colors.primary) { wraps.toggle() }
            KitoControlButton(systemImage: "textformat.size.smaller", label: "Smaller text", isOn: false,
                              tint: tint ?? theme.colors.primary) { fontSize = max(fontSize - 1, 9) }
            KitoControlButton(systemImage: "textformat.size.larger", label: "Larger text", isOn: false,
                              tint: tint ?? theme.colors.primary) { fontSize = min(fontSize + 1, 24) }
        }
        .padding(.horizontal, theme.spacing.md)
        .padding(.vertical, theme.spacing.xs)
        .background(.bar)
    }

    private func load() async {
        guard lines == nil, let url else { return }
        let text = await Task.detached(priority: .userInitiated) { () -> String? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
        }.value
        if let text {
            lines = KitoTextViewer.split(text)
        } else {
            failed = true
        }
    }

    static func split(_ text: String) -> [String] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
        var parts = normalized.components(separatedBy: "\n")
        if parts.count > 1, parts.last == "" { parts.removeLast() }
        return parts
    }
}

/// Colours for highlighted code.
struct KitoCodePalette {
    let dark: Bool

    var plain: Color { dark ? Color(white: 0.9) : Color(white: 0.12) }
    var number: Color { dark ? Color(white: 0.45) : Color(white: 0.6) }
    var keyword: Color { dark ? Color(red: 0.99, green: 0.37, blue: 0.64) : Color(red: 0.61, green: 0.14, blue: 0.58) }
    var string: Color { dark ? Color(red: 0.99, green: 0.42, blue: 0.36) : Color(red: 0.77, green: 0.10, blue: 0.09) }
    var literal: Color { dark ? Color(red: 0.82, green: 0.75, blue: 0.50) : Color(red: 0.11, green: 0.0, blue: 0.81) }
    var comment: Color { dark ? Color(red: 0.51, green: 0.55, blue: 0.60) : Color(red: 0.36, green: 0.42, blue: 0.47) }

    func color(for kind: KitoCodeHighlighter.TokenKind) -> Color {
        switch kind {
        case .keyword: keyword
        case .string: string
        case .number: literal
        case .comment: comment
        }
    }
}

/// One numbered line.
struct KitoTextLine: View {
    let number: Int
    let text: String
    let numberWidth: CGFloat
    let fontSize: CGFloat
    let wraps: Bool
    let tokens: [KitoCodeHighlighter.Token]
    let palette: KitoCodePalette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .foregroundStyle(palette.number)
                .frame(width: numberWidth, alignment: .trailing)
                .accessibilityHidden(true)
            Text(attributed)
                .lineLimit(wraps ? nil : 1)
                .fixedSize(horizontal: !wraps, vertical: true)
                .frame(maxWidth: wraps ? .infinity : nil, alignment: .leading)
        }
        .font(.system(size: fontSize, design: .monospaced))
        .padding(.trailing, 16)
        .padding(.vertical, 1)
    }

    private var attributed: AttributedString {
        let line = text.isEmpty ? " " : text
        var result = AttributedString(line)
        result.foregroundColor = palette.plain
        let chars = Array(line)
        for token in tokens where token.range.upperBound <= chars.count {
            let start = result.index(result.startIndex, offsetByCharacters: token.range.lowerBound)
            let end = result.index(result.startIndex, offsetByCharacters: token.range.upperBound)
            result[start..<end].foregroundColor = palette.color(for: token.kind)
        }
        return result
    }
}
