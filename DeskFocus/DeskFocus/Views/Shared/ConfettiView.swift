//
//  ConfettiView.swift
//  DeskFocus
//

import SwiftUI
import UIKit

// MARK: - Palette

enum ConfettiPalette {
    /// Standing milestones — cool greens and blues.
    case standing
    /// Completed Pomodoro — warm reds and oranges.
    case pomodoro
    /// Desk countdown reached zero.
    case countdown

    fileprivate var uiColors: [UIColor] {
        switch self {
        case .standing:
            return [
                UIColor(red: 0.18, green: 0.72, blue: 0.48, alpha: 1),
                UIColor(red: 0.12, green: 0.58, blue: 0.82, alpha: 1),
                UIColor(red: 0.22, green: 0.68, blue: 0.74, alpha: 1),
                UIColor(red: 0.35, green: 0.82, blue: 0.55, alpha: 1),
                UIColor(red: 0.15, green: 0.45, blue: 0.78, alpha: 1),
            ]
        case .pomodoro:
            return [
                UIColor(red: 0.95, green: 0.28, blue: 0.28, alpha: 1),
                UIColor(red: 1, green: 0.42, blue: 0.18, alpha: 1),
                UIColor(red: 1, green: 0.55, blue: 0.12, alpha: 1),
                UIColor(red: 0.92, green: 0.32, blue: 0.38, alpha: 1),
                UIColor(red: 0.98, green: 0.48, blue: 0.22, alpha: 1),
            ]
        case .countdown:
            return [
                UIColor(red: 0.95, green: 0.82, blue: 0.35, alpha: 1),
                UIColor(red: 0.28, green: 0.72, blue: 0.62, alpha: 1),
                UIColor(red: 0.45, green: 0.62, blue: 0.95, alpha: 1),
                UIColor(red: 0.55, green: 0.88, blue: 0.48, alpha: 1),
                UIColor(red: 0.98, green: 0.65, blue: 0.38, alpha: 1),
            ]
        }
    }
}

// MARK: - Driver (call from stores / app bootstrap)

/// Hooks hosted `UIView` + `CAEmitterLayer`; safe before the representable mounts (no-op until attached).
@MainActor
final class ConfettiBurstDriver {
    fileprivate weak var host: ConfettiEmitterHostView?

    /// Bursts confetti from the bottom-center; emitter stops spawning quickly and is removed after **3 s**.
    func fire(_ palette: ConfettiPalette) {
        host?.fire(palette: palette)
    }
}

// MARK: - UIKit host

final class ConfettiEmitterHostView: UIView {

    private var cleanupWorkItem: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func fire(palette: ConfettiPalette) {
        cleanupWorkItem?.cancel()

        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterMode = .surface
        emitter.renderMode = .unordered
        emitter.beginTime = CACurrentMediaTime()
        emitter.emitterCells = Self.cells(for: palette)

        layer.addSublayer(emitter)
        layoutEmitter(emitter)

        let burstRate: Float = 42
        emitter.birthRate = burstRate

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) { [weak emitter] in
            emitter?.birthRate = 0
        }

        let removal = DispatchWorkItem { [weak emitter] in
            emitter?.removeFromSuperlayer()
        }
        cleanupWorkItem = removal
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: removal)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.compactMap { $0 as? CAEmitterLayer }.forEach(layoutEmitter)
    }

    private func layoutEmitter(_ emitter: CAEmitterLayer) {
        emitter.frame = bounds
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY - 2)
        emitter.emitterSize = CGSize(width: min(bounds.width * 0.45, 220), height: 2)
    }

    private static func cells(for palette: ConfettiPalette) -> [CAEmitterCell] {
        let colors = palette.uiColors
        return colors.enumerated().map { index, uiColor in
            let cell = CAEmitterCell()
            cell.contents = ConfettiEmitterHostView.tileImage(color: uiColor)
            cell.birthRate = 9
            cell.lifetime = 3.2
            cell.velocity = CGFloat(320 + index * 35)
            cell.velocityRange = 140
            cell.yAcceleration = 260
            cell.emissionLongitude = -.pi / 2
            cell.emissionRange = .pi / 2.8
            cell.spin = 3.8
            cell.spinRange = 2.4
            cell.scale = 0.55
            cell.scaleRange = 0.25
            cell.alphaSpeed = -0.35
            cell.color = uiColor.cgColor
            return cell
        }
    }

    private static func tileImage(color: UIColor, size: CGSize = CGSize(width: 10, height: 14)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            color.setFill()
            UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 2).fill()
        }
    }
}

// MARK: - UIViewRepresentable

struct ConfettiView: UIViewRepresentable {

    let driver: ConfettiBurstDriver

    func makeCoordinator() -> Coordinator {
        Coordinator(driver: driver)
    }

    func makeUIView(context: Context) -> ConfettiEmitterHostView {
        let view = ConfettiEmitterHostView()
        context.coordinator.attach(view)
        return view
    }

    func updateUIView(_ uiView: ConfettiEmitterHostView, context: Context) {}

    static func dismantleUIView(_ uiView: ConfettiEmitterHostView, coordinator: Coordinator) {
        coordinator.detach()
    }

    /// Routes `fire` into the embedded emitter host (same as `ConfettiBurstDriver.fire`).
    final class Coordinator {
        private let driver: ConfettiBurstDriver

        init(driver: ConfettiBurstDriver) {
            self.driver = driver
        }

        func attach(_ view: ConfettiEmitterHostView) {
            driver.host = view
        }

        func detach() {
            driver.host = nil
        }

        func fire(_ palette: ConfettiPalette) {
            driver.fire(palette)
        }
    }
}
