#!/usr/bin/env python3
"""Repository-level safety checks for Project Zomboid Build 42 mods."""

from __future__ import annotations

from collections import Counter
from pathlib import Path
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
IGNORED_PARTS = {".git", ".github", "build", "dist", "release", "releases"}
TEXT_SUFFIXES = {".ini", ".json", ".lua", ".md", ".txt", ".vdf", ".xml", ".yaml", ".yml"}

errors: list[str] = []
warnings: list[str] = []


def relative(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def ignored(path: Path) -> bool:
    return bool(set(path.relative_to(ROOT).parts) & IGNORED_PARTS)


def error(message: str) -> None:
    errors.append(message)
    print(f"::error::{message}")


def warning(message: str) -> None:
    warnings.append(message)
    print(f"::warning::{message}")


files = [path for path in ROOT.rglob("*") if path.is_file() and not ignored(path)]
lua_files = [path for path in files if path.suffix.lower() == ".lua"
             and "tests" not in path.relative_to(ROOT).parts]
mod_info_files = [path for path in files if path.name.lower() == "mod.info"]
sandbox_files = [path for path in files if path.name.lower() == "sandbox-options.txt"]

if not lua_files:
    error("No Lua files were found.")
if not mod_info_files:
    error("No mod.info file was found.")

mod_ids: set[str] = set()
for path in mod_info_files:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    fields = dict(
        (key.lower(), value.strip())
        for key, value in re.findall(r"(?m)^\s*([A-Za-z][A-Za-z0-9]*)\s*=\s*(.*?)\s*$", text)
    )
    for required in ("name", "id"):
        if not fields.get(required):
            error(f"{relative(path)} is missing {required}=.")
    if fields.get("id"):
        mod_ids.add(fields["id"])
        if not re.fullmatch(r"[A-Za-z0-9_.-]+", fields["id"]):
            error(f"{relative(path)} has an invalid mod ID: {fields['id']!r}.")
    if "/42/" in f"/{relative(path).lower()}/" and not fields.get("versionmin", "").startswith("42"):
        warning(f"{relative(path)} is a Build 42 descriptor without versionMin=42.x.")

if len(mod_ids) > 1:
    error(f"Conflicting mod IDs found: {', '.join(sorted(mod_ids))}.")

for path in lua_files:
    normalized = f"/{relative(path).lower()}"
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    if "/media/lua/" not in normalized:
        warning(f"{relative(path)} is outside a media/lua directory.")
    if "sendClientCommand" in text and not any(part in normalized for part in ("/client/", "/shared/")):
        warning(f"{relative(path)} sends a client command from a non-client path.")
    if "sendServerCommand" in text and not any(part in normalized for part in ("/server/", "/shared/")):
        warning(f"{relative(path)} sends a server command from a non-server path.")

for path in sandbox_files:
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    if not re.search(r"(?m)^\s*VERSION\s*=\s*\d+\s*,?\s*$", text):
        error(f"{relative(path)} is missing a valid VERSION declaration.")
    names = re.findall(r"\boption\s+([A-Za-z0-9_.]+)\s*\{", text)
    if not names:
        error(f"{relative(path)} contains no Sandbox options.")
    for name, count in sorted(Counter(names).items()):
        if count > 1:
            error(f"{relative(path)} defines Sandbox option {name!r} {count} times.")
    prefixes = {name.split(".", 1)[0] for name in names if "." in name}
    if mod_ids and prefixes and prefixes.isdisjoint(mod_ids):
        warning(
            f"{relative(path)} uses Sandbox prefix(es) {', '.join(sorted(prefixes))}, "
            f"which do not match mod ID(s) {', '.join(sorted(mod_ids))}."
        )

secret_patterns = {
    "Discord webhook": re.compile(r"https://(?:canary\.|ptb\.)?discord(?:app)?\.com/api/webhooks/", re.I),
    "private key": re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "assigned credential": re.compile(
        r"(?im)^\s*(?:rcon_?password|password|api_?key|secret|token)\s*[=:]\s*[^\s\"']{8,}\s*$"
    ),
}
for path in files:
    if path.suffix.lower() not in TEXT_SUFFIXES:
        continue
    text = path.read_text(encoding="utf-8-sig", errors="replace")
    for label, pattern in secret_patterns.items():
        if pattern.search(text):
            error(f"Possible {label} found in {relative(path)}.")

print()
print("Project Zomboid mod audit summary")
print(f"Files inspected: {len(files)}")
print(f"Lua files: {len(lua_files)}")
print(f"mod.info files: {len(mod_info_files)}")
print(f"Sandbox files: {len(sandbox_files)}")
print(f"Errors: {len(errors)}")
print(f"Warnings: {len(warnings)}")

if errors:
    sys.exit(1)
