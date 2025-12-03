import argparse
import base64
import csv
import json
import re
import tkinter as tk
import zlib
from datetime import datetime
from pathlib import Path
from tkinter import filedialog, messagebox, ttk
from typing import Dict, List, Optional, Tuple

EMBEDDED_BASE64_ICONS_B64 = (
    "eJztfVt34kyy5Xv/lTNrRkii16mZdR4wkim5nakWSFDizYZqGcmU67RxCenXT+xI3QCJMpjv1M0PXsKgSyozMjMuO3bcvSxXT//7+Vv0t+Xd5u7/rtZ30ef/"
    "Q//+x3b9+P/u754//938X//8KPV5dmXez7Yvi1xb3X0cawvr6dutsTSWWd8QWf/bYr34JuJBKoYf8uV6sXJG86/3o/SDs+5/u18HK+fj/Ov803J4b0QfnHgQ"
    "ieEgk/zn/AfdP16sH9PlsH6Gs7r6Ore01afehy9h8CFd2h96S3tqLkfTl4X++O1+5Xz7Z7xNw0/jp+pZX6bZ/TCKw0lCz/c+OImWO9b0QawGmWPxM7eO5WzE"
    "OtqKta05lofvUseyI2qLtoztLPSdiM5P+fyJRtfdOFLfOXcjh5o2jad/d1b/SW2/eliOomi+fny+p/YuP908/2MoV/+YOBHa7/teJGf2Fs8on0X33d5ZeJaI"
    "RFY+a0Btlbrwbx7o87Zs761P5weRsXuult/6ciY/Pa1uc/M/F6Nr7W54tb6bbZ//ObnpLdbpk6OLr9SHCf0v6d16Ie4zqZ5F971+4mdleG7ZN/QMI0TfNNu7"
    "wfkTa7lz7q0vNqIX9j4fGYf5sBqHrRiahpwMjHCCI38u2/Ii84D+pro7NHuHv2vb2ziIxMdw0/47X7+5jRfH2zJptCXj6/vH2iK/05b231/ZllXVFgPnUh+n"
    "x9oiVsfb0v77K9uS1f0iV3w9xiojmS2eH1Ryi3vhbxnfPJSfG3L6gmcvV1r2irYk89k8p+Pz3az/GH66+bhYXyd3s+kLrQE870OaP58tm9aK6MW17Jxk2RSx"
    "thL0HBELnf7vC5/+z+g836HzHOoP25D0/9y4eZiPHh/vv4yn9+tHDevJ8pN8XDzKNJzJR1/vTxd6sKLn58vRh9T5KLV7Y7AJ9Q/P9wbdayWHXuKouWWMvy2G"
    "V9/m63k+/0T9FNurw/OF6VoRn3+rb7/er6cPi2SZhbPx1/msrx19z1X9ntLytPo9qc+s0Czfk9bJ8j1Tes++WF3kPdfzdXjCe8prL5kOx4Fz7F35czjbHr4r"
    "jU2o1n+SOdn/58RJ6f0yOm7p+KU6/3pM9+jn8/WH7J7e/X52rdH+YP7DUn0ksRb7zouMQ11mg03js6ZkMnkhOaE1LKJjaPBafGpfjT6s51/k45LaXcqV6qNe"
    "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"
)

