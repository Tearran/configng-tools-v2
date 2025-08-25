#!/usr/bin/env bash
set -euo pipefail

# ./html_set.sh - Armbian Config V2 module

html_set() {
	# Directory of this script (not assuming a bin/ directory exists)
	local SCRIPT_DIR
	SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
	# Project root = parent of script dir (adjust if you prefer SCRIPT_DIR itself)
	local PROJECT_ROOT
	if [[ -d "${SCRIPT_DIR}/../.git" ]]; then
		PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
	elif  [[ -d "${SCRIPT_DIR}/../../.git" ]];then
		PROJECT_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
	fi

	case "${1:-}" in
		help|-h|--help)
			_about_html_set
			;;
		"")
			_html_set_contrib
			_html_set_logo
			;;
		*)
			echo "Unknown command: ${1}"
			_about_html_set
			return 1
	esac
}

_html_set_contrib() {
local OUTFILE="${1:-$PROJECT_ROOT/public_html/contributors.html}"
mkdir -p "$(dirname "$OUTFILE")"

cat <<'EOF' > "$OUTFILE"
<!DOCTYPE html>
<html lang="en">

<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Armbian Top Contributors</title>
<style>
body {
font-family: sans-serif;
background: #111;
color: #eee;
margin: 0;
padding: 1rem;
}

h1 {
text-align: center;
}

.controls {
display: flex;
justify-content: space-between;
margin-bottom: 1rem;
flex-wrap: wrap;
}

.loading {
text-align: center;
padding: 2rem;
font-style: italic;
color: #999;
}

.error {
background: rgba(255, 0, 0, 0.2);
padding: 0.5rem;
border-radius: 4px;
margin-bottom: 1rem;
}

.block {
margin-bottom: 2rem;
border: 1px solid #333;
border-radius: 8px;
padding: 1rem;
}

.block h2 {
text-align: left;
margin: 0.5rem 0;
text-transform: capitalize;
}

.grid {
display: grid;
grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
gap: 1rem;
}

.contributor {
background: #222;
border-radius: 8px;
text-align: center;
padding: 0.5rem;
height: 100%;
display: flex;
flex-direction: column;
transition: transform 0.2s, background 0.2s;
}

.contributor:hover {
transform: translateY(-2px);
background: #2a2a2a;
}

.contributor img {
border-radius: 50%;
width: 80px;
height: 80px;
object-fit: cover;
margin: 0 auto;
}

.small img {
width: 50px;
height: 50px;
}

.contributor p {
margin: 0.25rem 0;
font-size: 0.85rem;
}

.contributor .name {
font-weight: bold;
}

a {
color: inherit;
text-decoration: none;
display: flex;
flex-direction: column;
height: 100%;
padding: 0.5rem;
}

a:hover {
text-decoration: underline;
}

select,
button {
background: #333;
color: #eee;
border: 1px solid #444;
padding: 0.5rem;
border-radius: 4px;
margin-right: 0.5rem;
}

@media (max-width: 600px) {
.grid {
	grid-template-columns: repeat(auto-fill, minmax(120px, 1fr));
}

.controls {
	flex-direction: column;
	gap: 0.5rem;
}
}
</style>
</head>

<body>
<main>
<h1>Armbian Top Contributors</h1>
<p>Contributors with more than 10 commits to the Armbian projects.</p>

<div class="controls">
<div>
	<select id="sort-select">
	<option value="contributions-desc">Most contributions</option>
	<option value="contributions-asc">Fewest contributions</option>
	<option value="name-asc">Name (A-Z)</option>
	<option value="name-desc">Name (Z-A)</option>
	</select>
	<button id="refresh-btn" aria-label="Refresh data">Refresh</button>
</div>
<div>
	<input type="text" id="filter-input" placeholder="Filter by username"
	aria-label="Filter contributors by username">
</div>
</div>

<!-- Container for contributors -->
<div id="contributors-container"></div>
</main>

<script>
(async () => {
const container = document.getElementById('contributors-container');
const sortSelect = document.getElementById('sort-select');
const filterInput = document.getElementById('filter-input');
const refreshBtn = document.getElementById('refresh-btn');

const blocks = [

// ← this gets auto-filled by the shell loop

EOF

# Add each contributors JSON as a block (json/contributors/*.json)
for f in "$PROJECT_ROOT"/public_html/json/contributors/*.json; do

	[[ -f "$f" ]] || continue
	fname=$(basename "$f")
	# Title: strip trailing .json
	title="${fname%.json}"
	# Use smaller icons for particular files (adjust as needed)
	icon_size="false"
	[[ "$fname" == "build-scripts.json" ]] && icon_size="true"
	# JSON file path, relative to the HTML page (WEB_ROOT/contributors.html -> json/contributors/<file>)
	echo "    { title: '$title', file: 'json/contributors/$fname', small: $icon_size }," >> "$OUTFILE"
done

cat <<'EOF' >> "$OUTFILE"

];

let contributorsData = {};

// Function to sort contributors
const sortContributors = (contributors, sortBy) => {
	const [field, direction] = sortBy.split('-');

	return [...contributors].sort((a, b) => {
	if (field === 'contributions') {
	return direction === 'asc'
	? a.contributions - b.contributions
	: b.contributions - a.contributions;
	} else if (field === 'name') {
	return direction === 'asc'
	? a.login.localeCompare(b.login)
	: b.login.localeCompare(a.login);
	}
	return 0;
	});
};

// Function to filter contributors
const filterContributors = (contributors, filterText) => {
	if (!filterText) return contributors;
	const lowerFilter = filterText.toLowerCase();
	return contributors.filter(user =>
	user.login.toLowerCase().includes(lowerFilter)
	);
};

// Function to render contributors
const renderContributors = () => {
	container.innerHTML = '';

	const sortBy = sortSelect.value;
	const filterText = filterInput.value;

	for (const block of blocks) {
	const divBlock = document.createElement('div');
	divBlock.className = 'block';

	const title = document.createElement('h2');
	title.textContent = block.title;
	divBlock.appendChild(title);

	const grid = document.createElement('div');
	grid.className = 'grid';
	if (block.small) grid.classList.add('small');

	if (!contributorsData[block.title]) {
	const loading = document.createElement('p');
	loading.className = 'loading';
	loading.textContent = 'Loading contributors...';
	divBlock.appendChild(loading);
	container.appendChild(divBlock);
	continue;
	}

	if (contributorsData[block.title].error) {
	const error = document.createElement('div');
	error.className = 'error';
	error.textContent = `Failed to load contributors: ${contributorsData[block.title].error}`;
	divBlock.appendChild(error);
	container.appendChild(divBlock);
	continue;
	}

	// Filter and sort the data
	const filteredData = filterContributors(contributorsData[block.title], filterText);
	const sortedData = sortContributors(filteredData, sortBy);

	if (sortedData.length === 0) {
	const noResults = document.createElement('p');
	noResults.textContent = 'No contributors match your filter.';
	divBlock.appendChild(noResults);
	container.appendChild(divBlock);
	continue;
	}

	sortedData.forEach(user => {
	const div = document.createElement('div');
	div.className = 'contributor';
	div.innerHTML = `
	<a href="${user.html_url}" target="_blank" rel="noopener" aria-label="View ${user.login}'s GitHub profile">
		<img src="${user.avatar_url}" alt="Avatar of ${user.login}" loading="lazy">
		<p class="name">${user.login}</p>
		<p>${user.contributions} commit${user.contributions !== 1 ? 's' : ''}</p>
	</a>
	`;
	grid.appendChild(div);
	});

	divBlock.appendChild(grid);
	container.appendChild(divBlock);
	}
};

// Function to load all data
const loadData = async () => {
	for (const block of blocks) {
	// Show loading state
	contributorsData[block.title] = null;
	renderContributors();

	try {
	const resp = await fetch(block.file);
	if (!resp.ok) {
	throw new Error(`HTTP error ${resp.status}`);
	}
	contributorsData[block.title] = await resp.json();
	} catch (e) {
	console.error("Failed to load " + block.file, e);
	contributorsData[block.title] = { error: e.message };
	}

	renderContributors();
	}
};

// Set up event listeners
sortSelect.addEventListener('change', renderContributors);
filterInput.addEventListener('input', renderContributors);
refreshBtn.addEventListener('click', loadData);

// Initial load
await loadData();
})();
</script>
</body>

</html>
EOF

echo "Contributor page written to $OUTFILE"
}


_html_set_logo() {

local OUTFILE="${1:-$PROJECT_ROOT/public_html/images.html}"
mkdir -p "$(dirname "$OUTFILE")"

# Write page header and UI (literal here-doc keeps JS template literals intact)
cat <<"EOF" > "$OUTFILE"
<!doctype html>
<html lang="en">

<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width,initial-scale=1" />
<title>Images (json/images/*.json)</title>
<style>
:root {
--bg: #0f1011;
--card: #141416;
--muted: #b9b9b9;
--accent: #2ea44f
}

body {
font-family: system-ui, -apple-system, Segoe UI, Roboto, Helvetica, Arial;
background: var(--bg);
color: #eee;
margin: 0;
padding: 1rem
}

header {
display: flex;
gap: 1rem;
align-items: center;
justify-content: space-between;
flex-wrap: wrap
}

h1 {
margin: .2rem 0
}

.controls {
display: flex;
gap: .5rem;
align-items: center
}

.filter,
input[type=search],
button {
background: #222;
border: 1px solid #333;
color: #eee;
padding: .35rem .6rem;
border-radius: 6px
}

.grid {
margin-top: 1rem;
display: grid;
grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
gap: 1rem
}

.card {
background: var(--card);
border-radius: 8px;
padding: .75rem;
text-align: center;
min-height: 160px;
display: flex;
flex-direction: column;
align-items: center;
gap: .5rem
}

.card img {
max-width: 100%;
height: 100px;
object-fit: contain;
display: block
}

.meta {
font-size: .85rem;
color: var(--muted);
word-break: break-word
}

.badge {
background: #333;
padding: .25rem .5rem;
border-radius: 6px;
font-size: .75rem;
color: #ddd
}

.empty {
color: #999;
padding: 2rem 0;
text-align: center
}

footer {
margin-top: 1rem;
color: #9b9b9b;
font-size: .85rem
}

a.small {
font-size: .85rem;
color: var(--muted);
display: inline-block;
margin-left: .5rem
}
</style>
</head>

<body>
<header>
<div>
<h1>Images</h1>
<div style="color:#bdbdbd;font-size:.95rem">Loads JSON files from <code>json/images/*.json</code> and displays
	entries.</div>
</div>

<div class="controls">
<label class="filter">Category
	<select id="categoryFilter" style="margin-left:.5rem">
	<option value="">All</option>
	</select>
</label>

<label class="filter">Search
	<input id="search" type="search" placeholder="name, title or description" style="margin-left:.5rem">
</label>

<button id="refresh" title="Reload data">Refresh</button>
</div>
</header>

<main>
<div id="grid" class="grid" aria-live="polite"></div>
<div id="empty" class="empty" style="display:none">No images found.</div>
</main>

<footer>
Note: this page attempts to auto-enumerate the directory listing at <code>/json/images/</code>.
If your web server doesn't expose a directory index, add an index file (for example a small JSON list)
or run the generator to write filenames into a list file.
<a class="small" href="#" id="debugOpen">Open debug console</a>
</footer>

<script>
(async () => {
const DIR = 'json/images/';                // relative to web root
const FALLBACKS = ['json/images/index.json', 'json/images/list.json', 'json/logos.json', 'json/logos.json'];
const grid = document.getElementById('grid');
const empty = document.getElementById('empty');
const categorySelect = document.getElementById('categoryFilter');
const searchInput = document.getElementById('search');
const refreshBtn = document.getElementById('refresh');

function normalize(s) { return (s || '').toString().toLowerCase(); }

// Try to fetch directory listing. Many simple servers (python -m http.server, nginx autoindex) return HTML
async function fetchDirectoryJsonFiles() {
	try {
	const res = await fetch(DIR, { cache: 'no-cache' });
	if (!res.ok) throw new Error('Directory listing not available: ' + res.status);
	const ct = res.headers.get('content-type') || '';
	if (ct.includes('text/html')) {
	const text = await res.text();
	const doc = new DOMParser().parseFromString(text, 'text/html');
	const hrefs = Array.from(doc.querySelectorAll('a'))
	.map(a => a.getAttribute('href'))
	.filter(h => h && h.toLowerCase().endsWith('.json'));
	// normalize to relative paths (json/images/filename)
	const files = hrefs.map(h => {
	try {
		const url = new URL(h, location.origin + '/' + DIR);
		return url.pathname.replace(/^\//, ''); // remove leading slash so fetch('json/images/..') works
	} catch (e) {
		// fallback: join
		return DIR + h.replace(/^\.\/|^\//, '');
	}
	});
	return Array.from(new Set(files));
	} else if (ct.includes('application/json')) {
	// Server returned JSON for the directory - could be a list of filenames or an array of objects.
	const j = await res.json();
	if (Array.isArray(j) && j.length && typeof j[0] === 'string') {
	return j.map(fn => (fn.startsWith('json/') ? fn : DIR + fn));
	}
	// Not a filename list - no directory file list available
	return [];
	} else {
	return [];
	}
	} catch (err) {
	console.debug('fetchDirectoryJsonFiles failed:', err);
	return [];
	}
}

// Try fallbacks if directory listing unavailable
async function findFiles() {
	let files = await fetchDirectoryJsonFiles();
	if (files.length > 0) return files;
	for (const fb of FALLBACKS) {
	try {
	const r = await fetch(fb, { cache: 'no-cache' });
	if (!r.ok) continue;
	// If fallback is index JSON containing an array of filenames
	const j = await r.json();
	if (Array.isArray(j) && j.length && typeof j[0] === 'string') {
	return j.map(fn => (fn.startsWith('json/') ? fn : DIR + fn));
	}
	// If the fallback is actually the desired content (array of image entries), return this file
	if (Array.isArray(j) && j.length && (j[0].name || j[0].svg || j[0].category)) {
	return [fb];
	}
	} catch (e) {
	// ignore and continue
	}
	}
	return [];
}

async function loadAll() {
	grid.innerHTML = '';
	empty.style.display = 'none';
	const files = await findFiles();
	if (!files || files.length === 0) {
	empty.textContent = 'No JSON files found in ' + DIR;
	empty.style.display = 'block';
	return [];
	}

	const merged = [];
	for (const f of files) {
	try {
	const res = await fetch(f + (f.includes('?') ? '&' : '?') + '_=' + Date.now(), { cache: 'no-cache' });
	if (!res.ok) { console.warn('failed to fetch', f, res.status); continue; }
	const data = await res.json();
	if (Array.isArray(data)) merged.push(...data);
	else if (data && typeof data === 'object') merged.push(data);
	} catch (err) {
	console.warn('failed to load json', f, err);
	}
	}
	// keep unique by name (last wins)
	const byName = new Map();
	for (const it of merged) {
	if (!it || !it.name) continue;
	byName.set(it.name, it);
	}
	const items = Array.from(byName.values());
	window._IMAGES_CACHE = items;
	populateCategorySelect(items);
	render(items);
	return items;
}

function populateCategorySelect(items) {
	const cats = Array.from(new Set(items.map(i => i.category || 'other'))).sort();
	// preserve first "All" option
	while (categorySelect.options.length > 1) categorySelect.remove(1);
	for (const c of cats) {
	const opt = document.createElement('option'); opt.value = c; opt.textContent = c;
	categorySelect.appendChild(opt);
	}
}

function render(items) {
	grid.innerHTML = '';
	if (!items || items.length === 0) {
	empty.textContent = 'No images matched your filters.';
	empty.style.display = 'block';
	return;
	}
	empty.style.display = 'none';
	for (const it of items) {
	const card = document.createElement('div'); card.className = 'card';
	const img = document.createElement('img');
	// pick a thumbnail: first PNG path (web) else svg (web)
	let src = '';
	if (Array.isArray(it.pngs) && it.pngs.length) {
	src = it.pngs[0].path;
	} else if (it.svg) {
	src = it.svg;
	}
	img.src = src;
	img.alt = it.name || '';
	img.loading = 'lazy';
	const meta = document.createElement('div'); meta.className = 'meta';
	const title = document.createElement('div'); title.innerHTML = '<strong>' + (it.name || '') + '</strong>';
	const subt = document.createElement('div'); subt.textContent = (it.svg_meta && it.svg_meta.title) ? it.svg_meta.title : '';
	const badge = document.createElement('div'); badge.className = 'badge'; badge.textContent = it.category || '';
	meta.appendChild(title); meta.appendChild(subt); meta.appendChild(badge);
	card.appendChild(img); card.appendChild(meta);
	grid.appendChild(card);
	}
}

function applyFilters() {
	const q = normalize(searchInput.value);
	const cat = categorySelect.value;
	const items = window._IMAGES_CACHE || [];
	const filtered = items.filter(it => {
	if (cat && (it.category || '') !== cat) return false;
	if (!q) return true;
	return normalize(it.name).includes(q) ||
	normalize((it.svg_meta && it.svg_meta.title) || '').includes(q) ||
	normalize((it.svg_meta && it.svg_meta.desc) || '').includes(q);
	});
	render(filtered);
}

refreshBtn.addEventListener('click', async () => {
	await loadAll();
});
searchInput.addEventListener('input', applyFilters);
categorySelect.addEventListener('change', applyFilters);

// debug link to open console easily (focuses console in browsers with devtools open)
document.getElementById('debugOpen').addEventListener('click', (e) => { e.preventDefault(); console.log('DEBUG: _IMAGES_CACHE', window._IMAGES_CACHE); alert('See console for debug info.'); });

// initial load
await loadAll();

})();
</script>
</body>

</html>
EOF

echo "Images page written to $OUTFILE"

}




_about_html_set() {
	cat <<EOF
Usage: html_set <command> [options]

Commands:
	foo         - Example 'foo' operation (replace with real command)
	bar         - Example 'bar' operation (replace with real command)
	help        - Show this help message

Examples:
	# Run the test operation
	html_set test

	# Perform the foo operation with an argument
	html_set foo arg1

	# Show help
	html_set help

Notes:
	- Replace 'foo' and 'bar' with real commands for your module.
	- All commands should accept '--help', '-h', or 'help' for details, if implemented.
	- Intended for use with the config-v2 menu and scripting.
	- Keep this help message up to date if commands change.

EOF
}

### START ./html_set.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
	# --- Capture and assert help output ---
	help_output="$(html_set help)"
	echo "$help_output" | grep -q "Usage: html_set" || {
		echo "fail: Help output does not contain expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---
	html_set "$@"
fi

### END ./html_set.sh - Armbian Config V2 test entrypoint

