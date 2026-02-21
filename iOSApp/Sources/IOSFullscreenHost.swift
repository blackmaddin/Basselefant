import SwiftUI
import UIKit

final class FullscreenHostingController<Content: View>: UIHostingController<Content> {
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
