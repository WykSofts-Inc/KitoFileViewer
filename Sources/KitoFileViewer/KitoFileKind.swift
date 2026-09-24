//
//  KitoFileKind.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import UniformTypeIdentifiers

/// What sort of file something is, used for its badge colour, its symbol, grouping and choosing a viewer.
public enum KitoFileKind: String, CaseIterable, Hashable, Sendable, Codable {
    case pdf, image, video, audio, doc, sheet, slides, archive, code, text, other

    /// Works out the kind from a file extension, then from a content type.
    ///
    /// ```swift
    /// KitoFileKind.detect(pathExtension: "xlsx")            // .sheet
    /// KitoFileKind.detect(contentType: .mpeg4Movie)         // .video
    /// ```
    public static func detect(pathExtension: String?, contentType: UTType? = nil) -> KitoFileKind {
        if let ext = pathExtension?.lowercased(), !ext.isEmpty, let kind = extensionTable[ext] {
            return kind
        }
        if let type = contentType ?? pathExtension.flatMap({ UTType(filenameExtension: $0.lowercased()) }) {
            return detect(contentType: type)
        }
        return .other
    }

    /// Works out the kind from a content type by conformance.
    public static func detect(contentType type: UTType) -> KitoFileKind {
        if let ext = type.preferredFilenameExtension, let kind = extensionTable[ext.lowercased()] {
            return kind
        }
        return conformanceOrder.first { type.conforms(to: $0.type) }?.kind ?? .other
    }

    /// Works out the kind from a file name such as "Invoice.pdf".
    public static func detect(fileName: String) -> KitoFileKind {
        detect(pathExtension: (fileName as NSString).pathExtension)
    }

    /// A plural title for group headers: "PDFs", "Images", "Spreadsheets".
    public var title: String {
        switch self {
        case .pdf: "PDFs"
        case .image: "Images"
        case .video: "Videos"
        case .audio: "Audio"
        case .doc: "Documents"
        case .sheet: "Spreadsheets"
        case .slides: "Presentations"
        case .archive: "Archives"
        case .code: "Code"
        case .text: "Text"
        case .other: "Other"
        }
    }

    /// A singular name for accessibility: "PDF", "Image", "Spreadsheet".
    public var singularTitle: String {
        switch self {
        case .pdf: "PDF"
        case .image: "Image"
        case .video: "Video"
        case .audio: "Audio file"
        case .doc: "Document"
        case .sheet: "Spreadsheet"
        case .slides: "Presentation"
        case .archive: "Archive"
        case .code: "Code file"
        case .text: "Text file"
        case .other: "File"
        }
    }

    /// The SF Symbol drawn on the badge.
    public var systemImage: String {
        switch self {
        case .pdf: "doc.richtext.fill"
        case .image: "photo.fill"
        case .video: "play.rectangle.fill"
        case .audio: "waveform"
        case .doc: "doc.text.fill"
        case .sheet: "tablecells.fill"
        case .slides: "rectangle.on.rectangle.angled.fill"
        case .archive: "archivebox.fill"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .text: "text.alignleft"
        case .other: "doc.fill"
        }
    }

    /// The badge colour: PDF red, documents blue, spreadsheets green, archives grey…
    public var color: Color {
        switch self {
        case .pdf: Color(red: 0.89, green: 0.20, blue: 0.19)
        case .image: Color(red: 0.62, green: 0.32, blue: 0.87)
        case .video: Color(red: 0.36, green: 0.34, blue: 0.90)
        case .audio: Color(red: 0.93, green: 0.27, blue: 0.53)
        case .doc: Color(red: 0.16, green: 0.42, blue: 0.87)
        case .sheet: Color(red: 0.11, green: 0.58, blue: 0.33)
        case .slides: Color(red: 0.93, green: 0.49, blue: 0.13)
        case .archive: Color(red: 0.47, green: 0.50, blue: 0.55)
        case .code: Color(red: 0.07, green: 0.56, blue: 0.62)
        case .text: Color(red: 0.36, green: 0.42, blue: 0.51)
        case .other: Color(red: 0.55, green: 0.57, blue: 0.62)
        }
    }

    /// Whether the package has its own viewer for this kind (otherwise QuickLook is used).
    public var hasNativeViewer: Bool {
        switch self {
        case .pdf, .image, .text, .code: true
        default: false
        }
    }

    static let extensionTable: [String: KitoFileKind] = {
        var table: [String: KitoFileKind] = ["pdf": .pdf]
        let groups: [(KitoFileKind, [String])] = [
            (.image, ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp", "tif", "tiff", "bmp", "svg"]),
            (.video, ["mov", "mp4", "m4v", "avi", "mkv", "webm", "3gp"]),
            (.audio, ["mp3", "m4a", "wav", "aac", "flac", "aiff", "ogg", "caf"]),
            (.doc, ["doc", "docx", "pages", "rtf", "odt"]),
            (.sheet, ["xls", "xlsx", "numbers", "ods", "csv", "tsv"]),
            (.slides, ["ppt", "pptx", "key", "odp"]),
            (.archive, ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz"]),
            (.code, ["swift", "m", "h", "c", "cpp", "js", "ts", "tsx", "jsx", "py", "rb", "go", "rs",
                     "kt", "java", "json", "xml", "yml", "yaml", "html", "css", "sh", "sql"]),
            (.text, ["txt", "md", "markdown", "log", "text"]),
        ]
        for (kind, extensions) in groups {
            for ext in extensions { table[ext] = kind }
        }
        return table
    }()

    private static let conformanceOrder: [(type: UTType, kind: KitoFileKind)] = [
        (.pdf, .pdf), (.image, .image), (.movie, .video), (.audio, .audio),
        (.spreadsheet, .sheet), (.presentation, .slides), (.archive, .archive),
        (.sourceCode, .code), (.json, .code), (.xml, .code), (.rtf, .doc),
        (.plainText, .text), (.text, .text),
    ]
}
