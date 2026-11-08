' vars.bas -- every variable, declared before any code uses it.
'
' Built with --jlp, every 16-bit (#) variable and array lives in JLP RAM
' from $8040 up; 8-bit variables stay in console RAM ($0100-$01EF). The
' make check-map step fails the build if the 16-bit area reaches the
' mailbox at $9C00. The few 8-bit variables are the ones read or written
' while JLP itself is in doubt (the startup probe and the JLP off/on test).

    ' ---- 8-bit, console RAM
    DIM jram_ok                ' JLP_PROBE result
    DIM tg_mag, tg_ram, tg_back ' JLP_TOGGLE results
    DIM in_c, in_last          ' raw controller byte, previous byte

    ' ---- results, read by tools/results.py through the .sym file
    DIM #tres(T_COUNT)         ' R_* code per test
    DIM #tval(T_COUNT)         ' main measured value
    DIM #tval2(T_COUNT)        ' second value (error count, frames, ...)
    DIM #run_done              ' 1 once the boot run has finished
    DIM #n_pass, #n_fail, #n_skip, #n_info

    ' ---- environment
    DIM #j_chk                 ' JLP_PROBE scratch
    DIM #sys_end               ' _SYSTEM2: first JLP RAM word not allocated
    DIM #first_row             ' FLASH.FIRST
    DIM #mbx_ok                ' 1 = mailbox answers, FujiNet tests may run
    DIM #mbx_wiped             ' 1 = live mailbox but its magic was cleared

    ' ---- ASM routine interfaces (asmlib.bas)
    DIM #ma, #mb, #mop, #hlo, #hhi, #plo, #phi
    DIM #dn, #dd, #dq, #dr
    DIM #crc, #cdat
    DIM #rbase, #rnum, #rseed, #rerr, #rfirst
    DIM #fl_addr, #fl_row, #fl_reg, #fl_key
    DIM #fl_last, #fl_keyseen, #fl_polls, #fl_pollshi
    DIM #tg_chk
    DIM #bo_mode, #bo_mul, #bo_div, #bo_mod   ' jlp_basic_ops

    ' ---- mailbox transport (fujinet.bas)
    DIM #fn_dev, #fn_cmd, #fn_np, #fn_txlen
    DIM #fn_seq, #fn_t0, #fn_limit
    DIM #fn_busy, #fn_ok, #fn_err, #fn_rxlen, #fn_frames
    DIM #pm_i, #pm_sz, #pm_val
    DIM #net_avail, #net_err, #net_want

    ' ---- download (tests_cd.bas)
    DIM #dl_async              ' 1 = run JLP work while each READ is in flight
    DIM #dl_got, #dl_bad, #dl_firstbad, #dl_go, #dl_stall
    DIM #dl_fail               ' 0 ok, else where it failed (1 open .. 5 short)
    DIM #dl_txn, #dl_txframes, #dl_lo, #dl_idx, #dl_b, #dl_e
    DIM #pay(1536)             ' PAT_WORDS: the payload, packed little-endian
    DIM #rb(1536)              ' read-back buffer (flash tests, D3, D4)
    DIM #hdr(96)               ' persistence header row

    ' ---- JLP work unit run during transactions (jlpwork.bas)
    DIM #work(64)
    DIM #ju_kind, #ju_ops, #ju_err, #ju_rngrep
    DIM #ju_rng(4), #ju_rngpos
    DIM #lfsr

    ' ---- generic temporaries
    DIM #ix, #jx, #kx, #tmp, #tmp2, #tmp3, #cnt, #errs, #tstart

    ' ---- UI
    DIM #page, #pos, #ch, #color, #row, #tst, #rcode, #rv1, #rv2
    DIM #hexval
    DIM #pd_v, #pd_i, #pd_d, #pd_on, #pd_zero   ' put_dec

    ' ---- details shown on the last page
    DIM #ssid(16), #ipstr(16), #fwver(16), #clk(6)
    DIM #ak_nonce
    DIM #fl_terase, #fl_twrite, #fl_tread
    DIM #txn_idle, #txn_load, #rng_rep, #wr2x, #key_total, #boot_count

    ' ---- stress loop
    DIM #st_pass, #st_fail, #st_ops, #st_errs, #stop_req, #tflash

    UNSIGNED #fl_polls, #hexval, #dl_firstbad, #sys_end, #rfirst, #pd_v
