import SwiftUI
import WebKit

/// Renders untrusted mail HTML in a locked-down `WKWebView`. Defense in depth:
///  1. JavaScript disabled.
///  2. A `WKContentRuleList` that BLOCKS every network load (no remote images / trackers / beacons).
///  3. A navigation delegate that cancels any http/https/file navigation as a backstop.
///  4. Fail-CLOSED: if the rule list can't compile, the message is NOT rendered (a notice shows
///     instead) so untrusted HTML never loads without the network block in place.
/// `baseURL: nil` so relative URLs can't resolve either.
struct MailHTMLView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.attach(to: webView, html: html)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.attach(to: webView, html: html)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        private static var ruleList: WKContentRuleList?
        private var loadedHTML: String?

        func attach(to webView: WKWebView, html: String) {
            guard html != loadedHTML else { return }
            loadedHTML = html
            if let list = Self.ruleList {
                load(webView, html: html, rules: list)
            } else {
                let json = #"[{"trigger":{"url-filter":".*"},"action":{"type":"block"}}]"#
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "kdwarm-mail-block-all", encodedContentRuleList: json) { [weak webView] list, _ in
                    Self.ruleList = list
                    guard let webView else { return }
                    self.load(webView, html: html, rules: list)
                }
            }
        }

        private func load(_ webView: WKWebView, html: String, rules: WKContentRuleList?) {
            webView.configuration.userContentController.removeAllContentRuleLists()
            guard let rules else {
                // Fail closed: never render untrusted HTML without the network block applied.
                webView.loadHTMLString(
                    "<body style='font:13px -apple-system;color:#888;padding:16px'>Could not render this message safely.</body>",
                    baseURL: nil)
                return
            }
            webView.configuration.userContentController.add(rules)
            webView.loadHTMLString(html, baseURL: nil)
        }

        /// Backstop: allow only the in-memory document load (about:blank / data), cancel any network
        /// navigation (a link click or a remote redirect the rule list somehow let through).
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let scheme = navigationAction.request.url?.scheme?.lowercased()
            if scheme == nil || scheme == "about" || scheme == "data" {
                decisionHandler(.allow)
            } else {
                decisionHandler(.cancel)        // never load http/https/file from untrusted mail
            }
        }
    }
}
