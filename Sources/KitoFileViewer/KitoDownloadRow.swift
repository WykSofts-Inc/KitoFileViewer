//
//  KitoDownloadRow.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A download or upload row: a progress ring around the file badge, the name, "4.2 MB of 18 MB ·
/// 1.3 MB/s · 12 s left", and pause, resume, cancel and retry buttons. A finished transfer shows a
/// green check and can be tapped to open.
///
/// ```swift
/// KitoDownloadRow(transfer, model: transfers) { file in preview = file }
/// ```
public struct KitoDownloadRow: View {
    private let transfer: KitoTransfer
    private let tint: Color?
    private let actions: KitoTransferActions
    private let onOpen: ((KitoFileItem) -> Void)?

    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// A row whose buttons call the model.
    public init(_ transfer: KitoTransfer, model: KitoTransferModel, tint: Color? = nil,
                onOpen: ((KitoFileItem) -> Void)? = nil) {
        self.init(transfer, actions: KitoTransferActions(model: model), tint: tint, onOpen: onOpen)
    }

    /// A row with your own button handling.
    public init(_ transfer: KitoTransfer, actions: KitoTransferActions, tint: Color? = nil,
                onOpen: ((KitoFileItem) -> Void)? = nil) {
        self.transfer = transfer
        self.actions = actions
        self.tint = tint
        self.onOpen = onOpen
    }

    public var body: some View {
        HStack(spacing: theme.spacing.md) {
            ring
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: theme.spacing.xxs) {
                HStack(spacing: theme.spacing.xxs) {
                    Image(systemName: transfer.direction.systemImage)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(stateColor)
                    Text(transfer.name)
                        .font(theme.typography.bodyEmphasized)
                        .foregroundStyle(theme.colors.onSurface)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Text(transfer.statusText)
                    .font(theme.typography.caption.monospacedDigit())
                    .foregroundStyle(transfer.phase.failureMessage == nil ? theme.colors.secondary : theme.colors.danger)
                    .lineLimit(1)
                    .contentTransition(.numericText())
                if transfer.phase.isActive, let fraction = transfer.fraction {
                    KitoLinearBar(fraction: fraction, color: stateColor)
                }
            }
            Spacer(minLength: 0)
            buttons
        }
        .padding(.vertical, theme.spacing.xs)
        .contentShape(Rectangle())
        .onTapGesture { open() }
        .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.8), value: transfer.phase)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(transfer.name), \(transfer.shortStatus)")
        .accessibilityValue(transfer.statusText)
    }

    private var stateColor: Color {
        switch transfer.phase {
        case .completed: theme.colors.success
        case .failed: theme.colors.danger
        case .paused: theme.colors.warning
        case .cancelled: theme.colors.secondary
        case .waiting, .running: tint ?? theme.colors.primary
        }
    }

    private var ring: some View {
        KitoProgressRing(fraction: ringFraction, tint: stateColor, lineWidth: 3.5) {
            ZStack {
                KitoFileBadge(kind: transfer.kind, label: "", color: transfer.kind.color, size: 28)
                    .opacity(transfer.phase == .completed ? 0 : 1)
                    .scaleEffect(transfer.phase == .completed ? 0.4 : 1)
                Image(systemName: "checkmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(theme.colors.success)
                    .scaleEffect(transfer.phase == .completed ? 1 : 0.2)
                    .opacity(transfer.phase == .completed ? 1 : 0)
                if transfer.phase.failureMessage != nil {
                    Image(systemName: "exclamationmark")
                        .font(.system(size: 11, weight: .heavy))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(theme.colors.danger))
                        .offset(x: 16, y: -16)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
    }

    private var ringFraction: Double? {
        switch transfer.phase {
        case .waiting: nil
        case .completed: 1
        case .cancelled: 0
        default: transfer.fraction
        }
    }

    @ViewBuilder
    private var buttons: some View {
        HStack(spacing: theme.spacing.xs) {
            switch transfer.phase {
            case .running, .waiting:
                KitoRowButton(systemImage: "pause.fill", label: "Pause", color: theme.colors.onSurface) {
                    actions.pause(transfer)
                }
                cancelButton
            case .paused:
                KitoRowButton(systemImage: "play.fill", label: "Resume", color: tint ?? theme.colors.primary) {
                    actions.resume(transfer)
                }
                cancelButton
            case .failed, .cancelled:
                KitoRowButton(systemImage: "arrow.clockwise", label: "Retry", color: tint ?? theme.colors.primary) {
                    actions.retry(transfer)
                }
                if let remove = actions.remove {
                    KitoRowButton(systemImage: "xmark", label: "Remove", color: theme.colors.secondary) { remove(transfer) }
                }
            case .completed:
                if onOpen != nil, transfer.fileItem != nil {
                    Text("Open")
                        .font(theme.typography.label.weight(.semibold))
                        .foregroundStyle(theme.colors.onPrimary)
                        .padding(.horizontal, theme.spacing.sm)
                        .frame(height: 30)
                        .background(Capsule().fill(tint ?? theme.colors.primary))
                        .accessibilityHidden(true)
                }
            }
        }
        .transition(.scale.combined(with: .opacity))
    }

    private var cancelButton: some View {
        KitoRowButton(systemImage: "xmark", label: "Cancel", color: theme.colors.secondary) {
            actions.cancel(transfer)
        }
    }

    private func open() {
        guard let onOpen, let file = transfer.fileItem else { return }
        onOpen(file)
    }
}

/// What the row's buttons do.
public struct KitoTransferActions {
    public var pause: (KitoTransfer) -> Void
    public var resume: (KitoTransfer) -> Void
    public var cancel: (KitoTransfer) -> Void
    public var retry: (KitoTransfer) -> Void
    public var remove: ((KitoTransfer) -> Void)?

    public init(pause: @escaping (KitoTransfer) -> Void, resume: @escaping (KitoTransfer) -> Void,
                cancel: @escaping (KitoTransfer) -> Void, retry: @escaping (KitoTransfer) -> Void,
                remove: ((KitoTransfer) -> Void)? = nil) {
        self.pause = pause
        self.resume = resume
        self.cancel = cancel
        self.retry = retry
        self.remove = remove
    }

    /// Buttons that call `KitoTransferModel`.
    @MainActor
    public init(model: KitoTransferModel) {
        self.init(pause: { model.pause($0) }, resume: { model.resume($0) }, cancel: { model.cancel($0) },
                  retry: { model.retry($0) }, remove: { transfer in withAnimation { model.remove(transfer) } })
    }
}

/// A round icon button used in transfer rows.
struct KitoRowButton: View {
    let systemImage: String
    let label: String
    let color: Color
    let action: () -> Void
    @Environment(\.kitoTheme) private var theme

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(color)
                .frame(width: 32, height: 32)
                .background(Circle().fill(theme.colors.surfaceMuted))
                .contentShape(Circle())
        }
        .buttonStyle(KitoPressableStyle())
        .accessibilityLabel(label)
    }
}

/// A thin capsule progress bar.
struct KitoLinearBar: View {
    let fraction: Double
    let color: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(color.opacity(0.15))
                Capsule()
                    .fill(LinearGradient(colors: [color.opacity(0.7), color], startPoint: .leading, endPoint: .trailing))
                    .frame(width: barWidth(proxy.size.width))
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.3), value: fraction)
        .accessibilityHidden(true)
    }

    private func barWidth(_ total: CGFloat) -> CGFloat {
        max(total * CGFloat(min(max(fraction, 0), 1)), 4)
    }
}
