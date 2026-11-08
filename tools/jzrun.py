#!/usr/bin/env python3
"""Run the test ROM headless in jzIntv and print (or check) its results.

    jzrun.py [options] build/jlpfn.rom

Starts jzIntv with its debugger on a pipe, runs the ROM until it sets
#run_done, then reads #tres/#tval/#tval2 by address from the .sym file
and prints one line per test, plus the screen. Rate control stays on:
FujiNet timeouts count emulated time, so running faster than real time
would make slow network replies look like failures.

Options:
  --jzintv PATH        jzIntv binary (default: $JZINTV or jzintv)
  --rom-dir DIR        directory with exec.bin and grom.bin
  --fujinet HOST:PORT  connect the FujiNet mailbox peripheral (BoIP)
  --save FILE          --jlp-savegame file (JLP flash persists in it)
  --sym FILE           symbol file of the ROM whose results to read
                       (default: the ROM's own .sym; pass the test ROM's when
                       booting it through tools/pushboot.bas)
  --bootdir DIR        --fujinet-bootdir: where pushed carts and their JLP
                       saves are staged
  --expect SPEC        comma list like A1=PASS,C1=SKIP; exit 1 on mismatch.
                       '*' as the test name sets a default for the rest.
  --timeout SECONDS    give up after this much wall time (default 300)
  --keys LIST          after the run, press these controller bytes (hex,
                       comma-separated; 21 = keypad 3, 41 = 2, 88 = CLEAR)
                       and print the screen after each; "wN" waits N steps;
                       "s" saves a screenshot (jzIntv's shotNNNN.gif, in the
                       current directory)
"""
import argparse
import os
import re
import select
import subprocess
import sys
import time

RESULT = ["....", "PASS", "FAIL", "SKIP", "INFO"]


def read_names(ui_path):
    text = open(ui_path).read()
    block = text.split("tname:", 1)[1].split("resname:", 1)[0]
    return [name for name in re.findall(r'"([^"]{10})"', block)]


def read_syms(sym_path):
    syms = {}
    for line in open(sym_path):
        parts = line.split()
        if len(parts) == 2 and re.fullmatch(r"[0-9A-Fa-f]+", parts[0]):
            syms[parts[1]] = int(parts[0], 16)
    return syms


class Debugger:
    def __init__(self, argv):
        self.proc = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=subprocess.STDOUT, bufsize=0)
        self.buf = b""
        self.log = []
        self.wait_prompt(60)

    def wait_prompt(self, seconds):
        deadline = time.time() + seconds
        while True:
            if re.search(rb"(^|\n)> $", self.buf):
                out, self.buf = self.buf, b""
                text = out.decode("latin-1")
                self.log.append(text)
                return text
            left = deadline - time.time()
            if left <= 0:
                raise TimeoutError("jzIntv debugger did not answer")
            ready, _, _ = select.select([self.proc.stdout], [], [], left)
            if ready:
                chunk = os.read(self.proc.stdout.fileno(), 65536)
                if not chunk:
                    raise EOFError("jzIntv exited:\n" + self.buf.decode("latin-1")[-2000:])
                self.buf += chunk

    def cmd(self, line, seconds=60):
        self.proc.stdin.write((line + "\n").encode())
        return self.wait_prompt(seconds)

    def peek(self, addr, count):
        # The dump starts at addr rounded down to 8, and a line may begin
        # with the "> " prompt; place each word by its line's address.
        mem = {}
        text = self.cmd(f"m {addr:x} {count + 8:x}")
        for line in text.splitlines():
            found = re.match(r"^[>\s]*([0-9A-Fa-f]{4}):\s+(.*?)(#|$)", line)
            if found:
                base = int(found.group(1), 16)
                for idx, word in enumerate(found.group(2).split()):
                    mem[base + idx] = int(word.rstrip("*"), 16)
        return [mem.get(addr + idx, -1) for idx in range(count)]

    def close(self):
        try:
            self.proc.stdin.write(b"q\n")
            self.proc.wait(10)
        except Exception:
            self.proc.kill()


