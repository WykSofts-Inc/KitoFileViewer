//
//  KitoSampleDocuments.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import UIKit

/// Generates real sample files on the device — no network needed — for demos, previews and tests:
/// a three-page invoice PDF from a made-up Nairobi design studio, a two-page school report, a CSV of
/// expenses, notes, a Swift file, a JSON file and two drawn images.
///
/// ```swift
/// let root = try KitoSampleDocuments.make()        // a KitoFolder tree in a temporary folder
/// @State var files = KitoFileBrowserModel(root: root)
///
/// let invoice = try KitoSampleDocuments.invoice()  // a single file
/// ```
///
/// Files are written once into `directory` and reused; modification dates are spread over the last
/// few months so grouping by date has something to show.
public enum KitoSampleDocuments {
    /// Where the samples live: a folder in the temporary directory.
    public static var directory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("KitoSampleDocuments", isDirectory: true)
    }

    /// Writes every sample (if needed) and returns the tree, including a few remote-only files
    /// (spreadsheet, slides, archive, video, audio) that show their badges but can't be previewed.
    public static func make(in directory: URL? = nil, now: Date = .now) throws -> KitoFolder {
        let root = (directory ?? self.directory).appendingPathComponent("Documents", isDirectory: true)
        for spec in specs {
            let url = root.appendingPathComponent(spec.path)
            try write(spec, to: url)
            let date = now.addingTimeInterval(-spec.age)
            try? FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        }
        var folder = KitoFolder.load(from: root)
        folder.name = "Documents"
        folder.files += remoteFiles(now: now)
        return folder
    }

    /// Every generated file, flat.
    public static func files(in directory: URL? = nil, now: Date = .now) throws -> [KitoFileItem] {
        try make(in: directory, now: now).allFiles.filter(\.isLocal)
    }

    /// The invoice PDF.
    public static func invoice() throws -> URL { try single("Invoices/Invoice INV-2026-0914.pdf") }
    /// The school report PDF.
    public static func schoolReport() throws -> URL { try single("School/Term 2 Report.pdf") }
    /// The expenses CSV.
    public static func expensesCSV() throws -> URL { try single("Invoices/Expenses Q3.csv") }
    /// The Swift file.
    public static func swiftFile() throws -> URL { try single("Code/FileListScreen.swift") }
    /// The plain-text notes.
    public static func notes() throws -> URL { try single("Meeting notes.txt") }
    /// The landscape photo.
    public static func photo() throws -> URL { try single("Photos/Maasai Mara sunset.png") }

    /// Items with sizes and dates but no local file, for showing badges and download rows.
    public static func remoteFiles(now: Date = .now) -> [KitoFileItem] {
        let day: TimeInterval = 86_400
        let remote = URL(string: "https://files.example.com/")
        func item(_ name: String, _ size: Int64, _ days: Double) -> KitoFileItem {
            KitoFileItem(name: name, url: remote?.appendingPathComponent(name), size: size,
                         modified: now.addingTimeInterval(-days * day))
        }
        return [
            item("Budget 2026.xlsx", 186_000, 0.2),
            item("Pitch deck.pptx", 8_400_000, 3),
            item("Supplier contract.docx", 94_000, 12),
            item("Brand assets.zip", 48_200_000, 40),
            item("Site walkthrough.mov", 212_000_000, 1),
            item("Voice memo.m4a", 3_100_000, 6),
        ]
    }

    // MARK: Writing

    struct Spec {
        let path: String
        let age: TimeInterval
        let content: () -> Data?
    }

    private static let hour: TimeInterval = 3_600

    static var specs: [Spec] { [
        Spec(path: "Invoices/Invoice INV-2026-0914.pdf", age: 2 * hour) { KitoSamplePDFs.invoice() },
        Spec(path: "Invoices/Expenses Q3.csv", age: 26 * hour) { Data(KitoSampleTexts.expenses.utf8) },
        Spec(path: "School/Term 2 Report.pdf", age: 5 * 24 * hour) { KitoSamplePDFs.schoolReport() },
        Spec(path: "School/Reading list.txt", age: 21 * 24 * hour) { Data(KitoSampleTexts.readingList.utf8) },
        Spec(path: "Photos/Maasai Mara sunset.png", age: 3 * 24 * hour) { KitoSampleImages.sunset() },
        Spec(path: "Photos/Nairobi skyline.png", age: 70 * 24 * hour) { KitoSampleImages.skyline() },
        Spec(path: "Code/FileListScreen.swift", age: 30 * 60) { Data(KitoSampleTexts.swift.utf8) },
        Spec(path: "Code/config.json", age: 9 * 24 * hour) { Data(KitoSampleTexts.json.utf8) },
        Spec(path: "Meeting notes.txt", age: 27 * hour) { Data(KitoSampleTexts.notes.utf8) },
    ] }

    private static func write(_ spec: Spec, to url: URL) throws {
        let manager = FileManager.default
        if manager.fileExists(atPath: url.path) { return }
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = spec.content() else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: url, options: .atomic)
    }

    private static func single(_ path: String) throws -> URL {
        let url = directory.appendingPathComponent("Documents", isDirectory: true).appendingPathComponent(path)
        guard let spec = specs.first(where: { $0.path == path }) else { throw CocoaError(.fileNoSuchFile) }
        try write(spec, to: url)
        return url
    }
}

