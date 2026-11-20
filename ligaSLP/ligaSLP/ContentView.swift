import SwiftUI
import WebKit

// MARK: - WebView

struct WebView: UIViewRepresentable {
    let url: URL
    @Binding var webView: WKWebView

    func makeUIView(context: Context) -> WKWebView {
        // Connect both the navigation and UI delegates to the coordinator
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url != url {
            uiView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // Adopt both protocols in the Coordinator
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        
        func webView(
            _ webView: WKWebView,
            didFinish navigation: WKNavigation!
        ) {
            print("Page Loaded")
        }
        
        // HELPER LOGIC: Centralized check to see if a URL belongs outside the app
        private func shouldOpenInSafari(url: URL) -> Bool {
            let scheme = url.scheme?.lowercased() ?? ""
            let host = url.host?.lowercased() ?? ""

            // 1. Check for native system schemes (mailto:, whatsapp:, tel:)
            let isExternalApp = !["http", "https"].contains(scheme)
            if isExternalApp { return true }
            
            // 2. Check for traditional social media URLs or email structures
            let isSocialOrEmail = host.contains("instagram.com") ||
                                  host.contains("facebook.com") ||
                                  host.contains("whatsapp.com") ||
                                  scheme == "mailto"
            if isSocialOrEmail { return true }
            
            // 3. COPAFINAL ROUTING ENGINE RULES:
            if host.contains("copafinal.com") {
                // If it belongs to CopaFinal but does NOT belong to your specific tournament subdomain context,
                // push it out to Safari.
                if !host.contains("ligacolegialslp") {
                    return true
                }
            } else {
                // Ignore blank states on startup
                if host.isEmpty { return false }
                
                // 4. Any other completely different external HTTPS link should go out to Safari
                return true
            }

            return false
        }
        
        // 1. FIX FOR STANDARD SAME-TAB CLICKED LINKS
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // ONLY intercept if the navigation comes from an explicit tap or link activation!
            // This prevents system initializations and automatic page loads from jumping to Safari.
            if navigationAction.navigationType == .linkActivated {
                if shouldOpenInSafari(url: url) {
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    decisionHandler(.cancel) // Prevent loading internally
                    return
                }
            }

            decisionHandler(.allow)
        }
        
        // 2. ABSOLUTE FIX FOR NEW TABS (Handles target="_blank" links without breaking SwiftUI)
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            
            if let url = navigationAction.request.url {
                if shouldOpenInSafari(url: url) {
                    // Instantly open the link in Safari directly from the user's action trigger
                    DispatchQueue.main.async {
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    }
                    return nil // Tell WKWebView to drop the new window frame completely
                } else {
                    // Fallback: If it's an internal link that accidentally had target="_blank", load it in place
                    webView.load(navigationAction.request)
                }
            }
            return nil
        }
    }
}

// MARK: - ContentView

struct ContentView: View {

    @State private var address = "https://www.ligacolegialslp.copafinal.com"
    @State private var currentURL = URL(string: "https://www.ligacolegialslp.copafinal.com")!

    @State private var webView = WKWebView()

    var body: some View {

        VStack(spacing: 0) {

            // Browser
            WebView(
                url: currentURL,
                webView: $webView
            )

            Divider()
                .padding()
                .font(.title3)
        }
    }

    private func loadPage() {

        var urlString = address.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if !urlString.hasPrefix("http://")
            && !urlString.hasPrefix("https://") {
            urlString = "https://" + urlString
        }

        if let url = URL(string: urlString) {
            currentURL = url
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
