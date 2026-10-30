//
//  KeyboardDismissOnTap.swift
//  StepKit
//
//  Tocar fuera de un campo de texto retira el teclado, en toda la app. El reconocedor vive en la
//  ventana y no se queda el toque (cancelsTouchesInView = false), así que botones, interruptores y
//  filas siguen funcionando igual; solo se añade el cierre del teclado.
//

import SwiftUI
import UIKit

struct KeyboardDismissOnTap: UIViewRepresentable {
    /// Se instala en cuanto la vista entra en una ventana (antes no hay dónde ponerlo).
    final class HostView: UIView {
        var onWindow: ((UIView) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window != nil { onWindow?(self) }
        }
    }

    func makeUIView(context: Context) -> HostView {
        let view = HostView(frame: .zero)
        view.isUserInteractionEnabled = false
        view.onWindow = { context.coordinator.install(from: $0) }
        return view
    }

    func updateUIView(_ uiView: HostView, context: Context) {
        context.coordinator.install(from: uiView)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private weak var window: UIWindow?

        func install(from view: UIView) {
            guard let window = view.window, window !== self.window else { return }
            self.window = window
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delaysTouchesEnded = false
            tap.delegate = self
            window.addGestureRecognizer(tap)
        }

        @objc private func dismiss() {
            window?.endEditing(true)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
        /// Sin dependencias con los gestos de SwiftUI: ni espera a que fallen ni los hace esperar.
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRequireFailureOf other: UIGestureRecognizer) -> Bool { false }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldBeRequiredToFailBy other: UIGestureRecognizer) -> Bool { false }

        /// Solo actúa si hay teclado; y nunca sobre el propio teclado ni sobre otro campo de texto
        /// (ese cambia el foco por sí mismo).
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard let view = touch.view, let window else { return false }
            guard window.firstResponderView != nil else { return false }
            var current: UIView? = view
            while let v = current {
                // El teclado vive en otra ventana: aquí solo hay que dejar pasar los campos de texto.
                if v is UITextField || v is UITextView { return false }
                current = v.superview
            }
            return true
        }
    }
}

private extension UIView {
    var firstResponderView: UIView? {
        if isFirstResponder { return self }
        for sub in subviews { if let r = sub.firstResponderView { return r } }
        return nil
    }
}

extension View {
    /// El teclado se cierra al tocar fuera de un campo de texto.
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissOnTap().frame(width: 0, height: 0))
    }
}


