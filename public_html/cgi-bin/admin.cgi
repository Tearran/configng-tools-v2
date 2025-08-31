#!/usr/bin/env python3
"""
Simple CGI editor for a JSON array of objects in json/nav.json.

- Edits two fields per item: "label" and a second field (either "href" or "html").
- Behavior:
  - GET: show list, raw file, Add form, and Edit form when ?edit=IDX
  - POST: action=add|edit|delete|replace modifies the file (atomic write)
- Priority for file resolution:
  - NAV_JSON_PATH env var (if set)
  - cgi-bin/../json/nav.json
  - $PWD/json/nav.json
  - DOCUMENT_ROOT/json/nav.json (if DOCUMENT_ROOT set)
  - /json/nav.json
- No external dependencies beyond Python 3 standard library.
"""
from html import escape
import cgi
import cgitb
import json
import os
import sys
import tempfile
from urllib.parse import parse_qs

cgitb.enable()

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))


def candidates():
    out = []
    out.append(os.path.normpath(os.path.join(SCRIPT_DIR, "..", "json", "nav.json")))
    out.append(os.path.normpath(os.path.join(os.getcwd(), "json", "nav.json")))
    docroot = os.environ.get("DOCUMENT_ROOT") or ""
    if docroot:
        out.append(os.path.normpath(os.path.join(docroot, "json", "nav.json")))
    out.append(os.path.normpath("/json/nav.json"))
    # dedupe preserve order
    res = []
    seen = set()
    for p in out:
        if p not in seen:
            seen.add(p)
            res.append(p)
    return res


def resolve_path():
    envp = os.environ.get("NAV_JSON_PATH")
    if envp:
        return os.path.realpath(envp)
    for p in candidates():
        if os.path.exists(p):
            return p
    return None


def read_nav(path):
    if not path or not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    if not isinstance(data, list):
        raise ValueError("nav.json top-level must be a JSON array")
    return data


def atomic_write(path, arr):
    txt = json.dumps(arr, indent=2, ensure_ascii=False) + "\n"
    d = os.path.dirname(path) or "."
    os.makedirs(d, exist_ok=True)
    # create tmp file in same dir
    fd, tmp = tempfile.mkstemp(prefix=".navtmp-", dir=d, text=True)
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


def choose_secondary_key(arr):
    # Prefer 'href' if any item has it, else 'html' if any, else default to 'href'
    for it in arr:
        if isinstance(it, dict) and "href" in it:
            return "href"
    for it in arr:
        if isinstance(it, dict) and "html" in it:
            return "html"
    return "href"


def html_head(title="Nav Editor"):
    return (
        "Content-Type: text/html; charset=utf-8\n\n"
        "<!doctype html><html lang='en'><head><meta charset='utf-8'>"
        f"<meta name='viewport' content='width=device-width,initial-scale=1'>"
        f"<title>{escape(title)}</title>"
        "<style>"
        "body{font-family:system-ui,Arial,sans-serif;padding:1rem;max-width:900px;margin:auto;color:#111}"
        ".card{border:1px solid #ddd;padding:.75rem;border-radius:6px;background:#fafafa;margin-bottom:.75rem}"
        ".item{font-family:monospace;white-space:pre-wrap;background:#fff;padding:.5rem;border-radius:4px;border:1px solid #eee}"
        ".small{color:#666;font-size:.9rem}"
        ".btn{padding:.3rem .6rem;border-radius:6px;border:1px solid #bbb;background:#eee;text-decoration:none;color:#000}"
        "form.inline{display:inline-block;margin:0}"
        "</style></head><body>"
    )


def html_tail():
    return "</body></html>"


