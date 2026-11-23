import SwiftUI
import WebKit

struct InstagramCleanerView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "reelLock")

        let blockReelsScript = #"""
        (function() {
            const STYLE_ID = 'insta-no-reels-style';
            function injectStyle() {
                if (document.getElementById(STYLE_ID)) return;
                const style = document.createElement('style');
                style.id = STYLE_ID;
                style.textContent = `
                    a[href="/reels/"],
                    a[href="/reels"] {
                        display: none !important;
                    }
                    .insta-lock-scroll {
                        overflow: hidden !important;
                        overflow-y: hidden !important;
                        touch-action: none !important;
                        overscroll-behavior: none !important;
                    }
                `;
                (document.head || document.documentElement).appendChild(style);
            }
            injectStyle();
            document.addEventListener('DOMContentLoaded', injectStyle);

            let allowedReelId = null;
            let lastNonReelUrl = '/';
            let isRedirecting = false;
            let isLocked = false;
            let lastNativeLockState = null;
            const lockedScrollPositions = new Map();

            function getReelId(pathname) {
                // Captura /reel/ID, /reels/ID e /usuario/reel/ID
                const match = pathname.match(/\/reels?\/([^\/]+)/i);
                return match ? match[1] : null;
            }

            function isReelsTab(pathname) {
                return /^\/reels\/?$/i.test(pathname);
            }

            function hasFullscreenVideo() {
                const path = window.location.pathname;
                if (path === '/' || path.startsWith('/stories/')) return false;
                const videos = document.querySelectorAll('video');
                const minHeight = window.innerHeight * 0.7;
                for (const v of videos) {
                    const rect = v.getBoundingClientRect();
                    if (rect.height >= minHeight && rect.bottom > 50 && rect.top < window.innerHeight - 50) {
                        return true;
                    }
                }
                return false;
            }

            function setNativeLock(locked) {
                if (lastNativeLockState === locked) return;
                lastNativeLockState = locked;
                if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.reelLock) {
                    window.webkit.messageHandlers.reelLock.postMessage(locked);
                }
            }

            function applyScrollLock(active) {
                isLocked = active;
                setNativeLock(active);

                if (!active) {
                    lockedScrollPositions.clear();
                    document.querySelectorAll('.insta-lock-scroll').forEach(el => {
                        el.classList.remove('insta-lock-scroll');
                    });
                    return;
                }

                if (document.documentElement) document.documentElement.classList.add('insta-lock-scroll');
                if (document.body) document.body.classList.add('insta-lock-scroll');

                const videos = document.querySelectorAll('video');
                videos.forEach(v => {
                    let parent = v.parentElement;
                    while (parent && parent !== document.body && parent !== document.documentElement) {
                        const cs = window.getComputedStyle(parent);
                        if (
                            cs.overflowY === 'scroll' ||
                            cs.overflowY === 'auto' ||
                            (cs.scrollSnapType && cs.scrollSnapType !== 'none')
                        ) {
                            if (!lockedScrollPositions.has(parent)) {
                                lockedScrollPositions.set(parent, parent.scrollTop);
                            }
                            parent.classList.add('insta-lock-scroll');
                        }
                        parent = parent.parentElement;
                    }
                });
            }

            function checkState() {
                injectStyle();
                const path = window.location.pathname;

                if (isReelsTab(path)) {
                    allowedReelId = null;
                    applyScrollLock(false);
                    window.location.replace('/');
                    return;
                }

                const currentId = getReelId(path);
                const fullscreenVideo = hasFullscreenVideo();

                if (currentId || fullscreenVideo) {
                    if (currentId) {
                        if (!allowedReelId) {
                            allowedReelId = currentId;
                        } else if (allowedReelId !== currentId && !isRedirecting) {
                            isRedirecting = true;
                            allowedReelId = null;
                            applyScrollLock(false);
                            window.location.replace(lastNonReelUrl || '/');
                            setTimeout(() => { isRedirecting = false; }, 800);
                            return;
                        }
                    }
                    applyScrollLock(true);
                } else {
                    allowedReelId = null;
                    lastNonReelUrl = window.location.href;
                    applyScrollLock(false);
                }
            }

            function isInsideCommentsOrShare(target) {
                const el = (target && target.nodeType === 3) ? target.parentElement : target;
                if (!el || typeof el.closest !== 'function') return false;
                if (el.closest('input, textarea, [contenteditable="true"]')) return true;
                const dialog = el.closest('[role="dialog"]');
                if (dialog && !dialog.querySelector('video')) return true;
                return false;
            }

            function blockGesture(e) {
                if (!isLocked) return;
                if (isInsideCommentsOrShare(e.target)) return;
                e.preventDefault();
                e.stopImmediatePropagation();
            }

            window.addEventListener('touchmove', blockGesture, { passive: false, capture: true });
            window.addEventListener('pointermove', blockGesture, { passive: false, capture: true });
            window.addEventListener('wheel', blockGesture, { passive: false, capture: true });

            document.addEventListener('scroll', function(e) {
                if (!isLocked) return;
                const target = e.target;
                if (isInsideCommentsOrShare(target)) return;
                if (target && target !== document && target.querySelector && target.querySelector('video')) {
                    if (!lockedScrollPositions.has(target)) {
                        lockedScrollPositions.set(target, 0);
                    }
                    target.classList.add('insta-lock-scroll');
                    const savedTop = lockedScrollPositions.get(target);
                    if (Math.abs(target.scrollTop - savedTop) > 2) {
                        target.scrollTop = savedTop;
                    }
                }
            }, true);

            const origPushState = history.pushState;
            const origReplaceState = history.replaceState;
            history.pushState = function() {
                const res = origPushState.apply(this, arguments);
                setTimeout(checkState, 0);
                return res;
            };
            history.replaceState = function() {
                const res = origReplaceState.apply(this, arguments);
                setTimeout(checkState, 0);
                return res;
            };

            window.addEventListener('popstate', checkState);

            function startObserver() {
                if (!document.documentElement) return;
                const observer = new MutationObserver(checkState);
                observer.observe(document.documentElement, { childList: true, subtree: true });
            }
            if (document.documentElement) {
                startObserver();
            } else {
                document.addEventListener('DOMContentLoaded', startObserver);
            }

            setInterval(checkState, 250);
            checkState();
        })();
        """#

        let userScript = WKUserScript(
            source: blockReelsScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(userScript)

        let config = WKWebViewConfiguration()
        config.userContentController = contentController
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.webView = webView
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://www.instagram.com") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "reelLock", let locked = message.body as? Bool {
                DispatchQueue.main.async {
                    self.webView?.scrollView.isScrollEnabled = !locked
                }
            }
        }
    }
}

struct ContentView: View {
    var body: some View {
        InstagramCleanerView()
            .ignoresSafeArea(edges: .bottom)
    }
}
