#!/bin/sh
# Headless test matrix for the JLP + FujiNet test ROM, in jzIntv.
#
#   JZINTV=/path/to/jzintv JZINTV_ROMS=/dir/with/exec.bin+grom.bin \
#   BOIP=localhost:1985 tools/run-tests.sh
#
# Needs a jzIntv that models the cart's JLP/mailbox sharing (FujiNetWIFI/
# jzintv with [vars] fujinet support) and a FujiNet (fujinet-pc RS232 build)
# answering BoIP at $BOIP. The download URL is compiled in, so this rebuilds
# the ROM against a local web server serving data/, and rebuilds the
# default ROM when it is done.
#
# Scenarios:
#   jlp-only    .rom, no FujiNet: every JLP test passes, FujiNet tests skip
#   both        .bin + .cfg with fujinet = 1: everything passes
#   both-again  second boot on the same flash file: D4 finds last boot's data
#   nofuji      .cfg without fujinet = 1: the mailbox is off, JLP still passes
#   pushed, pushed-again, pushed-nofuji
#               the same, but booted over the network: tools/pushboot.bas has
#               FujiNet push the .bin + .cfg from host slot 1, the way CONFIG
#               does. Needs FUJINET_SD, that FujiNet's SD directory (host
#               slot 1); the files go in its jlpfn-test/ folder.
set -eu
cd "$(dirname "$0")/.."

JZINTV=${JZINTV:-jzintv}
JZINTV_ROMS=${JZINTV_ROMS:?set JZINTV_ROMS to the directory holding exec.bin and grom.bin}
BOIP=${BOIP:-localhost:1985}
PORT=${PORT:-18431}
URL=${URL:-http://127.0.0.1:$PORT/pattern.bin}
WORK=build/test
mkdir -p "$WORK"

server_pid=
cleanup() {
    [ -n "$server_pid" ] && kill "$server_pid" 2>/dev/null || true
    make --no-print-directory >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

case "$URL" in
http://127.0.0.1:$PORT/*)
    python3 -m http.server "$PORT" --bind 127.0.0.1 --directory data \
        >"$WORK/http.log" 2>&1 &
    server_pid=$!
    sleep 1
    ;;
esac

make --no-print-directory URL="$URL" all nofuji build/pushboot.rom

run() {
    name=$1; shift
    echo "=== $name"
    if python3 -u tools/jzrun.py --jzintv "$JZINTV" --rom-dir "$JZINTV_ROMS" "$@" \
        >"$WORK/$name.txt" 2>&1; then
        echo "    ok"
    else
        echo "    FAILED"
        failed="$failed $name"
    fi
    sed 's/^/    /' "$WORK/$name.txt"
}

failed=
JLP_OK='A1=PASS,A3=PASS,A4=PASS,A5=PASS,A6=PASS,B1=PASS,B2=PASS,B3=PASS,B4=PASS,B5=PASS,B6=PASS,B7=PASS,B8=PASS,B9=PASS'
SKIP_NET='A2=SKIP,C1=SKIP,C2=SKIP,C3=SKIP,C4=SKIP,C5=SKIP,D1=SKIP,D2=SKIP,D3=SKIP'

run jlp-only --expect "$JLP_OK,$SKIP_NET,D4=INFO" build/jlpfn.rom

rm -f "$WORK/flash.jlp" "$WORK/flash.jlp~"
run both --fujinet "$BOIP" --save "$WORK/flash.jlp" \
    --expect "*=PASS,D4=INFO" build/jlpfn.bin
run both-again --fujinet "$BOIP" --save "$WORK/flash.jlp" \
    --expect "*=PASS" build/jlpfn.bin

run nofuji --fujinet "$BOIP" --expect "$JLP_OK,$SKIP_NET,D4=INFO" build/jlpfn-nofuji.bin

if [ -n "${FUJINET_SD:-}" ]; then
    push_dir=$FUJINET_SD/jlpfn-test
    mkdir -p "$push_dir"
    cp build/jlpfn.bin build/jlpfn.cfg "$push_dir/"
    rm -rf "$WORK/boot"
    run pushed --fujinet "$BOIP" --bootdir "$WORK/boot" --sym build/jlpfn.sym \
        --expect "*=PASS,D4=INFO" build/pushboot.rom
    run pushed-again --fujinet "$BOIP" --bootdir "$WORK/boot" --sym build/jlpfn.sym \
        --expect "*=PASS" build/pushboot.rom
    cp build/jlpfn-nofuji.bin "$push_dir/jlpfn.bin"
    cp build/jlpfn-nofuji.cfg "$push_dir/jlpfn.cfg"
    run pushed-nofuji --fujinet "$BOIP" --bootdir "$WORK/boot" --sym build/jlpfn-nofuji.sym \
        --expect "$JLP_OK,$SKIP_NET,D4=PASS|INFO" build/pushboot.rom
    rm -rf "$push_dir"
else
    echo "=== pushed: skipped (set FUJINET_SD to that FujiNet's SD directory)"
fi

if [ -n "$failed" ]; then
    echo "FAILED:$failed"
    exit 1
fi
echo "all scenarios passed"