def render_ui(path, tried, arr, sec_key, msg=None, err=None, edit_idx=None):
    out = []
    out.append(html_head("nav.json editor"))
    if path:
        out.append(f"<div class='card'>Using nav.json at: <code>{escape(path)}</code></div>")
    else:
        out.append("<div class='card' style='color:crimson'>nav.json not found. Adding will create the first candidate.</div>")

    out.append("<div class='card'><strong>Paths checked:</strong><ul>")
    for p in tried:
        out.append(f"<li><code>{escape(p)}</code> — {'found' if os.path.exists(p) else 'not found'}</li>")
    out.append("</ul></div>")

    if msg:
        out.append(f"<div class='card' style='color:green'>{escape(msg)}</div>")
    if err:
        out.append(f"<div class='card' style='color:crimson'>{escape(err)}</div>")

    out.append(f"<div class='card'><h2>Entries (label + {escape(sec_key)})</h2>")
    if not arr:
        out.append("<div class='item'>No entries</div>")
    else:
        out.append("<ul>")
        for i, it in enumerate(arr):
            label = it.get("label", "")
            sec = it.get(sec_key, "") if isinstance(it, dict) else ""
            # presentation: label then secondary value
            display = escape(label) if label else escape(sec)
            if label and sec:
                display = f"{escape(label)} — {escape(sec)}"
            out.append("<li>")
            out.append(display + " ")
            out.append(f"<a class='btn' href='?edit={i}'>Edit</a> ")
            out.append(
                "<form method='post' class='inline' onsubmit=\"return confirm('Delete?');\">"
                f"<input type='hidden' name='action' value='delete'>"
                f"<input type='hidden' name='index' value='{i}'>"
                "<button class='btn' type='submit'>Delete</button></form>"
            )
            out.append("</li>")
        out.append("</ul>")
    out.append("</div>")

    if path and os.path.exists(path):
        try:
            with open(path, "r", encoding="utf-8") as fh:
                raw = fh.read()
        except Exception as e:
            raw = f"Error reading file: {e}"
        out.append(f"<div class='card'><strong>Raw file ({escape(path)}):</strong><pre class='item'>{escape(raw)}</pre></div>")

    # Edit form or Add form
    if edit_idx is not None and 0 <= edit_idx < len(arr):
        item = arr[edit_idx]
        lbl = item.get("label", "")
        sec = item.get(sec_key, "")
        out.append(f"<div class='card'><h2>Edit item {edit_idx}</h2>")
        out.append("<form method='post'>")
        out.append(f"<input type='hidden' name='action' value='edit'>")
        out.append(f"<input type='hidden' name='index' value='{edit_idx}'>")
        out.append(f"<label>Label<br><input type='text' name='label' value='{escape(lbl)}'></label>")
        out.append(f"<label>{escape(sec_key)}<br><input type='text' name='value' value='{escape(sec)}'></label>")
        out.append("<div><button class='btn' type='submit'>Save</button> ")
        out.append(f"<a class='btn' href='{escape(os.environ.get('SCRIPT_NAME','/cgi-bin/nav-edit.cgi'))}'>Cancel</a></div>")
        out.append("</form></div>")
    else:
        out.append("<div class='card'><h2>Add entry</h2>")
        out.append("<form method='post'>")
        out.append("<input type='hidden' name='action' value='add'>")
        out.append("<label>Label<br><input type='text' name='label'></label>")
        out.append(f"<label>{escape(sec_key)}<br><input type='text' name='value'></label>")
        out.append("<div><button class='btn' type='submit'>Add</button></div>")
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

    try:
        if method == "GET":
            qs = os.environ.get("QUERY_STRING", "") or ""
            params = parse_qs(qs, keep_blank_values=True)
            if "edit" in params:
                try:
                    edit_idx = int(params.get("edit", [""])[0])
                except Exception:
                    edit_idx = None
            arr = []
            try:
                if path:
                    arr = read_nav(path)
            except Exception as e:
                err = f"Error reading JSON: {e}"
            sec = choose_secondary_key(arr)
            print(render_ui(path, tried, arr, sec, msg=None, err=err, edit_idx=edit_idx))
            return

        # POST
        action = fs.getfirst("action", "")
        # ensure target path exists or pick candidate[0] for writes
        target = path or candidates()[0]
        try:
            arr = read_nav(target) if os.path.exists(target) else []
        except Exception as e:
            arr = []
            # continue, will report on write failures

        sec = choose_secondary_key(arr)

        if action == "add":
            label = fs.getfirst("label", "") or ""
            value = fs.getfirst("value", "") or ""
            item = {"label": label, sec: value} if sec else {"label": label, "value": value}
            arr.append(item)
            try:
                atomic_write(target, arr)
                msg = f"Added item (wrote {target})"
                path = target
            except Exception as e:
                err = f"Write failed: {e}"

        elif action == "edit":
            idx = fs.getfirst("index", "")
            try:
                i = int(idx)
            except Exception:
                err = "Invalid index for edit"
                i = None
            if i is not None:
                if 0 <= i < len(arr):
                    label = fs.getfirst("label", "") or ""
                    value = fs.getfirst("value", "") or ""
                    itm = dict(arr[i]) if isinstance(arr[i], dict) else {}
                    itm["label"] = label
                    itm[sec] = value
                    arr[i] = itm
                    try:
                        atomic_write(target, arr)
                        msg = f"Edited index {i}"
                        path = target
                    except Exception as e:
                        err = f"Edit write failed: {e}"
                else:
                    err = "Edit index out of range"

        elif action == "delete":
            idx = fs.getfirst("index", "")
            try:
                i = int(idx)
            except Exception:
                err = "Invalid index for delete"
                i = None
            if i is not None:
                if 0 <= i < len(arr):
                    arr.pop(i)
                    try:
                        atomic_write(target, arr)
                        msg = f"Deleted index {i}"
                        path = target
                    except Exception as e:
                        err = f"Delete write failed: {e}"
                else:
                    err = "Delete index out of range"

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
                arr2 = read_nav(path)
        except Exception:
            arr2 = []
        sec2 = choose_secondary_key(arr2)
        print(render_ui(path, tried, arr2, sec2, msg=msg, err=err, edit_idx=None))
        return

    except Exception as e:
        import traceback
        tb = traceback.format_exc()
        print(html_head("Error"))
        print(f"<div class='card' style='color:crimson'><pre class='item'>{escape(tb)}</pre></div>")
        print(html_tail())


if __name__ == "__main__":
    main()