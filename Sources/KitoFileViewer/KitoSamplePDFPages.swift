//
//  KitoSamplePDFPages.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import UIKit

extension KitoSamplePDFs {
    static let invoiceItems: [[String]] = [
        ["Brand discovery workshop (2 days)", "1", "85,000", "85,000"],
        ["Logo and identity system", "1", "120,000", "120,000"],
        ["Packaging design — 250g coffee bag", "3", "28,000", "84,000"],
        ["Café menu boards", "4", "9,500", "38,000"],
        ["Website design — 6 pages", "6", "22,000", "132,000"],
        ["Product photography, half day", "1", "45,000", "45,000"],
        ["Social media templates", "12", "2,500", "30,000"],
        ["Print management and proofs", "1", "18,000", "18,000"],
    ]

    static func invoiceFirstPage(_ canvas: KitoPDFCanvas) {
        let m = KitoPDFCanvas.margin
        canvas.fill(CGRect(x: 0, y: 0, width: KitoPDFCanvas.pageSize.width, height: 150), green)
        canvas.text("Mti Mkubwa Design Studio Ltd", at: CGPoint(x: m, y: 44), size: 22, weight: .bold, color: .white)
        canvas.text("4th Floor, Kilimani Business Centre · Argwings Kodhek Road, Nairobi\nhello@mtimkubwa.example · +254 700 000 000",
                    at: CGPoint(x: m, y: 76), size: 10, color: UIColor(white: 1, alpha: 0.85))
        canvas.text("INVOICE", at: CGPoint(x: m, y: 44), size: 26, weight: .heavy,
                    color: UIColor(white: 1, alpha: 0.9), alignment: .right)

        canvas.text("BILLED TO", at: CGPoint(x: m, y: 184), size: 9, weight: .bold, color: green)
        canvas.text("Baobab Coffee Company\nAttn: Njeri Kamau\nWestlands Road, Nairobi 00800",
                    at: CGPoint(x: m, y: 200), size: 11, color: .darkGray)
        let details = "Invoice no.  INV-2026-0914\nIssued  14 September 2026\nDue  14 October 2026\nKRA PIN  P000000000X"
        canvas.text(details, at: CGPoint(x: m, y: 184), size: 11, color: .darkGray, alignment: .right)

        canvas.fill(CGRect(x: m, y: 290, width: canvas.width, height: 110), UIColor(white: 0.96, alpha: 1), radius: 10)
        canvas.text("Total due", at: CGPoint(x: m + 20, y: 310), size: 12, color: .gray)
        canvas.text("KSh 640,320", at: CGPoint(x: m + 20, y: 330), size: 34, weight: .bold, color: green)
        canvas.text("Pay by M-Pesa Paybill 000111, account INV0914,\nor bank transfer — details on page 3.",
                    at: CGPoint(x: m + 20, y: 336), size: 10, color: .gray, width: canvas.width - 40, alignment: .right)

        canvas.text("Summary", at: CGPoint(x: m, y: 430), size: 14, weight: .semibold, color: .black)
        let summary = [["Design services", "", "", "534,000"], ["Materials and printing", "", "", "18,000"],
                       ["Subtotal", "", "", "552,000"], ["VAT 16%", "", "", "88,320"],
                       ["Total due (KSh)", "", "", "640,320"]]
        canvas.table(summary, header: ["Item", "", "", "Amount"], widths: [0.55, 0.1, 0.15, 0.2], at: 456, accent: green)
        canvas.text("Thank you for working with us. Asante sana!", at: CGPoint(x: m, y: 660), size: 12,
                    weight: .medium, color: green)
    }

    static func invoiceItemsPage(_ canvas: KitoPDFCanvas) {
        let m = KitoPDFCanvas.margin
        canvas.text("Line items", at: CGPoint(x: m, y: 56), size: 20, weight: .bold, color: .black)
        canvas.text("Project: Baobab Coffee rebrand, July – September 2026", at: CGPoint(x: m, y: 84), size: 11, color: .gray)
        let bottom = canvas.table(invoiceItems, header: ["Description", "Qty", "Rate", "Amount"],
                                  widths: [0.52, 0.1, 0.18, 0.2], at: 116, accent: green)
        canvas.line(from: CGPoint(x: m, y: bottom), to: CGPoint(x: m + canvas.width, y: bottom))
        let totals = "Services  534,000\nMaterials  18,000\nSubtotal  552,000\nVAT 16%  88,320\nTotal due  KSh 640,320"
        canvas.text(totals, at: CGPoint(x: m, y: bottom + 14), size: 11, weight: .medium, color: .darkGray, alignment: .right)
        canvas.text("Notes", at: CGPoint(x: m, y: bottom + 120), size: 13, weight: .semibold, color: .black)
        let notes = "Photography includes up to 40 edited images delivered as JPEG and HEIC. Website design covers "
            + "desktop and mobile layouts; development is quoted separately. Packaging artwork is supplied print-ready "
            + "with a 3 mm bleed."
        canvas.text(notes, at: CGPoint(x: m, y: bottom + 142), size: 11, color: .darkGray)
    }

