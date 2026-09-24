//
//  KitoAttachmentChip.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers
import KitoCore

/// An attachment chip for forms and composers: "Invoice.pdf · 240 KB ✕".
///
/// ```swift
/// KitoAttachmentChip(file) { attachments.removeAll { $0.id == file.id } }
/// ```
public struct KitoAttachmentChip: View {
    private let file: KitoFileItem
    private let tint: Color?
    private let onTap: (() -> Void)?
    private let onRemove: (() -> Void)?
    @Environment(\.kitoTheme) private var theme

    public init(_ file: KitoFileItem, tint: Color? = nil, onTap: (() -> Void)? = nil,
                onRemove: (() -> Void)? = nil) {
        self.file = file
        self.tint = tint
        self.onTap = onTap
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: theme.spacing.xs) {
            KitoFileBadge(kind: file.kind, label: "", color: tint ?? file.kind.color, size: 22)
                .frame(width: 18, height: 22)
            Text(file.name)
                .font(theme.typography.label.weight(.medium))
                .foregroundStyle(theme.colors.onSurface)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: 160, alignment: .leading)
                .fixedSize(horizontal: true, vertical: false)
            if let size = file.size {
                Text("· \(KitoByteCount.string(size))")
                    .font(theme.typography.caption)
                    .foregroundStyle(theme.colors.secondary)
                    .fixedSize()
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(theme.colors.secondary)
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(theme.colors.border.opacity(0.5)))
                        .contentShape(Circle().inset(by: -8))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(file.name)")
            }
        }
        .padding(.leading, theme.spacing.sm)
        .padding(.trailing, onRemove == nil ? theme.spacing.sm : theme.spacing.xxs + 2)
        .frame(height: 36)
        .background(Capsule().fill(theme.colors.surface))
        .overlay(Capsule().strokeBorder((tint ?? file.kind.color).opacity(0.35), lineWidth: 1))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .contentShape(Capsule())
        .onTapGesture { onTap?() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(file.name), \(file.size.map(KitoByteCount.string) ?? file.kind.singularTitle)")
    }
}

/// A scrolling row of attachment chips with an optional "Add" chip that opens the Files picker.
/// Chips pop in and out as files are added and removed.
///
/// ```swift
/// @State private var attachments: [KitoFileItem] = []
///
/// KitoAttachmentRow($attachments, allowedContentTypes: [.pdf, .image]) { file in preview = file }
/// ```
public struct KitoAttachmentRow: View {
    @Binding private var files: [KitoFileItem]
    private let allowsAdding: Bool
    private let allowedContentTypes: [UTType]
    private let maxCount: Int?
    private let tint: Color?
    private let onTap: ((KitoFileItem) -> Void)?

    @State private var picking = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ files: Binding<[KitoFileItem]>, allowsAdding: Bool = true,
                allowedContentTypes: [UTType] = [.item], maxCount: Int? = nil, tint: Color? = nil,
                onTap: ((KitoFileItem) -> Void)? = nil) {
        self._files = files
        self.allowsAdding = allowsAdding
        self.allowedContentTypes = allowedContentTypes
        self.maxCount = maxCount
        self.tint = tint
        self.onTap = onTap
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: theme.spacing.xs) {
                if allowsAdding, canAdd { addChip }
                ForEach(files) { file in
                    KitoAttachmentChip(file, onTap: onTap.map { handler in { handler(file) } }) { remove(file) }
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .padding(.horizontal, theme.spacing.md)
            .padding(.vertical, theme.spacing.xs)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75), value: files.map(\.id))
        .fileImporter(isPresented: $picking, allowedContentTypes: allowedContentTypes,
                      allowsMultipleSelection: true) { result in
            guard case let .success(urls) = result else { return }
            let room = maxCount.map { max($0 - files.count, 0) } ?? urls.count
            files.append(contentsOf: urls.prefix(room).map(KitoDocumentImport.copy))
        }
    }

    private var canAdd: Bool { maxCount.map { files.count < $0 } ?? true }

    private var addChip: some View {
        let accent = tint ?? theme.colors.primary
        return Button { picking = true } label: {
            HStack(spacing: theme.spacing.xxs) {
                Image(systemName: "plus").font(.system(size: 12, weight: .bold))
                Text("Add").font(theme.typography.label.weight(.semibold))
            }
            .foregroundStyle(accent)
            .padding(.horizontal, theme.spacing.sm)
            .frame(height: 36)
            .background(Capsule().fill(accent.opacity(0.1)))
            .overlay(Capsule().strokeBorder(accent.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
        .buttonStyle(KitoPressableStyle())
        .accessibilityLabel("Add attachment")
    }

    private func remove(_ file: KitoFileItem) {
        files.removeAll { $0.id == file.id }
    }
}