EMBEDDED_SVG_MAP_B64 = (
    "eJxdlO2OKiEMQP/zLJtN7q7JfR6GL1GgZKjj6NNvFYXWH4Zz2gIzQzEaKF9uR6UvNsJ328JXrr/Mrnpj5pM2TCEEZlrk8kHzZTI3qJfGJ0bvuT42MWDd00yt"
    "UxaNU+qNcfs3ZVvalOPEEwsj45PeNNuQISsKwOLZkhTUBvuGxgt/McVqTNBjOrhCkba9Vt4GI7EFsz+FQMguLHNDkcMpYFG5vT8qjYNzi4MN5MHNrOqIOfXv"
    "hXlKPqLIJJHiukttT02xnJ+aynnKZWWZq1sSvXICqL2SQIH30Th6rFjx9UYNFRSHYLoXVwDdR+hD6zmoan3vD+tVPQL2DjvVIMxxpR+zJVdmIfJlauGVVhg+"
    "enrq0UXDlN6aLxsN8GWbVRWubl1i9yXunwFUtWI/7QcIy8xA5EBO49KEsElgq1qxf0UaVauvW9rqrtqt+Zh6F9mUhBMLf/SyqF83hXs/XxoH0916Y4IwOJY4"
    "2PgZp7vmh5walCE3TS04hDECyRate//hHZjpLYqcCzybYeN25kaHmpn6JJJZTDwIo3aUWzL9DVXtqfXDeICwLIwLikIUhVqIXGOZRrdO7e/7TZ9scBOMTOxg"
    "i1bdY7/UNA7+fx+46nUwMg6zZLn/DN5nODYYbHNQf5FsdeI="
)


def decode_embedded_text(data_b64: str) -> str:
    return zlib.decompress(base64.b64decode(data_b64)).decode("utf-8")


def parse_icon_map_text(text: str) -> Dict[str, str]:
    icon_map: Dict[str, str] = {}
    reader = csv.DictReader(text.splitlines())
    for row in reader:
        ext = row["ext"].lower().strip()
        if not ext:
            continue
        icon_map.setdefault(ext, row["icon"])
    return icon_map


def parse_base64_text(text: str) -> Dict[str, str]:
    lines = text.splitlines()
    non_blank = [line.strip() for line in lines if line.strip()]
    base64_map: Dict[str, str] = {}
    for i in range(0, len(non_blank), 2):
        if i + 1 >= len(non_blank):
            break
        name = non_blank[i]
        data_uri = non_blank[i + 1]
        if name and data_uri:
            base64_map[name] = data_uri
    return base64_map


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate a fresh HTML directory listing using mysite.csv and "
            "svg_map_tall.csv (optional; embedded fallback) and base64 icons, writing the result to a new file. Launches a "
            "Tkinter GUI by default; use --no-gui for CLI mode."
        )
    )
    parser.add_argument(
        "--html",
        default="Elements(M) - 2025-11-30 19-07-48.html",
        help="Source HTML report to copy and update.",
    )
    parser.add_argument(
        "--csv",
        default="mysite.csv",
        help="CSV containing Name, Modified, Modified By, Item Type, Path, URL columns.",
    )
    parser.add_argument(
        "--svg-map",
        default=None,
        help="Tall CSV mapping of icon filename to extension. Uses embedded map when omitted.",
    )
    parser.add_argument(
        "--base64-icons",
        default=None,
        help="Text file containing pairs of icon filename and data URI lines. Uses embedded icons when omitted.",
    )
    parser.add_argument(
        "--output",
        default=None,
        help="Output HTML file. Defaults to <html>-mysite.html next to the source.",
    )
    parser.add_argument(
        "--no-gui",
        action="store_true",
        help="Run generation immediately from CLI args (skip the GUI).",
    )
    return parser.parse_args()


def load_icon_map(svg_map_path: Path | None) -> Dict[str, str]:
    if svg_map_path is not None and svg_map_path.exists():
        with svg_map_path.open(newline="", encoding="utf-8") as f:
            return parse_icon_map_text(f.read())
    return parse_icon_map_text(decode_embedded_text(EMBEDDED_SVG_MAP_B64))


def load_base64_icons(path: Path | None) -> Dict[str, str]:
    """
    File format: alternating lines of icon filename and data URI, with optional blank lines.
    Falls back to the embedded icon set when no path is provided or the file is missing.
    """
    if path is not None and path.exists():
        return parse_base64_text(path.read_text(encoding="utf-8"))
    return parse_base64_text(decode_embedded_text(EMBEDDED_BASE64_ICONS_B64))


