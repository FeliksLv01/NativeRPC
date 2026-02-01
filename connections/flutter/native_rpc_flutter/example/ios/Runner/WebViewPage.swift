import UIKit
import WebKit
import NativeRPCKit

/// A view controller that displays a WKWebView connected to NativeRPC.
///
/// This page loads the web demo (React + Vite) and connects it to the same
/// CounterService that the Flutter app uses.
///
/// ## Usage
/// 1. Start the web demo: `cd examples/web-counter && pnpm dev`
/// 2. Open this page from Flutter via MethodChannel
/// 3. The web page can call native services through NativeRPC
class WebViewPage: UIViewController {
    
    // MARK: - Properties
    
    private var webView: WKWebView!
    private var rpcConnection: WebViewNativeRPCConnection?
    
    /// URL to load (defaults to local Vite dev server)
    var urlString: String = "http://localhost:5173"
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
        setupWebView()
        setupNativeRPC()
        loadWebDemo()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Web Demo"
        
        // Add close button
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        
        // Add reload button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .refresh,
            target: self,
            action: #selector(reloadTapped)
        )
    }
    
    private func setupWebView() {
        // Create configuration
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        
        // Create WebView
        webView = WKWebView(frame: .zero, configuration: config)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        
        // Allow inspecting with Safari DevTools
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        
        view.addSubview(webView)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupNativeRPC() {
        // Create WebView connection - this uses the SDK's WebViewNativeRPCConnection
        // Services are already registered in AppDelegate (CounterService)
        rpcConnection = WebViewNativeRPCConnection(
            webView: webView,
            handlerName: "nativeRPC",
            rootViewController: self
        )
        rpcConnection?.debugEnabled = true
        
        print("[WebViewPage] NativeRPC connection established")
    }
    
    private func loadWebDemo() {
        guard let url = URL(string: urlString) else {
            showError("Invalid URL: \(urlString)")
            return
        }
        
        print("[WebViewPage] Loading: \(url)")
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - Actions
    
    @objc private func closeTapped() {
        dismiss(animated: true)
    }
    
    @objc private func reloadTapped() {
        webView.reload()
    }
    
    // MARK: - Helpers
    
    private func showError(_ message: String) {
        let alert = UIAlertController(
            title: "Error",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Cleanup
    
    deinit {
        rpcConnection?.close()
        print("[WebViewPage] Closed and cleaned up")
    }
}

// MARK: - WKNavigationDelegate

extension WebViewPage: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("[WebViewPage] Started loading...")
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("[WebViewPage] Finished loading")
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("[WebViewPage] Navigation failed: \(error.localizedDescription)")
        showError("Failed to load page: \(error.localizedDescription)")
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("[WebViewPage] Provisional navigation failed: \(error.localizedDescription)")
        
        // Provide helpful message for common errors
        let nsError = error as NSError
        var message = error.localizedDescription
        
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost:
                message = "Cannot connect to \(urlString)\n\nMake sure the web demo is running:\ncd examples/web-counter && pnpm dev"
            case NSURLErrorTimedOut:
                message = "Connection timed out.\n\nMake sure the web demo is running on \(urlString)"
            default:
                break
            }
        }
        
        showError(message)
    }
}
