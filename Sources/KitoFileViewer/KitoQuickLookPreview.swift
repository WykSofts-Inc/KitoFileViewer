//
//  KitoQuickLookPreview.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import QuickLook

/// QuickLook inside SwiftUI: Office documents, Keynote, Numbers, video, audio, 3D models and more.
///
/// ```swift
/// KitoQuickLookPreview(urls: [budgetURL, pitchURL], selection: $index)
/// KitoQuickLookPreview.canPreview(url)     // check first
/// ```
public struct KitoQuickLookPreview: UIViewControllerRepresentable {
    private let urls: [URL]
    @Binding private var selection: Int

    public init(urls: [URL], selection: Binding<Int> = .constant(0)) {
        self.urls = urls
        self._selection = selection
    }

    public init(url: URL) {
        self.init(urls: [url])
    }

    /// Whether QuickLook can show this file.
    @MainActor
    public static func canPreview(_ url: URL) -> Bool {
        QLPreviewController.canPreview(url as NSURL)
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(urls: urls, selection: $selection)
    }

    public func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.currentPreviewItemIndex = clampedSelection
        return controller
    }

    public func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        let changed = context.coordinator.urls != urls
        context.coordinator.urls = urls
        context.coordinator.selection = $selection
        if changed { controller.reloadData() }
        if controller.currentPreviewItemIndex != clampedSelection {
            controller.currentPreviewItemIndex = clampedSelection
        }
    }

    private var clampedSelection: Int {
        urls.isEmpty ? 0 : min(max(selection, 0), urls.count - 1)
    }

    public final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var urls: [URL]
        var selection: Binding<Int>

        init(urls: [URL], selection: Binding<Int>) {
            self.urls = urls
            self.selection = selection
        }

        public func numberOfPreviewItems(in controller: QLPreviewController) -> Int { urls.count }

        public func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            urls[index] as NSURL
        }

        public func previewController(_ controller: QLPreviewController,
                                      editingModeFor previewItem: QLPreviewItem) -> QLPreviewItemEditingMode {
            .disabled
        }
    }
}
