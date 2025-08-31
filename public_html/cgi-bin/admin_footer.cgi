#!/usr/bin/env python3
"""
CGI editor for json/footer.json

Supports:
 - Viewing sections (array of objects)
 - Adding / editing / deleting sections
 - For sections with "items": add/edit/delete items (typical for type=="links")
 - For sections with "html": edit the html content (typical for type=="legal" or "about")
 - Replace entire file with pasted JSON
 - Atomic writes and path resolution similar to your nav editor

Path resolution priority:
 - FOOTER_JSON_PATH env var (if set)
 - cgi-bin/../json/footer.json
 - $PWD/json/footer.json
 - DOCUMENT_ROOT/json/footer.json (if DOCUMENT_ROOT set)
 - /json/footer.json

Drop into cgi-bin and make executable (chmod +x footer-edit.cgi).
"""
from html import escape
import cgi
import cgitb
import json
import os
import tempfile
from urllib.parse import parse_qs

cgitb.enable()

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def candidates():
    out = []
    out.append(os.path.normpath(os.path.join(SCRIPT_DIR, "..", "json", "footer.json")))
    out.append(os.path.normpath(os.path.join(os.getcwd(), "json", "footer.json")))
    docroot = os.environ.get("DOCUMENT_ROOT") or ""
    if docroot:
        out.append(os.path.normpath(os.path.join(docroot, "json", "footer.json")))
    out.append(os.path.normpath("/json/footer.json"))
    # dedupe preserve order
    res = []
    seen = set()
    for p in out:
        if p not in seen:
            seen.add(p)
            res.append(p)
    return res


def resolve_path():
    envp = os.environ.get("FOOTER_JSON_PATH")
    if envp:
        return os.path.realpath(envp)
    for p in candidates():
        if os.path.exists(p):
            return p
    return None


def read_footer(path):
    if not path or not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, list):
        raise ValueError("footer.json top-level must be a JSON array")
    return data


