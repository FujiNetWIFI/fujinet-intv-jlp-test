' tests_cd.bas -- C: FujiNet on its own; D: FujiNet and JLP at once.

' skip_c: a FujiNet test that can't run because A2 found no live mailbox.
skip_c: PROCEDURE
    #rcode = R_SKIP : #rv1 = 0 : #rv2 = 0
    GOSUB set_res
END

' fail_c: the transaction failed; the value is the error (255 = timeout).
fail_c: PROCEDURE
    #rcode = R_FAIL : #rv1 = #fn_err : #rv2 = #fn_frames
    GOSUB set_res
END

' C1: WiFi status; 3 means connected.
test_c1: PROCEDURE
    #tst = T_C1 : GOSUB running
    IF #mbx_ok = 0 THEN GOSUB skip_c : RETURN
    #fn_limit = 600
    #fn_dev = DEV_FUJI : #fn_cmd = FC_WIFISTATUS : GOSUB fn_simple
    IF #fn_ok = 0 THEN GOSUB fail_c : RETURN
    #rv1 = PEEK(MB_RX) AND 255 : #rv2 = #fn_frames
    IF #rv1 = 3 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' copy_ascii: #cnt bytes from MB_RX + #tmp into the array at #tmp2.
copy_ascii: PROCEDURE
    FOR #kx = 0 TO #cnt - 1
        POKE #tmp2 + #kx, PEEK(MB_RX + #tmp + #kx) AND 255
    NEXT #kx
END

' C2: the 240-byte extended adapter config; keeps SSID, IP and version.
test_c2: PROCEDURE
    #tst = T_C2 : GOSUB running
    IF #mbx_ok = 0 THEN GOSUB skip_c : RETURN
    #fn_dev = DEV_FUJI : #fn_cmd = FC_ADAPTERCFG : GOSUB fn_simple
    IF #fn_ok = 0 THEN GOSUB fail_c : RETURN
    #cnt = 16
    #tmp = 0 : #tmp2 = VARPTR #ssid(0) : GOSUB copy_ascii
    #tmp = 140 : #tmp2 = VARPTR #ipstr(0) : GOSUB copy_ascii
    #cnt = 15
    #tmp = 125 : #tmp2 = VARPTR #fwver(0) : GOSUB copy_ascii
    #rv1 = #fn_rxlen : #rv2 = #fn_frames
    IF #fn_rxlen = 240 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' C3: the clock device ($45), APETIME: day, month, year, hour, min, sec.
test_c3: PROCEDURE
    #tst = T_C3 : GOSUB running
    IF #mbx_ok = 0 THEN GOSUB skip_c : RETURN
    #fn_dev = DEV_CLOCK : #fn_cmd = CLK_APETIME : GOSUB fn_simple
    IF #fn_ok = 0 THEN GOSUB fail_c : RETURN
    FOR #kx = 0 TO 5
        #clk(#kx) = PEEK(MB_RX + #kx) AND 255
    NEXT #kx
    #rv1 = #fn_rxlen : #rv2 = #fn_frames
    #rcode = R_FAIL
    IF #fn_rxlen = 6 THEN
        IF #clk(0) >= 1 THEN
            IF #clk(0) <= 31 THEN
                IF #clk(1) >= 1 THEN
                    IF #clk(1) <= 12 THEN
                        IF #clk(3) < 24 THEN
                            IF #clk(4) < 60 THEN #rcode = R_PASS
                        END IF
                    END IF
                END IF
            END IF
        END IF
    END IF
    GOSUB set_res
END

