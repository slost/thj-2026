#!/usr/bin/env python3
"""Scan a hot-swap folder and write manifest.json (and an optional status page).

Usage:
  python tools/make_manifest.py assets/
  python tools/make_manifest.py assets/ -o build/web/assets/manifest.json \
         --status build/web/assets/status.html
  python tools/make_manifest.py assets/ --strict     # exit 1 on any warning

Rules:
  * ID = file name without extension, lowercased.
    sfx_jump.ogg -> "sfx_jump"
    sfx.scissors.use.ogg -> "sfx.scissors.use" (matches a Lost AssetEntry key)
  * Valid ID: a letter, then a-z, 0-9, or underscore, with optional ".segment" pieces.
  * Sub-folders are scanned. "file" keeps the relative path (case preserved,
    because GitHub Pages URLs are case-sensitive).
  * Duplicate IDs (sfx_jump.ogg + sfx_jump.wav): the preferred extension wins.
  * expected_ids.txt (one ID per line, # comments) drives the status page.
  * Ids that start with bgm_ or bgm. are marked "loop": true.
  * .tres and .res are animations. The file must be an Animation resource with no
    embedded or referenced script, or it is skipped.

Python 3.8+, standard library only.
"""
from __future__ import annotations

import argparse
import hashlib
import html
import json
import re
import sys
import time
from pathlib import Path

TEXTURE_EXTS = [".png", ".webp", ".jpg", ".jpeg"]
AUDIO_EXTS = [".ogg", ".mp3", ".wav"]
ANIMATION_EXTS = [".tres", ".res"]
PREFERENCE = {ext: index for index, ext in enumerate(AUDIO_EXTS + TEXTURE_EXTS + ANIMATION_EXTS)}
KNOWN_PREFIXES = {
    "tex_": "texture",
    "spr_": "texture",
    "ui_": "texture",
    "bg_": "texture",
    "sfx_": "audio",
    "bgm_": "audio",
    "vo_": "audio",
    "amb_": "audio",
    "anim_": "animation",
    "tex.": "texture",
    "spr.": "texture",
    "ui.": "texture",
    "bg.": "texture",
    "sfx.": "audio",
    "bgm.": "audio",
    "vo.": "audio",
    "amb.": "audio",
    "anim.": "animation",
}
SCRIPT_TYPES = ("Script", "GDScript", "CSharpScript", "VisualScript", "ScriptExtension", "NativeScript")
IGNORED_NAMES = {"manifest.json", "expected_ids.txt", "status.html", "readme.md", ".gdignore"}
ID_RE = re.compile(r"^[a-z][a-z0-9_]*(?:\.[a-z][a-z0-9_]*)*$")
SEGMENT_RE = re.compile(r"^[A-Za-z0-9_\-.]+$")

warnings: list[str] = []


def warn(msg: str) -> None:
    warnings.append(msg)
    print(f"WARNING: {msg}", file=sys.stderr)


def asset_type(ext: str) -> str | None:
    if ext in TEXTURE_EXTS:
        return "texture"
    if ext in AUDIO_EXTS:
        return "audio"
    if ext in ANIMATION_EXTS:
        return "animation"
    return None


def _prefixed_string(data: bytes, text: str) -> bool:
    raw = text.encode("utf-8")
    needle = len(raw).to_bytes(4, "little") + raw
    return needle in data


def animation_problem(path: Path) -> str | None:
    """Return a skip reason when a .tres/.res is not a script-free Animation."""
    data = path.read_bytes()
    ext = path.suffix.lower()
    if ext == ".tres":
        text = data.decode("utf-8", errors="replace").lstrip("\ufeff").lstrip()
        if not text.startswith("[gd_resource"):
            return "not a Godot text resource"
        header = text.split("]", 1)[0]
        if 'type="Animation"' not in header and "type='Animation'" not in header:
            return "not an Animation resource (save the Animation, not the scene or library)"
        for match in re.finditer(r'type\s*=\s*["\']([A-Za-z0-9_]+)["\']', text):
            res_type = match.group(1)
            if res_type == "Script" or res_type.endswith("Script"):
                return f"references a Script ({res_type})"
        for match in re.finditer(r'path\s*=\s*["\']([^"\']+)["\']', text):
            resource_path = match.group(1).lower()
            if resource_path.endswith((".gd", ".gdc", ".cs", ".csx")):
                return f"references a script path ({match.group(1)})"
        if "script_class" in header or "script/source" in text or re.search(r"(?m)^\s*script\s*=", text):
            return "assigns or embeds a script"
        return None
    if data[:4] == b"RSCC":
        return "compressed .res is not supported; save the Animation as .tres"
    if data[:4] != b"RSRC" or len(data) < 28:
        return "not a Godot Animation resource"
    length = int.from_bytes(data[24:28], "little")
    if length <= 0 or 28 + length > len(data):
        return "could not read the resource type"
    root = data[28 : 28 + length].decode("utf-8", errors="replace")
    if root != "Animation":
        return f"resource type is {root}, not Animation"
    for script_type in SCRIPT_TYPES:
        if _prefixed_string(data, script_type):
            return f"references a Script ({script_type})"
    if b".gd" in data or b".gdc" in data or b".cs" in data or b"script/source" in data:
        return "references a script path"
    return None


