#!/usr/bin/env python3
"""Turn docs/JLP-and-FujiNet.md into its fujinet-firmware wiki twin.

    mkwiki.py docs/JLP-and-FujiNet.md > JLP-and-FujiNet-on-the-Intellivision.md

Relative links become links into this repository on GitHub; the title moves
to the wiki page name, so the H1 is dropped.
"""
import re
import sys

REPO = "https://github.com/FujiNetWIFI/fujinet-intv-jlp-test"
RAW = "https://raw.githubusercontent.com/FujiNetWIFI/fujinet-intv-jlp-test/main"


def fix(match):
    bang, text, target = match.group(1), match.group(2), match.group(3)
    if re.match(r"[a-z]+:|#", target):
        return match.group(0)
    path = re.sub(r"^(\./)?", "", target)
    if path.startswith("../"):
        path = path[3:]
    else:
        path = "docs/" + path
    if bang:
        url = f"{RAW}/{path}"
    elif path == "README.md":
        url = REPO
    else:
        url = f"{REPO}/blob/main/{path}"
    return f"{bang}[{text}]({url})"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    text = open(sys.argv[1]).read()
    text = re.sub(r"\A# .*\n\n", "", text)
    text = re.sub(r"(!?)\[([^\]]*)\]\(([^)]+)\)", fix, text)
    note = (f"*This page mirrors [`docs/JLP-and-FujiNet.md`]({REPO}/blob/main/docs/JLP-and-FujiNet.md) "
            f"in [fujinet-intv-jlp-test]({REPO}), which also has the test ROM and a printable "
            f"booklet.*\n\n")
    sys.stdout.write(note + text)


if __name__ == "__main__":
    main()