' C4: AppKey round trip: write 64 fresh bytes, read them back. Needs the
' FujiNet's SD card; a refused open is a SKIP, not a FAIL.
test_c4: PROCEDURE
    #tst = T_C4 : GOSUB running
    IF #mbx_ok = 0 THEN GOSUB skip_c : RETURN
    #ak_nonce = FRAME AND 255
    #tmp = 1 : GOSUB ak_open
    IF #fn_ok = 0 THEN
        #rcode = R_SKIP : #rv1 = #fn_err : #rv2 = 0
        GOSUB set_res
        RETURN
    END IF
    FOR #kx = 0 TO AK_LEN - 1
        POKE MB_TX + #kx, #kx XOR #ak_nonce
    NEXT #kx
    #fn_dev = DEV_FUJI : #fn_cmd = FC_AK_WRITE : #fn_np = 0 : #fn_txlen = AK_LEN
    GOSUB fn_transact
    IF #fn_ok = 0 THEN GOSUB fail_c : RETURN
    #tmp = 0 : GOSUB ak_open
    IF #fn_ok = 0 THEN GOSUB fail_c : RETURN
    #fn_dev = DEV_FUJI : #fn_cmd = FC_AK_READ : GOSUB fn_simple
    IF #fn_ok = 0 THEN GOSUB fail_c : RETURN
    #rv1 = (PEEK(MB_RX) AND 255) + (PEEK(MB_RX + 1) AND 255) * 256
    #cnt = 0
    IF #rv1 = AK_LEN THEN
        FOR #kx = 0 TO AK_LEN - 1
            IF (PEEK(MB_RX + 2 + #kx) AND 255) <> (#kx XOR #ak_nonce) THEN #cnt = #cnt + 1
        NEXT #kx
    ELSE
        #cnt = AK_LEN
    END IF
    #rv2 = #cnt
    #fn_dev = DEV_FUJI : #fn_cmd = FC_AK_CLOSE : GOSUB fn_simple
    IF #rv2 = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' ---- download ----------------------------------------------------------
' dl_run: GET url_text into #pay, checking every byte against the pattern
' as it lands. #dl_async = 1 runs jlp_unit for as long as each READ is in
' flight. Leaves #dl_fail: 0 ok, 1 open, 2 status, 3 channel error,
' 4 stalled, 5 wrong length, 6 read, 7 short read.
dl_run: PROCEDURE
    #dl_got = 0 : #dl_bad = 0 : #dl_firstbad = $FFFF : #dl_fail = 0
    #dl_txn = 0 : #dl_txframes = 0 : #dl_stall = 0 : #dl_lo = 0
    #fn_limit = 900
    GOSUB net_open
    IF #fn_ok = 0 THEN #dl_fail = 1 : RETURN
    #dl_go = 1
    WHILE #dl_go
        GOSUB net_status
        IF #fn_ok = 0 THEN
            #dl_fail = 2 : #dl_go = 0
        ELSEIF #net_avail = 0 THEN
            IF #net_err = NET_EOF THEN
                #dl_go = 0
            ELSEIF #net_err <> 1 THEN
                #dl_fail = 3 : #dl_go = 0
            ELSE
                WAIT
                #dl_stall = #dl_stall + 1
                IF #dl_stall > 600 THEN #dl_fail = 4 : #dl_go = 0
            END IF
        ELSE
            #dl_stall = 0
            #net_want = #net_avail
            IF #net_want > MB_RX_MAX THEN #net_want = MB_RX_MAX
            #tmp = PAT_LEN - #dl_got
            IF #net_want > #tmp THEN #net_want = #tmp
            IF #net_want = 0 THEN
                #dl_fail = 5 : #dl_go = 0
            ELSE
                GOSUB dl_read
                IF #dl_fail THEN #dl_go = 0
                IF #dl_got >= PAT_LEN THEN #dl_go = 0
            END IF
        END IF
    WEND
    GOSUB net_close
    IF #dl_fail = 0 THEN
        IF #dl_got <> PAT_LEN THEN #dl_fail = 5
    END IF
END

' dl_read: one READ of #net_want bytes, verified and packed into #pay.
dl_read: PROCEDURE
    GOSUB net_read_begin
    IF #dl_async THEN
        WHILE #fn_busy
            GOSUB jlp_unit
            GOSUB fn_poll
        WEND
    ELSE
        WHILE #fn_busy
            WAIT
            GOSUB fn_poll
        WEND
    END IF
    #dl_txn = #dl_txn + 1
    #dl_txframes = #dl_txframes + #fn_frames
    IF #fn_ok = 0 THEN #dl_fail = 6 : RETURN
    IF #fn_rxlen <> #net_want THEN #dl_fail = 7 : RETURN
    FOR #ix = 0 TO #fn_rxlen - 1
        #dl_b = PEEK(MB_RX + #ix) AND 255
        #dl_idx = #dl_got + #ix
        #dl_e = ((#dl_idx AND 255) XOR $5A XOR ((#dl_idx / 256) * 16)) AND 255
        IF #dl_b <> #dl_e THEN
            #dl_bad = #dl_bad + 1
            IF #dl_firstbad = $FFFF THEN #dl_firstbad = #dl_idx
        END IF
        IF (#dl_idx AND 1) THEN
            #pay(#dl_idx / 2) = #dl_lo + #dl_b * 256
        ELSE
            #dl_lo = #dl_b
        END IF
    NEXT #ix
    #dl_got = #dl_got + #fn_rxlen
END

' dl_verdict: #rcode/#rv1/#rv2 for a download test.
dl_verdict: PROCEDURE
    #rcode = R_FAIL : #rv1 = #dl_fail : #rv2 = #dl_bad
    IF #dl_fail = 0 THEN
        #rv1 = #dl_got
        IF #dl_bad = 0 THEN #rcode = R_PASS
    END IF
END

' C5: the N: download, blocking, the way a game without JLP would do it.
' Also checks the software CRC of the packed words against the host's.
test_c5: PROCEDURE
    #tst = T_C5 : GOSUB running
    IF #mbx_ok = 0 THEN GOSUB skip_c : RETURN
    #dl_async = 0
    GOSUB dl_run
    #txn_idle = #dl_txframes
    GOSUB dl_verdict
    IF #rcode = R_PASS THEN
        #crc = CRC_INIT : #rbase = VARPTR #pay(0) : #rnum = PAT_WORDS
        ASM CALL SW_CRCBUF
        IF #crc <> PAT_CRC THEN #rcode = R_FAIL : #rv2 = 1
    END IF
    GOSUB set_res
END

' ---- simultaneous ------------------------------------------------------

' jlp_unit: one slice of JLP work, run while a READ is in flight. Rotates
' RAM, multiply, divide, CRC + RNG; every result is checked.
jlp_unit: PROCEDURE
    #ju_ops = #ju_ops + 1
    IF #ju_kind = 0 THEN
        #rbase = VARPTR #work(0) : #rnum = 64 : #rseed = #ju_ops
        ASM CALL RAM_FILL
        ASM CALL RAM_CHECK
        #ju_err = #ju_err + #rerr
    ELSEIF #ju_kind = 1 THEN
        GOSUB lfsr_pair
        ASM CALL SW_MPYUU
        #mop = JLP_MPYUU : ASM CALL HW_OP
        IF #hlo <> #plo THEN #ju_err = #ju_err + 1
        IF #hhi <> #phi THEN #ju_err = #ju_err + 1
    ELSEIF #ju_kind = 2 THEN
        GOSUB lfsr_pair
        IF #mb = 0 THEN #mb = 1
        #dn = #ma : #dd = #mb : ASM CALL SW_DIVUU
        #mop = JLP_DIVUU : ASM CALL HW_OP
        IF #hlo <> #dq THEN #ju_err = #ju_err + 1
        IF #hhi <> #dr THEN #ju_err = #ju_err + 1
    ELSE
        #tmp = #ju_ops AND 7
        #crc = kat_init(#tmp) : #work(0) = kat_data(#tmp)
        #rbase = VARPTR #work(0) : #rnum = 1 : ASM CALL HW_CRC
        IF #crc <> kat_out(#tmp) THEN #ju_err = #ju_err + 1
        ' The slot about to be overwritten holds the sample from four
        ' samples ago; a match there is the cart's stale RNG buffer.
        #tmp2 = #ju_rng(#ju_rngpos)
        #rbase = VARPTR #ju_rng(#ju_rngpos) : #rnum = 1 : ASM CALL HW_RNG
        IF #ju_rng(#ju_rngpos) = #tmp2 THEN #ju_rngrep = #ju_rngrep + 1
        #ju_rngpos = (#ju_rngpos + 1) AND 3
    END IF
    #ju_kind = (#ju_kind + 1) AND 3
    in_c = CONT
    IF in_c = KP_CLEAR THEN #stop_req = 1
END

' D1: the same download with JLP busy during every READ. Passes only if
' the data is intact and no JLP result was wrong.
test_d1: PROCEDURE
    #tst = T_D1 : GOSUB running
    IF #mbx_ok = 0 THEN GOSUB skip_c : RETURN
    #ju_ops = 0 : #ju_err = 0 : #ju_rngrep = 0
    #dl_async = 1
    GOSUB dl_run
    #txn_load = #dl_txframes
    GOSUB dl_verdict
    IF #rcode = R_PASS THEN
        #rv1 = #ju_ops : #rv2 = #ju_err
        IF #ju_err THEN #rcode = R_FAIL
    END IF
    GOSUB set_res
END

' D2: the JLP CRC unit, fed the downloaded words, must produce the CRC the
' host computed for the file. JLP verifying FujiNet's data.
test_d2: PROCEDURE
    #tst = T_D2 : GOSUB running
    IF #tres(T_D1) <> R_PASS THEN GOSUB skip_c : RETURN
    #crc = CRC_INIT : #rbase = VARPTR #pay(0) : #rnum = PAT_WORDS
    ASM CALL HW_CRC
    #rv1 = #crc : #rv2 = 0
    IF #crc = PAT_CRC THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' pay_to_flash: the payload into rows FR_PAY.., read back into #rb, then
' the header row. #cnt = words that came back wrong; #errs = commands that
' never finished; #rv1 = frames for the lot.
pay_to_flash: PROCEDURE
    #errs = 0
    #tflash = FRAME
    #fl_row = FR_PAY : GOSUB fl_erase
    #fl_row = FR_PAY + 8 : GOSUB fl_erase
    #tmp2 = VARPTR #pay(0)
    FOR #jx = 0 TO PAY_ROWS - 1
        #fl_row = FR_PAY + #jx : #fl_addr = #tmp2 : GOSUB fl_write
        #tmp2 = #tmp2 + ROW_WORDS
    NEXT #jx
    FOR #jx = 0 TO PAT_WORDS - 1 : #rb(#jx) = 0 : NEXT #jx
    #tmp2 = VARPTR #rb(0)
    FOR #jx = 0 TO PAY_ROWS - 1
        #fl_row = FR_PAY + #jx : #fl_addr = #tmp2 : GOSUB fl_read
        #tmp2 = #tmp2 + ROW_WORDS
    NEXT #jx
    #cnt = 0
    FOR #jx = 0 TO PAT_WORDS - 1
        IF #rb(#jx) <> #pay(#jx) THEN #cnt = #cnt + 1
    NEXT #jx
    FOR #jx = 0 TO ROW_WORDS - 1 : #hdr(#jx) = 0 : NEXT #jx
    #hdr(0) = HDR_MAGIC : #hdr(1) = 1 : #hdr(2) = #boot_count + 1 : #hdr(3) = PAT_CRC
    #fl_row = FR_HDR : GOSUB fl_erase
    #fl_row = FR_HDR : #fl_addr = VARPTR #hdr(0) : GOSUB fl_write
    #rv1 = FRAME - #tflash
END

' D3: downloaded data to flash and back.
test_d3: PROCEDURE
    #tst = T_D3 : GOSUB running
    IF #tres(T_D1) <> R_PASS THEN GOSUB skip_c : RETURN
    GOSUB pay_to_flash
    #rv2 = #cnt + #errs
    IF #rv2 = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' D4: what the last run's D3 left in flash, read back at this boot. Runs
' before C and D so this boot hasn't touched those rows yet.
test_d4: PROCEDURE
    #tst = T_D4 : GOSUB running
    #errs = 0
    #fl_row = FR_HDR : #fl_addr = VARPTR #hdr(0) : GOSUB fl_read
    IF #hdr(0) <> HDR_MAGIC THEN
        #boot_count = 0
        #rcode = R_INFO : #rv1 = 0 : #rv2 = #errs
        GOSUB set_res
        RETURN
    END IF
    #boot_count = #hdr(2)
    #tmp2 = VARPTR #rb(0)
    FOR #jx = 0 TO PAY_ROWS - 1
        #fl_row = FR_PAY + #jx : #fl_addr = #tmp2 : GOSUB fl_read
        #tmp2 = #tmp2 + ROW_WORDS
    NEXT #jx
    #crc = CRC_INIT : #rbase = VARPTR #rb(0) : #rnum = PAT_WORDS
    ASM CALL HW_CRC
    #rv1 = #boot_count : #rv2 = #errs
    #rcode = R_FAIL
    IF #crc = PAT_CRC THEN
        IF #hdr(3) = PAT_CRC THEN #rcode = R_PASS
    END IF
    GOSUB set_res
END
