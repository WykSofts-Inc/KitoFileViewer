//
//  KitoFileIcon.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import QuickLookThumbnailing
import KitoCore

/// A page with a folded top-right corner — the outline of a file badge.
struct KitoDocumentShape: Shape {
    var foldRatio: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        let fold = min(rect.width, rect.height) * foldRatio
        let radius = min(rect.width, rect.height) * 0.12
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                          control: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                          control: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY),
                          control: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

/// The folded corner flap of a file badge.
struct KitoDocumentFold: Shape {
    var foldRatio: CGFloat = 0.28

    func path(in rect: CGRect) -> Path {
        let fold = min(rect.width, rect.height) * foldRatio
        var path = Path()
        path.move(to: CGPoint(x: rect.maxX - fold, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - fold, y: rect.minY + fold * 0.8))
        path.addQuadCurve(to: CGPoint(x: rect.maxX - fold * 0.8, y: rect.minY + fold),
                          control: CGPoint(x: rect.maxX - fold, y: rect.minY + fold))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + fold))
        path.closeSubpath()
        return path
    }
}

/// A coloured file-type badge with the extension on it — red for PDF, blue for DOCX, green for XLSX,
/// grey for ZIP — or a QuickLook thumbnail of the file itself when one can be made.
///
/// ```swift
/// KitoFileIcon(item, size: 44)
/// KitoFileIcon(kind: .sheet, extension: "xlsx", size: 60)
/// KitoFileIcon(item, size: 120, showsThumbnail: true)   // a real preview for images and PDFs
/// ```
public struct KitoFileIcon: View {
    private let kind: KitoFileKind
    private let label: String
    private let url: URL?
    private let size: CGFloat
    private let showsThumbnail: Bool
    private let tint: Color?

    @State private var thumbnail: UIImage?
    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// - Parameters:
    ///   - item: The file; its kind and extension pick the colour and label.
    ///   - size: The badge height in points. The width is about three quarters of it.
    ///   - showsThumbnail: Asks QuickLook for a thumbnail of local files and shows it when ready.
    ///   - tint: Overrides the kind's colour.
    public init(_ item: KitoFileItem, size: CGFloat = 44, showsThumbnail: Bool = false, tint: Color? = nil) {
        self.kind = item.kind
        self.label = item.pathExtension
        self.url = item.isLocal ? item.url : nil
        self.size = size
        self.showsThumbnail = showsThumbnail
        self.tint = tint
    }

    /// A badge for a kind and extension with no file behind it.
    public init(kind: KitoFileKind, extension ext: String, size: CGFloat = 44, tint: Color? = nil) {
        self.kind = kind
        self.label = ext
        self.url = nil
        self.size = size
        self.showsThumbnail = false
        self.tint = tint
    }

    public var body: some View {
        ZStack {
            if let thumbnail {
                thumbnailView(thumbnail)
                    .transition(.opacity)
            } else {
                KitoFileBadge(kind: kind, label: label, color: tint ?? kind.color, size: size)
                    .transition(.opacity)
            }
        }
        .frame(width: badgeWidth, height: size)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: thumbnail != nil)
        .task(id: thumbnailKey) { await loadThumbnail() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(kind.singularTitle)
    }

    private var badgeWidth: CGFloat { thumbnail == nil ? size * 0.78 : size }

    private var thumbnailKey: String {
        showsThumbnail ? (url?.absoluteString ?? "") + "@\(Int(size))" : ""
    }

    private func thumbnailView(_ image: UIImage) -> some View {
        let radius = size * 0.12
        return Image(uiImage: image)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.12), radius: size * 0.06, y: size * 0.03)
    }

    private func loadThumbnail() async {
        guard showsThumbnail, let url else { return }
        let pixelSize = CGSize(width: size, height: size)
        thumbnail = await KitoThumbnailCache.shared.thumbnail(for: url, size: pixelSize, scale: displayScale)
    }
}

/// The drawn badge: a gradient page with a folded corner, the kind's symbol and the extension.
struct KitoFileBadge: View {
    let kind: KitoFileKind
    let label: String
    let color: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            KitoDocumentShape()
                .fill(LinearGradient(colors: [color.opacity(0.82), color], startPoint: .top, endPoint: .bottom))
            KitoDocumentShape()
                .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .topLeading, endPoint: .center))
            KitoDocumentFold()
                .fill(Color.white.opacity(0.45))
            content
        }
        .compositingGroup()
        .shadow(color: color.opacity(0.35), radius: size * 0.08, y: size * 0.05)
    }

    private var content: some View {
        VStack(spacing: size * 0.04) {
            Image(systemName: kind.systemImage)
                .font(.system(size: size * 0.26, weight: .semibold))
            if showsLabel {
                Text(displayLabel)
                    .font(.system(size: labelSize, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, size * 0.06)
        .padding(.top, size * 0.14)
    }

    private var showsLabel: Bool { size >= 28 && !label.isEmpty }
    private var displayLabel: String { String(label.uppercased().prefix(4)) }
    private var labelSize: CGFloat { size * (displayLabel.count > 3 ? 0.16 : 0.19) }
}

/// A folder icon with a back flap, a raised front and an optional count.
public struct KitoFolderIcon: View {
    private let size: CGFloat
    private let tint: Color?
    @Environment(\.kitoTheme) private var theme

    public init(size: CGFloat = 44, tint: Color? = nil) {
        self.size = size
        self.tint = tint
    }

    public var body: some View {
        let color = tint ?? Color(red: 0.24, green: 0.56, blue: 0.96)
        let radius = size * 0.1
        return ZStack(alignment: .bottom) {
            UnevenRoundedRectangle(topLeadingRadius: radius, topTrailingRadius: radius, style: .continuous)
                .fill(color.opacity(0.7))
                .frame(width: size * 0.42, height: size * 0.2)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .offset(y: size * 0.08)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(color.opacity(0.75))
                .frame(height: size * 0.66)
                .offset(y: -size * 0.04)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(LinearGradient(colors: [color.opacity(0.9), color], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Rectangle().fill(.white.opacity(0.3)).frame(height: max(size * 0.02, 0.5))
                }
                .frame(height: size * 0.6)
        }
        .frame(width: size, height: size * 0.82)
        .shadow(color: color.opacity(0.3), radius: size * 0.08, y: size * 0.05)
        .accessibilityHidden(true)
    }
}

/// Caches QuickLook thumbnails in memory.
final class KitoThumbnailCache: @unchecked Sendable {
    static let shared = KitoThumbnailCache()
    private let cache = NSCache<NSString, UIImage>()

    func thumbnail(for url: URL, size: CGSize, scale: CGFloat) async -> UIImage? {
        let key = "\(url.absoluteString)#\(Int(size.width))x\(Int(size.height))@\(scale)" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: size, scale: scale,
                                                   representationTypes: .thumbnail)
        guard let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let image = representation.uiImage
        cache.setObject(image, forKey: key)
        return image
    }
}
