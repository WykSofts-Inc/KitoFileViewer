# KitoFileViewer

Files and documents for SwiftUI: file lists and grids with sort, grouping, search, breadcrumbs,
swipe actions and a selection bar; a PDFKit viewer with page thumbnails, "3 / 12", search with
highlighted matches and zoom; QuickLook for everything else; zoomable images; a line-numbered
code viewer; download and upload rows with a progress ring, speed and time left; a Files picker
button, a share button and attachment chips. It can also generate sample documents on the device,
so demos work offline. Part of the [Kito](https://github.com/WykSofts-Inc/KitoDevKit) ecosystem.

## A file browser in one view

```swift
@State private var files = KitoFileBrowserModel(root: KitoFolder.load(from: documentsURL),
                                                sort: .newest, grouping: .kind)
@State private var preview: KitoFileItem?

KitoFileBrowser(model: files) { file in preview = file }     // list ⇄ grid toggle in the header
    .fullScreenCover(item: $preview) { KitoFilePreview($0) }
```

The header shows a tappable breadcrumb ("Documents › School › 2026"), a search field that looks
through the current folder and everything inside it, a sort and group menu, and Select. In
selection mode a floating bar offers All, Share, Move and Delete. Swipe a row to share or delete it;
long-press for Open, Share, Move to and Delete.

```swift
KitoFileList(model: files, options: KitoFileBrowserOptions(showsSearch: false, allowsMove: false)) { open($0) }
KitoFileGrid(model: files, minimumTileWidth: 110, tint: .indigo) { open($0) }

files.sort = KitoFileSort(.size)            // .name, .date, .size, .kind; ascending or not
files.grouping = .date                       // Today, Yesterday, Previous 7 Days, … "June 2026"
files.open(folder); files.goUp()
files.onDelete = { removed in removed.compactMap(\.url).forEach { try? FileManager.default.removeItem(at: $0) } }
files.onMove = { moved, folder in … }
```

## Models

```swift
KitoFileItem(name: "Invoice.pdf", url: url, size: 240_000, modified: .now)   // kind from the extension
KitoFileItem(contentsOf: localURL)                                            // reads size, date, type
KitoFolder.load(from: url, depth: 3)
folder.allFiles, folder.totalSize, folder.path(to: id), folder.moving(ids, to: otherID)

KitoFileKind.detect(pathExtension: "xlsx")      // .sheet
KitoFileKind.detect(contentType: .mpeg4Movie)   // .video
```

Kinds are `pdf, image, video, audio, doc, sheet, slides, archive, code, text, other`, each with a
colour, symbol and title.

## Icons

```swift
KitoFileIcon(file, size: 44)                         // PDF red, DOCX blue, XLSX green, ZIP grey…
KitoFileIcon(file, size: 120, showsThumbnail: true)  // QuickLook thumbnail, badge until it's ready
KitoFolderIcon(size: 44)
```

## Previews

```swift
KitoFilePreview(file)                     // header with Close and Share, then the best viewer
KitoPDFViewer(url: invoiceURL)            // thumbnails strip, "3 / 12", search, zoom, share
KitoFileImageViewer(url: photoURL)        // pinch, drag, double-tap
KitoTextViewer(url: swiftFileURL)         // line numbers, monospaced, light syntax colours, wrap
KitoQuickLookPreview(urls: [docxURL, keynoteURL], selection: $index)
```

`KitoFilePreview` uses the package's viewers for PDFs, images, text, code and CSV, and QuickLook
for Office, iWork, video, audio and anything else QuickLook can open. Drive the PDF viewer yourself
with its model:

```swift
@State private var pdf = KitoPDFViewerModel(url: reportURL)

KitoPDFViewer(model: pdf)
pdf.searchQuery = "total"     // every match highlighted
pdf.nextResult()              // pdf.cursor.label == "2 of 7"
pdf.go(toPage: 2); pdf.zoomIn(); pdf.pageLabel   // "3 / 12"
```

## Downloads and uploads

```swift
@State private var transfers = KitoTransferModel()

transfers.download(reportURL)                             // URLSession, pause keeps resume data
transfers.upload(fileURL, to: URLRequest(url: uploadURL))
transfers.simulate(name: "Site plan.pdf", size: 18_400_000, duration: 8, failsAt: 0.6)   // for demos

KitoTransferList(model: transfers) { file in preview = file }
KitoDownloadRow(transfer, model: transfers)
KitoTransferProgressRing(fraction: 0.42, tint: .blue)
```

Rows show "4.2 MB of 18 MB · 1.3 MB/s · 12 s left" with pause, resume and cancel; a failed
transfer turns red with Retry; a finished one shows a check and opens on tap. Speed is smoothed
(`KitoTransferRate`) and each transfer moves through `KitoTransferPhase`
(waiting → running ⇄ paused → completed, or failed → retry).

## Picking, sharing and attachments

```swift
KitoDocumentPickerButton("Attach files", allowedContentTypes: [.pdf, .image]) { attachments += $0 }
KitoShareButton(items: attachments, style: .outlined)
KitoAttachmentChip(file) { remove(file) }                    // "Invoice.pdf · 240 KB ✕"
KitoAttachmentRow($attachments, allowedContentTypes: [.pdf, .image], maxCount: 5)
```

Picked files are copied into a temporary folder while access is granted, so their URLs keep working.

## Sample documents

```swift
let root = try KitoSampleDocuments.make()     // a KitoFolder of real files in a temporary folder
let invoice = try KitoSampleDocuments.invoice()
```

Generates a three-page invoice from a made-up Nairobi design studio, a two-page school report, a
CSV of expenses, notes, a Swift file, JSON and two drawn images, plus a few remote-only items
(xlsx, pptx, docx, zip, mov, m4a) that show their badges. Everything is fictional.

## Migrating from 0.1

0.2.0 renames three types so KitoFileViewer can sit in the same file as KitoImageLoader,
KitoCarousel and KitoLoaders without "ambiguous" errors:

| 0.1 | 0.2 |
| --- | --- |
| `KitoImageViewer` | `KitoFileImageViewer` |
| `KitoPageIndicator` | `KitoPDFPageIndicator` |
| `KitoProgressRing` | `KitoTransferProgressRing` |

Initialisers and behaviour are unchanged; a find-and-replace of the old names is all it takes.

## Info.plist

Nothing is required. The Files picker, share sheet and QuickLook need no usage descriptions. Add
`UIFileSharingEnabled` and `LSSupportsOpeningDocumentsInPlace` only if you also want your app's
Documents folder to appear in the Files app.

## Installation

```swift
.package(url: "https://github.com/WykSofts-Inc/KitoFileViewer.git", from: "0.2.0")
```

## License

MIT — see [LICENSE](LICENSE).
