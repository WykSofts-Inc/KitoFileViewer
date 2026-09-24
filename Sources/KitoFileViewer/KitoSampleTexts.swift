//
//  KitoSampleTexts.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// The contents of the generated text, CSV, Swift and JSON samples.
enum KitoSampleTexts {
    static let expenses = """
    Date,Category,Vendor,Description,Amount (KSh),Paid by
    2026-07-02,Transport,Little Cabs,Airport pickup for client workshop,2450,M-Pesa
    2026-07-03,Meals,Java House Kilimani,Workshop lunch (8 people),9600,Card
    2026-07-08,Printing,Kenyan Print Works,Packaging proofs,18000,Bank transfer
    2026-07-15,Software,Design Tools Inc,Monthly licences,14200,Card
    2026-07-21,Photography,Studio Hire Westlands,Half-day studio,12000,M-Pesa
    2026-08-01,Internet,Fibre Co,Office fibre August,6500,M-Pesa
    2026-08-06,Transport,SGR Madaraka,Nairobi to Mombasa site visit,3000,M-Pesa
    2026-08-07,Accommodation,Nyali Beach Hotel,Two nights,21800,Card
    2026-08-19,Office,Stationery Hub,Sketchbooks and markers,3900,Cash
    2026-09-02,Internet,Fibre Co,Office fibre September,6500,M-Pesa
    2026-09-09,Meals,Kahawa Roasters,Client review coffee,2100,Card
    2026-09-12,Printing,Kenyan Print Works,Menu board print run,8700,Bank transfer
    """

    static let notes = """
    Baobab Coffee — design review
    Thursday 24 September 2026, Kilimani office

    Attendees: Njeri (Baobab), Kevin, Aisha, Wanjiku

    1. Packaging
       - Njeri loves the kraft paper option; asked for a darker green on the 1 kg bag.
       - Print run of 5,000 bags approved once the new proof is signed off.

    2. Website
       - Home page hero: swap the stock photo for our Mara sunset shoot.
       - Menu page needs Swahili translations — Aisha to send by Monday.

    3. Timeline
       - Final artwork: 2 October
       - Printing: 5–9 October
       - Launch at the Westlands café: Saturday 17 October

    Action items
    [ ] Kevin: update packaging proof with darker green
    [ ] Aisha: menu translations
    [x] Wanjiku: send invoice INV-2026-0914
    """

    static let readingList = """
    Grade 7 reading list — Term 3

    The River and the Source — Margaret A. Ogola
    Blossoms of the Savannah — Henry R. Ole Kulet
    Weep Not, Child — Ngũgĩ wa Thiong'o
    Things Fall Apart — Chinua Achebe
    Kifo Kisimani — Kithaka wa Mberia

    Write one page on each book before the end of term.
    """

    static let json = """
    {
      "app": "Baobab Coffee",
      "version": "2.4.0",
      "currency": "KES",
      "stores": [
        { "id": 1, "name": "Westlands", "open": true, "seats": 42 },
        { "id": 2, "name": "Kilimani", "open": true, "seats": 28 },
        { "id": 3, "name": "Karen", "open": false, "seats": 36 }
      ],
      "features": { "mpesa": true, "loyalty": true, "delivery": null }
    }
    """

    static let swift = """
    //
    //  FileListScreen.swift
    //  Baobab Coffee
    //

    import SwiftUI
    import KitoFileViewer

    /// Shows the shared project folder and opens files full screen.
    struct FileListScreen: View {
        @State private var files = KitoFileBrowserModel(root: KitoFolder(name: "Projects"),
                                                        grouping: .kind)
        @State private var preview: KitoFileItem?

        var body: some View {
            NavigationStack {
                KitoFileBrowser(model: files) { file in
                    preview = file
                }
                .navigationTitle("Projects")
                .fullScreenCover(item: $preview) { file in
                    KitoFilePreview(file)
                }
            }
            .task { await reload() }
        }

        private func reload() async {
            let url = URL.documentsDirectory.appending(path: "Projects")
            files.reload(KitoFolder.load(from: url, depth: 3))
            print("Loaded \\(files.root.allFiles.count) files")   // 12 files, 3 folders
        }
    }
    """
}
