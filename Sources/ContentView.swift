import SwiftUI
import WebKit

struct InstagramCleanerView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        
        // Script CSS + JS para ocultar a aba Reels e bloquear o scroll infinito
        let blockReelsScript = """
        (function() {
            const style = document.createElement('style');
            style.innerHTML = `
                /* Oculta o ícone do Reels na barra de navegação inferior/lateral */
                a[href*="/reels/"], 
                a[href="/reels"] {
                    display: none !important;
                }
                /* Oculta carrosséis de Reels sugeridos no feed */
                article:has(a[href*="/reel/"]) {
                    /* Opcional: remova o comentário abaixo se também quiser esconder Reels do feed */
                    /* display: none !important; */
                }
            `;
            document.documentElement.appendChild(style);

            // Impede navegação direta para a aba de feed infinito do Reels (/reels/),
            // mas permite abrir um Reel individual (/reel/ID) enviado por DM
            const observer = new MutationObserver(() => {
                if (window.location.pathname.startsWith('/reels')) {
                    window.location.replace('/');
                }
            });
            observer.observe(document.body, { childList: true, subtree: true });
        })();
        """
        
        let userScript = WKUserScript(
            source: blockReelsScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(userScript)
        
        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true
        
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        
        if let url = URL(string: "https://www.instagram.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
        InstagramCleanerView()
            .ignoresSafeArea(edges: .bottom)
    }
}