def atomic_write(path, arr):
    txt = json.dumps(arr, indent=2, ensure_ascii=False) + "\n"
    d = os.path.dirname(path) or "."
    os.makedirs(d, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=".footertmp-", dir=d, text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(txt)
            fh.flush()
            os.fsync(fh.fileno())
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            try:
                os.remove(tmp)
            except Exception:
                pass


def html_head(title="Footer Editor"):
    return (
        "Content-Type: text/html; charset=utf-8\n\n"
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        f"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{escape(title)}</title>"
        "<style>"
        "body{font-family:system-ui,Arial,sans-serif;padding:1rem;max-width:1000px;margin:auto;color:#111}"
        ".card{border:1px solid #ddd;padding:.75rem;border-radius:6px;background:#fafafa;margin-bottom:.75rem}"
        ".item{font-family:monospace;white-space:pre-wrap;background:#fff;padding:.5rem;border-radius:4px;border:1px solid #eee}"
        ".small{color:#666;font-size:.9rem}"
        ".btn{padding:.3rem .6rem;border-radius:6px;border:1px solid #bbb;background:#eee;text-decoration:none;color:#000}"
        "form.inline{display:inline-block;margin:0}"
        "table{width:100%;border-collapse:collapse}"
        "th,td{padding:.25rem .5rem;border-bottom:1px solid #eee;text-align:left;vertical-align:top}"
        "label{display:block;margin:.25rem 0}"
        "input[type=text], textarea{width:100%;box-sizing:border-box}"
        "pre.item{white-space:pre-wrap;word-break:break-word}"
        "</style></head><body>"
    )


def html_tail():
    return "</body></html>"


def render_ui(path, tried, arr, msg=None, err=None, edit_idx=None, edit_item_idx=None):
    out = []
    out.append(html_head("footer.json editor"))
    if path:
        out.append(f"<div class='card'>Using footer.json at: <code>{escape(path)}</code></div>")
    else:
        out.append("<div class='card' style='color:crimson'>footer.json not found. Adding will create the first candidate.</div>")

    out.append("<div class='card'><strong>Paths checked:</strong><ul>")
    for p in tried:
        out.append(f"<li><code>{escape(p)}</code> — {'found' if os.path.exists(p) else 'not found'}</li>")
    out.append("</ul></div>")

    if msg:
        out.append(f"<div class='card' style='color:green'>{escape(msg)}</div>")
    if err:
        out.append(f"<div class='card' style='color:crimson'>{escape(err)}</div>")

    # Sections summary
    out.append("<div class='card'><h2>Sections</h2>")
    if not arr:
        out.append("<div class='item'>No sections</div>")
    else:
        out.append("<ul>")
        for i, sec in enumerate(arr):
            stype = sec.get("type", "")
            title = sec.get("title", "")
            has_items = isinstance(sec.get("items"), list)
            has_html = isinstance(sec.get("html"), str) and sec.get("html") != ""
            summary = f"{escape(stype)}"
            if title:
                summary += f" — {escape(title)}"
            if has_items:
                summary += f" ({len(sec.get('items', []))} items)"
            elif has_html:
                preview = sec.get("html", "")[:80].replace("\n", " ")
                summary += f" — html: {escape(preview)}"
            out.append("<li>")
            out.append(summary + " ")
            out.append(f"<a class='btn' href='?edit={i}'>Edit</a> ")
            out.append(
                "<form method='post' class='inline' onsubmit=\"return confirm('Delete section?');\">"
                f"<input type='hidden' name='action' value='delete_section'>"
                f"<input type='hidden' name='index' value='{i}'>"
                "<button class='btn' type='submit'>Delete</button></form>"
            )
            out.append("</li>")
        out.append("</ul>")
    out.append("</div>")

    # raw file view
    if path and os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except Exception as e:
            raw = f"Error reading file: {e}"
        out.append(f"<div class='card'><strong>Raw file ({escape(path)}):</strong><pre class='item'>{escape(raw)}</pre></div>")

    # If editing a section, show section editor and either items UI or html UI
    if edit_idx is not None and 0 <= edit_idx < len(arr):
        section = arr[edit_idx]
        stype = section.get("type", "links")
        title = section.get("title", "")
        has_items = isinstance(section.get("items"), list)
        has_html = isinstance(section.get("html"), str)
        out.append(f"<div class='card'><h2>Edit section {edit_idx}</h2>")
        out.append("<form method='post'>")
        out.append("<input type='hidden' name='action' value='edit_section'>")
        out.append(f"<input type='hidden' name='index' value='{edit_idx}'>")
        out.append(f"<label>Type<br><input type='text' name='type' value='{escape(stype)}'></label>")
        out.append(f"<label>Title<br><input type='text' name='title' value='{escape(title)}'></label>")
        out.append("<label>HTML (optional) — if non-empty it will be saved as section-level html and items will be removed<br>")
        out.append(f"<textarea name='html' rows='8' style='font-family:monospace'>{escape(section.get('html','') if has_html else '')}</textarea></label>")
        out.append("<div><button class='btn' type='submit'>Save section</button> ")
        out.append(f"<a class='btn' href='{escape(os.environ.get('SCRIPT_NAME','/cgi-bin/footer-edit.cgi'))}'>Close</a></div>")
        out.append("</form></div>")

        # If section uses items, show item list and item forms
        if has_items:
            items = section.get("items", [])
            out.append("<div class='card'><h3>Items</h3>")
            if not items:
                out.append("<div class='item'>No items</div>")
            else:
                out.append("<table><thead><tr><th>#</th><th>Preview</th><th>Actions</th></tr></thead><tbody>")
                for j, it in enumerate(items):
                    if isinstance(it, dict):
                        if stype == "links":
                            preview = f"{escape(it.get('label',''))} — {escape(it.get('href',''))}"
                        else:
                            preview = escape(it.get('html',''))
                    else:
                        preview = escape(str(it))
                    out.append("<tr>")
                    out.append(f"<td>{j}</td>")
                    out.append(f"<td>{preview}</td>")
                    out.append("<td>")
                    out.append(f"<a class='btn' href='?edit={edit_idx}&edit_item={j}'>Edit</a> ")
                    out.append(
                        "<form method='post' class='inline' onsubmit=\"return confirm('Delete item?');\">"
                        f"<input type='hidden' name='action' value='delete_item'>"
                        f"<input type='hidden' name='section' value='{edit_idx}'>"
                        f"<input type='hidden' name='index' value='{j}'>"
                        "<button class='btn' type='submit'>Delete</button></form>"
                    )
                    out.append("</td></tr>")
                out.append("</tbody></table>")
            out.append("</div>")

            # Add item form
            out.append("<div class='card'><h3>Add item</h3>")
            out.append("<form method='post'>")
            out.append("<input type='hidden' name='action' value='add_item'>")
            out.append(f"<input type='hidden' name='section' value='{edit_idx}'>")
            if stype == "links":
                out.append("<label>Label<br><input type='text' name='label'></label>")
                out.append("<label>Href<br><input type='text' name='href'></label>")
                out.append("<label>Rel (optional)<br><input type='text' name='rel'></label>")
            else:
                out.append("<label>HTML<br><textarea name='html' rows='6' style='font-family:monospace'></textarea></label>")
            out.append("<div><button class='btn' type='submit'>Add item</button></div>")
            out.append("</form></div>")

            # Edit single item if requested
            if edit_item_idx is not None and 0 <= edit_item_idx < len(items):
                it = items[edit_item_idx]
                out.append("<div class='card'><h3>Edit item</h3>")
                out.append("<form method='post'>")
                out.append("<input type='hidden' name='action' value='edit_item'>")
                out.append(f"<input type='hidden' name='section' value='{edit_idx}'>")
                out.append(f"<input type='hidden' name='index' value='{edit_item_idx}'>")
                if stype == "links":
                    out.append(f"<label>Label<br><input type='text' name='label' value='{escape(it.get('label','') if isinstance(it, dict) else '')}'></label>")
                    out.append(f"<label>Href<br><input type='text' name='href' value='{escape(it.get('href','') if isinstance(it, dict) else '')}'></label>")
                    out.append(f"<label>Rel (optional)<br><input type='text' name='rel' value='{escape(it.get('rel','') if isinstance(it, dict) else '')}'></label>")
                else:
                    out.append(f"<label>HTML<br><textarea name='html' rows='6' style='font-family:monospace'>{escape(it.get('html','') if isinstance(it, dict) else '')}</textarea></label>")
                out.append("<div><button class='btn' type='submit'>Save item</button> ")
                out.append(f"<a class='btn' href='{escape(os.environ.get('SCRIPT_NAME','/cgi-bin/footer-edit.cgi'))}?edit={edit_idx}'>Cancel</a></div>")
                out.append("</form></div>")

        else:
            # Section uses html (or none); show HTML editor (section-level)
            out.append("<div class='card'><h3>Section HTML</h3>")
            out.append("<div class='small'>Edit the HTML stored on the section (this is not an 'items' list).</div>")
            out.append("<form method='post'>")
            out.append("<input type='hidden' name='action' value='edit_section'>")
            out.append(f"<input type='hidden' name='index' value='{edit_idx}'>")
            out.append(f"<textarea name='html' rows='10' style='font-family:monospace'>{escape(section.get('html','') if has_html else '')}</textarea>")
            out.append("<div><button class='btn' type='submit'>Save HTML</button></div>")
            out.append("</form></div>")

    else:
        # Add section form on main page
        out.append("<div class='card'><h2>Add section</h2>")
        out.append("<form method='post'>")
        out.append("<input type='hidden' name='action' value='add_section'>")
        out.append("<label>Type (e.g. links, legal, about)<br><input type='text' name='type' value='links'></label>")
        out.append("<label>Title<br><input type='text' name='title'></label>")
        out.append("<label>Optional initial HTML (leave empty to create an items-section)<br><textarea name='html' rows='6' style='font-family:monospace'></textarea></label>")
        out.append("<div><button class='btn' type='submit'>Add section</button></div>")
        out.append("</form></div>")

    # Replace entire file
    out.append("<div class='card'><h2>Replace entire file</h2>")
    out.append("<form method='post'>")
    out.append("<input type='hidden' name='action' value='replace'>")
    out.append("<label>Paste full JSON array<br><textarea name='whole' rows='10' style='width:100%;font-family:monospace'></textarea></label>")
    out.append("<div><button class='btn' type='submit' onclick=\"return confirm('Replace entire file?')\">Replace file</button></div>")
    out.append("</form></div>")

    out.append(html_tail())
    return "\n".join(out)


def main():
    tried = candidates()
    path = resolve_path()
    fs = cgi.FieldStorage()
    method = os.environ.get("REQUEST_METHOD", "GET").upper()
    msg = None
    err = None
    edit_idx = None
    edit_item_idx = None

    try:
        if method == "GET":
            qs = os.environ.get("QUERY_STRING", "") or ""
            params = parse_qs(qs, keep_blank_values=True)
            if "edit" in params:
                try:
                    edit_idx = int(params.get("edit", [""])[0])
                except Exception:
                    edit_idx = None
            if "edit_item" in params:
                try:
                    edit_item_idx = int(params.get("edit_item", [""])[0])
                except Exception:
                    edit_item_idx = None
            arr = []
            try:
                if path:
                    arr = read_footer(path)
            except Exception as e:
                err = f"Error reading JSON: {e}"
            print(render_ui(path, tried, arr, msg=None, err=err, edit_idx=edit_idx, edit_item_idx=edit_item_idx))
            return

        # POST
        action = fs.getfirst("action", "")
        target = path or candidates()[0]
        try:
            arr = read_footer(target) if os.path.exists(target) else []
        except Exception:
            arr = []

        if action == "add_section":
            stype = fs.getfirst("type", "links") or "links"
            title = fs.getfirst("title", "") or ""
            htmltxt = fs.getfirst("html", "")
            if htmltxt:
                sec = {"type": stype, "title": title, "html": htmltxt}
            else:
                sec = {"type": stype, "title": title, "items": []}
            arr.append(sec)
            try:
                atomic_write(target, arr)
                msg = f"Added section (wrote {target})"
                path = target
            except Exception as e:
                err = f"Write failed: {e}"

        elif action == "edit_section":
            idx = fs.getfirst("index", "")
            try:
                i = int(idx)
            except Exception:
                err = "Invalid index for edit_section"
                i = None
            if i is not None:
                if 0 <= i < len(arr):
                    stype = fs.getfirst("type", "") or arr[i].get("type", "links")
                    title = fs.getfirst("title", "") or ""
                    htmltxt = fs.getfirst("html", None)
                    itm = dict(arr[i]) if isinstance(arr[i], dict) else {}
                    itm["type"] = stype
                    itm["title"] = title
                    # If html is provided (possibly empty string), treat as section-level html.
                    if htmltxt is not None:
                        # if empty string provided, remove html; keep items (if any) as-is
                        if htmltxt != "":
                            itm["html"] = htmltxt
                            itm.pop("items", None)
                        else:
                            # empty html: remove html key; ensure items list exists
                            itm.pop("html", None)
                            if "items" not in itm or not isinstance(itm.get("items"), list):
                                itm["items"] = itm.get("items", [])
                                if itm["items"] is None:
                                    itm["items"] = []
                    else:
                        # no html field in the form (shouldn't happen), ensure items exist
                        if "items" not in itm or not isinstance(itm.get("items"), list):
                            itm["items"] = []
                    arr[i] = itm
                    try:
                        atomic_write(target, arr)
                        msg = f"Edited section {i}"
                        path = target
                    except Exception as e:
                        err = f"Edit write failed: {e}"
                else:
                    err = "Edit section index out of range"

        elif action == "delete_section":
            idx = fs.getfirst("index", "")
            try:
                i = int(idx)
            except Exception:
                err = "Invalid index for delete_section"
                i = None
            if i is not None:
                if 0 <= i < len(arr):
                    arr.pop(i)
                    try:
                        atomic_write(target, arr)
                        msg = f"Deleted section {i}"
                        path = target
                    except Exception as e:
                        err = f"Delete write failed: {e}"
                else:
                    err = "Delete section index out of range"

        elif action == "add_item":
            sidx = fs.getfirst("section", "")
            try:
                si = int(sidx)
            except Exception:
                err = "Invalid section for add_item"
                si = None
            if si is not None and 0 <= si < len(arr):
                stype = arr[si].get("type", "links")
                # If the section currently has 'html', we convert it to an items-section when adding an item.
                if isinstance(arr[si].get("html"), str):
                    arr[si].pop("html", None)
                    arr[si]["items"] = []
                items = arr[si].get("items")
                if items is None or not isinstance(items, list):
                    items = []
                if stype == "links":
                    label = fs.getfirst("label", "") or ""
                    href = fs.getfirst("href", "") or ""
                    rel = fs.getfirst("rel", "") or ""
                    item = {"label": label, "href": href}
                    if rel:
                        item["rel"] = rel
                else:
                    htmltxt = fs.getfirst("html", "") or ""
                    item = {"html": htmltxt}
                items.append(item)
                arr[si]["items"] = items
                try:
                    atomic_write(target, arr)
                    msg = f"Added item to section {si}"
                    path = target
                except Exception as e:
                    err = f"Add item write failed: {e}"
            else:
                if err is None:
                    err = "Add item: section out of range"

        elif action == "edit_item":
            sidx = fs.getfirst("section", "")
            idx = fs.getfirst("index", "")
            try:
                si = int(sidx)
                i = int(idx)
            except Exception:
                err = "Invalid indices for edit_item"
                si = i = None
            if si is not None and i is not None:
                if 0 <= si < len(arr) and isinstance(arr[si].get("items"), list) and 0 <= i < len(arr[si]["items"]):
                    stype = arr[si].get("type", "links")
                    if stype == "links":
                        label = fs.getfirst("label", "") or ""
                        href = fs.getfirst("href", "") or ""
                        rel = fs.getfirst("rel", "") or ""
                        itm = dict(arr[si]["items"][i]) if isinstance(arr[si]["items"][i], dict) else {}
                        itm["label"] = label
                        itm["href"] = href
                        if rel:
                            itm["rel"] = rel
                        else:
                            itm.pop("rel", None)
                    else:
                        htmltxt = fs.getfirst("html", "") or ""
                        itm = {"html": htmltxt}
                    arr[si]["items"][i] = itm
                    try:
                        atomic_write(target, arr)
                        msg = f"Edited item {i} in section {si}"
                        path = target
                    except Exception as e:
                        err = f"Edit item write failed: {e}"
                else:
                    err = "Edit item index out of range"

        elif action == "delete_item":
            sidx = fs.getfirst("section", "")
            idx = fs.getfirst("index", "")
            try:
                si = int(sidx)
                i = int(idx)
            except Exception:
                err = "Invalid indices for delete_item"
                si = i = None
            if si is not None and i is not None:
                if 0 <= si < len(arr) and isinstance(arr[si].get("items"), list) and 0 <= i < len(arr[si]["items"]):
                    arr[si]["items"].pop(i)
                    try:
                        atomic_write(target, arr)
                        msg = f"Deleted item {i} from section {si}"
                        path = target
                    except Exception as e:
                        err = f"Delete item write failed: {e}"
                else:
                    err = "Delete item index out of range"

        elif action == "replace":
            whole = fs.getfirst("whole", "") or ""
            try:
                parsed = json.loads(whole)
                if not isinstance(parsed, list):
                    err = "Replacement must be a JSON array"
                else:
                    atomic_write(target, parsed)
                    msg = f"Replaced file {target}"
                    path = target
            except Exception as e:
                err = f"Replace failed: {e}"

        else:
            err = f"Unknown action: {escape(action)}"

        # reload for display
        arr2 = []
        try:
            if path:
                arr2 = read_footer(path)
        except Exception:
            arr2 = []
        print(render_ui(path, tried, arr2, msg=msg, err=err, edit_idx=None))
        return

    except Exception:
        import traceback
        tb = traceback.format_exc()
        print(html_head("Error"))
        print(f"<div class='card' style='color:crimson'><pre class='item'>{escape(tb)}</pre></div>")
        print(html_tail())


if __name__ == "__main__":
    main()