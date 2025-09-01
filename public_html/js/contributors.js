// Minimal static JSON renderer for index.html
// Loads exactly /json/contributors.json and renders into #contributors-container.
// No GitHub API fallback. Exposes window.renderContribsFromFile(path) for manual calls.

(function () {
        const DEFAULT_PATH = '/json/contributors.json';
        const CONTAINER_ID = 'contributors-container';

        function el(id) { return document.getElementById(id); }
        function escapeHtml(s) {
                return String(s == null ? '' : s)
                        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
                        .replace(/"/g, '&quot;').replace(/'/g, '&#39;');
        }

        function showMessage(container, msg) {
                if (!container) return;
                container.innerHTML = `<p>${escapeHtml(msg)}</p>`;
        }

        function buildTile(user) {
                const a = document.createElement('a');
                a.className = 'contributor';
                a.href = user.html_url || '#';
                a.target = '_blank';
                a.rel = 'noopener';
                a.setAttribute('aria-label', `View ${user.login}'s GitHub profile`);

                const img = document.createElement('img');
                img.src = user.avatar_url || '';
                img.alt = `Avatar of ${user.login || 'contributor'}`;
                img.loading = 'lazy';

                const name = document.createElement('p');
                name.className = 'name';
                name.textContent = user.login || '';

                const meta = document.createElement('p');
                meta.className = 'meta';
                meta.textContent = `${user.contributions || 0} commit${(user.contributions || 0) !== 1 ? 's' : ''}`;

                a.appendChild(img);
                a.appendChild(name);
                a.appendChild(meta);
                return a;
        }

        async function fetchAndRender(path) {
                const container = el(CONTAINER_ID);
                if (!container) {
                        console.warn('contribs: container not found; call window.renderContribsFromFile(path) after the DOM or include injection.');
                        return;
                }

                showMessage(container, 'Loading contributors…');

                try {
                        const res = await fetch(path, { cache: 'no-cache' });
                        if (!res.ok) {
                                showMessage(container, `Contributors JSON not found at ${path} (HTTP ${res.status})`);
                                return;
                        }
                        const data = await res.json();
                        if (!Array.isArray(data) || data.length === 0) {
                                showMessage(container, 'No contributors in JSON.');
                                return;
                        }

                        // Render grid
                        container.innerHTML = '';
                        const grid = document.createElement('div');
                        grid.className = 'grid';
                        data.forEach(u => grid.appendChild(buildTile(u)));
                        container.appendChild(grid);
                } catch (err) {
                        console.error('contribs fetch error', err);
                        showMessage(container, 'Error loading contributors JSON.');
                }
        }

        // Expose manual function
        window.renderContribsFromFile = function (path) {
                const p = path || DEFAULT_PATH;
                return fetchAndRender(p);
        };

        // Auto-run on DOM ready if the container is already present in the page
        if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', () => {
                        if (el(CONTAINER_ID)) window.renderContribsFromFile(DEFAULT_PATH);
                }, { once: true });
        } else {
                if (el(CONTAINER_ID)) window.renderContribsFromFile(DEFAULT_PATH);
        }
})();