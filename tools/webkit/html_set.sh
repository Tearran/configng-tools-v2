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

			if [[ -f "$PROJECT_ROOT/assets/html/images.html" ]]; then
				cp "$PROJECT_ROOT/assets/html/images.html" "$PROJECT_ROOT/public_html/images.html"
				echo "Copied images.html to $PROJECT_ROOT/public_html/images.html"
			else
				echo "Warning: $PROJECT_ROOT/assets/html/images.html not found, skipping copy."
			fi
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