def parse_datetime(value: str) -> int:
    """
    Parse dates in "mm/dd/yyyy hh:mm" or "mm/dd/yyyy hh:mm:ss" (24h) formats.
    """
    for fmt in ("%m/%d/%Y %H:%M:%S", "%m/%d/%Y %H:%M"):
        try:
            return int(datetime.strptime(value, fmt).timestamp())
        except ValueError:
            continue
    raise ValueError(f"Unrecognized date format: {value!r}")


def common_prefix_segments(paths: List[str]) -> List[str]:
    if not paths:
        return []
    split_paths = [p.split("/") for p in paths]
    prefix = split_paths[0][:]
    for parts in split_paths[1:]:
        limit = min(len(prefix), len(parts))
        idx = 0
        while idx < limit and prefix[idx] == parts[idx]:
            idx += 1
        prefix = prefix[:idx]
        if not prefix:
            break
    return prefix


class DirNode:
    def __init__(self, path: str) -> None:
        self.path = path
        self.children: Dict[str, "DirNode"] = {}
        self.files: List[Dict[str, object]] = []
        self.dir_size = 0
        self.timestamp: int | None = None

    def ensure_child(self, name: str, full_path: str) -> "DirNode":
        if name not in self.children:
            self.children[name] = DirNode(full_path)
        return self.children[name]

    def add_file(
        self,
        name: str,
        timestamp: int,
        modified_by: str,
        item_type: str,
        url: str,
        size: int = 0,
    ) -> None:
        self.files.append(
            {
                "name": name,
                "timestamp": timestamp,
                "modified_by": modified_by,
                "item_type": item_type,
                "url": url,
                "size": size,
            }
        )
        self.dir_size += size
        if self.timestamp is None or timestamp > self.timestamp:
            self.timestamp = timestamp


def build_tree(entries: List[Dict[str, str]]) -> Tuple[DirNode, List[str]]:
    dir_paths = [entry["dir_path"] for entry in entries]
    prefix_segments = common_prefix_segments(dir_paths)
    if not prefix_segments and dir_paths:
        # Fallback to the first segment so we always have a root.
        prefix_segments = [dir_paths[0].split("/")[0]]
    root_path = "/".join(prefix_segments)
    root = DirNode(root_path)

    for entry in entries:
        dir_path = entry["dir_path"]
        parts = dir_path.split("/")
        idx = len(prefix_segments)
        node = root
        while idx < len(parts):
            seg = parts[idx]
            full = "/".join(parts[: idx + 1])
            node = node.ensure_child(seg, full)
            idx += 1
        node.add_file(
            entry["filename"],
            entry["timestamp"],
            entry["modified_by"],
            entry["item_type"],
            entry["url"],
            entry["size"],
        )
    return root, prefix_segments


def propagate_timestamps(node: DirNode) -> None:
    child_ts = []
    for child in node.children.values():
        propagate_timestamps(child)
        if child.timestamp is not None:
            child_ts.append(child.timestamp)
    if node.timestamp is None:
        node.timestamp = max(child_ts) if child_ts else int(datetime.now().timestamp())


def generate_dir_entries(node: DirNode) -> List[List[object]]:
    entries: List[List[object]] = []

    def walk(current: DirNode) -> int:
        current_id = len(entries)
        entries.append([])  # placeholder
        child_ids: List[int] = []
        for name in sorted(current.children):
            child_ids.append(walk(current.children[name]))
        dir_info = f"{current.path}*{current.dir_size}*{current.timestamp}*268435456*D"
        files = [
            f"{f['name']}*{f['timestamp']}*{f['modified_by']}*{f['item_type']}*{f['url']}"
            for f in current.files
        ]
        subdir_str = "*".join(str(cid) for cid in child_ids) if child_ids else ""
        entries[current_id] = [dir_info, *files, current.dir_size, subdir_str]
        return current_id

    walk(node)
    return entries