def matching_prefix(asset_id: str) -> str | None:
    matches = [prefix for prefix in KNOWN_PREFIXES if asset_id.startswith(prefix)]
    if not matches:
        return None
    return max(matches, key=len)


def short_sha1(path: Path) -> str:
    digest = hashlib.sha1()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()[:10]


def should_loop(asset_id: str) -> bool:
    return asset_id.startswith("bgm_") or asset_id.startswith("bgm.")


def scan(folder: Path) -> dict:
    warnings.clear()
    candidates: dict[str, list[tuple[Path, str]]] = {}
    for path in sorted(folder.rglob("*")):
        rel = path.relative_to(folder)
        if any(part.startswith(".") for part in rel.parts):
            continue
        if path.is_dir() or path.name.lower() in IGNORED_NAMES or path.suffix.lower() == ".import":
            continue
        ext = path.suffix.lower()
        kind = asset_type(ext)
        if kind is None:
            warn(
                f"{rel.as_posix()}: unsupported file type '{ext or '(none)'}' - skipped "
                f"(use {', '.join(AUDIO_EXTS + TEXTURE_EXTS + ANIMATION_EXTS)})"
            )
            continue
        if path.stat().st_size == 0:
            warn(f"{rel.as_posix()}: file is empty (0 bytes) - skipped")
            continue
        if kind == "animation":
            problem = animation_problem(path)
            if problem:
                warn(f"{rel.as_posix()}: {problem} - skipped")
                continue
        skipped = False
        for seg in rel.parts[:-1]:
            if not SEGMENT_RE.match(seg):
                warn(f"{rel.as_posix()}: folder name '{seg}' has spaces or special characters - skipped")
                skipped = True
                break
        if skipped:
            continue
        asset_id = path.stem.lower()
        if not ID_RE.match(asset_id):
            warn(
                f"{rel.as_posix()}: invalid name '{path.stem}' - use a-z, 0-9, underscore, "
                f"and optional dots, and start with a letter (for example sfx_jump{ext}) - skipped"
            )
            continue
        if path.stem != asset_id:
            warn(
                f"{rel.as_posix()}: name has uppercase letters; ID becomes '{asset_id}' "
                "(please rename the file to lowercase)"
            )
        prefix = matching_prefix(asset_id)
        if prefix is None:
            warn(
                f"{rel.as_posix()}: '{asset_id}' has no known prefix "
                f"({', '.join(sorted(KNOWN_PREFIXES))})"
            )
        elif KNOWN_PREFIXES[prefix] != kind:
            warn(f"{rel.as_posix()}: prefix suggests a different type than '{kind}'")
        candidates.setdefault(asset_id, []).append((path, kind))

    assets: dict[str, dict] = {}
    for asset_id in sorted(candidates):
        files = sorted(
            candidates[asset_id],
            key=lambda item: (PREFERENCE.get(item[0].suffix.lower(), 99), str(item[0])),
        )
        path, kind = files[0]
        if len(files) > 1:
            others = ", ".join(other.relative_to(folder).as_posix() for other, _kind in files[1:])
            warn(
                f"duplicate ID '{asset_id}': using {path.relative_to(folder).as_posix()}, ignoring {others}"
            )
        entry = {
            "file": path.relative_to(folder).as_posix(),
            "type": kind,
            "hash": short_sha1(path),
            "size": path.stat().st_size,
        }
        if should_loop(asset_id):
            entry["loop"] = True
        assets[asset_id] = entry
    return {"version": int(time.time()), "assets": assets}


def read_expected(path: Path) -> list[str]:
    ids: list[str] = []
    if not path.is_file():
        return ids
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.split("#", 1)[0].strip().lower()
        if not line:
            continue
        if not ID_RE.match(line):
            warn(f"{path.name}: invalid expected ID '{line}'")
        if line not in ids:
            ids.append(line)
    return ids


def human_size(size: int) -> str:
    value = float(size)
    for unit in ("B", "KB", "MB"):
        if value < 1024 or unit == "MB":
            return f"{value:.0f} {unit}" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return str(size)


