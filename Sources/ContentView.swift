import SwiftUI
import WebKit

struct InstagramCleanerView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        
        // Usamos #""" para permitir regex no JavaScript sem conflito no Swift
        let blockReelsScript = #"""
        (function() {
            // 1. Oculta o botão da aba Reels na navegação sem esconder links enviados na DM
            const style = document.createElement('style');
            style.innerHTML = `
                a[href="/reels/"],
                a[href="/reels"] {
                    display: none !important;
                }
            `;
            document.documentElement.appendChild(style);

            let allowedReelId = null;
            let isRedirecting = false;

            function getReelId(pathname) {
                const match = pathname.match(/^\/reels?\/([^\/]+)/);
                return match ? match[1] : null;
            }

            function isReelsTab(pathname) {
                return pathname === '/reels' || pathname === '/reels/';
            }

            // 2. Vigia a URL: permite apenas o 1º Reel aberto via DM e bloqueia o próximo
            function checkRoute() {
                const path = window.location.pathname;

                if (isReelsTab(path)) {
                    allowedReelId = null;
                    window.location.replace('/');
                    return;
                }

                const currentId = getReelId(path);

                if (currentId) {
                    if (!allowedReelId) {
                        allowedReelId = currentId;
                    } else if (allowedReelId !== currentId && !isRedirecting) {
                        isRedirecting = true;
                        allowedReelId = null;
                        window.history.back();
                        setTimeout(() => { isRedirecting = false; }, 600);
                    }
                } else {
                    // Ao voltar para o Direct ou Feed, libera para abrir outro link enviado
                    allowedReelId = null;
                }
            }

            // 3. Trava o gesto de deslizar para baixo/cima na tela do Reel
            function blockScroll(e) {
                if (getReelId(window.location.pathname)) {
                    // Mantém o scroll funcionando dentro de modais (comentários / enviar)
                    if (e.target && e.target.closest('[role="dialog"]')) {
                        return;
                    }
                    e.preventDefault();
                }
            }

            window.addEventListener('touchmove', blockScroll, { passive: false, capture: true });
            window.addEventListener('wheel', blockScroll, { passive: false, capture: true });

            const observer = new MutationObserver(checkRoute);
            observer.observe(document.documentElement, { childList: true, subtree: true });
            window.addEventListener('popstate', checkRoute);
            setInterval(checkRoute, 300);

            checkRoute();
        })();
        """#
        
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
