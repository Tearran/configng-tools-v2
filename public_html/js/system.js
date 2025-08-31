// public_html/js/system.js
// Simple, separate poller that loads the fragment once then polls JSON every 2s and updates fields.
// Usage: include <script src="/js/system.js"></script> in the composed page.
(function () {
        const FRAGMENT_URL = '/cgi-bin/system';
        const JSON_URL = '/cgi-bin/system?json=1';
        const POLL_MS = 2000;

        function escapeHtml(s) { return String(s).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;'); }

        // inject fragment once (initial snapshot)
        async function loadFragmentOnce() {
                try {
                        const res = await fetch(FRAGMENT_URL, { cache: 'no-store' });
                        if (!res.ok) return;
                        const html = await res.text();
                        const container = document.getElementById('site-system');
                        if (container) {
                                container.innerHTML = html;
                        } else {
                                const alt = document.getElementById('system-fragment-root');
                                if (alt) alt.innerHTML = html;
                        }
                } catch (e) {
                        console.debug('system: initial fragment load failed', e);
                }
        }

        // update summary & process table from JSON
        function applyJson(d) {
                if (!d) return;
                const setText = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };
                setText('sys-ts', d.timestamp || '');
                setText('cpu-pct', (Number(d.cpu) || 0).toFixed(1) + '%');
                const cpuFill = document.getElementById('cpu-fill'); if (cpuFill) cpuFill.style.width = (Number(d.cpu) || 0) + '%';
                setText('mem-pct', (Number(d.mem) || 0).toFixed(1) + '%');
                const memFill = document.getElementById('mem-fill'); if (memFill) memFill.style.width = (Number(d.mem) || 0) + '%';
                setText('disk-pct', (Number(d.disk) || 0) + '%');
                const diskFill = document.getElementById('disk-fill'); if (diskFill) diskFill.style.width = (Number(d.disk) || 0) + '%';

                if (Array.isArray(d.processes)) {
                        const tbody = document.getElementById('proc-rows');
                        if (!tbody) return;
                        let html = '';
                        d.processes.forEach(p => {
                                html += '<tr><td>' + escapeHtml(p.pid) + '</td><td>' + escapeHtml(p.user) + '</td><td style="text-align:right">' + Number(p.pcpu).toFixed(1) + '</td><td style="text-align:right">' + Number(p.pmem).toFixed(1) + '</td><td>' + escapeHtml(p.cmd) + '</td></tr>';
                        });
                        tbody.innerHTML = html;
                }
        }

        async function fetchJsonAndApply() {
                try {
                        const r = await fetch(JSON_URL, { cache: 'no-store' });
                        if (!r.ok) throw new Error('HTTP ' + r.status);
                        const json = await r.json();
                        applyJson(json);
                        const last = document.getElementById('sys-last'); if (last) last.textContent = new Date().toISOString();
                        const status = document.getElementById('sys-status-text'); if (status) { status.textContent = 'ok'; status.style.color = '#7bd389'; }
                } catch (e) {
                        const status = document.getElementById('sys-status-text'); if (status) { status.textContent = 'error'; status.style.color = '#ff6b6b'; }
                        console.debug('system poll error', e);
                }
        }

        async function init() {
                await loadFragmentOnce();
                await fetchJsonAndApply();
                setInterval(fetchJsonAndApply, POLL_MS);
        }

        if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', init);
        } else {
                init();
        }
})();