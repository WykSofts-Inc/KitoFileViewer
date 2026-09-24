# ``KitoFileViewer``

File browsing, document previews, transfer progress and attachments for SwiftUI.

## Overview

KitoFileViewer gives an app a complete file experience. ``KitoFileBrowser`` shows the contents of
a ``KitoFolder`` as a list or grid, with a breadcrumb, a search field that looks through
subfolders, sort and group menus, swipe actions and a selection bar. Its state lives in a
``KitoFileBrowserModel``, so you can change the sort, grouping or current folder from code.

```swift
struct DocumentsView: View {
    @State private var files = KitoFileBrowserModel(root: KitoFolder.load(from: documentsURL),
                                                    sort: .newest, grouping: .kind)
    @State private var preview: KitoFileItem?

    var body: some View {
        KitoFileBrowser(model: files) { file in preview = file }
            .fullScreenCover(item: $preview) { KitoFilePreview($0) }
    }
}
```

``KitoFilePreview`` picks the best viewer for each ``KitoFileKind``: ``KitoPDFViewer`` for PDFs,
with page thumbnails, search with highlighted matches and zoom; ``KitoFileImageViewer`` for
images; ``KitoTextViewer`` for text, code and CSV; and ``KitoQuickLookPreview`` for Office, iWork,
video, audio and anything else QuickLook can open.

``KitoTransferModel`` runs downloads and uploads over `URLSession` and ``KitoTransferList`` shows
them with progress, speed, time left, pause, resume and retry. ``KitoDocumentPickerButton``,
``KitoShareButton`` and ``KitoAttachmentChip`` cover picking, sharing and attaching files, and
``KitoSampleDocuments`` generates real sample files on the device so demos work offline.

Every view reads the Kito theme from the environment and takes an optional `tint`.

## Topics

### Essentials

- ``KitoFileBrowser``
- ``KitoFileBrowserModel``
- ``KitoFileBrowserOptions``
- ``KitoFileItem``
- ``KitoFolder``
- ``KitoFileKind``

### Browsing

- ``KitoFileList``
- ``KitoFileGrid``
- ``KitoFileRow``
- ``KitoFolderRow``
- ``KitoFileIcon``
- ``KitoFolderIcon``
- ``KitoFileSearchField``
- ``KitoBreadcrumbBar``
- ``KitoBreadcrumb``
- ``KitoBreadcrumbItem``
- ``KitoFileEmptyState``

### Sorting and Grouping

- ``KitoFileLayout``
- ``KitoFileSort``
- ``KitoFileGrouping``
- ``KitoFileGroup``
- ``KitoFileFilter``

### Previews

- ``KitoFilePreview``
- ``KitoPreviewMode``
- ``KitoPDFViewer``
- ``KitoPDFViewerModel``
- ``KitoPDFSearchResult``
- ``KitoDocumentSearchCursor``
- ``KitoPDFPageIndicator``
- ``KitoFileImageViewer``
- ``KitoTextViewer``
- ``KitoCodeHighlighter``
- ``KitoQuickLookPreview``

### Downloads and Uploads

- ``KitoTransferModel``
- ``KitoTransfer``
- ``KitoTransferList``
- ``KitoDownloadRow``
- ``KitoTransferActions``
- ``KitoTransferProgressRing``
- ``KitoTransferPhase``
- ``KitoTransferEvent``
- ``KitoTransferDirection``
- ``KitoTransferRate``

### Picking, Sharing and Utilities

- ``KitoDocumentPickerButton``
- ``KitoShareButton``
- ``KitoFileButtonStyle``
- ``KitoAttachmentChip``
- ``KitoAttachmentRow``
- ``KitoByteCount``
- ``KitoSampleDocuments``
- ``KitoFileViewer``