    static func invoiceTermsPage(_ canvas: KitoPDFCanvas) {
        let m = KitoPDFCanvas.margin
        canvas.text("Payment details", at: CGPoint(x: m, y: 56), size: 20, weight: .bold, color: .black)
        let payment = [["M-Pesa Paybill", "", "", "000111"], ["Account", "", "", "INV0914"],
                       ["Bank", "", "", "Example Bank Kenya"], ["Branch", "", "", "Kilimani"],
                       ["Account no.", "", "", "0000 0000 0000"], ["SWIFT", "", "", "EXAMKENA"]]
        canvas.table(payment, header: ["Method", "", "", "Details"], widths: [0.4, 0.1, 0.1, 0.4], at: 92, accent: green)
        canvas.text("Terms", at: CGPoint(x: m, y: 270), size: 16, weight: .semibold, color: .black)
        let terms = [
            "1. Payment is due within 30 days of the invoice date.",
            "2. Late payments attract interest of 1.5% per month on the balance due.",
            "3. Artwork copyright passes to the client once the invoice is paid in full.",
            "4. Please quote the invoice number INV-2026-0914 with every payment.",
            "5. Questions about this invoice? Write to accounts@mtimkubwa.example.",
        ]
        canvas.text(terms.joined(separator: "\n\n"), at: CGPoint(x: m, y: 296), size: 11, color: .darkGray)
        canvas.fill(CGRect(x: m, y: 520, width: canvas.width, height: 70), green.withAlphaComponent(0.08), radius: 10)
        canvas.text("This is a sample document generated by KitoFileViewer. The company, people and numbers are made up.",
                    at: CGPoint(x: m + 16, y: 540), size: 10, color: green, width: canvas.width - 32)
    }

    static func reportGradesPage(_ canvas: KitoPDFCanvas) {
        let m = KitoPDFCanvas.margin
        canvas.fill(CGRect(x: 0, y: 0, width: KitoPDFCanvas.pageSize.width, height: 130), navy)
        canvas.text("Kilele Hills Academy", at: CGPoint(x: m, y: 40), size: 22, weight: .bold, color: .white)
        canvas.text("Ngong Road, Nairobi · Term 2 Report, 2026", at: CGPoint(x: m, y: 72), size: 11,
                    color: UIColor(white: 1, alpha: 0.85))
        canvas.text("Amani Wanjiru\nGrade 7 · Class 7 Baobab\nAdmission no. 2021-0457",
                    at: CGPoint(x: m, y: 160), size: 12, color: .darkGray)
        canvas.text("Mean grade  A−\nPosition  4 of 38\nAttendance  96%",
                    at: CGPoint(x: m, y: 160), size: 12, weight: .medium, color: navy, alignment: .right)
        let grades = [["Mathematics", "84", "A", "Very good"], ["English", "78", "B+", "Good"],
                      ["Kiswahili", "81", "A−", "Very good"], ["Integrated Science", "88", "A", "Excellent"],
                      ["Social Studies", "74", "B", "Good"], ["Creative Arts", "91", "A", "Excellent"],
                      ["Agriculture", "69", "B−", "Fair"], ["Pre-Technical Studies", "80", "A−", "Very good"]]
        canvas.table(grades, header: ["Subject", "Score", "Grade", "Remark"], widths: [0.45, 0.15, 0.15, 0.25],
                     at: 240, accent: navy)
        canvas.text("Scores by subject", at: CGPoint(x: m, y: 470), size: 13, weight: .semibold, color: .black)
        let values: [(String, CGFloat)] = [("MAT", 0.84), ("ENG", 0.78), ("KIS", 0.81), ("SCI", 0.88),
                                           ("SST", 0.74), ("ART", 0.91), ("AGR", 0.69), ("PTS", 0.80)]
        canvas.bars(values, in: CGRect(x: m, y: 500, width: canvas.width, height: 180), color: navy)
    }

    static func reportCommentsPage(_ canvas: KitoPDFCanvas) {
        let m = KitoPDFCanvas.margin
        canvas.text("Comments", at: CGPoint(x: m, y: 56), size: 20, weight: .bold, color: .black)
        let teacher = "Amani has had an excellent term. Her science project on rainwater harvesting in Kajiado "
            + "was one of the best in the grade, and she leads her group with patience. She should keep "
            + "practising English composition, where her ideas are strong but her paragraphs could be tighter."
        canvas.text("Class teacher — Mr. Otieno", at: CGPoint(x: m, y: 92), size: 11, weight: .semibold, color: navy)
        canvas.text(teacher, at: CGPoint(x: m, y: 110), size: 11, color: .darkGray)
        let head = "A fine term, Amani. Keep up the curiosity and the hard work. Hongera!"
        canvas.text("Head teacher — Mrs. Mwangi", at: CGPoint(x: m, y: 210), size: 11, weight: .semibold, color: navy)
        canvas.text(head, at: CGPoint(x: m, y: 228), size: 11, color: .darkGray)
        canvas.text("Clubs and activities", at: CGPoint(x: m, y: 290), size: 14, weight: .semibold, color: .black)
        let clubs = [["Science club", "", "", "Secretary"], ["Swimming", "", "", "Under-13 team"],
                     ["Choir", "", "", "Member"], ["Environment club", "", "", "Tree nursery lead"]]
        canvas.table(clubs, header: ["Activity", "", "", "Role"], widths: [0.5, 0.1, 0.1, 0.3], at: 316, accent: navy)
        canvas.text("Term dates", at: CGPoint(x: m, y: 470), size: 14, weight: .semibold, color: .black)
        canvas.text("Term 3 opens Monday 5 October 2026 and closes Friday 27 November 2026.\nFees are due by the first day of term.",
                    at: CGPoint(x: m, y: 494), size: 11, color: .darkGray)
        canvas.fill(CGRect(x: m, y: 580, width: canvas.width, height: 60), navy.withAlphaComponent(0.07), radius: 10)
        canvas.text("This is a sample document generated by KitoFileViewer. The school, pupil and grades are made up.",
                    at: CGPoint(x: m + 16, y: 600), size: 10, color: navy, width: canvas.width - 32)
    }
}
