//
//  KitoSamplePDFDrawing.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import UIKit

/// Small drawing helpers for the generated sample PDFs.
struct KitoPDFCanvas {
    static let pageSize = CGSize(width: 595, height: 842)
    static let margin: CGFloat = 48

    let context: UIGraphicsPDFRendererContext

    var width: CGFloat { Self.pageSize.width - Self.margin * 2 }

    func text(_ string: String, at point: CGPoint, size: CGFloat = 11, weight: UIFont.Weight = .regular,
              color: UIColor = .darkGray, width: CGFloat? = nil, alignment: NSTextAlignment = .left) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineSpacing = 2
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: style,
        ]
        let box = CGRect(x: point.x, y: point.y, width: width ?? self.width, height: 400)
        NSAttributedString(string: string, attributes: attributes)
            .draw(with: box, options: [.usesLineFragmentOrigin], context: nil)
    }

    func fill(_ rect: CGRect, _ color: UIColor, radius: CGFloat = 0) {
        color.setFill()
        UIBezierPath(roundedRect: rect, cornerRadius: radius).fill()
    }

    func line(from start: CGPoint, to end: CGPoint, color: UIColor = UIColor(white: 0.85, alpha: 1)) {
        let path = UIBezierPath()
        path.move(to: start)
        path.addLine(to: end)
        path.lineWidth = 0.75
        color.setStroke()
        path.stroke()
    }

    func footer(_ string: String, page: Int, of pages: Int) {
        let y = Self.pageSize.height - 36
        line(from: CGPoint(x: Self.margin, y: y - 8), to: CGPoint(x: Self.pageSize.width - Self.margin, y: y - 8))
        text(string, at: CGPoint(x: Self.margin, y: y), size: 8, color: .gray)
        text("Page \(page) of \(pages)", at: CGPoint(x: Self.margin, y: y), size: 8, color: .gray, alignment: .right)
    }

    /// A table: header row, then rows, with columns sized by `widths` (fractions of the page width).
    /// Returns the y below the table.
    @discardableResult
    func table(_ rows: [[String]], header: [String], widths: [CGFloat], at top: CGFloat,
               accent: UIColor) -> CGFloat {
        var y = top
        fill(CGRect(x: Self.margin, y: y, width: width, height: 24), accent.withAlphaComponent(0.12), radius: 4)
        drawRow(header, widths: widths, y: y + 6, weight: .semibold, color: accent)
        y += 30
        for (index, row) in rows.enumerated() {
            if index.isMultiple(of: 2) {
                fill(CGRect(x: Self.margin, y: y - 4, width: width, height: 22), UIColor(white: 0.97, alpha: 1))
            }
            drawRow(row, widths: widths, y: y, weight: .regular, color: .darkGray)
            y += 22
        }
        return y + 6
    }

    private func drawRow(_ cells: [String], widths: [CGFloat], y: CGFloat, weight: UIFont.Weight, color: UIColor) {
        var x = Self.margin + 8
        for (index, cell) in cells.enumerated() where index < widths.count {
            let columnWidth = width * widths[index] - 8
            let alignment: NSTextAlignment = index == 0 ? .left : .right
            text(cell, at: CGPoint(x: x, y: y), size: 10, weight: weight, color: color, width: columnWidth - 8,
                 alignment: alignment)
            x += columnWidth + 8
        }
    }

    /// A simple bar chart, used in the school report.
    func bars(_ values: [(String, CGFloat)], in rect: CGRect, color: UIColor) {
        guard !values.isEmpty else { return }
        let slot = rect.width / CGFloat(values.count)
        for (index, value) in values.enumerated() {
            let height = rect.height * min(max(value.1, 0), 1)
            let x = rect.minX + CGFloat(index) * slot + slot * 0.2
            let bar = CGRect(x: x, y: rect.maxY - height, width: slot * 0.6, height: height)
            fill(bar, color.withAlphaComponent(0.35 + 0.65 * value.1), radius: 4)
            text(value.0, at: CGPoint(x: x - 6, y: rect.maxY + 6), size: 8, color: .gray, width: slot * 0.6 + 12,
                 alignment: .center)
            text("\(Int(value.1 * 100))", at: CGPoint(x: x - 6, y: bar.minY - 14), size: 8, weight: .semibold,
                 color: .darkGray, width: slot * 0.6 + 12, alignment: .center)
        }
    }
}

/// The two sample PDFs: an invoice from a made-up Nairobi design studio and a school report.
enum KitoSamplePDFs {
    static let green = UIColor(red: 0.07, green: 0.45, blue: 0.33, alpha: 1)
    static let navy = UIColor(red: 0.12, green: 0.23, blue: 0.47, alpha: 1)

    static func invoice() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: KitoPDFCanvas.pageSize),
                                             format: format(title: "Invoice INV-2026-0914"))
        return renderer.pdfData { context in
            let canvas = KitoPDFCanvas(context: context)
            context.beginPage()
            invoiceFirstPage(canvas)
            canvas.footer("Mti Mkubwa Design Studio Ltd · Invoice INV-2026-0914", page: 1, of: 3)
            context.beginPage()
            invoiceItemsPage(canvas)
            canvas.footer("Mti Mkubwa Design Studio Ltd · Invoice INV-2026-0914", page: 2, of: 3)
            context.beginPage()
            invoiceTermsPage(canvas)
            canvas.footer("Mti Mkubwa Design Studio Ltd · Invoice INV-2026-0914", page: 3, of: 3)
        }
    }

    static func schoolReport() -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: KitoPDFCanvas.pageSize),
                                             format: format(title: "Term 2 Report — Amani Wanjiru"))
        return renderer.pdfData { context in
            let canvas = KitoPDFCanvas(context: context)
            context.beginPage()
            reportGradesPage(canvas)
            canvas.footer("Kilele Hills Academy · Term 2 2026 · Amani Wanjiru", page: 1, of: 2)
            context.beginPage()
            reportCommentsPage(canvas)
            canvas.footer("Kilele Hills Academy · Term 2 2026 · Amani Wanjiru", page: 2, of: 2)
        }
    }

    private static func format(title: String) -> UIGraphicsPDFRendererFormat {
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = [kCGPDFContextTitle as String: title, kCGPDFContextAuthor as String: "KitoFileViewer"]
        return format
    }
}
