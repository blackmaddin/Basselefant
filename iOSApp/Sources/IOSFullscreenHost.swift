import SwiftUI
import UIKit

final class FullscreenHostingController<Content: View>: UIHostingController<Content> {
    private var didConfigureCatalystWindow = false

    override var prefersStatusBarHidden: Bool { true }
    override var preferredStatusBarUpdateAnimation: UIStatusBarAnimation { .fade }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.insetsLayoutMarginsFromSafeArea = false
        additionalSafeAreaInsets = .zero
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        #if targetEnvironment(macCatalyst)
        configureCatalystWindowIfNeeded()
        DispatchQueue.main.async { [weak self] in
            self?.configureCatalystWindowIfNeeded()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.configureCatalystWindowIfNeeded()
        }
        #endif
    }

    #if targetEnvironment(macCatalyst)
    private func configureCatalystWindowIfNeeded() {
        guard !didConfigureCatalystWindow else { return }
        guard let windowScene = view.window?.windowScene else { return }

        windowScene.titlebar?.titleVisibility = .hidden
        windowScene.titlebar?.toolbar = nil

        didConfigureCatalystWindow = true
    }
    #endif
}

struct IOSFullscreenHost<Content: View>: UIViewControllerRepresentable {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    func makeUIViewController(context: Context) -> FullscreenHostingController<Content> {
        FullscreenHostingController(rootView: content)
    }

    func updateUIViewController(_ controller: FullscreenHostingController<Content>, context: Context) {
        controller.rootView = content
        controller.setNeedsStatusBarAppearanceUpdate()
    }
}
