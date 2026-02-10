import os
import re
import sys
import time
import queue
import json
import stat
import sqlite3
import threading
from pathlib import Path
import tkinter as tk
import tkinter.font as tkfont
from tkinter import ttk, filedialog, messagebox

DB_NAME = "fileindex.sqlite"
CONFIG_NAME = "every.config.json"


def _move_db_files(src_db: Path, dst_db: Path) -> bool:
    try:
        dst_db.parent.mkdir(parents=True, exist_ok=True)
        os.replace(str(src_db), str(dst_db))
        for suffix in ("-wal", "-shm"):
            src = Path(str(src_db) + suffix)
            dst = Path(str(dst_db) + suffix)
            if src.exists():
                os.replace(str(src), str(dst))
        return True
    except OSError:
        return False


def _legacy_default_db_path(script_dir: Path) -> Path:
    # Keep DB location stable regardless of launch working directory.
    script_dir_db = script_dir / DB_NAME
    cwd_db = (Path.cwd() / DB_NAME).resolve()
    if script_dir_db.exists():
        return script_dir_db
    if cwd_db.exists() and cwd_db != script_dir_db:
        if _move_db_files(cwd_db, script_dir_db):
            return script_dir_db
        return cwd_db
    return script_dir_db


def load_or_create_config() -> tuple[Path, Path]:
    script_dir = Path(__file__).resolve().parent
    config_path = script_dir / CONFIG_NAME
    default_db = _legacy_default_db_path(script_dir)
    db_path = default_db
    config_data = {}

    if config_path.exists():
        try:
            config_data = json.loads(config_path.read_text(encoding="utf-8"))
            configured = config_data.get("db_path")
            if configured:
                configured_path = Path(str(configured))
                if not configured_path.is_absolute():
                    configured_path = (script_dir / configured_path).resolve()
                db_path = configured_path
        except Exception:
            db_path = default_db

    if db_path != default_db and not db_path.exists() and default_db.exists():
        if not _move_db_files(default_db, db_path):
            db_path = default_db

    db_path.parent.mkdir(parents=True, exist_ok=True)
    config_payload = {
        "db_path": str(db_path),
        "note": "Edit db_path to choose where the SQLite index is stored.",
    }
    try:
        config_path.write_text(json.dumps(config_payload, indent=2), encoding="utf-8")
    except OSError:
        pass
    return db_path, config_path


def save_config(config_path: Path, db_path: Path) -> None:
    payload = {
        "db_path": str(db_path),
        "note": "Edit db_path to choose where the SQLite index is stored.",
    }
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.write_text(json.dumps(payload, indent=2), encoding="utf-8")


DB_PATH, CONFIG_PATH = load_or_create_config()

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA synchronous=NORMAL;
PRAGMA temp_store=MEMORY;
PRAGMA foreign_keys=ON;

CREATE TABLE IF NOT EXISTS roots (
    root TEXT PRIMARY KEY,
    max_depth INTEGER NOT NULL DEFAULT -1
);

