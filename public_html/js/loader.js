// Simple SPA router: show/hide sections by id (no framework).
// Calls window.renderContribsFromFile('/json/contributors.json') when showing #contributors.
// Safe, minimal, and accessible-ish (manages focus).

(function () {
        const DEFAULT_SLUG = 'home';
        const CONTRIBUTORS_ID = 'contributors';
        const CONTRIBUTORS_JSON = '/json/contributors.json';

        function slugFromHash(hash) {
                if (!hash) return '';
                return hash.replace(/^#/, '').replace(/^\/+/, '') || '';
        }

        function showSection(slug) {
                const sections = document.querySelectorAll('section.spa-section');
                let target = null;
                sections.forEach(sec => {
                        if (sec.id === slug) {
                                sec.classList.add('is-active');
                                target = sec;
                        } else {
                                sec.classList.remove('is-active');
                        }
                });

                // If no matching section, show default
                if (!target) {
                        const def = document.getElementById(DEFAULT_SLUG);
                        if (def) {
                                def.classList.add('is-active');
                                def.focus && def.focus();
                        }
                } else {
                        // move focus to the first focusable element or the section for keyboard users
                        const focusable = target.querySelector('a,button,input,textarea,[tabindex]:not([tabindex="-1"])');
                        (focusable || target).focus && (focusable || target).focus();
                }

                // If contributors section shown, call the renderer (once)
                if (slug === CONTRIBUTORS_ID && typeof window.renderContribsFromFile === 'function') {
                        try {
                                window.renderContribsFromFile(CONTRIBUTORS_JSON);
                        } catch (e) {
                                // renderer will log errors itself
                                console.warn('spa-router: renderContribsFromFile threw', e);
                        }
                }
        }

        // Kick: run on load and on hashchange
        function onRouteChange() {
                const slug = slugFromHash(location.hash) || DEFAULT_SLUG;
                showSection(slug);
        }

        // Wire internal nav clicks to update location.hash (not strictly necessary if <a href="#..."> used)
        document.addEventListener('click', function (ev) {
                const a = ev.target.closest && ev.target.closest('a[href^="#"]');
                if (!a) return;
                // allow default anchor behavior to set hash; router reacts to hashchange
        }, false);

        if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', onRouteChange, { once: true });
        } else {
                onRouteChange();
        }
        window.addEventListener('hashchange', onRouteChange, false);

        // Expose navigation helper
        window.spaNavigate = function (slug) {
                if (!slug) slug = DEFAULT_SLUG;
                const newHash = '#' + slug;
                if (location.hash !== newHash) {
                        location.hash = newHash;
                } else {
                        // force re-show
                        showSection(slug);
                }
        };
})();