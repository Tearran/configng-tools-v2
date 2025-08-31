document.addEventListener('DOMContentLoaded', () => {
        const PAGE_SEL = '.page-section';
        const HOME_ID = 'home';
        const siteNavEl = document.getElementById('site-nav'); // nav container (may be filled later)

        // Utility: read current sections live
        const sections = () => Array.from(document.querySelectorAll(PAGE_SEL));

        // Hide everything except home (use hidden attribute so content is not rendered)
        function forceInitialHome() {
                sections().forEach(s => {
                        if (s.id === HOME_ID) {
                                s.removeAttribute('hidden');
                                s.dataset.active = 'true';
                                s.classList.add('active');
                                s.setAttribute('aria-hidden', 'false');
                        } else {
                                s.setAttribute('hidden', '');
                                s.dataset.active = 'false';
                                s.classList.remove('active');
                                s.setAttribute('aria-hidden', 'true');
                        }
                });
        }

        function showPage(id) {
                if (!id) return;
                const target = document.getElementById(id);
                if (!target) {
                        console.warn('showPage: no element with id=', id);
                        return;
                }

                sections().forEach(s => {
                        if (s === target) {
                                s.removeAttribute('hidden');
                                s.dataset.active = 'true';
                                s.classList.add('active');
                                s.setAttribute('aria-hidden', 'false');
                                // focus first focusable element for keyboard users
                                const focusable = s.querySelector('a,button,input,select,textarea,[tabindex]:not([tabindex="-1"])');
                                if (focusable && typeof focusable.focus === 'function') focusable.focus();
                        } else {
                                s.setAttribute('hidden', '');
                                s.dataset.active = 'false';
                                s.classList.remove('active');
                                s.setAttribute('aria-hidden', 'true');
                        }
                });

                // update hash so back button works and links reflect state
                try { history.replaceState(null, '', '#' + id); } catch (e) { /* ignore */ }
        }

        // initial state: force home visible
        forceInitialHome();

        // Event delegation: handle clicks on links or buttons inside the nav container
        // If siteNavEl doesn't exist yet, we still attach to document and filter by closest('#site-nav')
        (siteNavEl || document).addEventListener('click', (ev) => {
                const el = ev.target.closest('a, button');
                if (!el) return;

                // ensure the clicked element lives inside the nav container
                const inNav = el.closest('#site-nav');
                if (!inNav) return;

                // Anchor with hash -> internal page
                if (el.tagName.toLowerCase() === 'a') {
                        const href = (el.getAttribute('href') || '').trim();
                        if (href.startsWith('#') && href.length > 1) {
                                ev.preventDefault();
                                showPage(href.slice(1));
                                return;
                        }
                        // allow external links to work as normal
                        if (!href || href === '#') {
                                ev.preventDefault();
                                return;
                        }
                }

                // Button with data-target OR any element with data-target inside nav
                const targetId = el.dataset && el.dataset.target ? el.dataset.target : null;
                if (targetId) {
                        ev.preventDefault();
                        showPage(targetId);
                        return;
                }

                // Fallback: try to map normalized link text -> id
                if (el.tagName.toLowerCase() === 'a') {
                        const label = (el.textContent || el.innerText || '').trim();
                        if (label) {
                                const idFromLabel = label.toLowerCase().replace(/\s+/g, '-').replace(/[^\w-]/g, '');
                                if (document.getElementById(idFromLabel)) {
                                        ev.preventDefault();
                                        showPage(idFromLabel);
                                        return;
                                }
                        }
                }
        });

        // If user manually changes the hash after load, respect it (but initial load forced home)
        window.addEventListener('hashchange', () => {
                const id = location.hash.slice(1);
                if (id && document.getElementById(id)) showPage(id);
        });
});