def tree_total_size(node: DirNode) -> int:
    total = node.dir_size
    for child in node.children.values():
        total += tree_total_size(child)
    return total


def replace_data_block(html: str, new_block: str) -> str:
    pattern = re.compile(
        r"Array\.prototype\.p = Array\.prototype\.push;.*?delete\(Array\.prototype\.p\);\s*// remove alias added above",
        re.DOTALL,
    )
    return pattern.sub(new_block, html, count=1)


def replace_var(html: str, var_name: str, value: str | int) -> str:
    return re.sub(
        rf"var {re.escape(var_name)} = .*?;",
        f"var {var_name} = {json.dumps(value)};",
        html,
        count=1,
    )


def replace_text_tag(html: str, tag: str, new_text: str) -> str:
    return re.sub(
        rf"<{tag}>.*?</{tag}>",
        f"<{tag}>{new_text}</{tag}>",
        html,
        count=1,
        flags=re.DOTALL,
    )


def update_header_stats(html: str, files: int, folders: int, total_size: int) -> str:
    new_stats = (
        f"{files} Files / {folders} Folders "
        f"(<span id=\"tot_size\">{total_size}</span>) | File System: Virtual<br>"
        f"Report time: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')} -- updated from mysite.csv"
    )
    return re.sub(
        r'<div class="app_header_stats">.*?</div>',
        f'<div class="app_header_stats">{new_stats}</div>',
        html,
        count=1,
        flags=re.DOTALL,
    )


STYLE_OVERRIDES: list[tuple[str, str]] = [
    (r"font-size:\s*68\.75%;", "font-size: 90%;"),
    (r"max-width:\s*1440px;", "max-width: 1600px;"),
    (r"width:\s*90%;", "width: 95%;"),
    (r"font-size:\s*8pt;", "font-size: 10pt;"),
]


def apply_style_overrides(html: str) -> str:
    for pattern, replacement in STYLE_OVERRIDES:
        html = re.sub(pattern, replacement, html)
    return html


def inject_style(html: str) -> str:
    icon_style = """
		/* custom icon overrides */
	span.file, span.file_folder {
		background: none !important;
		padding-left: 0;
	}
	img.file-icon, img.folder-icon {
		width: 20px;
		height: 20px;
		vertical-align: middle;
		margin-right: 6px;
	}
	.row_link_icon img.link-icon {
		width: 16px;
		height: 16px;
		vertical-align: middle;
	}
    """
    return html.replace("</style>", icon_style + "\n\t</style>", 1)


def inject_icon_script(
    html: str,
    icon_map: Dict[str, str],
    default_icon: str,
    folder_icon: str,
    link_icon: str,
) -> str:
    icon_json = json.dumps(icon_map, separators=(",", ":"))
    script = f"""
\t<script type="text/javascript">
\t\t// icon rendering injected by build_mysite_html.py
\t\tconst ICON_MAP = {icon_json};
\t\tconst DEFAULT_ICON = "{default_icon}";
\t\tconst FOLDER_ICON = "{folder_icon}";
\t\tconst LINK_ICON = "{link_icon}";

\t\tfunction iconForFilename(name) {{
\t\t\tconst ext = name.toLowerCase().split('.').pop();
\t\t\treturn ICON_MAP[ext] || DEFAULT_ICON;
\t\t}}

\t\tfunction applyIcons(container) {{
\t\t\tconst root = container || document;
\t\t\trouteSpans(root.querySelectorAll('span.file'), false);
\t\t\trouteSpans(root.querySelectorAll('span.file_folder'), true);
\t\t}}

\t\tfunction routeSpans(spans, isFolder) {{
\t\t\tspans.forEach(span => {{
\t\t\t\tif (span.dataset.iconApplied === "1") return;
\t\t\t\tconst link = span.querySelector('a');
\t\t\t\tconst name = (link ? link.textContent : span.textContent).trim();
\t\t\t\tconst img = document.createElement('img');
\t\t\t\timg.className = isFolder ? 'folder-icon' : 'file-icon';
\t\t\t\timg.src = isFolder ? FOLDER_ICON : iconForFilename(name);
\t\t\t\timg.alt = '';
\t\t\t\tspan.prepend(img);
\t\t\t\tspan.dataset.iconApplied = "1";
\t\t\t}});
\t\t}}

\t\tfunction attachIconObserver() {{
\t\t\tconst target = document.getElementById('list_files');
\t\t\tif (!target) return;
\t\t\tapplyIcons(target);
\t\t\tconst observer = new MutationObserver(() => applyIcons(target));
\t\t\tobserver.observe(target, {{ childList: true, subtree: true }});
\t\t}}
\t\tdocument.addEventListener('DOMContentLoaded', attachIconObserver);
\t</script>
"""
    return html.replace("</head>", script + "\n</head>", 1)


