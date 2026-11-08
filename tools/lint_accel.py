#!/usr/bin/env python3
"""Fail if compiled IntyBASIC code touches the JLP accelerators unexpectedly.

    lint_accel.py build/jlpfn.asm

With --jlp, IntyBASIC turns multiply, divide and MOD into accesses to
$9F80-$9F8F, and PEEK/POKE there compile to the same. The compiler writes
those addresses in decimal (40832-40959); this ROM's deliberate
accelerator code is ASM in asmlib.bas and writes them as $9Fxx. So any
decimal accelerator address outside jlp_basic_ops means the test harness
itself depends on the hardware it is testing: an RP2040 cart with stale
accelerator results would then corrupt the harness instead of failing a
test.
"""
import re
import sys

ALLOWED = {"label_JLP_BASIC_OPS"}
# Memory operands only: "#40832" is an immediate (an address being
# computed), not an access.
ADDR = re.compile(r"(?<![#\w])(4083[2-9]|408[4-9]\d|409[0-5]\d)\b")
PROC = re.compile(r"^(label_\w+):\s+PROC\b")


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    current, errors = None, []
    for number, raw in enumerate(open(sys.argv[1]), 1):
        code = raw.split(";")[0]
        found = PROC.match(code)
        if found:
            current = found.group(1)
            continue
        if re.search(r"\bENDP\b", code):
            current = None
            continue
        if ADDR.search(code) and current not in ALLOWED:
            errors.append(f"{sys.argv[1]}:{number}: {code.strip()}  (in {current or 'top level'})")
    if errors:
        print("lint_accel: compiled code uses the JLP accelerators outside jlp_basic_ops:",
              file=sys.stderr)
        for err in errors:
            print("  " + err, file=sys.stderr)
        sys.exit(1)
    print("lint_accel: ok")


if __name__ == "__main__":
    main()