def write_status(path: Path, manifest: dict, expected: list[str], warns: list[str]) -> None:
    assets = manifest["assets"]
    rows = []
    for asset_id in expected:
        if asset_id in assets:
            entry = assets[asset_id]
            rows.append(("ok", asset_id, entry["file"], human_size(entry["size"])))
        else:
            rows.append(("missing", asset_id, "", ""))
    for asset_id in assets:
        if asset_id not in expected:
            entry = assets[asset_id]
            rows.append(("extra", asset_id, entry["file"], human_size(entry["size"])))
    done = sum(1 for row in rows if row[0] == "ok")
    label = {
        "ok": "ready / อัปแล้ว",
        "missing": "still placeholder / ยังเป็น placeholder",
        "extra": "not in the list / ไม่อยู่ในรายการ",
    }
    body_rows = "\n".join(
        f'<tr class="{state}"><td>{html.escape(label[state])}</td>'
        f"<td><code>{html.escape(asset_id)}</code></td>"
        f"<td>{html.escape(filename)}</td><td>{size}</td></tr>"
        for state, asset_id, filename, size in rows
    )
    warn_html = "".join(f"<li>{html.escape(item)}</li>" for item in warns) or "<li>None / ไม่มี</li>"
    built = time.strftime("%Y-%m-%d %H:%M:%S %Z", time.localtime(manifest["version"]))
    pct = int(100 * done / len(expected)) if expected else 100
    path.write_text(
        f"""<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Asset status / สถานะแอสเซ็ต</title>
<style>
 body{{font-family:system-ui,sans-serif;max-width:900px;margin:2em auto;padding:0 1em;background:#1b1b22;color:#eee}}
 table{{border-collapse:collapse;width:100%}} td,th{{padding:.4em .6em;border-bottom:1px solid #333;text-align:left}}
 tr.ok td:first-child{{color:#6f6}} tr.missing td:first-child{{color:#fc6}} tr.extra td:first-child{{color:#8cf}}
 .bar{{background:#333;border-radius:6px;overflow:hidden;height:14px}} .bar>div{{background:#6c6;height:100%;width:{pct}%}}
 code{{color:#f9c}} a{{color:#8cf}}
</style></head><body>
<h1>Asset status / สถานะแอสเซ็ต</h1>
<p>Ready / เสร็จแล้ว <b>{done}/{len(expected)}</b>
· updated / อัปเดต {html.escape(built)} ·
<a href="manifest.json">manifest.json</a> · <a href="../">open the game / เปิดเกม</a></p>
<p>Files named <code>bgm_*</code> or <code>bgm.*</code> loop. / ไฟล์ที่ขึ้นต้นด้วย bgm_ หรือ bgm. จะเล่นวน</p>
<p>Files named <code>anim_*</code> or <code>anim.*</code> (<code>.tres</code> / <code>.res</code>) replace AnimationPlayer clips. / ไฟล์ anim_ หรือ anim. เป็นแอนิเมชันที่จะไปแทนคลิปใน AnimationPlayer</p>
<div class="bar"><div></div></div>
<table><thead><tr><th>Status / สถานะ</th><th>ID</th><th>File / ไฟล์</th><th>Size / ขนาด</th></tr></thead>
<tbody>
{body_rows}
</tbody></table>
<h2>Warnings / คำเตือน</h2><ul>{warn_html}</ul>
</body></html>
""",
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("folder", type=Path, help="asset folder to scan (for example assets/)")
    parser.add_argument("-o", "--output", type=Path, help="manifest path (default: <folder>/manifest.json)")
    parser.add_argument("--expected", type=Path, help="expected IDs file (default: <folder>/expected_ids.txt)")
    parser.add_argument("--status", type=Path, help="also write an HTML status page here")
    parser.add_argument("--strict", action="store_true", help="exit with code 1 if there were warnings")
    args = parser.parse_args()

    folder: Path = args.folder
    if not folder.is_dir():
        print(f"ERROR: {folder} is not a folder", file=sys.stderr)
        return 2
    manifest = scan(folder)
    out = args.output or folder / "manifest.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {out} ({len(manifest['assets'])} assets)")

    expected = read_expected(args.expected or folder / "expected_ids.txt")
    missing = [asset_id for asset_id in expected if asset_id not in manifest["assets"]]
    if expected:
        print(
            f"Expected: {len(expected) - len(missing)}/{len(expected)} present"
            + (f"; still placeholder: {', '.join(missing)}" if missing else "")
        )
    if args.status:
        args.status.parent.mkdir(parents=True, exist_ok=True)
        write_status(args.status, manifest, expected, warnings)
        print(f"Wrote {args.status}")
    return 1 if (args.strict and warnings) else 0


if __name__ == "__main__":
    sys.exit(main())
