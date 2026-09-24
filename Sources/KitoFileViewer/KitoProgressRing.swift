//
//  KitoProgressRing.swift
//  KitoFileViewer
//
//  Created by Wycliff on 9/24/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import KitoCore

/// A circular progress ring with a gradient stroke and a rounded cap. `nil` spins as indeterminate.
///
/// ```swift
/// KitoProgressRing(fraction: 0.42, tint: .blue)
/// KitoProgressRing(fraction: nil)              // size unknown yet
/// ```
public struct KitoProgressRing<Center: View>: View {
    private let fraction: Double?
    private let tint: Color?
    private let lineWidth: CGFloat
    private let center: Center

    @State private var spinning = false
    @Environment(\.kitoTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(fraction: Double?, tint: Color? = nil, lineWidth: CGFloat = 3.5,
                @ViewBuilder center: () -> Center) {
        self.fraction = fraction
        self.tint = tint
        self.lineWidth = lineWidth
        self.center = center()
    }

    public var body: some View {
        let color = tint ?? theme.colors.primary
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: trimmed)
                .stroke(gradient(color), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(rotation)
            center
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.3), value: fraction)
        .onAppear { startSpinning() }
        .onChange(of: fraction == nil) { _, _ in startSpinning() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress")
        .accessibilityValue(fraction.map { "\(Int(($0 * 100).rounded())) percent" } ?? "In progress")
    }

    private var trimmed: CGFloat {
        guard let fraction else { return 0.28 }
        return CGFloat(min(max(fraction, 0), 1))
    }

    private var rotation: Angle {
        let base = Angle.degrees(-90)
        guard fraction == nil else { return base }
        return spinning ? base + .degrees(360) : base
    }

    private func gradient(_ color: Color) -> AngularGradient {
        AngularGradient(colors: [color.opacity(0.55), color], center: .center,
                        startAngle: .degrees(0), endAngle: .degrees(360 * max(Double(trimmed), 0.01)))
    }

    private func startSpinning() {
        guard fraction == nil, !reduceMotion else {
            spinning = false
            return
        }
        spinning = false
        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) { spinning = true }
    }
}

public extension KitoProgressRing where Center == EmptyView {
    init(fraction: Double?, tint: Color? = nil, lineWidth: CGFloat = 3.5) {
        self.init(fraction: fraction, tint: tint, lineWidth: lineWidth) { EmptyView() }
    }
}