/// The two drawn sample images.
enum KitoSampleImages {
    static let size = CGSize(width: 1200, height: 800)

    static func sunset() -> Data? {
        render { context in
            gradient(context, [UIColor(red: 0.98, green: 0.55, blue: 0.22, alpha: 1),
                               UIColor(red: 0.62, green: 0.20, blue: 0.42, alpha: 1)])
            UIColor(red: 1, green: 0.86, blue: 0.45, alpha: 1).setFill()
            UIBezierPath(ovalIn: CGRect(x: 760, y: 330, width: 190, height: 190)).fill()
            hills(y: 560, amplitude: 40, color: UIColor(red: 0.30, green: 0.12, blue: 0.20, alpha: 1))
            acacia(at: CGPoint(x: 320, y: 600), scale: 1.3)
            acacia(at: CGPoint(x: 980, y: 640), scale: 0.8)
        }
    }

    static func skyline() -> Data? {
        render { context in
            gradient(context, [UIColor(red: 0.10, green: 0.16, blue: 0.36, alpha: 1),
                               UIColor(red: 0.30, green: 0.48, blue: 0.78, alpha: 1)])
            let heights: [CGFloat] = [260, 340, 220, 460, 300, 520, 280, 380, 240, 330, 200]
            for (index, height) in heights.enumerated() {
                let x = CGFloat(index) * 110 - 10
                UIColor(red: 0.06, green: 0.09, blue: 0.20, alpha: 1).setFill()
                UIBezierPath(rect: CGRect(x: x, y: size.height - height, width: 96, height: height)).fill()
                windows(in: CGRect(x: x + 12, y: size.height - height + 20, width: 72, height: height - 40))
            }
        }
    }

    private static func render(_ draw: (CGContext) -> Void) -> Data? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { draw($0.cgContext) }
    }

    private static func gradient(_ context: CGContext, _ colors: [UIColor]) {
        let cgColors = colors.map(\.cgColor) as CFArray
        guard let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgColors, locations: nil) else { return }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
    }

    private static func hills(y: CGFloat, amplitude: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 0, y: y))
        path.addCurve(to: CGPoint(x: size.width, y: y - amplitude),
                      controlPoint1: CGPoint(x: size.width * 0.3, y: y - amplitude * 2),
                      controlPoint2: CGPoint(x: size.width * 0.6, y: y + amplitude))
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.close()
        color.setFill()
        path.fill()
    }

    private static func acacia(at base: CGPoint, scale: CGFloat) {
        let color = UIColor(red: 0.16, green: 0.06, blue: 0.10, alpha: 1)
        color.setFill()
        UIBezierPath(rect: CGRect(x: base.x - 6 * scale, y: base.y - 150 * scale, width: 12 * scale, height: 150 * scale)).fill()
        let crown = CGRect(x: base.x - 130 * scale, y: base.y - 190 * scale, width: 260 * scale, height: 60 * scale)
        UIBezierPath(ovalIn: crown).fill()
    }

    private static func windows(in rect: CGRect) {
        UIColor(red: 1, green: 0.85, blue: 0.5, alpha: 0.75).setFill()
        var y = rect.minY
        var row = 0
        while y + 14 < rect.maxY {
            for column in 0..<3 where (row + column) % 3 != 0 {
                UIBezierPath(rect: CGRect(x: rect.minX + CGFloat(column) * 26, y: y, width: 14, height: 10)).fill()
            }
            y += 26
            row += 1
        }
    }
}