CREATE TABLE IF NOT EXISTS files (
    path TEXT PRIMARY KEY,
    root TEXT NOT NULL,
    name TEXT NOT NULL,
    name_lc TEXT NOT NULL,
    ext TEXT NOT NULL,
    size INTEGER NOT NULL,
    ctime REAL NOT NULL,
    mtime REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS root_index_state (
    root TEXT PRIMARY KEY,
    last_indexed_at REAL,
    file_count INTEGER NOT NULL DEFAULT 0,
    skipped INTEGER NOT NULL DEFAULT 0,
    access_errors INTEGER NOT NULL DEFAULT 0,
    duration_sec REAL NOT NULL DEFAULT 0,
    FOREIGN KEY(root) REFERENCES roots(root) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS index_runs (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    root TEXT NOT NULL,
    started_at REAL NOT NULL,
    finished_at REAL,
    status TEXT NOT NULL DEFAULT 'running',
    total_files INTEGER NOT NULL DEFAULT 0,
    skipped INTEGER NOT NULL DEFAULT 0,
    access_errors INTEGER NOT NULL DEFAULT 0,
    notes TEXT
);

CREATE TABLE IF NOT EXISTS scan_errors (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    run_id INTEGER NOT NULL,
    root TEXT NOT NULL,
    path TEXT NOT NULL,
    error_type TEXT NOT NULL,
    error_message TEXT NOT NULL,
    ts REAL NOT NULL,
    FOREIGN KEY(run_id) REFERENCES index_runs(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_files_name_lc ON files(name_lc);
CREATE INDEX IF NOT EXISTS idx_files_root ON files(root);
CREATE INDEX IF NOT EXISTS idx_files_ext ON files(ext);
CREATE INDEX IF NOT EXISTS idx_index_runs_root_started ON index_runs(root, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_scan_errors_run_id ON scan_errors(run_id);
"""


def connect_db(db_path: str) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path), check_same_thread=False)
    conn.execute("PRAGMA busy_timeout=5000;")
    conn.execute("PRAGMA foreign_keys=ON;")
    conn.executescript(SCHEMA)
    _migrate_schema(conn)
    return conn


def _migrate_schema(conn: sqlite3.Connection) -> None:
    try:
        cols = [r[1] for r in conn.execute("PRAGMA table_info(roots)").fetchall()]
        if "max_depth" not in cols:
            conn.execute("ALTER TABLE roots ADD COLUMN max_depth INTEGER NOT NULL DEFAULT -1")
            conn.commit()
    except sqlite3.DatabaseError:
        pass


def fmt_ts(ts: float) -> str:
    try:
        return time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ts))
    except Exception:
        return ""


def fmt_size(n: int, unit_mode: str = "AUTO") -> str:
    if n is None:
        return ""
    n = int(n)
    mode = (unit_mode or "AUTO").upper()

    fixed = {
        "KB": 1024.0,
        "MB": 1024.0**2,
        "GB": 1024.0**3,
    }
    if mode in fixed:
        unit = "kB" if mode == "KB" else mode
        return f"{(n / fixed[mode]):.2f} {unit}"

    units = ["B", "kB", "MB", "GB", "TB", "PB"]
    f = float(n)
    i = 0
    while f >= 1024.0 and i < len(units) - 1:
        f /= 1024.0
        i += 1
    if i == 0:
        return f"{n} {units[i]}"
    return f"{f:.2f} {units[i]}"


def norm_ext_from_name(name: str) -> str:
    dot = name.rfind(".")
    if dot <= 0:
        return ""
    return name[dot + 1 :].lower()


def basename_without_ext(name: str) -> str:
    dot = name.rfind(".")
    if dot <= 0:
        return name
    return name[:dot]


def build_ext_set(ext_field: str) -> set[str] | None:
    s = (ext_field or "").strip()
    if not s:
        return None
    parts = [p.strip().lower() for p in s.split("|") if p.strip()]
    cleaned = []
    for p in parts:
        if p.startswith("."):
            p = p[1:]
        if p:
            cleaned.append(p)
    return set(cleaned) if cleaned else None


def wildcard_to_regex(pattern: str) -> str:
    # "regex style wildcard": support * and ? in addition to normal literals
    # * -> .*  ? -> .
    out = []
    for ch in pattern:
        if ch == "*":
            out.append(".*")
        elif ch == "?":
            out.append(".")
        else:
            out.append(re.escape(ch))
    return "".join(out)


def compile_name_pattern(user_pattern: str) -> re.Pattern | None:
    p = (user_pattern or "").strip()
    if not p:
        return None
    # Treat as wildcard pattern, not full regex. Anchor as substring match.
    rx = wildcard_to_regex(p)
    return re.compile(rx, re.IGNORECASE)


def open_file(path: str) -> None:
    try:
        if sys.platform.startswith("win"):
            os.startfile(path)
        elif sys.platform == "darwin":
            os.system(f'open "{path}"')
        else:
            os.system(f'xdg-open "{path}"')
    except Exception as e:
        messagebox.showerror("Open File", str(e))


def open_containing_folder(path: str) -> None:
    try:
        p = Path(path)
        if sys.platform.startswith("win"):
            # explorer select
            os.system(f'explorer /select,"{str(p)}"')
        elif sys.platform == "darwin":
            os.system(f'open -R "{str(p)}"')
        else:
            os.system(f'xdg-open "{str(p.parent)}"')
    except Exception as e:
        messagebox.showerror("Open Folder", str(e))


class App(tk.Tk):
    def __init__(self):
        super().__init__()
        self.title("Fast File Search (SQLite Index)")
        self.geometry("1150x650")

        self.db_path = DB_PATH.resolve()
        self.config_path = CONFIG_PATH.resolve()
        self.conn = connect_db(str(self.db_path))
        self.msg_q: queue.Queue = queue.Queue()
        self.worker: threading.Thread | None = None
        self.stop_flag = threading.Event()
        self._sort_reverse: dict[str, bool] = {}
        self._error_log_limit = 500
        self.size_unit_var = tk.StringVar(value="MB")
        self.status_var = tk.StringVar(value="")
        self._status_mode = "Ready"
        self._status_text = ""
        self._results_count = 0
        self._current_results: list[tuple[str, str, str, int, float, float, str]] = []
        self._size_by_path: dict[str, int] = {}
        self._root_filter_vars: dict[str, tk.BooleanVar] = {}
        self._root_filter_popup: tk.Menu | None = None
        self._file_root_filter_menu: tk.Menu | None = None
        self._ordered_roots: list[str] = []
        self._root_depths: dict[str, int] = {}
        self._config_window: tk.Toplevel | None = None
        self._config_db_path_var = tk.StringVar(value=str(self.db_path))
        self.depth_var = tk.StringVar(value="All")
        self._min_col_widths = {
            "name": 260,
            "ext": 35,
            "size": 60,
            "created": 110,
            "modified": 110,
            "path": 380,
        }

        self._build_ui()
        self._load_roots()
        self._set_status("Ready")
        self.after(100, self._poll_msgs)
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def _build_ui(self):
        menubar = tk.Menu(self)
        file_menu = tk.Menu(menubar, tearoff=0)
        self._file_root_filter_menu = tk.Menu(file_menu, tearoff=0)
        file_menu.add_cascade(label="Indexed Folders", menu=self._file_root_filter_menu)
        file_menu.add_separator()
        file_menu.add_command(label="Exit", command=self.on_close)
        menubar.add_cascade(label="File", menu=file_menu)

        config_menu = tk.Menu(menubar, tearoff=0)
        config_menu.add_command(label="Settings...", command=self.on_open_config_window)
        menubar.add_cascade(label="Config", menu=config_menu)

        options_menu = tk.Menu(menubar, tearoff=0)
        units_menu = tk.Menu(options_menu, tearoff=0)
        units_menu.add_radiobutton(
            label="kB",
            variable=self.size_unit_var,
            value="KB",
            command=self.on_size_unit_change,
        )
        units_menu.add_radiobutton(
            label="MB",
            variable=self.size_unit_var,
            value="MB",
            command=self.on_size_unit_change,
        )
        units_menu.add_radiobutton(
            label="GB",
            variable=self.size_unit_var,
            value="GB",
            command=self.on_size_unit_change,
        )
        units_menu.add_radiobutton(
            label="Auto",
            variable=self.size_unit_var,
            value="AUTO",
            command=self.on_size_unit_change,
        )
        options_menu.add_cascade(label="Size Units", menu=units_menu)
        menubar.add_cascade(label="Options", menu=options_menu)
        self.config(menu=menubar)

        top = ttk.Frame(self, padding=10)
        top.pack(fill="x")

        # Row 1: roots + index buttons
        r1 = ttk.Frame(top)
        r1.pack(fill="x")

        ttk.Label(r1, text="Indexed roots:").pack(side="left")
        self.roots_var = tk.StringVar(value="")
        self.roots_box = ttk.Combobox(
            r1, textvariable=self.roots_var, width=70, state="readonly"
        )
        self.roots_box.pack(side="left", padx=8, fill="x", expand=True)
        self.roots_box.bind("<Button-3>", self._on_roots_box_right_click)
        self.roots_box.bind("<<ComboboxSelected>>", self._on_root_selected)

        ttk.Label(r1, text="Depth:").pack(side="left", padx=(6, 2))
        depth_values = ["All"] + [str(i) for i in range(0, 51)]
        self.depth_box = ttk.Combobox(
            r1,
            textvariable=self.depth_var,
            values=depth_values,
            width=5,
            state="readonly",
        )
        self.depth_box.pack(side="left")

        ttk.Button(r1, text="Add root + Reindex", command=self.on_add_root).pack(
            side="left", padx=6
        )
        ttk.Button(
            r1, text="Reindex selected root", command=self.on_reindex_selected
        ).pack(side="left")
        ttk.Button(r1, text="Save depth", command=self.on_set_depth_selected).pack(
            side="left", padx=(6, 0)
        )

        # Row 2: search controls
        r2 = ttk.Frame(top)
        r2.pack(fill="x", pady=(10, 0))

        ttk.Label(r2, text="Filename / Pattern:").pack(side="left")
        self.pattern_var = tk.StringVar()
        self.pattern_entry = ttk.Entry(r2, textvariable=self.pattern_var, width=40)
        self.pattern_entry.pack(side="left", padx=8)

        self.match_path_var = tk.BooleanVar(value=False)
        ttk.Checkbutton(
            r2, text="Match against full path", variable=self.match_path_var
        ).pack(side="left")

        ttk.Label(r2, text="File type (ext):").pack(side="left", padx=(16, 0))
        self.ext_var = tk.StringVar()
        self.ext_entry = ttk.Entry(r2, textvariable=self.ext_var, width=25)
        self.ext_entry.pack(side="left", padx=8)
        ttk.Label(r2, text="Examples: pdf  or  ppt|pptm|xlsx").pack(side="left")

        ttk.Button(r2, text="Search", command=self.on_search).pack(side="right")
        ttk.Button(r2, text="Clear", command=self.on_clear).pack(side="right", padx=6)

        # Table
        mid = ttk.Frame(self, padding=(10, 0, 10, 10))
        mid.pack(fill="both", expand=True)

        cols = ("name", "ext", "size", "created", "modified", "path")
        headings = {
            "name": "Name",
            "ext": "Type",
            "size": "Size",
            "created": "Created",
            "modified": "Last Modified",
            "path": "Full Path",
        }
        self.tree = ttk.Treeview(
            mid, columns=cols, show="headings", selectmode="browse"
        )
        for col in cols:
            self.tree.heading(
                col, text=headings[col], command=lambda c=col: self._on_heading_click(c)
            )

        self.tree.column(
            "name",
            width=self._min_col_widths["name"],
            minwidth=self._min_col_widths["name"],
            stretch=False,
            anchor="w",
        )
        self.tree.column(
            "ext",
            width=self._min_col_widths["ext"],
            minwidth=self._min_col_widths["ext"],
            stretch=False,
            anchor="w",
        )
        self.tree.column(
            "size",
            width=self._min_col_widths["size"],
            minwidth=self._min_col_widths["size"],
            stretch=False,
            anchor="e",
        )
        self.tree.column(
            "created",
            width=self._min_col_widths["created"],
            minwidth=self._min_col_widths["created"],
            stretch=False,
            anchor="w",
        )
        self.tree.column(
            "modified",
            width=self._min_col_widths["modified"],
            minwidth=self._min_col_widths["modified"],
            stretch=False,
            anchor="w",
        )
        self.tree.column(
            "path",
            width=self._min_col_widths["path"],
            minwidth=self._min_col_widths["path"],
            stretch=False,
            anchor="w",
        )

        vsb = ttk.Scrollbar(mid, orient="vertical", command=self.tree.yview)
        hsb = ttk.Scrollbar(mid, orient="horizontal", command=self.tree.xview)
        self.tree.configure(yscrollcommand=vsb.set, xscrollcommand=hsb.set)

        self.tree.grid(row=0, column=0, sticky="nsew")
        vsb.grid(row=0, column=1, sticky="ns")
        hsb.grid(row=1, column=0, sticky="ew")
        mid.grid_rowconfigure(0, weight=1)
        mid.grid_columnconfigure(0, weight=1)

        self.tree.bind("<Double-1>", self._on_tree_double_click)
        self.tree.bind("<Button-3>", self._on_right_click)

        # Bottom buttons
        bot = ttk.Frame(self, padding=(10, 0, 10, 10))
        bot.pack(fill="x")

        ttk.Button(bot, text="Open file", command=self.on_open_file).pack(side="left")
        ttk.Button(
            bot, text="Open containing folder", command=self.on_open_folder
        ).pack(side="left", padx=8)
        ttk.Button(bot, text="Remove selected root", command=self.on_remove_root).pack(
            side="right"
        )

        status_bar = ttk.Frame(self, padding=(10, 3, 10, 6))
        status_bar.pack(fill="x", side="bottom")
        ttk.Label(status_bar, textvariable=self.status_var).pack(side="left")

        # Context menu
        self.menu = tk.Menu(self, tearoff=0)
        self.menu.add_command(label="Open file", command=self.on_open_file)
        self.menu.add_command(
            label="Open containing folder", command=self.on_open_folder
        )
        self._root_filter_popup = tk.Menu(self, tearoff=0)

        self.pattern_entry.focus_set()
        self.after_idle(self._autosize_columns)

    def _on_right_click(self, event):
        iid = self.tree.identify_row(event.y)
        if iid:
            self.tree.selection_set(iid)
            self.menu.tk_popup(event.x_root, event.y_root)

    def _on_tree_double_click(self, event):
        region = self.tree.identify_region(event.x, event.y)
        if region not in ("cell", "tree"):
            return "break"
        iid = self.tree.identify_row(event.y)
        if not iid:
            return "break"
        self.tree.selection_set(iid)
        self.tree.focus(iid)
        self.on_open_file()
        return "break"

    def _on_roots_box_right_click(self, event):
        self._rebuild_root_filter_menus()
        if self._root_filter_popup is None:
            return
        try:
            self._root_filter_popup.tk_popup(event.x_root, event.y_root)
        finally:
            self._root_filter_popup.grab_release()

    def _rebuild_root_filter_menus(self):
        menus = [
            m
            for m in (self._root_filter_popup, self._file_root_filter_menu)
            if m is not None
        ]
        if not menus:
            return
        for menu in menus:
            menu.delete(0, "end")
            menu.add_command(
                label="Check all", command=lambda: self._set_all_root_filters(True)
            )
            menu.add_command(
                label="Uncheck all", command=lambda: self._set_all_root_filters(False)
            )
            menu.add_separator()
            if not self._ordered_roots:
                menu.add_command(label="(No indexed folders)", state="disabled")
                continue
            for root in self._ordered_roots:
                var = self._root_filter_vars.get(root)
                if var is None:
                    continue
                menu.add_checkbutton(
                    label=root, variable=var, command=self._on_root_filter_change
                )

    def _set_all_root_filters(self, checked: bool):
        for var in self._root_filter_vars.values():
            var.set(bool(checked))
        self._on_root_filter_change()

    def _selected_search_roots(self) -> list[str]:
        return [
            r
            for r in self._ordered_roots
            if self._root_filter_vars.get(r) and self._root_filter_vars[r].get()
        ]

    def _on_root_filter_change(self):
        self._apply_root_filter_to_current_results()

    def _path_dedupe_key(self, path: str) -> str:
        return os.path.normcase(os.path.normpath(path or ""))

    def _apply_root_filter_to_current_results(self):
        selected = set(self._selected_search_roots())
        if not selected:
            visible_rows = []
        else:
            visible_rows = []
            seen_keys = set()
            for row in self._current_results:
                root = row[0]
                if root not in selected:
                    continue
                key = self._path_dedupe_key(row[6])
                if key in seen_keys:
                    continue
                seen_keys.add(key)
                visible_rows.append(row)
        self._set_results_count(len(visible_rows))
        self._populate_results(visible_rows, keep_current=False)

    def on_open_config_window(self):
        if self._config_window is not None and self._config_window.winfo_exists():
            self._config_window.deiconify()
            self._config_window.lift()
            self._config_window.focus_force()
            return

        win = tk.Toplevel(self)
        win.title("Config Settings")
        win.transient(self)
        win.grab_set()
        win.resizable(False, False)
        win.protocol("WM_DELETE_WINDOW", self._close_config_window)
        self._config_window = win
        self._config_db_path_var.set(str(self.db_path))

        body = ttk.Frame(win, padding=12)
        body.pack(fill="both", expand=True)

        ttk.Label(body, text="Config file:").grid(row=0, column=0, sticky="w")
        ttk.Label(body, text=str(self.config_path)).grid(
            row=0, column=1, columnspan=3, sticky="w", padx=(8, 0)
        )

        ttk.Label(body, text="Database file path:").grid(
            row=1, column=0, sticky="w", pady=(10, 0)
        )
        db_entry = ttk.Entry(body, textvariable=self._config_db_path_var, width=75)
        db_entry.grid(
            row=1, column=1, columnspan=3, sticky="ew", padx=(8, 0), pady=(10, 0)
        )

        ttk.Button(body, text="Browse File...", command=self._pick_config_db_file).grid(
            row=2, column=1, sticky="w", padx=(8, 0), pady=(8, 0)
        )
        ttk.Button(
            body, text="Browse Folder...", command=self._pick_config_db_folder
        ).grid(row=2, column=2, sticky="w", padx=(8, 0), pady=(8, 0))
        ttk.Button(
            body, text="Default Location", command=self._set_default_db_path
        ).grid(row=2, column=3, sticky="e", padx=(8, 0), pady=(8, 0))

        ttk.Label(
            body,
            text="Tip: Browse File picks a .sqlite file directly. Browse Folder keeps the current file name.",
        ).grid(row=3, column=0, columnspan=4, sticky="w", pady=(8, 0))

        actions = ttk.Frame(body)
        actions.grid(row=4, column=0, columnspan=4, sticky="e", pady=(12, 0))
        ttk.Button(actions, text="Cancel", command=self._close_config_window).pack(
            side="right"
        )
        ttk.Button(actions, text="Save", command=self._save_config_from_window).pack(
            side="right", padx=(0, 8)
        )

        body.columnconfigure(1, weight=1)
        db_entry.focus_set()

    def _close_config_window(self):
        if self._config_window is not None and self._config_window.winfo_exists():
            self._config_window.destroy()
        self._config_window = None

    def _pick_config_db_file(self):
        current = Path(self._config_db_path_var.get().strip() or str(self.db_path))
        initial_dir = (
            str(current.parent) if current.parent.exists() else str(self.db_path.parent)
        )
        chosen = filedialog.asksaveasfilename(
            parent=self._config_window,
            title="Select SQLite database file",
            defaultextension=".sqlite",
            initialdir=initial_dir,
            initialfile=current.name or DB_NAME,
            filetypes=[("SQLite DB", "*.sqlite *.db"), ("All files", "*.*")],
        )
        if chosen:
            self._config_db_path_var.set(chosen)

    def _pick_config_db_folder(self):
        current = Path(self._config_db_path_var.get().strip() or str(self.db_path))
        initial_dir = (
            str(current.parent) if current.parent.exists() else str(self.db_path.parent)
        )
        chosen = filedialog.askdirectory(
            parent=self._config_window,
            title="Select database folder",
            initialdir=initial_dir,
        )
        if chosen:
            filename = current.name or DB_NAME
            self._config_db_path_var.set(str(Path(chosen) / filename))

    def _set_default_db_path(self):
        default_db = _legacy_default_db_path(Path(__file__).resolve().parent)
        self._config_db_path_var.set(str(default_db))

    def _save_config_from_window(self):
        if self.worker and self.worker.is_alive():
            messagebox.showinfo(
                "Busy",
                "Wait for the current job to finish before changing config.",
                parent=self._config_window,
            )
            return

        raw = self._config_db_path_var.get().strip()
        if not raw:
            messagebox.showerror(
                "Invalid path",
                "Database file path cannot be empty.",
                parent=self._config_window,
            )
            return

        new_db_path = Path(raw).expanduser()
        if not new_db_path.is_absolute():
            new_db_path = (self.config_path.parent / new_db_path).resolve()
        else:
            new_db_path = new_db_path.resolve()

        if new_db_path.suffix == "":
            new_db_path = new_db_path.with_suffix(".sqlite")

        try:
            new_db_path.parent.mkdir(parents=True, exist_ok=True)
        except OSError as exc:
            messagebox.showerror(
                "Invalid path",
                f"Cannot create folder:\n{exc}",
                parent=self._config_window,
            )
            return

        old_db_path = self.db_path

        try:
            save_config(self.config_path, new_db_path)
        except OSError as exc:
            messagebox.showerror(
                "Save failed",
                f"Failed to write config file:\n{exc}",
                parent=self._config_window,
            )
            return

        if new_db_path == old_db_path:
            self._close_config_window()
            self._set_status("Ready")
            return

        try:
            self.conn.commit()
        except Exception:
            pass
        try:
            self.conn.close()
        except Exception:
            pass

        moved = False
        if old_db_path.exists() and not new_db_path.exists():
            moved = _move_db_files(old_db_path, new_db_path)

        try:
            self.conn = connect_db(str(new_db_path))
        except Exception as exc:
            self.conn = connect_db(str(old_db_path))
            save_config(self.config_path, old_db_path)
            messagebox.showerror(
                "Connection failed",
                f"Could not open new database file:\n{exc}",
                parent=self._config_window,
            )
            return

        self.db_path = new_db_path
        self._config_db_path_var.set(str(self.db_path))
        self._current_results = []
        self._size_by_path = {}
        self._clear_table()
        self._set_results_count(0)
        self._load_roots()
        if moved:
            self._set_status("Ready")
        else:
            self._set_status("Ready")
        self._close_config_window()

    def _depth_to_label(self, depth: int) -> str:
        if depth is None or int(depth) < 0:
            return "All"
        return str(int(depth))

    def _depth_from_control(self) -> int | None:
        raw = (self.depth_var.get() or "").strip()
        if not raw:
            raw = "All"
        if raw.lower() == "all":
            return -1
        try:
            value = int(raw)
        except ValueError:
            messagebox.showerror(
                "Invalid depth", "Depth must be 'All' or an integer 0 or greater."
            )
            return None
        if value < 0:
            messagebox.showerror(
                "Invalid depth", "Depth must be 'All' or an integer 0 or greater."
            )
            return None
        return value

    def _selected_root_depth(self, root: str) -> int:
        return int(self._root_depths.get(root, -1))

    def _sync_depth_control_for_selected_root(self):
        root = self.roots_var.get().strip()
        if not root:
            self.depth_var.set("All")
            return
        self.depth_var.set(self._depth_to_label(self._selected_root_depth(root)))

    def _on_root_selected(self, _event=None):
        self._sync_depth_control_for_selected_root()

    def _save_root_depth(self, root: str, depth: int):
        self.conn.execute(
            """
            INSERT INTO roots(root, max_depth) VALUES(?, ?)
            ON CONFLICT(root) DO UPDATE SET max_depth = excluded.max_depth
            """,
            (root, int(depth)),
        )
        self.conn.commit()
        self._root_depths[root] = int(depth)
        self._sync_depth_control_for_selected_root()

    def on_set_depth_selected(self):
        root = self.roots_var.get().strip()
        if not root:
            messagebox.showinfo("Depth", "No root selected.")
            return
        depth = self._depth_from_control()
        if depth is None:
            return
        self._save_root_depth(root, depth)
        self._set_status("Ready")

    def _load_roots(self):
        cur = self.conn.execute(
            "SELECT root, COALESCE(max_depth, -1) FROM roots ORDER BY root"
        )
        rows = cur.fetchall()
        roots = [r[0] for r in rows]
        self._root_depths = {r[0]: int(r[1]) for r in rows}
        if not roots:
            # Recover roots list from file entries if roots table is empty.
            recovered = [
                r[0]
                for r in self.conn.execute(
                    "SELECT DISTINCT root FROM files ORDER BY root"
                ).fetchall()
            ]
            if recovered:
                self.conn.executemany(
                    "INSERT OR IGNORE INTO roots(root, max_depth) VALUES(?, -1)",
                    [(r,) for r in recovered],
                )
                self.conn.commit()
                roots = recovered
                self._root_depths = {r: -1 for r in recovered}
        prev_states = {root: var.get() for root, var in self._root_filter_vars.items()}
        self._ordered_roots = roots
        self._root_filter_vars = {
            root: tk.BooleanVar(value=prev_states.get(root, True)) for root in roots
        }
        self._rebuild_root_filter_menus()
        self.roots_box["values"] = roots
        if roots and not self.roots_var.get():
            self.roots_var.set(roots[0])
        if self.roots_var.get() and self.roots_var.get() not in roots:
            self.roots_var.set(roots[0] if roots else "")
        self._sync_depth_control_for_selected_root()

    def _db_summary_text(self) -> str:
        try:
            roots_count = self.conn.execute("SELECT COUNT(*) FROM roots").fetchone()[0]
            files_count = self.conn.execute("SELECT COUNT(*) FROM files").fetchone()[0]
            return (
                f"DB: {self.db_path} | Config: {self.config_path.name} | "
                f"roots: {roots_count:,} | files: {files_count:,}"
            )
        except Exception:
            return f"DB: {self.db_path}"

    def _flush_scan_errors(self, rows: list[tuple[int, str, str, str, str, float]]):
        if not rows:
            return
        self.conn.executemany(
            """
            INSERT INTO scan_errors(run_id, root, path, error_type, error_message, ts)
            VALUES(?, ?, ?, ?, ?, ?)
            """,
            rows,
        )
        self.conn.commit()

    def _set_status(self, text: str):
        self._status_text = (text or "").strip()
        lower = self._status_text.lower()
        if lower.startswith("indexing"):
            self._status_mode = "Indexing"
        elif lower.startswith("error") or lower.startswith("index failed"):
            self._status_mode = "Error"
        else:
            self._status_mode = "Ready"
        self._refresh_status_bar()

    def _set_results_count(self, count: int):
        self._results_count = max(0, int(count))
        self._refresh_status_bar()

    def _refresh_status_bar(self):
        text = f"{self._status_mode} | Results: {self._results_count:,}"
        if self._status_mode == "Error" and self._status_text:
            text = f"{text} | {self._status_text}"
        self.status_var.set(text)

    def _clear_table(self):
        for iid in self.tree.get_children():
            self.tree.delete(iid)
        self._autosize_columns()

    def _size_to_bytes(self, text: str) -> float:
        s = (text or "").strip()
        if not s:
            return -1.0
        parts = s.split()
        if len(parts) != 2:
            return -1.0
        try:
            num = float(parts[0])
        except ValueError:
            return -1.0
        unit = parts[1].upper()
        factors = {
            "B": 1.0,
            "KB": 1024.0,
            "MB": 1024.0**2,
            "GB": 1024.0**3,
            "TB": 1024.0**4,
            "PB": 1024.0**5,
        }
        return num * factors.get(unit, 1.0)

    def _sort_key(self, col: str, value: str):
        if col == "size":
            return self._size_to_bytes(value)
        if col in ("created", "modified"):
            try:
                return time.mktime(time.strptime(value, "%Y-%m-%d %H:%M:%S"))
            except Exception:
                return float("-inf")
        return (value or "").lower()

    def _on_heading_click(self, col: str):
        cols = list(self.tree["columns"])
        if col not in cols:
            return
        idx = cols.index(col)
        reverse = self._sort_reverse.get(col, False)
        sortable = []
        for iid in self.tree.get_children(""):
            values = self.tree.item(iid, "values")
            cell = values[idx] if idx < len(values) else ""
            sortable.append((self._sort_key(col, cell), iid))
        sortable.sort(key=lambda x: x[0], reverse=reverse)
        for pos, (_, iid) in enumerate(sortable):
            self.tree.move(iid, "", pos)
        self._sort_reverse[col] = not reverse

    def _autosize_columns(self):
        cols = list(self.tree["columns"])
        if not cols:
            return

        style = ttk.Style(self)

        def _font_from_style(
            style_name: str, option: str, fallback_name: str
        ) -> tkfont.Font:
            spec = style.lookup(style_name, option)
            if spec:
                try:
                    return tkfont.Font(font=spec)
                except tk.TclError:
                    try:
                        return tkfont.nametofont(spec)
                    except tk.TclError:
                        pass
            try:
                return tkfont.nametofont(fallback_name)
            except tk.TclError:
                return tkfont.nametofont("TkDefaultFont")

        body_font = _font_from_style("Treeview", "font", "TkDefaultFont")
        heading_font = _font_from_style("Treeview.Heading", "font", "TkHeadingFont")

        for idx, col in enumerate(cols):
            header = self.tree.heading(col, "text")
            max_width = heading_font.measure(str(header)) + 20
            for iid in self.tree.get_children(""):
                values = self.tree.item(iid, "values")
                if idx < len(values):
                    value_width = body_font.measure(str(values[idx])) + 20
                    if value_width > max_width:
                        max_width = value_width
            min_width = self._min_col_widths.get(col, 40)
            self.tree.column(
                col, width=max(max_width, min_width), minwidth=min_width, stretch=False
            )

    def on_size_unit_change(self):
        if not self._size_by_path:
            return
        for iid in self.tree.get_children(""):
            values = list(self.tree.item(iid, "values"))
            if len(values) < 6:
                continue
            path = values[5]
            size_bytes = self._size_by_path.get(path)
            if size_bytes is None:
                continue
            values[2] = fmt_size(size_bytes, self.size_unit_var.get())
            self.tree.item(iid, values=values)
        self._autosize_columns()

    def on_clear(self):
        self.pattern_var.set("")
        self.ext_var.set("")
        self.match_path_var.set(False)
        self._current_results = []
        self._size_by_path = {}
        self._clear_table()
        self._set_results_count(0)
        self._set_status("Ready")

    def on_add_root(self):
        root = filedialog.askdirectory(title="Select a root directory to index")
        if not root:
            return
        root = str(Path(root).resolve())
        depth = self._depth_from_control()
        if depth is None:
            return
        self._save_root_depth(root, depth)
        self._load_roots()
        self.roots_var.set(root)
        self._start_index_job(root, depth)

    def on_reindex_selected(self):
        root = self.roots_var.get().strip()
        if not root:
            messagebox.showinfo("Reindex", "No root selected.")
            return
        depth = self._depth_from_control()
        if depth is None:
            return
        self._save_root_depth(root, depth)
        self._start_index_job(root, depth)

    def on_remove_root(self):
        root = self.roots_var.get().strip()
        if not root:
            return
        if not messagebox.askyesno(
            "Remove root", f"Remove root and its indexed entries?\n\n{root}"
        ):
            return
        self.conn.execute("DELETE FROM files WHERE root = ?", (root,))
        self.conn.execute("DELETE FROM root_index_state WHERE root = ?", (root,))
        self.conn.execute("DELETE FROM index_runs WHERE root = ?", (root,))
        self.conn.execute("DELETE FROM roots WHERE root = ?", (root,))
        self.conn.commit()
        self._load_roots()
        self._current_results = []
        self._size_by_path = {}
        self._clear_table()
        self._set_results_count(0)
        self._set_status("Ready")

    def _start_index_job(self, root: str, max_depth: int | None = None):
        if self.worker and self.worker.is_alive():
            messagebox.showinfo("Busy", "A job is already running.")
            return
        if max_depth is None:
            max_depth = self._selected_root_depth(root)
        self.stop_flag.clear()
        depth_label = self._depth_to_label(max_depth)
        self._set_status(f"Indexing: {root} (depth: {depth_label})")
        self.worker = threading.Thread(
            target=self._index_root_worker, args=(root, int(max_depth)), daemon=True
        )
        self.worker.start()

    def _index_root_worker(self, root: str, max_depth: int):
        root_path = str(Path(root).resolve())
        t0 = time.time()
        run_id: int | None = None

        to_upsert = []
        seen = set()
        total_files = 0
        skipped = 0
        access_errors = 0
        logged_errors = 0
        scan_error_rows: list[tuple[int, str, str, str, str, float]] = []

        try:
            run_id = self.conn.execute(
                "INSERT INTO index_runs(root, started_at, status) VALUES(?, ?, 'running')",
                (root_path, t0),
            ).lastrowid
            self.conn.commit()

            stack: list[tuple[str, int]] = [(root_path, 0)]
            while stack and not self.stop_flag.is_set():
                curdir, cur_depth = stack.pop()
                try:
                    with os.scandir(curdir) as it:
                        for entry in it:
                            if self.stop_flag.is_set():
                                break
                            try:
                                if entry.is_dir(follow_symlinks=False):
                                    if max_depth < 0 or cur_depth < max_depth:
                                        stack.append((entry.path, cur_depth + 1))
                                    continue

                                # OneDrive placeholders may not always report as files
                                # with follow_symlinks=False; fall back to stat mode.
                                st = None
                                is_file = entry.is_file(follow_symlinks=False)
                                if not is_file:
                                    st = entry.stat(follow_symlinks=True)
                                    is_file = stat.S_ISREG(st.st_mode)
                                if not is_file:
                                    continue

                                if st is None:
                                    try:
                                        st = entry.stat(follow_symlinks=False)
                                    except (PermissionError, FileNotFoundError, OSError):
                                        st = entry.stat(follow_symlinks=True)

                                p = os.path.normpath(os.path.abspath(entry.path))
                                name = entry.name
                                ext = norm_ext_from_name(name)
                                seen.add(p)
                                to_upsert.append(
                                    (
                                        p,
                                        root_path,
                                        name,
                                        name.lower(),
                                        ext,
                                        int(st.st_size),
                                        float(st.st_ctime),
                                        float(st.st_mtime),
                                    )
                                )
                                total_files += 1
                                if len(to_upsert) >= 5000:
                                    self._flush_upsert(to_upsert)
                                    to_upsert.clear()
                                    self.msg_q.put(
                                        (
                                            "status",
                                            (
                                                f"Indexing: {root_path} "
                                                f"(depth: {self._depth_to_label(max_depth)}) "
                                                f"(files: {total_files:,})"
                                            ),
                                        )
                                    )
                            except (PermissionError, FileNotFoundError, OSError) as exc:
                                skipped += 1
                                access_errors += 1
                                if (
                                    run_id is not None
                                    and logged_errors < self._error_log_limit
                                ):
                                    scan_error_rows.append(
                                        (
                                            run_id,
                                            root_path,
                                            entry.path,
                                            type(exc).__name__,
                                            str(exc),
                                            time.time(),
                                        )
                                    )
                                    logged_errors += 1
                                    if len(scan_error_rows) >= 200:
                                        self._flush_scan_errors(scan_error_rows)
                                        scan_error_rows.clear()
                                continue
                except (PermissionError, FileNotFoundError, OSError) as exc:
                    skipped += 1
                    access_errors += 1
                    if run_id is not None and logged_errors < self._error_log_limit:
                        scan_error_rows.append(
                            (
                                run_id,
                                root_path,
                                curdir,
                                type(exc).__name__,
                                str(exc),
                                time.time(),
                            )
                        )
                        logged_errors += 1
                        if len(scan_error_rows) >= 200:
                            self._flush_scan_errors(scan_error_rows)
                            scan_error_rows.clear()
                    continue

            if to_upsert and not self.stop_flag.is_set():
                self._flush_upsert(to_upsert)
            if scan_error_rows:
                self._flush_scan_errors(scan_error_rows)

            dt = time.time() - t0
            count = self.conn.execute(
                "SELECT COUNT(*) FROM files WHERE root = ?", (root_path,)
            ).fetchone()[0]

            if not self.stop_flag.is_set():
                # Clean stale entries for this root.
                cur = self.conn.execute(
                    "SELECT path FROM files WHERE root = ?", (root_path,)
                )
                stale = [row[0] for row in cur.fetchall() if row[0] not in seen]
                if stale:
                    self.conn.executemany(
                        "DELETE FROM files WHERE path = ?", [(p,) for p in stale]
                    )
                    self.conn.commit()
                    count = self.conn.execute(
                        "SELECT COUNT(*) FROM files WHERE root = ?", (root_path,)
                    ).fetchone()[0]

                self.conn.execute(
                    """
                    INSERT INTO root_index_state(root, last_indexed_at, file_count, skipped, access_errors, duration_sec)
                    VALUES(?, ?, ?, ?, ?, ?)
                    ON CONFLICT(root) DO UPDATE SET
                        last_indexed_at=excluded.last_indexed_at,
                        file_count=excluded.file_count,
                        skipped=excluded.skipped,
                        access_errors=excluded.access_errors,
                        duration_sec=excluded.duration_sec
                    """,
                    (root_path, time.time(), count, skipped, access_errors, dt),
                )
                if run_id is not None:
                    self.conn.execute(
                        """
                        UPDATE index_runs
                        SET finished_at = ?, status = ?, total_files = ?, skipped = ?, access_errors = ?, notes = ?
                        WHERE id = ?
                        """,
                        (
                            time.time(),
                            "completed",
                            total_files,
                            skipped,
                            access_errors,
                            f"logged_errors={logged_errors} limit={self._error_log_limit}",
                            run_id,
                        ),
                    )
                self.conn.commit()
                self.msg_q.put(("roots_reload", None))
                self.msg_q.put(
                    (
                        "status",
                        (
                            f"Indexed {count:,} files in {dt:.2f}s "
                            f"(skipped: {skipped:,}, access errors: {access_errors:,}, "
                            f"logged: {logged_errors:,})"
                        ),
                    )
                )
                self.msg_q.put(("db_summary", None))
            else:
                if run_id is not None:
                    self.conn.execute(
                        """
                        UPDATE index_runs
                        SET finished_at = ?, status = ?, total_files = ?, skipped = ?, access_errors = ?, notes = ?
                        WHERE id = ?
                        """,
                        (
                            time.time(),
                            "cancelled",
                            total_files,
                            skipped,
                            access_errors,
                            "Indexing cancelled by user/close.",
                            run_id,
                        ),
                    )
                    self.conn.commit()
                self.msg_q.put(
                    (
                        "status",
                        f"Index cancelled after {dt:.2f}s (files: {total_files:,}, access errors: {access_errors:,})",
                    )
                )
        except Exception as exc:
            try:
                if scan_error_rows:
                    self._flush_scan_errors(scan_error_rows)
                if run_id is not None:
                    self.conn.execute(
                        """
                        UPDATE index_runs
                        SET finished_at = ?, status = ?, total_files = ?, skipped = ?, access_errors = ?, notes = ?
                        WHERE id = ?
                        """,
                        (
                            time.time(),
                            "error",
                            total_files,
                            skipped,
                            access_errors,
                            str(exc),
                            run_id,
                        ),
                    )
                    self.conn.commit()
            except Exception:
                pass
            self.msg_q.put(("error", f"Index failed: {exc}"))

    def _flush_upsert(self, rows):
        self.conn.executemany(
            """
            INSERT INTO files(path, root, name, name_lc, ext, size, ctime, mtime)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(path) DO UPDATE SET
                root=excluded.root,
                name=excluded.name,
                name_lc=excluded.name_lc,
                ext=excluded.ext,
                size=excluded.size,
                ctime=excluded.ctime,
                mtime=excluded.mtime
            """,
            rows,
        )
        self.conn.commit()

    def on_search(self):
        if self.worker and self.worker.is_alive():
            messagebox.showinfo(
                "Busy", "Index job is running. Try again after it finishes."
            )
            return

        pattern = self.pattern_var.get()
        ext_field = self.ext_var.get()
        match_path = bool(self.match_path_var.get())
        selected_roots = self._selected_search_roots()

        ext_set = build_ext_set(ext_field)
        rx = compile_name_pattern(pattern)

        self._current_results = []
        self._size_by_path = {}
        self._clear_table()
        self._set_results_count(0)
        self._set_status("Ready")
        if not selected_roots:
            return

        self.worker = threading.Thread(
            target=self._search_worker,
            args=(selected_roots, ext_set, rx, match_path, pattern),
            daemon=True,
        )
        self.worker.start()

    def _search_worker(
        self,
        selected_roots: list[str],
        ext_set: set[str] | None,
        rx: re.Pattern | None,
        match_path: bool,
        raw_pattern: str,
    ):
        t0 = time.time()

        where = []
        params = {}

        root_placeholders = []
        for i, root in enumerate(selected_roots):
            k = f"root{i}"
            root_placeholders.append(f":{k}")
            params[k] = root
        where.append(f"root IN ({', '.join(root_placeholders)})")

        if ext_set is not None:
            # ext stored without dot; match any in set
            placeholders = []
            for i, e in enumerate(sorted(ext_set)):
                k = f"e{i}"
                placeholders.append(f":{k}")
                params[k] = e
            if placeholders:
                where.append(f"ext IN ({', '.join(placeholders)})")
            else:
                where.append("ext = ''")

        # Coarse filter using LIKE if pattern is simple enough; otherwise pull more.
        # We do final filtering with regex in Python anyway.
        coarse_like = None
        p = (raw_pattern or "").strip().lower()
        if p:
            # Convert '*' to '%' and '?' to '_' for a SQL coarse filter.
            coarse = []
            for ch in p:
                if ch == "*":
                    coarse.append("%")
                elif ch == "?":
                    coarse.append("_")
                else:
                    # Escape SQL LIKE wildcards
                    if ch in ["%", "_"]:
                        coarse.append("\\" + ch)
                    else:
                        coarse.append(ch)
            coarse_like = "%" + "".join(coarse) + "%"
            if match_path:
                where.append("path LIKE :like ESCAPE '\\'")
            else:
                where.append("name_lc LIKE :like ESCAPE '\\'")
            params["like"] = coarse_like

        sql = "SELECT root, name, ext, size, ctime, mtime, path FROM files"
        if where:
            sql += " WHERE " + " AND ".join(where)
        sql += " ORDER BY mtime DESC LIMIT 5000"

        rows = []
        try:
            cur = self.conn.execute(sql, params)
            rows = cur.fetchall()
        except Exception as e:
            self.msg_q.put(("error", f"Search failed: {e}"))
            return

        # Final filter with regex wildcard over name or full path
        out = []
        for root, name, ext, size, ctime, mtime, path in rows:
            target = path if match_path else basename_without_ext(name)
            if rx is not None and not rx.search(target):
                continue
            out.append((root, name, ext, size, ctime, mtime, path))

        dt = time.time() - t0
        self.msg_q.put(("results", out))
        self.msg_q.put(
            ("status", f"Results: {len(out):,} (scanned: {len(rows):,}) in {dt:.2f}s")
        )

    def _poll_msgs(self):
        try:
            while True:
                typ, payload = self.msg_q.get_nowait()
                if typ == "status":
                    self._set_status(payload)
                elif typ == "roots_reload":
                    self._load_roots()
                elif typ == "error":
                    self._set_status(payload)
                    messagebox.showerror("Error", payload)
                elif typ == "results":
                    self._current_results = list(payload)
                    self._apply_root_filter_to_current_results()
                elif typ == "db_summary":
                    self._set_status("Ready")
        except queue.Empty:
            pass
        self.after(100, self._poll_msgs)

    def _populate_results(self, rows, keep_current: bool = True):
        if keep_current:
            self._current_results = list(rows)
        self._size_by_path = {path: int(size) for (_, _, _, size, _, _, path) in rows}
        self._clear_table()
        for _, name, ext, size, ctime, mtime, path in rows:
            self.tree.insert(
                "",
                "end",
                values=(
                    name,
                    (ext or ""),
                    fmt_size(size, self.size_unit_var.get()),
                    fmt_ts(ctime),
                    fmt_ts(mtime),
                    path,
                ),
            )
        self._autosize_columns()

    def _selected_path(self) -> str | None:
        sel = self.tree.selection()
        if not sel:
            return None
        vals = self.tree.item(sel[0], "values")
        if not vals:
            return None
        # path is last column
        return vals[-1]

    def on_open_file(self):
        p = self._selected_path()
        if not p:
            return
        open_file(p)

    def on_open_folder(self):
        p = self._selected_path()
        if not p:
            return
        open_containing_folder(p)

    def on_close(self):
        self.stop_flag.set()
        if self.worker and self.worker.is_alive():
            self.worker.join(timeout=2.0)
        try:
            self.conn.execute("PRAGMA optimize;")
            self.conn.execute("PRAGMA wal_checkpoint(PASSIVE);")
            freelist = self.conn.execute("PRAGMA freelist_count;").fetchone()[0]
            page_count = self.conn.execute("PRAGMA page_count;").fetchone()[0]
            # Vacuum only when there is meaningful free space.
            if page_count > 0 and freelist > 5000 and (freelist / page_count) > 0.2:
                self.conn.execute("VACUUM;")
            self.conn.commit()
        except Exception:
            pass
        try:
            self.conn.close()
        except Exception:
            pass
        self.destroy()


if __name__ == "__main__":
    app = App()
    app.mainloop()
