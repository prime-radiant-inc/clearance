import AppKit
import SwiftUI
import WebKit

struct HeadingScrollRequest: Equatable {
    let headingIndex: Int
    let sequence: Int
}

struct RenderedMarkdownView: NSViewRepresentable {
    let document: ParsedMarkdownDocument
    let sourceDocumentURL: URL
    let headingScrollRequest: HeadingScrollRequest?
    let theme: AppTheme
    let appearance: AppearancePreference
    var isRemoteContent: Bool = false
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
        let html = builder.build(
            document: document,
            theme: theme,
            appearance: appearance,
            isRemoteContent: isRemoteContent
        )
        let coordinator = context.coordinator
        coordinator.sourceDocumentURL = sourceDocumentURL
        coordinator.onOpenLinkedDocument = onOpenLinkedDocument
        let baseURL = sourceDocumentURL.deletingLastPathComponent()
        if coordinator.renderedHTML != html {
            coordinator.renderedHTML = html
            coordinator.pendingScrollRequest = headingScrollRequest
            webView.loadHTMLString(html, baseURL: baseURL)
            return
        }

        coordinator.applyScrollRequestIfNeeded(headingScrollRequest, in: webView)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var sourceDocumentURL: URL
        var onOpenLinkedDocument: (URL) -> Void
        var renderedHTML: String?
        var pendingScrollRequest: HeadingScrollRequest?
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
            applyScrollRequestIfNeeded(pendingScrollRequest, in: webView)
            pendingScrollRequest = nil
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
