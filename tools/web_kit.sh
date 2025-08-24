#!/usr/bin/env bash
set -euo pipefail

web_kit() {

	case "${1:-}" in
		help|-h|--help)
			_about_web_kit
			;;
		server|-s)
			shift 1
			_web_kit_server_py "${1:-${PUBLIC_HTML:-}}"
			;;
		icons|-i)
			shift 1
			# Usage: web_kit icons [SRC_DIR] [OUT_DIR]
			# Defaults: SRC_DIR="$SVG_LOGO_ROOT", OUT_DIR="$WEB_LOGO_ROOT"
			_web_kit_icon_set "${1:-${SVG_LOGO_ROOT:-}}" "${2:-${WEB_LOGO_ROOT:-}}"
			;;
		json|-j)
			shift 1
			_web_kit_contributors_json "${1:-Tearran}" "${2:-configng-v2}" "${3:-${WEB_JSON_ROOT:-$PUBLIC_HTML/json}/contributors/configng-v2.json}"
			_web_kit_logo_json
			;;
		pages|-p)
			shift 1
			_web_kit_contrib_page "$PUBLIC_HTML/contributors.html"
			_web_kit_images_page "$PUBLIC_HTML/images.html"
			;;
		build|-b)
			shift 1
			# Build all: icons, logos JSON, contributors JSON, and pages
			# generate icons set
			_web_kit_icon_set "${SVG_LOGO_ROOT:-}" "${WEB_LOGO_ROOT:-}"
			_web_kit_logo_json

			# generate contributors set
			_web_kit_contributors_json "${1:-Tearran}" "${2:-configng-v2}"
			_web_kit_contributors_json "${1:-armbian}" "${2:-configng}"
			#_web_kit_contributors_json "${1:-armbian}" "${2:-build}"
			_web_kit_contributors_json "${1:-armbian}" "${2:-documentation}"

			_web_kit_contrib_page "$PUBLIC_HTML/contributors.html"
			_web_kit_images_page "$PUBLIC_HTML/images.html"
			# run the test web server
			_web_kit_server_py "${PUBLIC_HTML:-}"
			;;
		*)
			_about_web_kit
			;;
	esac
}

