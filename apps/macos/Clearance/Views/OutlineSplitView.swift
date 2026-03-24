import AppKit
import SwiftUI

struct OutlineSplitView<Primary: View, Inspector: View>: NSViewControllerRepresentable {
    let showsInspector: Bool
    let inspectorWidth: CGFloat
    private let primary: Primary
    private let inspector: Inspector

    init(
        showsInspector: Bool,
        inspectorWidth: CGFloat = 240,
        @ViewBuilder primary: () -> Primary,
        @ViewBuilder inspector: () -> Inspector
    ) {
        self.showsInspector = showsInspector
        self.inspectorWidth = inspectorWidth
        self.primary = primary()
        self.inspector = inspector()
    }

    func makeNSViewController(context: Context) -> OutlineSplitViewController {
        OutlineSplitViewController(
            primary: AnyView(primary),
            inspector: AnyView(inspector),
            showsInspector: showsInspector,
            inspectorWidth: inspectorWidth
        )
    }

    func updateNSViewController(_ controller: OutlineSplitViewController, context: Context) {
        controller.update(
            primary: AnyView(primary),
            inspector: AnyView(inspector),
            showsInspector: showsInspector,
            inspectorWidth: inspectorWidth
        )
    }
}

@MainActor
final class OutlineSplitViewController: NSSplitViewController {
    let inspectorItem: NSSplitViewItem

    private let primaryHostingController: NSHostingController<AnyView>
    private let inspectorHostingController: NSHostingController<AnyView>
    private let primaryItem: NSSplitViewItem
    private var currentInspectorWidth: CGFloat
    private var pendingInspectorCollapsed: Bool

    init(
        primary: AnyView,
        inspector: AnyView,
        showsInspector: Bool,
        inspectorWidth: CGFloat = 240
    ) {
        primaryHostingController = NSHostingController(rootView: primary)
        inspectorHostingController = NSHostingController(rootView: inspector)
        primaryItem = NSSplitViewItem(viewController: primaryHostingController)
        self.inspectorItem = NSSplitViewItem(inspectorWithViewController: inspectorHostingController)
        self.currentInspectorWidth = 0
        self.pendingInspectorCollapsed = !showsInspector

        super.init(nibName: nil, bundle: nil)

        splitView.isVertical = true
        splitView.dividerStyle = .thin

        configureInspectorWidth(inspectorWidth)
        inspectorItem.canCollapse = true
        inspectorItem.canCollapseFromWindowResize = false
        inspectorItem.collapseBehavior = .preferResizingSiblingsWithFixedSplitView
        inspectorItem.isCollapsed = pendingInspectorCollapsed

        addSplitViewItem(primaryItem)
        addSplitViewItem(inspectorItem)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(
        primary: AnyView,
        inspector: AnyView,
        showsInspector: Bool,
        inspectorWidth: CGFloat
    ) {
        primaryHostingController.rootView = primary
        inspectorHostingController.rootView = inspector
        configureInspectorWidth(inspectorWidth)
        setInspectorCollapsed(!showsInspector, animated: view.window != nil)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        applyPendingInspectorState(animated: false)
    }

    func setInspectorCollapsed(_ collapsed: Bool, animated: Bool) {
        pendingInspectorCollapsed = collapsed
        applyPendingInspectorState(animated: animated)
    }

    private func applyPendingInspectorState(animated: Bool) {
        guard view.window != nil,
              inspectorItem.isCollapsed != pendingInspectorCollapsed else {
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                inspectorItem.animator().isCollapsed = pendingInspectorCollapsed
            }
        } else {
            inspectorItem.isCollapsed = pendingInspectorCollapsed
        }
    }

    private func configureInspectorWidth(_ width: CGFloat) {
        guard currentInspectorWidth != width else {
            return
        }

        currentInspectorWidth = width
        inspectorItem.minimumThickness = width
        inspectorItem.maximumThickness = width
    }
}
