//
//  KitoPDFViewerModel.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import PDFKit
import Observation

/// One match found by searching a PDF.
public struct KitoPDFSearchResult: Identifiable, Hashable {
    public let id: Int
    /// Zero-based page index.
    public let pageIndex: Int
    /// The words around the match, e.g. "…Total due KSh 48,500 by 30…".
    public let snippet: String
}

/// The state behind `KitoPDFViewer`: the document, current page, zoom, thumbnails and search.
///
/// ```swift
/// @State private var pdf = KitoPDFViewerModel(url: invoiceURL)
///
/// KitoPDFViewer(model: pdf)
/// pdf.go(toPage: 2)
/// pdf.searchQuery = "total"          // highlights every match; pdf.nextResult() steps through them
/// pdf.zoomIn()
/// ```
@Observable
@MainActor
public final class KitoPDFViewerModel {
    public let url: URL?
    public let document: PDFDocument?
    /// Zero-based index of the page in view.
    public private(set) var pageIndex: Int = 0
    public var pageCount: Int { document?.pageCount ?? 0 }
    /// The zoom as a fraction of fitting the width; 1 is fit.
    public private(set) var zoom: CGFloat = 1
    /// Search text. Matches are found a moment after it stops changing.
    public var searchQuery: String = "" {
        didSet { scheduleSearch() }
    }
    public private(set) var results: [KitoPDFSearchResult] = []
    public private(set) var cursor = KitoDocumentSearchCursor()
    public private(set) var isSearching = false

    /// "3 / 12".
    public var pageLabel: String { KitoPageIndicator.label(pageIndex: pageIndex, pageCount: pageCount) }

    /// The result that is selected, if any.
    public var currentResult: KitoPDFSearchResult? {
        cursor.index.flatMap { results.indices.contains($0) ? results[$0] : nil }
    }

    @ObservationIgnored let pdfView: PDFView
    @ObservationIgnored private var selections: [PDFSelection] = []
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var observer: KitoPDFObserver?
    @ObservationIgnored private var fitScale: CGFloat = 1
    @ObservationIgnored private var thumbnails: [Int: UIImage] = [:]

    public convenience init(url: URL) {
        self.init(document: PDFDocument(url: url), url: url)
    }

    public init(document: PDFDocument?, url: URL? = nil) {
        self.url = url ?? document?.documentURL
        self.document = document
        let view = PDFView()
        view.document = document
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.pageShadowsEnabled = true
        view.backgroundColor = .clear
        self.pdfView = view
        let observer = KitoPDFObserver(view: view)
        observer.onPageChange = { [weak self] in self?.syncPage() }
        observer.onScaleChange = { [weak self] in self?.syncZoom() }
        self.observer = observer
    }

    // MARK: Pages

    public func go(toPage index: Int) {
        guard let page = document?.page(at: min(max(index, 0), max(pageCount - 1, 0))) else { return }
        pdfView.go(to: page)
        syncPage()
    }

    public func nextPage() { go(toPage: pageIndex + 1) }
    public func previousPage() { go(toPage: pageIndex - 1) }

    /// A small image of a page, made on first request and kept.
    public func thumbnail(forPage index: Int) -> UIImage? {
        if let cached = thumbnails[index] { return cached }
        guard let page = document?.page(at: index) else { return nil }
        let image = page.thumbnail(of: CGSize(width: 90, height: 120), for: .cropBox)
        thumbnails[index] = image
        return image
    }

    // MARK: Zoom

    public func zoomIn() { setZoom(zoom * 1.25) }
    public func zoomOut() { setZoom(zoom / 1.25) }

    /// Back to fitting the page width.
    public func resetZoom() {
        pdfView.autoScales = true
        fitScale = pdfView.scaleFactorForSizeToFit
        syncZoom()
    }

    /// Zoom as a percentage of fit: "125%".
    public var zoomLabel: String { "\(Int((zoom * 100).rounded()))%" }

    private func setZoom(_ value: CGFloat) {
        let base = currentFitScale()
        let clamped = min(max(value, 0.5), 5)
        pdfView.autoScales = false
        pdfView.scaleFactor = base * clamped
        syncZoom()
    }

    private func currentFitScale() -> CGFloat {
        let fit = pdfView.scaleFactorForSizeToFit
        if fit > 0 { fitScale = fit }
        return fitScale
    }

    // MARK: Search

    public func nextResult() {
        cursor.next()
        showCurrentResult()
    }

    public func previousResult() {
        cursor.previous()
        showCurrentResult()
    }

    public func selectResult(_ result: KitoPDFSearchResult) {
        cursor.select(result.id)
        showCurrentResult()
    }

    /// Clears the query and highlights.
    public func endSearch() {
        searchQuery = ""
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            apply(selections: [])
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            self?.runSearch(query)
        }
    }

    private func runSearch(_ query: String) {
        let found = document?.findString(query, withOptions: [.caseInsensitive, .diacriticInsensitive]) ?? []
        apply(selections: found)
    }

    private func apply(selections found: [PDFSelection]) {
        isSearching = false
        selections = found
        let highlight = UIColor.systemYellow.withAlphaComponent(0.55)
        for selection in found { selection.color = highlight }
        pdfView.highlightedSelections = found.isEmpty ? nil : found
        results = found.enumerated().map { index, selection in
            KitoPDFSearchResult(id: index, pageIndex: pageIndex(of: selection), snippet: snippet(for: selection))
        }
        cursor.reset(count: found.count)
        if found.isEmpty {
            pdfView.clearSelection()
        } else {
            showCurrentResult()
        }
    }

    private func showCurrentResult() {
        guard let index = cursor.index, selections.indices.contains(index) else { return }
        let selection = selections[index]
        pdfView.setCurrentSelection(selection, animate: true)
        pdfView.go(to: selection)
        syncPage()
    }

    private func pageIndex(of selection: PDFSelection) -> Int {
        guard let page = selection.pages.first, let document else { return 0 }
        return document.index(for: page)
    }

    private func snippet(for selection: PDFSelection) -> String {
        guard let context = selection.copy() as? PDFSelection else { return selection.string ?? "" }
        context.extend(atStart: 24)
        context.extend(atEnd: 32)
        let text = (context.string ?? "").replacingOccurrences(of: "\n", with: " ")
        return "…" + text.trimmingCharacters(in: .whitespaces) + "…"
    }

    // MARK: Sync

    private func syncPage() {
        guard let page = pdfView.currentPage, let document else { return }
        let index = document.index(for: page)
        if index != pageIndex { pageIndex = index }
    }

    private func syncZoom() {
        let base = currentFitScale()
        guard base > 0 else { return }
        let value = pdfView.scaleFactor / base
        if abs(value - zoom) > 0.005 { zoom = value }
    }
}

/// Forwards PDFView page and zoom notifications.
final class KitoPDFObserver: NSObject {
    var onPageChange: (@MainActor () -> Void)?
    var onScaleChange: (@MainActor () -> Void)?

    init(view: PDFView) {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(pageChanged), name: .PDFViewPageChanged, object: view)
        center.addObserver(self, selector: #selector(scaleChanged), name: .PDFViewScaleChanged, object: view)
    }

    @objc private func pageChanged() {
        MainActor.assumeIsolated { onPageChange?() }
    }

    @objc private func scaleChanged() {
        MainActor.assumeIsolated { onScaleChange?() }
    }
}
