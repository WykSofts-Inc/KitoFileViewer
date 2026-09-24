//
//  KitoFileImageViewer.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// An image you can pinch to zoom, drag around when zoomed, and double-tap to zoom in or back out.
///
/// ```swift
/// KitoFileImageViewer(url: photoURL)
/// KitoFileImageViewer(image: uiImage, maximumZoom: 6)
/// ```
public struct KitoFileImageViewer: View {
    private let source: Source
    private let maximumZoom: CGFloat

    @State private var loaded: UIImage?
    @State private var failed = false
    @State private var zoom: CGFloat = 1
    @State private var committedZoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection

    private enum Source {
        case url(URL)
        case image(UIImage)
    }

    public init(url: URL, maximumZoom: CGFloat = 5) {
        self.source = .url(url)
        self.maximumZoom = maximumZoom
    }

    public init(image: UIImage, maximumZoom: CGFloat = 5) {
        self.source = .image(image)
        self.maximumZoom = maximumZoom
        self._loaded = State(initialValue: image)
    }

    public var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let loaded {
                    zoomable(loaded, in: proxy.size)
                } else if failed {
                    KitoFilePreviewUnavailable(title: "Can't open this image", message: "The file is missing or damaged.")
                } else {
                    ProgressView()
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipped()
        .task { await load() }
    }

    private func zoomable(_ image: UIImage, in size: CGSize) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: size.width, height: size.height)
            .scaleEffect(zoom)
            .offset(offset)
            .gesture(magnify.simultaneously(with: drag(in: size)))
            .onTapGesture(count: 2) { toggleZoom() }
            .accessibilityLabel("Image")
            .accessibilityValue(zoom > 1.01 ? "Zoomed \(Int(zoom * 100)) percent" : "Fit to screen")
            .accessibilityAction(named: zoom > 1.01 ? "Zoom out" : "Zoom in") { toggleZoom() }
    }

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { value in zoom = clampZoom(committedZoom * value.magnification) }
            .onEnded { _ in
                committedZoom = zoom
                if zoom <= 1 { reset() }
            }
    }

    private func drag(in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard zoom > 1 else { return }
                offset = limited(translated(value.translation), in: size)
            }
            .onEnded { _ in committedOffset = offset }
    }

    private func translated(_ translation: CGSize) -> CGSize {
        // Drag translations are physical, but `.offset(x:)` mirrors in right-to-left layouts.
        let dx = layoutDirection == .rightToLeft ? -translation.width : translation.width
        return CGSize(width: committedOffset.width + dx, height: committedOffset.height + translation.height)
    }

    private func limited(_ proposed: CGSize, in size: CGSize) -> CGSize {
        let maxX = size.width * (zoom - 1) / 2
        let maxY = size.height * (zoom - 1) / 2
        let x = min(max(proposed.width, -maxX), maxX)
        let y = min(max(proposed.height, -maxY), maxY)
        return CGSize(width: x, height: y)
    }

    private func clampZoom(_ value: CGFloat) -> CGFloat {
        min(max(value, 0.8), maximumZoom)
    }

    private func toggleZoom() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            if zoom > 1.01 {
                reset()
            } else {
                zoom = min(2.5, maximumZoom)
                committedZoom = zoom
            }
        }
    }

    private func reset() {
        withAnimation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8)) {
            zoom = 1
            committedZoom = 1
            offset = .zero
            committedOffset = .zero
        }
    }

    private func load() async {
        guard loaded == nil, case let .url(url) = source else { return }
        let image = await Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return UIImage(data: data)?.preparingForDisplay()
        }.value
        loaded = image
        failed = image == nil
    }
}