def press(dbg, syms, byte):
    """Make the ROM's next in_poll see controller byte `byte`, once."""
    hook = syms["IN_POLL_HOOK"]
    var = syms["var_IN_C"]
    dbg.cmd(f"b {hook:x}")
    dbg.cmd("r", 60)
    dbg.cmd(f"e {var:x} {byte:x}")
    dbg.cmd(f"n {hook:x}")
    for _ in range(3):
        dbg.cmd("r 300000", 120)


def screen_text(words):
    rows = []
    for row in range(12):
        chars = []
        for word in words[row * 20:row * 20 + 20]:
            card = (word >> 3) & 0xFF
            chars.append(chr(card + 32) if not word & 0x800 and card < 95 else "#")
        rows.append("".join(chars))
    return rows


def main():
    parser = argparse.ArgumentParser(usage=__doc__)
    parser.add_argument("rom")
    parser.add_argument("--jzintv", default=os.environ.get("JZINTV", "jzintv"))
    parser.add_argument("--rom-dir", default=os.environ.get("JZINTV_ROMS", "."))
    parser.add_argument("--fujinet")
    parser.add_argument("--save")
    parser.add_argument("--sym")
    parser.add_argument("--bootdir")
    parser.add_argument("--expect", default="")
    parser.add_argument("--timeout", type=float, default=300)
    parser.add_argument("--keys", default="")
    args = parser.parse_args()

    syms = read_syms(args.sym or os.path.splitext(args.rom)[0] + ".sym")
    names = read_names(os.path.join(os.path.dirname(__file__), "..", "src", "ui.bas"))
    argv = [args.jzintv, "-d", "-e", os.path.join(args.rom_dir, "exec.bin"),
            "-g", os.path.join(args.rom_dir, "grom.bin")]
    if args.fujinet:
        argv.append("--fujinet=" + args.fujinet)
    if args.bootdir:
        os.makedirs(args.bootdir, exist_ok=True)
        argv.append("--fujinet-bootdir=" + args.bootdir)
    if args.save:
        argv += ["--jlp-savegame=" + args.save, "--jlp-flash=6"]
    argv.append(args.rom)
    env = dict(os.environ, SDL_VIDEODRIVER="dummy", SDL_AUDIODRIVER="dummy")
    os.environ.update(env)

    dbg = Debugger(argv)
    done_addr = syms["var_&RUN_DONE"]
    start = time.time()
    try:
        while True:
            dbg.cmd("r 300000", 120)
            if dbg.peek(done_addr, 1) == [1]:
                break
            if time.time() - start > args.timeout:
                print("jzrun: timed out waiting for #run_done", file=sys.stderr)
                print("\n".join(screen_text(dbg.peek(0x200, 240))), file=sys.stderr)
                sys.exit(2)
        for key in filter(None, args.keys.split(",")):
            if key == "s":
                dbg.cmd("vs")
                continue
            if key == "d":
                words = dbg.peek(0x200, 240)
                for row in range(12):
                    print(" ".join(f"{w:04X}" for w in words[row * 20:row * 20 + 20]))
                continue
            if key.startswith("w"):
                for _ in range(int(key[1:])):
                    dbg.cmd("r 300000", 120)
            else:
                press(dbg, syms, int(key, 16))
            print(f"--- after {key}")
            print("\n".join("| " + row + " |" for row in screen_text(dbg.peek(0x200, 240))))
        count = len(names)
        res = dbg.peek(syms["array_&TRES"], count)
        val = dbg.peek(syms["array_&TVAL"], count)
        val2 = dbg.peek(syms["array_&TVAL2"], count)
        screen = screen_text(dbg.peek(0x200, 240))
    finally:
        dbg.close()

    print(f"run took {time.time() - start:.0f} s")
    print("\n".join("| " + row + " |" for row in screen))
    expect, default = {}, None
    for item in filter(None, args.expect.split(",")):
        key, _, want = item.partition("=")
        if key == "*":
            default = want
        else:
            expect[key] = want
    bad = 0
    for idx, name in enumerate(names):
        tid = name[:2]
        got = RESULT[res[idx]] if res[idx] < len(RESULT) else f"?{res[idx]}"
        want = expect.get(tid, default)
        mark = ""
        if want and got not in want.split("|"):
            mark = f"   <-- want {want}"
            bad += 1
        print(f"{name}  {got}  {val[idx]:5d} ${val[idx]:04X}  {val2[idx]:5d}{mark}")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
