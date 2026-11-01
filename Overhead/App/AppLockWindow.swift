//
//  AppLockWindow.swift
//  Overhead
//
//  Created by Lorenzo Mazzarotto on 30/10/26.
//

import ComposableArchitecture
import SwiftUI

extension View {
    func appLock(store: StoreOf<AppLock>, session: StoreOf<AppFeature>) -> some View {
        modifier(AppLockModifier(session: session, store: store))
    }
}

private struct AppLockModifier: ViewModifier {
    let session: StoreOf<AppFeature>
    let store: StoreOf<AppLock>

    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .background(AppLockWindow(isVisible: store.isCovering && session.scene.is(\.tabs), store: store))
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .active:
                    store.send(.sceneBecameActive)
                case .background:
                    store.send(.sceneBecameBackground)
                case .inactive:
                    store.send(.sceneBecameInactive)
                @unknown default:
                    break
                }
            }
            .onChange(of: session.scene.is(\.signIn)) { _, isSignedOut in
                if isSignedOut { store.send(.signedOut) }
            }
    }
}

private struct AppLockWindow: UIViewRepresentable {
    let isVisible: Bool
    let store: StoreOf<AppLock>

    func makeUIView(context: Context) -> AppLockWindowAnchor {
        AppLockWindowAnchor(store: store)
    }

    func updateUIView(_ anchor: AppLockWindowAnchor, context: Context) {
        anchor.isLockVisible = isVisible
    }
}

final class AppLockWindowAnchor: UIView {
    var fadeDuration: TimeInterval = 0.25
    var isLockVisible = false {
        didSet {
            guard isLockVisible != oldValue else { return }
            update()
        }
    }

    private let store: StoreOf<AppLock>
    private var lockWindow: UIWindow?

    init(store: StoreOf<AppLock>) {
        self.store = store
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        update()
    }

    private func hideLockWindow() {
        guard let lockWindow else { return }
        lockWindow.isUserInteractionEnabled = false
        UIView.animate(withDuration: fadeDuration) {
            lockWindow.alpha = 0
        } completion: { [weak self] _ in
            guard let self, !isLockVisible else { return }
            lockWindow.isHidden = true
            self.lockWindow = nil
        }
    }

    private func showLockWindow() {
        if let lockWindow {
            lockWindow.layer.removeAllAnimations()
            lockWindow.isUserInteractionEnabled = true
            lockWindow.alpha = 1
            return
        }
        guard let windowScene = window?.windowScene else { return }
        let hostingController = UIHostingController(rootView: AppLockView(store: store))
        hostingController.view.backgroundColor = .clear
        let lockWindow = UIWindow(windowScene: windowScene)
        lockWindow.rootViewController = hostingController
        lockWindow.backgroundColor = .clear
        lockWindow.windowLevel = UIWindow.Level(UIWindow.Level.normal.rawValue + 2)
        lockWindow.isHidden = false
        self.lockWindow = lockWindow
    }

    private func update() {
        isLockVisible ? showLockWindow() : hideLockWindow()
    }
}
