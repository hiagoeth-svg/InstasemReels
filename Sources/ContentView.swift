import SwiftUI
import WebKit

struct InstagramCleanerView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        
        let blockReelsScript = #"""
        (function() {
            // Aviso visual rápido (2s) para confirmar que a atualização entrou no iPhone
            function showVersionToast() {
                const toast = document.createElement('div');
                toast.textContent = 'Sem Reels v2 ativo';
                toast.style.cssText = 'position:fixed;top:52px;left:50%;transform:translateX(-50%);background:rgba(0,0,0,0.82);color:#fff;padding:6px 14px;border-radius:20px;font-size:12px;font-family:-apple-system,sans-serif;z-index:999999;pointer-events:none;transition:opacity 0.5s;';
                document.body.appendChild(toast);
                setTimeout(() => { toast.style.opacity = '0'; }, 1800);
                setTimeout(() => { toast.remove(); }, 2400);
            }
            if (document.body) showVersionToast();
            else window.addEventListener('DOMContentLoaded', showVersionToast);

            // 1. Oculta a aba Reels na barra de navegação e prepara a trava global de scroll
            const style = document.createElement('style');
            style.innerHTML = `
                a[href="/reels/"],
                a[href="/reels"] {
                    display: none !important;
                }
                html.reel-locked,
                html.reel-locked body {
                    overflow: hidden !important;
                    overscroll-behavior: none !important;
                    touch-action: none !important;
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

            // Detecta se um Reel foi aberto como janela sobreposta (modal) dentro da DM
            function isVideoOpenInModal() {
                const dialogs = document.querySelectorAll('[role="dialog"]');
                for (const d of dialogs) {
                    if (d.querySelector('video')) return true;
                }
                return false;
            }

            // Trava os containers internos com scroll vertical que envolvem o vídeo
            function lockReelContainers(shouldLock) {
                document.documentElement.classList.toggle('reel-locked', shouldLock);

                if (!shouldLock) {
                    document.querySelectorAll('[data-reel-locked="1"]').forEach(el => {
                        el.style.removeProperty('overflow-y');
                        el.style.removeProperty('touch-action');
                        delete el.dataset.reelLocked;
                    });
                    return;
                }

                document.querySelectorAll('video').forEach(video => {
                    let el = video.parentElement;
                    while (el && el !== document.body) {
                        const cs = window.getComputedStyle(el);
                        if (cs.overflowY === 'scroll' || cs.overflowY === 'auto' || (cs.scrollSnapType && cs.scrollSnapType !== 'none')) {
                            el.dataset.reelLocked = '1';
                            el.style.setProperty('overflow-y', 'hidden', 'important');
                            el.style.setProperty('touch-action', 'none', 'important');
                        }
                        el = el.parentElement;
                    }
                });
            }

            function checkRoute() {
                const path = window.location.pathname;

                if (isReelsTab(path)) {
                    allowedReelId = null;
                    window.location.replace('/');
                    return;
                }

                const currentId = getReelId(path);
                const modalVideo = isVideoOpenInModal();

                if (currentId) {
                    if (!allowedReelId) {
                        allowedReelId = currentId;
                    } else if (allowedReelId !== currentId && !isRedirecting) {
                        // Se conseguir trocar de vídeo de alguma forma, volta imediatamente
                        isRedirecting = true;
                        allowedReelId = null;
                        window.history.back();
                        setTimeout(() => { isRedirecting = false; }, 600);
                        return;
                    }
                    lockReelContainers(true);
                } else if (modalVideo) {
                    lockReelContainers(true);
                } else {
                    allowedReelId = null;
                    lockReelContainers(false);
                }
            }

            // 2. Bloqueia o arraste na tela do Reel (libera apenas listas de comentários e campos de texto)
            function blockScroll(e) {
                const inReel = Boolean(getReelId(window.location.pathname)) || isVideoOpenInModal();
                if (!inReel) return;

                if (e.target && e.target.closest('ul, textarea, input')) {
                    return;
                }
                e.preventDefault();
            }

            window.addEventListener('touchmove', blockScroll, { passive: false, capture: true });
            window.addEventListener('wheel', blockScroll, { passive: false, capture: true });

            const observer = new MutationObserver(checkRoute);
            observer.observe(document.documentElement, { childList: true, subtree: true });
            window.addEventListener('popstate', checkRoute);
            setInterval(checkRoute, 250);

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
