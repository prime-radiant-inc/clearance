import AppKit
import Combine
import SwiftUI

@MainActor
final class DockVisibilityController {
    static let shared = DockVisibilityController { policy in
        let application = NSApplication.shared
        guard application.activationPolicy() != policy else { return }
        let wasActive = application.isActive
        if application.setActivationPolicy(policy), policy == .regular, wasActive {
            application.activate(ignoringOtherApps: true)
        }
    }

    private let applyActivationPolicy: (NSApplication.ActivationPolicy) -> Void
    private var settingsSubscription: AnyCancellable?
    private var documentWindows: Set<ObjectIdentifier> = []
    private weak var workspaceWindow: NSWindow?
    private var hasRegisteredWorkspaceWindow = false
    private var workspaceSceneOpener: (() -> Void)?
    private var workspaceOpenHandler: (([URL]) -> Void)?
    private var pendingOpenURLs: [[URL]] = []
    private(set) var hideDockIconWhenNoDocuments = false

    init(applyActivationPolicy: @escaping (NSApplication.ActivationPolicy) -> Void) {
        self.applyActivationPolicy = applyActivationPolicy
    }

    func observe(_ settings: AppSettings) {
        settingsSubscription = settings.$hideDockIconWhenNoDocuments
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.hideDockIconWhenNoDocuments = enabled
                self?.updateActivationPolicy()
            }
    }

    func setDocumentOpen(_ open: Bool, for window: NSWindow) {
        let id = ObjectIdentifier(window)
        if open {
            documentWindows.insert(id)
        } else {
            documentWindows.remove(id)
        }
        updateActivationPolicy()
    }

    func removeWindow(_ window: NSWindow) {
        documentWindows.remove(ObjectIdentifier(window))
        updateActivationPolicy()
    }

    func updateActivationPolicy() {
        applyActivationPolicy(hideDockIconWhenNoDocuments && documentWindows.isEmpty ? .accessory : .regular)
    }

    func registerWorkspaceWindow(_ window: NSWindow) {
        workspaceWindow = window
        hasRegisteredWorkspaceWindow = true
    }

    func registerWorkspaceSceneOpener(_ opener: @escaping () -> Void) {
        workspaceSceneOpener = opener
    }

    @discardableResult
    func showWorkspace() -> Bool {
        guard let workspaceWindow else {
            guard let workspaceSceneOpener else { return false }
            workspaceSceneOpener()
            return true
        }
        if workspaceWindow.isMiniaturized {
            workspaceWindow.deminiaturize(nil)
        }
        workspaceWindow.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        return true
    }

    func openURLs(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        if hasRegisteredWorkspaceWindow, workspaceWindow == nil {
            // A released SwiftUI window has a new view model when recreated.
            workspaceOpenHandler = nil
            hasRegisteredWorkspaceWindow = false
        }
        // Queue before opening the scene: onAppear may install its receiver immediately.
        pendingOpenURLs.append(urls)
        showWorkspace()
        deliverPendingOpenURLs()
    }

    func registerWorkspaceOpenHandler(_ handler: @escaping ([URL]) -> Void) {
        workspaceOpenHandler = handler
        deliverPendingOpenURLs()
    }

    private func deliverPendingOpenURLs() {
        guard let workspaceOpenHandler else { return }
        let pending = pendingOpenURLs
        pendingOpenURLs.removeAll()
        for urls in pending {
            workspaceOpenHandler(urls)
        }
    }
}

struct DockDocumentWindowRegistration: NSViewRepresentable {
    let hasDocument: Bool
    var isWorkspace = false

    func makeNSView(context: Context) -> DockDocumentWindowObserver {
        let view = DockDocumentWindowObserver(controller: .shared, isWorkspace: isWorkspace)
        view.hasDocument = hasDocument
        return view
    }

    func updateNSView(_ view: DockDocumentWindowObserver, context: Context) {
        view.hasDocument = hasDocument
    }

    static func dismantleNSView(_ view: DockDocumentWindowObserver, coordinator: ()) {
        view.stopTracking()
    }
}

@MainActor
final class DockDocumentWindowObserver: NSView {
    var hasDocument = false {
        didSet { updateRegistration() }
    }
    private let controller: DockVisibilityController
    private let isWorkspace: Bool
    private weak var trackedWindow: NSWindow?
    private var isClosed = false

    init(controller: DockVisibilityController, isWorkspace: Bool = false) {
        self.controller = controller
        self.isWorkspace = isWorkspace
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopTracking()
        guard let window else { return }
        trackedWindow = window
        isClosed = false
        if isWorkspace {
            controller.registerWorkspaceWindow(window)
        }
        NotificationCenter.default.addObserver(self, selector: #selector(windowWillClose),
                                              name: NSWindow.willCloseNotification, object: window)
        NotificationCenter.default.addObserver(self, selector: #selector(windowDidBecomeKey),
                                              name: NSWindow.didBecomeKeyNotification, object: window)
        updateRegistration()
    }

    func stopTracking() {
        NotificationCenter.default.removeObserver(self)
        if let trackedWindow {
            controller.removeWindow(trackedWindow)
        }
        trackedWindow = nil
    }

    @objc private func windowWillClose(_ notification: Notification) {
        isClosed = true
        if let trackedWindow {
            controller.removeWindow(trackedWindow)
        }
    }

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        isClosed = false
        updateRegistration()
    }

    private func updateRegistration() {
        guard !isClosed, let trackedWindow else { return }
        controller.setDocumentOpen(hasDocument, for: trackedWindow)
    }
}
