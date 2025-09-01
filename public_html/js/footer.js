// footer.js

// Path to your JSON file
const footerJSONPath = "/json/footer.json";

// Utility to render HTML into a container
function renderHTML(html, selector) {
        const container = document.querySelector(selector);
        if (container) {
                container.innerHTML = html;
                container.classList.remove("footer-loading");
        }
}

// Render link groups
function renderLinks(blocks, selector) {
        const container = document.querySelector(selector);
        if (!container) return;

        container.innerHTML = ""; // clear loading text

        blocks.forEach(group => {
                const groupDiv = document.createElement("div");
                groupDiv.classList.add("footer-links");

                // Title
                const title = document.createElement("h4");
                title.textContent = group.title;
                groupDiv.appendChild(title);

                // List of links
                const ul = document.createElement("ul");
                group.items.forEach(item => {
                        const li = document.createElement("li");
                        const a = document.createElement("a");
                        a.href = item.href;
                        a.textContent = item.label;
                        li.appendChild(a);
                        ul.appendChild(li);
                });
                groupDiv.appendChild(ul);

                container.appendChild(groupDiv);
        });
}

// Load JSON and populate footer
async function loadFooter() {
        try {
                const res = await fetch(footerJSONPath);
                if (!res.ok) throw new Error(`Failed to load ${footerJSONPath}`);
                const data = await res.json();

                // Separate by type
                const links = data.filter(d => d.type === "links");
                const legal = data.find(d => d.type === "legal");
                const about = data.find(d => d.type === "about");

                if (links.length) renderLinks(links, "#footer-links");
                if (legal) renderHTML(legal.html, "#footer-legal");
                if (about) renderHTML(about.html, "#footer-about");

        } catch (err) {
                console.error("Error loading footer JSON:", err);
        }
}

// Run on page load
document.addEventListener("DOMContentLoaded", loadFooter);
