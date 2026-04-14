import AppKit
import SwiftUI
import WebKit

struct HeadingScrollRequest: Equatable {
    let headingIndex: Int
    let sequence: Int
}

@MainActor
final class RenderedHTMLLoadHandle {
    let fileURL: URL
    let readAccessURL: URL
    private let stagedDirectoryURL: URL

    init(html: String, relatedContentURL: URL) throws {
        let stagedDirectoryURL = try Self.makeStagedDirectoryURL(near: relatedContentURL)
        let fileURL = stagedDirectoryURL.appendingPathComponent("rendered-preview.html")
        try html.write(to: fileURL, atomically: true, encoding: .utf8)

        self.fileURL = fileURL
        self.readAccessURL = relatedContentURL
        self.stagedDirectoryURL = stagedDirectoryURL
    }

    deinit {
        try? FileManager.default.removeItem(at: stagedDirectoryURL)
    }

    static func load(
        html: String,
        baseURL: URL,
        allowingReadAccessTo relatedContentURL: URL?,
        in webView: WKWebView
    ) -> RenderedHTMLLoadHandle? {
        guard let relatedContentURL,
              baseURL.isFileURL,
              relatedContentURL.isFileURL,
              let handle = try? RenderedHTMLLoadHandle(
                html: html,
                relatedContentURL: relatedContentURL
              ) else {
            webView.loadHTMLString(html, baseURL: baseURL)
            return nil
        }

        webView.loadFileURL(handle.fileURL, allowingReadAccessTo: handle.readAccessURL)
        return handle
    }

    private static func makeStagedDirectoryURL(near relatedContentURL: URL) throws -> URL {
        let fileManager = FileManager.default
        let contentDirectoryURL = relatedContentURL.hasDirectoryPath
            ? relatedContentURL
            : relatedContentURL.deletingLastPathComponent()
        let stagedDirectoryURL = contentDirectoryURL
            .appendingPathComponent(".clearance-rendered-preview-\(UUID().uuidString)", isDirectory: true)

        try fileManager.createDirectory(
            at: stagedDirectoryURL,
            withIntermediateDirectories: true
        )

        return stagedDirectoryURL
    }
}

struct RenderedMarkdownView: NSViewRepresentable {
    fileprivate struct RenderContentKey: Equatable {
        let body: String
        let flattenedFrontmatter: [String: String]
        let sourceDocumentURL: URL
        let isRemoteContent: Bool
        let theme: AppTheme
        let appearance: AppearancePreference
    }

    let document: ParsedMarkdownDocument
    let sourceDocumentURL: URL
    let isRemoteContent: Bool
    let headingScrollRequest: HeadingScrollRequest?
    let theme: AppTheme
    let appearance: AppearancePreference
    let textScale: Double
    let onOpenLinkedDocument: (URL) -> Void
    private let builder = RenderedHTMLBuilder()

    func makeCoordinator() -> Coordinator {
        Coordinator(
            sourceDocumentURL: sourceDocumentURL,
            onOpenLinkedDocument: onOpenLinkedDocument
        )
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let renderContentKey = RenderContentKey(
            body: document.body,
            flattenedFrontmatter: document.flattenedFrontmatter,
            sourceDocumentURL: sourceDocumentURL,
            isRemoteContent: isRemoteContent,
            theme: theme,
            appearance: appearance
        )
        let html = builder.build(
            document: document,
            sourceDocumentURL: sourceDocumentURL,
            theme: theme,
            appearance: appearance,
            textScale: textScale,
            isRemoteContent: isRemoteContent
        )
        let coordinator = context.coordinator
        coordinator.sourceDocumentURL = sourceDocumentURL
        coordinator.onOpenLinkedDocument = onOpenLinkedDocument
        let baseURL = Self.navigationBaseURL(for: sourceDocumentURL)
        if coordinator.renderContentKey != renderContentKey {
            coordinator.renderContentKey = renderContentKey
            coordinator.appliedTextScale = textScale
            coordinator.pendingTextScale = nil
            coordinator.pendingScrollRequest = headingScrollRequest
            coordinator.loadHandle = RenderedHTMLLoadHandle.load(
                html: html,
                baseURL: baseURL,
                allowingReadAccessTo: isRemoteContent ? nil : sourceDocumentURL.deletingLastPathComponent(),
                in: webView
            )
            return
        }

        coordinator.applyTextScaleIfNeeded(textScale, in: webView)
        coordinator.applyScrollRequestIfNeeded(headingScrollRequest, in: webView)
    }

    static func navigationBaseURL(for sourceDocumentURL: URL) -> URL {
        sourceDocumentURL.deletingLastPathComponent()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var sourceDocumentURL: URL
        var onOpenLinkedDocument: (URL) -> Void
        fileprivate var renderContentKey: RenderContentKey?
        var pendingScrollRequest: HeadingScrollRequest?
        var pendingTextScale: Double?
        var appliedTextScale: Double?
        var loadHandle: RenderedHTMLLoadHandle?
        private var appliedScrollRequest: HeadingScrollRequest?

        init(sourceDocumentURL: URL, onOpenLinkedDocument: @escaping (URL) -> Void) {
            self.sourceDocumentURL = sourceDocumentURL
            self.onOpenLinkedDocument = onOpenLinkedDocument
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated {
                switch MarkdownLinkRouter.action(for: navigationAction.request.url, sourceDocumentURL: sourceDocumentURL) {
                case .allowWebView:
                    break
                case .openInApp(let url):
                    onOpenLinkedDocument(url)
                    decisionHandler(.cancel)
                    return
                case .openExternal(let url):
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }

            if LocalNavigationPolicy.allows(navigationAction.request.url) {
                decisionHandler(.allow)
                return
            }

            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyTextScaleIfNeeded(pendingTextScale, in: webView)
            pendingTextScale = nil
            applyScrollRequestIfNeeded(pendingScrollRequest, in: webView)
            pendingScrollRequest = nil
        }

        func applyTextScaleIfNeeded(_ textScale: Double?, in webView: WKWebView) {
            guard let textScale,
                  textScale != appliedTextScale else {
                return
            }

            guard !webView.isLoading else {
                pendingTextScale = textScale
                return
            }

            let formattedTextScale = RenderedHTMLBuilder.formatCSSNumber(textScale)
            let script = "document.documentElement.style.setProperty('--text-scale', '\(formattedTextScale)');"
            webView.evaluateJavaScript(script)
            appliedTextScale = textScale
            pendingTextScale = nil
        }

        func applyScrollRequestIfNeeded(_ request: HeadingScrollRequest?, in webView: WKWebView) {
            guard let request,
                  request != appliedScrollRequest else {
                return
            }

            let script = """
            (function() {
              const headings = document.querySelectorAll('article.markdown h1, article.markdown h2, article.markdown h3, article.markdown h4, article.markdown h5, article.markdown h6');
              const target = headings[\(request.headingIndex)];
              if (!target) { return false; }
              target.scrollIntoView({ behavior: 'smooth', block: 'start', inline: 'nearest' });
              return true;
            })();
            """

            webView.evaluateJavaScript(script)
            appliedScrollRequest = request
        }
    }
}
