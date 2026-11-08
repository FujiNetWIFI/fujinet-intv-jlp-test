#!/usr/bin/env python3
"""Fail the build if the ROM can't coexist with JLP and the FujiNet mailbox.

    check_map.py [--nofuji] build/jlpfn.cfg build/jlpfn.sym

Checks:
  * no ROM segment in $7000-$7FFF (the EXEC executes $7000 at boot),
    $8000-$9FFF (JLP's window, mailbox included), $E000-$EFFF (ECS ROM),
    or the GRAM aliases $B800-$BFFF and $F800-$FFFF;
  * no [memattr] section: on a JLP cart, RAM declared under $8000-$9FFF
    makes the cart refuse the game (CONFIG says JLP CONFLICT);
  * [vars] has jlp = 3, jlpflash = 6 and fujinet = 1 (absent with --nofuji);
  * every IntyBASIC 16-bit variable (_SYSTEM2) ends below the mailbox.
"""
import re
import sys

FORBIDDEN = [
    (0x7000, 0x7FFF, "$7000 boot trap"),
    (0x8000, 0x9FFF, "JLP window"),
    (0xB800, 0xBFFF, "GRAM alias"),
    (0xE000, 0xEFFF, "ECS ROM"),
    (0xF800, 0xFFFF, "GRAM alias"),
]
MAILBOX = 0x9C00


def parse_cfg(path):
    sections, current = {}, None
    for raw in open(path):
        line = raw.split(";")[0].strip()
        if not line:
            continue
        head = re.fullmatch(r"\[(\w+)\]", line)
        if head:
            current = head.group(1).lower()
            sections.setdefault(current, [])
        elif current:
            sections[current].append(line)
    return sections


def main():
    args = sys.argv[1:]
    nofuji = "--nofuji" in args
    args = [a for a in args if a != "--nofuji"]
    if len(args) != 2:
        sys.exit(__doc__)
    cfg_path, sym_path = args
    errors = []
    sections = parse_cfg(cfg_path)

    for line in sections.get("mapping", []):
        found = re.fullmatch(r"\$([0-9A-Fa-f]+)\s*-\s*\$([0-9A-Fa-f]+)\s*=\s*\$([0-9A-Fa-f]+).*", line)
        if not found:
            errors.append(f"unparsed [mapping] line: {line}")
            continue
        first, last, addr = (int(group, 16) for group in found.groups())
        end = addr + (last - first)
        for low, high, why in FORBIDDEN:
            if addr <= high and end >= low:
                errors.append(f"segment ${addr:04X}-${end:04X} overlaps ${low:04X}-${high:04X} ({why})")

    if sections.get("memattr"):
        errors.append("[memattr] present: a JLP cart refuses RAM declared under $8000-$9FFF")

    found_vars = {}
    for line in sections.get("vars", []):
        key, _, value = line.partition("=")
        found_vars[key.strip().lower()] = value.strip()
    want = {"jlp": "3", "jlpflash": "6"}
    if not nofuji:
        want["fujinet"] = "1"
    for key, value in want.items():
        if found_vars.get(key) != value:
            errors.append(f"[vars] {key} = {found_vars.get(key)}, want {value}")
    if nofuji and "fujinet" in found_vars:
        errors.append("[vars] fujinet present in the --nofuji build")

    system2 = None
    for line in open(sym_path):
        parts = line.split()
        if len(parts) == 2 and parts[1] == "_SYSTEM2":
            system2 = int(parts[0], 16)
    if system2 is None:
        errors.append("_SYSTEM2 not in the symbol file")
    elif system2 > MAILBOX:
        errors.append(f"16-bit variables end at ${system2:04X}, inside the mailbox (${MAILBOX:04X})")

    if errors:
        for err in errors:
            print(f"check_map: {cfg_path}: {err}", file=sys.stderr)
        sys.exit(1)
    print(f"check_map: {cfg_path}: ok (variables end at ${system2:04X})")


if __name__ == "__main__":
    main()