def generate_report(
    html_path: Path,
    csv_path: Path,
    svg_map_path: Path | None,
    base64_path: Path | None,
    output_path: Optional[Path] = None,
) -> Path:
    output_path = (
        Path(output_path)
        if output_path is not None
        else html_path.with_name(f"{html_path.stem}-mysite{html_path.suffix}")
    )

    icon_map = load_icon_map(svg_map_path)
    base64_map = load_base64_icons(base64_path)
    default_icon_data = base64_map.get("genericfile.svg", "") or next(
        iter(base64_map.values()), ""
    )
    folder_icon_data = base64_map.get("folder.svg", default_icon_data)
    link_icon_data = base64_map.get("link.svg", default_icon_data)
    icon_data_map = {
        ext: base64_map.get(icon_name, default_icon_data)
        for ext, icon_name in icon_map.items()
    }

    entries: List[Dict[str, object]] = []
    with csv_path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        for row in reader:
            name = row["Name"].strip()
            modified = row["Modified"].strip()
            path_raw = row["Path"].strip().rstrip("/")
            # remove trailing filename if present so path is folder only
            dir_path = path_raw
            if path_raw.lower().endswith(name.lower()):
                dir_path = path_raw[: -len(name)].rstrip("/")
            if not dir_path:
                dir_path = path_raw or "root"
            entries.append(
                {
                    "filename": name,
                    "timestamp": parse_datetime(modified),
                    "dir_path": dir_path,
                    "size": 0,
                    "modified_by": row.get("Modified By", "").strip(),
                    "item_type": row.get("Item Type", "").strip(),
                    "url": row.get("URL", "").strip(),
                }
            )

    root, prefix_segments = build_tree(entries)
    propagate_timestamps(root)
    dir_entries = generate_dir_entries(root)

    d_lines = [f"D.p({json.dumps(entry, separators=(',', ':'))})" for entry in dir_entries]
    new_d_block = (
        "Array.prototype.p = Array.prototype.push;\n\n"
        + "\n".join(d_lines)
        + "\n\n\t\tdelete(Array.prototype.p); // remove alias added above"
    )

    html_text = html_path.read_text(encoding="utf-8")
    html_text = replace_data_block(html_text, new_d_block)
    html_text = replace_var(html_text, "numberOfFiles", len(entries))
    html_text = replace_var(html_text, "sourceRoot", root.path)

    total_size = tree_total_size(root)
    html_text = replace_text_tag(
        html_text, "title", f"Directory list [{root.path}] -- generated"
    )
    html_text = replace_text_tag(
        html_text, "h1", f"Directory list [{root.path}] -- generated"
    )
    html_text = update_header_stats(
        html_text, files=len(entries), folders=len(dir_entries), total_size=total_size
    )
    html_text = apply_style_overrides(html_text)
    html_text = inject_style(html_text)
    html_text = inject_icon_script(
        html_text, icon_data_map, default_icon_data, folder_icon_data, link_icon_data
    )

    output_path.write_text(html_text, encoding="utf-8")
    return output_path


