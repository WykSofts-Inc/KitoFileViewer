//
//  KitoTransferList.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// Every transfer in a model: a summary card with overall progress, then "In progress" and "Done"
/// sections of `KitoDownloadRow`s. Swipe a row to remove it.
///
/// ```swift
/// KitoTransferList(model: transfers) { file in preview = file }
/// ```
public struct KitoTransferList: View {
    private let model: KitoTransferModel
    private let showsSummary: Bool
    private let tint: Color?
    private let onOpen: ((KitoFileItem) -> Void)?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(model: KitoTransferModel, showsSummary: Bool = true, tint: Color? = nil,
                onOpen: ((KitoFileItem) -> Void)? = nil) {
        self.model = model
        self.showsSummary = showsSummary
        self.tint = tint
        self.onOpen = onOpen
    }

    public var body: some View {
        List {
            if showsSummary, model.activeCount > 0 {
                summary
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
            section("In progress", model.transfers.filter { $0.phase.isActive || $0.phase.failureMessage != nil })
            section("Done", model.transfers.filter { $0.phase == .completed || $0.phase == .cancelled }, clearable: true)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(theme.colors.background)
        .overlay {
            if model.transfers.isEmpty {
                KitoFileEmptyState(title: "No transfers", message: "Downloads and uploads appear here.", tint: tint)
            }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.85), value: model.transfers.map(\.phase))
    }

    @ViewBuilder
    private func section(_ title: String, _ items: [KitoTransfer], clearable: Bool = false) -> some View {
        if !items.isEmpty {
            Section {
                ForEach(items) { transfer in
                    KitoDownloadRow(transfer, model: model, tint: tint, onOpen: onOpen)
                        .swipeActions {
                            Button(role: .destructive) { withAnimation { model.remove(transfer) } } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            } header: {
                HStack {
                    KitoGroupHeader(title: title, count: items.count, kind: nil)
                    if clearable {
                        Button("Clear") { withAnimation { model.clearFinished() } }
                            .font(theme.typography.label.weight(.semibold))
                            .foregroundStyle(tint ?? theme.colors.primary)
                    }
                }
            }
        }
    }

    private var summary: some View {
        let accent = tint ?? theme.colors.primary
        let count = model.activeCount
        return HStack(spacing: theme.spacing.md) {
            KitoTransferProgressRing(fraction: model.overallFraction, tint: accent, lineWidth: 5) {
                Text("\(Int((model.overallFraction * 100).rounded()))%")
                    .font(theme.typography.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(theme.colors.onSurface)
                    .contentTransition(.numericText())
            }
            .frame(width: 58, height: 58)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                Text(count == 1 ? "1 transfer" : "\(count) transfers")
                    .font(theme.typography.titleMedium)
                    .foregroundStyle(theme.colors.onSurface)
                Text(summaryDetail)
                    .font(theme.typography.caption.monospacedDigit())
                    .foregroundStyle(theme.colors.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(theme.spacing.md)
        .background(summaryBackground(accent))
        .accessibilityElement(children: .combine)
    }

    private var summaryDetail: String {
        let running = model.transfers.filter { $0.phase == .running }
        let speed = running.compactMap(\.bytesPerSecond).reduce(0, +)
        let left = running.compactMap(\.secondsLeft).max()
        var parts: [String] = []
        if speed > 0 { parts.append(KitoByteCount.rate(speed)) }
        if let left { parts.append(KitoByteCount.timeLeft(left)) }
        return parts.isEmpty ? "Paused" : parts.joined(separator: " · ")
    }

    private func summaryBackground(_ accent: Color) -> some View {
        RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
            .fill(LinearGradient(colors: [accent.opacity(0.14), accent.opacity(0.04)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(RoundedRectangle(cornerRadius: theme.radii.lg, style: .continuous)
                .strokeBorder(accent.opacity(0.18), lineWidth: 1))
    }
}