# Writes a single combined JSON file at ${WEB_JSON_ROOT:-$PUBLIC_HTML/json}/images/logo.json
# Usage: call _web_kit_logo_json (no args) or set env vars:
#   PUBLIC_HTML, WEB_JSON_ROOT, SVG_SRC_DIR, LOGO_IMG_ROOT, LOGO_IMG_WEB, ICON_SIZES
_web_kit_logo_json() {

	local PUBLIC_HTML="${PUBLIC_HTML:-$BIN_ROOT/../public_html}"
	local WEB_JSON_ROOT="${WEB_JSON_ROOT:-$PUBLIC_HTML/json}"
	local SVG_SRC_DIR="${SVG_SRC_DIR:-$BIN_ROOT/../assets/images/logos}"   # filesystem source SVGs
	local LOGO_IMG_ROOT="${LOGO_IMG_ROOT:-$PUBLIC_HTML/images}"              # filesystem PNG root
	local LOGO_IMG_WEB="${LOGO_IMG_WEB:-images/logos}"                    # desired web prefix (normalized)
	local LOGO_JSON_OUT="${LOGO_JSON_OUT:-${WEB_JSON_ROOT}/images/logo.json}" # combined output file

	# If WEB_LOGO_ROOT (filesystem) provided and LOGO_IMG_WEB left default, prefer deriving web prefix from it
	if [[ -n "${WEB_LOGO_ROOT:-}" && "${LOGO_IMG_WEB:-}" == "images/logos" ]]; then
		LOGO_IMG_WEB="${WEB_LOGO_ROOT}"
	fi

	# Normalize LOGO_IMG_WEB: strip filesystem PUBLIC_HTML prefix and any leading slash/./
	LOGO_IMG_WEB="${LOGO_IMG_WEB%/}"
	if [[ -n "$PUBLIC_HTML" && "${LOGO_IMG_WEB#"$PUBLIC_HTML"/}" != "$LOGO_IMG_WEB" ]]; then
		LOGO_IMG_WEB="${LOGO_IMG_WEB#"$PUBLIC_HTML"/}"
	fi
	LOGO_IMG_WEB="${LOGO_IMG_WEB#/}"
	LOGO_IMG_WEB="${LOGO_IMG_WEB#./}"

	# Sizes (override by setting ICON_SIZES as comma-separated list)
	if [ -n "${ICON_SIZES:-}" ]; then
		IFS=',' read -r -a SIZES <<< "${ICON_SIZES}"
	else
		SIZES=(16 32 48 64 96 128 180 192 256 384 512 1024)
	fi

	# Ensure output directory exists
	mkdir -p "$(dirname "$LOGO_JSON_OUT")"

	# Find SVG files
	mapfile -t svg_files < <(find "$SVG_SRC_DIR" -type f -name "*.svg" 2>/dev/null | sort -u)

	# JSON escaping helper
	json_escape() {
		local s="$1"
		s="${s//\\/\\\\}"
		s="${s//\"/\\\"}"
		s="${s//$'\n'/ }"
		printf '%s' "$s"
	}

	# Extract tag content helper (fallback)
	extract_tag_content() {
		local file="$1" primary="$2" fallback="$3" val
		if val="$(grep -m1 -o "<${primary}>[^<]*</${primary}>" "$file" 2>/dev/null)"; then
			val="$(printf '%s' "$val" | sed 's|<[^>]*>||g')"
			printf '%s' "$val"; return 0
		fi
		if [ -n "$fallback" ]; then
			if val="$(grep -m1 -o "<${fallback}>[^<]*</${fallback}>" "$file" 2>/dev/null)"; then
				val="$(printf '%s' "$val" | sed 's|<[^>]*>||g')"
				printf '%s' "$val"; return 0
			fi
		fi
		printf ''; return 1
	}

	# Build combined JSON
	printf '[\n' > "$LOGO_JSON_OUT"
	local first=1

	for file in "${svg_files[@]}"; do
		[ -e "$file" ] || continue
		local base name category is_legacy rel_svg_path svg_title svg_desc
		base="$(basename "$file")"
		name="${base%.svg}"

		# category and svg path
		is_legacy=0
		if [[ "$file" == */legacy/* ]]; then
			if [[ "$name" == armbian_* ]]; then category="armbian-legacy"
			elif [[ "$name" == configng_* ]]; then category="configng-legacy"
			else category="other-legacy"; fi
			is_legacy=1
			rel_svg_path="${LOGO_IMG_WEB}/scalable/legacy/${name}.svg"
		else
			if [[ "$name" == armbian_* ]]; then category="armbian"
			elif [[ "$name" == configng_* ]]; then category="configng"
			else category="other"; fi
			rel_svg_path="${LOGO_IMG_WEB}/scalable/${name}.svg"
		fi

		# metadata
		svg_title="$(extract_tag_content "$file" "dc:title" "title")"
		[ -z "$svg_title" ] && svg_title="$(extract_tag_content "$file" "title" "")"
		svg_desc="$(extract_tag_content "$file" "dc:description" "desc")"
		[ -z "$svg_desc" ] && svg_desc="$(extract_tag_content "$file" "desc" "")"
		svg_title="$(json_escape "$svg_title")"
		svg_desc="$(json_escape "$svg_desc")"

		# pngs array (web paths)
		local png_entries="" png_count=0 sz img_path full_img_path kb kb_decimal
		for sz in "${SIZES[@]}"; do
			img_path="${LOGO_IMG_WEB}/${sz}x${sz}/${name}.png"
			full_img_path="${LOGO_IMG_ROOT}/${sz}x${sz}/${name}.png"
			if [[ -f "$full_img_path" ]]; then
				kb=$(du -k "$full_img_path" 2>/dev/null | cut -f1 || echo 0)
				if (( kb > 0 )); then
					kb_decimal="$(printf "%.2f" "$kb")"
					if (( png_count > 0 )); then
						png_entries="${png_entries},\n      { \"path\": \"${img_path}\", \"size\": \"${sz}x${sz}\", \"kb\": ${kb_decimal} }"
					else
						png_entries="      { \"path\": \"${img_path}\", \"size\": \"${sz}x${sz}\", \"kb\": ${kb_decimal} }"
					fi
					((png_count++))
				fi
			fi
		done

		# comma between objects
		if [ "$first" -eq 0 ]; then
			printf ',\n' >> "$LOGO_JSON_OUT"
		fi
		first=0

		# write object
		{
		printf '  {\n'
		printf '    "name": "%s",\n' "$name"
		printf '    "category": "%s",\n' "$category"
		printf '    "svg": "%s",\n' "$rel_svg_path"
		printf '    "svg_meta": {\n'
		printf '      "title": "%s",\n' "$svg_title"
		printf '      "desc": "%s"\n' "$svg_desc"
		printf '    },\n'
		printf '    "pngs": [\n'
		if [[ -n "$png_entries" ]]; then
			printf '%b\n' "$png_entries"
			printf '    ]\n'
		else
			printf '    ]\n'
		fi
		printf '  }'
		} >> "$LOGO_JSON_OUT"
	done

	# close array
	printf '\n]\n' >> "$LOGO_JSON_OUT"

	printf 'Combined JSON written to: %s\n' "$LOGO_JSON_OUT"
}

_web_kit_images_page() {


local WEB_JSON_ROOT="${WEB_JSON_ROOT:-$PUBLIC_HTML/json}"

local OUTFILE="${1:-${PUBLIC_HTML}/images.html}"
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


_web_kit_server_py() {

	local root="${1:-${PUBLIC_HTML:-}}"
	local port="${WEB_PORT:-8080}"

	if ! command -v python3 >/dev/null 2>&1; then
		echo "Python 3 is required to run the server. Please install it."
		exit 1
	fi

	if [[ -z "${root}" ]]; then
		_about_web_kit
		echo "Web root directory is not set. Provide a path or set PUBLIC_HTML."
		exit 1
	fi

	if [[ ! -d "${root}" ]]; then
		_about_web_kit
		echo "Web root directory ${root} does not exist. Please create it or specify a valid path."
		exit 1
	fi



	cd "${root}"




	# Only wait for a keypress if not in CI
	if [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${TRAVIS:-}" || -n "${JENKINS_URL:-}" || -n "${CIRCLECI:-}" ]]; then
		echo "CI environment detected - nothing to serve in CI context"
		echo "Exiting gracefully..."
		kill "${PYTHON_PID}" >/dev/null 2>&1 || true
		wait "${PYTHON_PID}" 2>/dev/null || true
		trap - INT TERM EXIT
		return 0
	else
		echo "Starting Python web server in $(pwd) on port ${port}"
		python3 -m http.server "${port}" --bind 127.0.0.1 &
		PYTHON_PID=$!
		echo "Python web server started with PID ${PYTHON_PID}"
		echo "You can access the server at http://localhost:${port}/"
		echo "Press any key to stop the server..."
		trap 'echo; echo "Stopping the server..."; kill "${PYTHON_PID}" >/dev/null 2>&1 || true; wait "${PYTHON_PID}" 2>/dev/null || true' INT TERM EXIT

		read -r -n 1 -s

		echo
		echo "Stopping the server..."
		kill "${PYTHON_PID}" >/dev/null 2>&1 || true
		wait "${PYTHON_PID}" 2>/dev/null || true
		trap - INT TERM EXIT
		echo "Server stopped."
	fi


}

_web_kit_contributors_json() {

	if ! command -v jq >/dev/null 2>&1 || ! command -v wget >/dev/null 2>&1; then
		echo "jq and wget are required to generate the contributors JSON. Please install them."
		exit 1
	fi

	local USER="${1:-Tearran}"
	local REPO="${2:-configng-v2}"
	local MIN_COMMITS=1   # Default minimum commits

	local json_root="${WEB_JSON_ROOT:-${PUBLIC_HTML:-./}/json}"
	mkdir -p "${json_root}/contributors/"

	local OUTFILE="${3:-${json_root}/contributors/${REPO}.json}"

	#echo "Generating contributors JSON for ${USER}/${REPO} (min commits: ${MIN_COMMITS})..."

	local headers=(--header="Accept: application/vnd.github+json")
	local url="https://api.github.com/repos/${USER}/${REPO}/contributors?per_page=100"

	if ! wget -qO- "${headers[@]}" "${url}" \
		| jq --argjson min "$MIN_COMMITS" '[.[] | select(.contributions > $min) | {login, contributions, avatar_url, html_url}]' \
		> "${OUTFILE}"; then
		echo "Failed to generate contributors JSON for ${USER}/${REPO}."
		exit 1
	fi

	echo "Contributors JSON generated at ${OUTFILE}"
}

_web_kit_contrib_page() {
local OUTFILE="${1:-$PUBLIC_HTML/contributors.html}"
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
<h1>Cofigurartion Next Generation Contributors</h1>
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
for f in "$WEB_JSON_ROOT"/contributors/*.json; do
	[[ -f "$f" ]] || continue
	fname=$(basename "$f")
	# Title: strip trailing .json
	title="${fname%.json}"
	# Use smaller icons for particular files (adjust as needed)
	icon_size="false"
	[[ "$fname" == "build-scripts.json" ]] && icon_size="true"
	# JSON file path, relative to the HTML page (PUBLIC_HTML/contributors.html -> json/contributors/<file>)
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

_web_kit_icon_set() {
	local SRC_DIR="${1:-${SVG_LOGO_ROOT:-}}"
	local OUT_DIR_BASE="${2:-${WEB_LOGO_ROOT:-}}"

	[[ -n "${SRC_DIR}" && -d "${SRC_DIR}" ]] || { echo "SVG source not found: ${SRC_DIR}"; return 1; }
	[[ -n "${OUT_DIR_BASE}" ]] || { echo "Output directory not given or empty"; return 1; }

	# Prefer 'magick' if available, else 'convert'
	local IM="convert"
	if command -v magick >/dev/null 2>&1; then
		IM="magick"
	elif ! command -v convert >/dev/null 2>&1; then
		echo "ImageMagick is required ('magick' or 'convert' not found)."
		return 1
	fi

	# Sizes
	local DEFAULT_SIZES="16,32,48,64,96,128,180,192,256,384,512,1024"
	local sizes_csv="${ICON_SIZES:-$DEFAULT_SIZES}"
	IFS=',' read -r -a SIZES <<<"${sizes_csv//[[:space:]]/}"

	# Ensure output structure
	mkdir -p "${OUT_DIR_BASE}/scalable" "${OUT_DIR_BASE}/scalable/legacy"

	# Copy SVGs (non-legacy)
	find "${SRC_DIR}" -maxdepth 1 -type f -name "*.svg" -exec cp -f {} "${OUT_DIR_BASE}/scalable/" \;

	# Copy legacy SVGs if present
	if [[ -d "${SRC_DIR}/legacy" ]]; then
		find "${SRC_DIR}/legacy" -maxdepth 1 -type f -name "*.svg" -exec cp -f {} "${OUT_DIR_BASE}/scalable/legacy/" \;
	fi

	# Render PNGs into <out>/<size>x<size>/<name>.png
	# Iterate both src and optional src/legacy
	shopt -s nullglob
	local svg
	for svg in "${SRC_DIR}"/*.svg "${SRC_DIR}/legacy"/*.svg; do
		[[ -e "$svg" ]] || continue
		local base="$(basename "${svg%.svg}")"
		for size in "${SIZES[@]}"; do
			[[ "$size" =~ ^[0-9]+$ ]] || continue
			local OUT_DIR="${OUT_DIR_BASE}/${size}x${size}"
			mkdir -p "${OUT_DIR}"
			# Transparent background, keep aspect, center and pad to square
			# 'magick' and 'convert' accept the same arguments here.
			$IM -background none -density 384 "$svg" \
				-resize "${size}x${size}" \
				-gravity center -extent "${size}x${size}" \
				"${OUT_DIR}/${base}.png"
		done
	done
	shopt -u nullglob

	# Favicon generation
	# Prefer a specific file if present; fall back to the first available SVG
	local FAVICON_SVG="${SRC_DIR}/armbian_social.svg"
	if [[ ! -f "$FAVICON_SVG" ]]; then
		for svg in "${SRC_DIR}"/*.svg; do
			[[ -f "$svg" ]] || continue
			FAVICON_SVG="$svg"
			break
		done
	fi

	if [[ -f "$FAVICON_SVG" ]]; then
		local tmp16="${PUBLIC_HTML}/favicon-16.png"
		local tmp32="${PUBLIC_HTML}/favicon-32.png"
		local tmp48="${PUBLIC_HTML}/favicon-48.png"
		$IM -background none "$FAVICON_SVG" -resize 16x16 "$tmp16"
		$IM -background none "$FAVICON_SVG" -resize 32x32 "$tmp32"
		$IM -background none "$FAVICON_SVG" -resize 48x48 "$tmp48"
		$IM "$tmp16" "$tmp32" "$tmp48" "${PUBLIC_HTML}/favicon.ico"
		rm -f "$tmp16" "$tmp32" "$tmp48"
		echo "Favicon generated at ${PUBLIC_HTML}/favicon.ico"
	else
		echo "No SVG found for favicon in ${SRC_DIR} (looked for armbian_social.svg or any .svg). Skipping favicon."
	fi

	echo "SVGs copied to:       ${OUT_DIR_BASE}/scalable[/legacy]"
	echo "PNG icons generated:  ${OUT_DIR_BASE}/{SIZE}x{SIZE}/name.png"
}


_about_web_kit() {
	cat <<EOF
Usage: web_kit <command> [options]

Commands:
	server,  -s [PATH]         Run a Python 3 simple web server for the specified
				path, or use the default web root.
	icons,   -i [SRC] [OUT]    Generate icon sets and favicon from SVG sources.
				Defaults: SRC=\$SVG_LOGO_ROOT, OUT=\$WEB_LOGO_ROOT
	json,    -j                Generate a logos JSON file from all SVGs and PNGs.
	contrib, -c [USER] [REPO]  Generate a contributors JSON file for a GitHub repo.
	build,   -b                Build icons, logos JSON, and contributors JSON.
	help,    -h                Show this help message.

Environment:
	ICON_SIZES                 Comma-separated list of sizes. Default:
				16,32,48,64,96,128,180,192,256,384,512,1024
	SVG_LOGO_ROOT             (defaults to \$BIN_ROOT/../assets/images/logos)
	WEB_LOGO_ROOT             (defaults to \$PUBLIC_HTML/images/logos)

Examples:
	# Run server in a specific directory
	web_kit -s ~/public_html
	web_kit server /var/www/html

# Run server in default web root
	web_kit server
	web_kit -s

# Generate icons
	web_kit icons
	web_kit -i

# Generate logos JSON
	web_kit json
	web_kit -j

# Generate contributors JSON
	web_kit contrib Tearran configng-v2
	web_kit -c Tearran configng-v2

# Build all
	web_kit build
	web_kit -b

Notes:
	- Requires Python 3, jq, and ImageMagick ('magick' or 'convert') in PATH.
	- Server runs on port 8080 and stops with any key press.
	- Keep this help text updated if commands or usage change.
EOF
}

### START ./web_kit.sh - Armbian Config V2 test entrypoint

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then

	BIN_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	SVG_LOGO_ROOT="${SVG_ROOT:-$BIN_ROOT/../assets/images/logos}"

	PUBLIC_HTML="${PUBLIC_HTML:-$BIN_ROOT/../public_html}"
	WEB_JSON_ROOT="${WEB_JSON_ROOT:-$PUBLIC_HTML/json}"
	WEB_DOC_ROOT="${WEB_DOC_ROOT:-$PUBLIC_HTML/doc}"
	WEB_LOGO_ROOT="${WEB_LOGO_ROOT:-$PUBLIC_HTML/images/logos}"

	# --- Capture and assert help output ---
	help_output="$(web_kit help)"
	echo "$help_output" | grep -q "Usage: web_kit" || {
		echo "fail: Help output does not contain the expected usage string"
		echo "test complete"
		exit 1
	}
	# --- end assertion ---

	web_kit "$@"
fi

### END ./web_kit.sh - Armbian Config V2 test entrypoint