def launch_gui(
    default_html: str,
    default_csv: str,
    default_svg: str | None,
    default_base64: str | None,
    default_output: str | None,
) -> None:
    window = tk.Tk()
    window.title("Build mysite HTML")
    window.resizable(False, False)

    path_vars = {
        "html": tk.StringVar(value=default_html),
        "csv": tk.StringVar(value=default_csv),
        "svg": tk.StringVar(value=default_svg or ""),
        "base64": tk.StringVar(value=default_base64 or ""),
        "output": tk.StringVar(value=default_output or ""),
    }
    status_var = tk.StringVar(value="Ready")

    def browse_file(var_name: str, filetypes: list[tuple[str, str]]) -> None:
        initial = path_vars[var_name].get()
        chosen = filedialog.askopenfilename(
            initialdir=str(Path(initial).parent) if initial else ".",
            filetypes=filetypes,
        )
        if chosen:
            path_vars[var_name].set(chosen)

    def browse_output() -> None:
        initial = path_vars["output"].get() or ""
        chosen = filedialog.asksaveasfilename(
            initialfile=Path(initial).name if initial else "",
            defaultextension=".html",
            filetypes=[("HTML files", "*.html"), ("All files", "*.*")],
        )
        if chosen:
            path_vars["output"].set(chosen)

    def on_generate() -> None:
        try:
            output_path = generate_report(
                Path(path_vars["html"].get()),
                Path(path_vars["csv"].get()),
                Path(path_vars["svg"].get()) if path_vars["svg"].get() else None,
                Path(path_vars["base64"].get()) if path_vars["base64"].get() else None,
                Path(path_vars["output"].get()) if path_vars["output"].get() else None,
            )
        except Exception as exc:  # noqa: BLE001
            status_var.set(f"Error: {exc}")
            messagebox.showerror("Build failed", str(exc))
            return
        status_var.set(f"Wrote {output_path}")
        messagebox.showinfo("Build complete", f"Wrote\n{output_path}")

    padding = {"padx": 6, "pady": 4}
    form = ttk.Frame(window, padding=12)
    form.grid(row=0, column=0, sticky="nsew")

    rows = [
        ("Source HTML", "html", [("HTML files", "*.html"), ("All files", "*.*")]),
        ("mysite.csv", "csv", [("CSV files", "*.csv"), ("All files", "*.*")]),
        ("svg_map_tall.csv (optional)", "svg", [("CSV files", "*.csv"), ("All files", "*.*")]),
        ("Base64 icons (optional)", "base64", [("Text files", "*.txt"), ("All files", "*.*")]),
        ("Output HTML", "output", None),
    ]

    for idx, (label, key, types) in enumerate(rows):
        ttk.Label(form, text=label).grid(row=idx, column=0, sticky="w", **padding)
        entry = ttk.Entry(form, textvariable=path_vars[key], width=60)
        entry.grid(row=idx, column=1, sticky="w", **padding)
        if types is not None:
            btn = ttk.Button(
                form,
                text="Browse",
                command=lambda k=key, t=types: browse_file(k, t),
            )
        else:
            btn = ttk.Button(form, text="Browse", command=browse_output)
        btn.grid(row=idx, column=2, sticky="w", **padding)

    ttk.Button(form, text="Generate", command=on_generate).grid(
        row=len(rows), column=0, columnspan=3, sticky="ew", pady=(8, 4)
    )
    ttk.Label(form, textvariable=status_var, foreground="blue").grid(
        row=len(rows) + 1, column=0, columnspan=3, sticky="w", **padding
    )

    window.mainloop()


if __name__ == "__main__":
    args = parse_args()
    if args.no_gui:
        output = generate_report(
            Path(args.html),
            Path(args.csv),
            Path(args.svg_map) if args.svg_map else None,
            Path(args.base64_icons) if args.base64_icons else None,
            Path(args.output) if args.output else None,
        )
        print(f"Wrote {output}")
    else:
        launch_gui(args.html, args.csv, args.svg_map, args.base64_icons, args.output)
