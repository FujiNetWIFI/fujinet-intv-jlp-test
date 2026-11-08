' tests_b.bas -- B: JLP on its own. Accelerators are checked against the
' software references in asmlib.bas; flash is driven by hand (JF_CMD) so
' each command can be timed and its register watched, then once through
' IntyBASIC's FLASH statements the way a game would use it.

' B1: march four patterns through every free JLP RAM word below the mailbox.
test_b1: PROCEDURE
    #tst = T_B1 : GOSUB running
    #rbase = #sys_end : #rnum = JLP_RAMTOP - #sys_end + 1
    #errs = 0
    FOR #jx = 0 TO 3
        #rseed = march_seed(#jx)
        ASM CALL RAM_FILL
        ASM CALL RAM_CHECK
        #errs = #errs + #rerr
    NEXT #jx
    #rv1 = #rnum : #rv2 = #errs
    IF #errs = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' lfsr_step: 16-bit Galois LFSR in #lfsr (no accelerator involved).
lfsr_step: PROCEDURE
    #tmp = #lfsr AND 1
    #lfsr = #lfsr / 2
    IF #tmp THEN #lfsr = #lfsr XOR $B400
END

' lfsr_pair: #ma, #mb from the LFSR.
lfsr_pair: PROCEDURE
    GOSUB lfsr_step : #ma = #lfsr
    GOSUB lfsr_step : #mb = #lfsr
END

' mpy_check4: all four multiplies of #ma, #mb against the software product.
' Signed products differ from the unsigned one only in the high word:
' subtract b if a is negative and a if b is negative.
mpy_check4: PROCEDURE
    ASM CALL SW_MPYUU
    #tmp = 0 : #tmp2 = 0
    IF (#ma AND $8000) THEN #tmp = #mb
    IF (#mb AND $8000) THEN #tmp2 = #ma
    FOR #kx = 0 TO 3
        #mop = JLP_MPYSS + #kx * 2
        ASM CALL HW_OP
        #dq = #phi
        IF #kx = 0 THEN #dq = #phi - #tmp - #tmp2
        IF #kx = 1 THEN #dq = #phi - #tmp
        IF #kx = 2 THEN #dq = #phi - #tmp2
        IF #hlo <> #plo THEN #errs = #errs + 1
        IF #hhi <> #dq THEN #errs = #errs + 1
        #cnt = #cnt + 1
    NEXT #kx
    ' The compiler's own multiply (low word) must agree too.
    #bo_mode = 0 : GOSUB jlp_basic_ops
    IF #bo_mul <> #plo THEN #errs = #errs + 1
END

' B2: multiply. Eight edge pairs, then sixteen LFSR pairs, four ways each.
test_b2: PROCEDURE
    #tst = T_B2 : GOSUB running
    #errs = 0 : #cnt = 0
    FOR #jx = 0 TO 23
        IF #jx < 8 THEN
            #ma = mul_a(#jx) : #mb = mul_b(#jx)
        ELSE
            GOSUB lfsr_pair
        END IF
        GOSUB mpy_check4
    NEXT #jx
    #rv1 = #cnt : #rv2 = #errs
    IF #errs = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' div_check2: unsigned and signed divide of #ma by #mb (#mb <> 0). Signed
' division truncates toward zero; the remainder takes the dividend's sign.
div_check2: PROCEDURE
    #dn = #ma : #dd = #mb : ASM CALL SW_DIVUU
    #mop = JLP_DIVUU : ASM CALL HW_OP
    IF #hlo <> #dq THEN #errs = #errs + 1
    IF #hhi <> #dr THEN #errs = #errs + 1
    ' The compiler's own / and MOD are unsigned divides.
    #bo_mode = 1 : GOSUB jlp_basic_ops
    IF #bo_div <> #dq THEN #errs = #errs + 1
    IF #bo_mod <> #dr THEN #errs = #errs + 1
    #dn = #ma : #dd = #mb
    IF (#ma AND $8000) THEN #dn = 0 - #ma
    IF (#mb AND $8000) THEN #dd = 0 - #mb
    ASM CALL SW_DIVUU
    IF ((#ma XOR #mb) AND $8000) THEN #dq = 0 - #dq
    IF (#ma AND $8000) THEN #dr = 0 - #dr
    #mop = JLP_DIVSS : ASM CALL HW_OP
    IF #hlo <> #dq THEN #errs = #errs + 1
    IF #hhi <> #dr THEN #errs = #errs + 1
    #cnt = #cnt + 2
END

' B3: divide. Edge pairs, then LFSR pairs. Never divides by zero (the cart
' has no guard) or $8000 by -1 (overflows in C).
test_b3: PROCEDURE
    #tst = T_B3 : GOSUB running
    #errs = 0 : #cnt = 0
    FOR #jx = 0 TO 23
        IF #jx < 8 THEN
            #ma = div_a(#jx) : #mb = div_b(#jx)
        ELSE
            GOSUB lfsr_pair
            IF #mb = 0 THEN #mb = 1
            IF #ma = $8000 THEN #ma = $8001
        END IF
        GOSUB div_check2
    NEXT #jx
    #rv1 = #cnt : #rv2 = #errs
    IF #errs = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' B4: CRC-16 known answers (tools/mkpattern.py), through both the
' software step and the JLP unit.
test_b4: PROCEDURE
    #tst = T_B4 : GOSUB running
    #errs = 0 : #cnt = 0
    FOR #jx = 0 TO KAT_COUNT - 1
        #crc = kat_init(#jx) : #cdat = kat_data(#jx)
        ASM CALL SW_CRC
        IF #crc <> kat_out(#jx) THEN #cnt = #cnt + 1
        #crc = kat_init(#jx) : #work(0) = kat_data(#jx)
        #rbase = VARPTR #work(0) : #rnum = 1
        ASM CALL HW_CRC
        IF #crc <> kat_out(#jx) THEN #errs = #errs + 1
    NEXT #jx
    #rv1 = KAT_COUNT : #rv2 = #errs
    ' #cnt counts failures of the software step: a bug in this ROM, not JLP.
    IF #errs + #cnt = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' B5: 256 random numbers. Fails on a stuck generator, one that repeats
' every four reads (the cart's 4-entry buffer not being refilled), or a
' run of zeros.
test_b5: PROCEDURE
    #tst = T_B5 : GOSUB running
    #rbase = VARPTR #rb(0) : #rnum = 256
    ASM CALL HW_RNG
    #cnt = 0 : #errs = 0 : #tmp2 = 0
    FOR #jx = 4 TO 255
        IF #rb(#jx) = #rb(#jx - 4) THEN #cnt = #cnt + 1
        IF #rb(#jx) = #rb(#jx - 1) THEN #tmp2 = #tmp2 + 1
        IF #rb(#jx) = 0 THEN #errs = #errs + 1
    NEXT #jx
    #rng_rep = #cnt
    #rv1 = #cnt : #rv2 = #tmp2
    #rcode = R_PASS
    IF #cnt > 2 THEN #rcode = R_FAIL
    IF #tmp2 > 2 THEN #rcode = R_FAIL
    IF #errs > 2 THEN #rcode = R_FAIL
    GOSUB set_res
END

' ---- flash helpers. #fl_row is an offset from FLASH.FIRST; buffers are
' #rb(0..95) (source) and #rb(96..191) (destination).

' fl_cmd: run one command, time it in frames (#tmp3), count key read-backs.
fl_cmd: PROCEDURE
    #fl_row = #fl_row + #first_row
    #tstart = FRAME
    ASM CALL JF_CMD
    #tmp3 = FRAME - #tstart
    #key_total = #key_total + #fl_keyseen
    IF #fl_last <> 0 THEN #errs = #errs + 1
END

fl_erase: PROCEDURE
    #fl_reg = JLP_ERASE : #fl_key = KEY_ERASE : #fl_addr = VARPTR #rb(0)
    GOSUB fl_cmd
    #fl_terase = #tmp3
END

fl_write: PROCEDURE
    #fl_reg = JLP_WRITE : #fl_key = KEY_WRITE
    GOSUB fl_cmd
    #fl_twrite = #tmp3
END

fl_read: PROCEDURE
    #fl_reg = JLP_READ : #fl_key = KEY_READ
    GOSUB fl_cmd
    #fl_tread = #tmp3
END

' fill_src: #rb(0..95) = k XOR #rseed.
fill_src: PROCEDURE
    FOR #kx = 0 TO ROW_WORDS - 1
        #rb(#kx) = #kx XOR #rseed
    NEXT #kx
END

' cmp_dst: #cnt = words of #rb(96..191) that are not k XOR #rseed.
cmp_dst: PROCEDURE
    #cnt = 0
    FOR #kx = 0 TO ROW_WORDS - 1
        IF #rb(ROW_WORDS + #kx) <> (#kx XOR #rseed) THEN #cnt = #cnt + 1
    NEXT #kx
END

' rd_row: read row offset #tmp into #rb(96..), compare with #rseed.
rd_row: PROCEDURE
    FOR #kx = 0 TO ROW_WORDS - 1
        #rb(ROW_WORDS + #kx) = $5A5A
    NEXT #kx
    #fl_row = #tmp : #fl_addr = VARPTR #rb(ROW_WORDS)
    GOSUB fl_read
    GOSUB cmp_dst
END

' B6: erase sectors 0 and 1, write a row in each, read both back; then
' write one row twice without erasing and record what the cart did.
test_b6: PROCEDURE
    #tst = T_B6 : GOSUB running
    #errs = 0
    #fl_row = FR_PROBE0 : GOSUB fl_erase
    #fl_row = FR_PROBE1 : GOSUB fl_erase
    #rseed = $1111 : GOSUB fill_src
    #fl_row = FR_PROBE0 : #fl_addr = VARPTR #rb(0) : GOSUB fl_write
    #rseed = $8888 : GOSUB fill_src
    #fl_row = FR_PROBE1 : #fl_addr = VARPTR #rb(0) : GOSUB fl_write
    #tmp2 = 0
    #rseed = $1111 : #tmp = FR_PROBE0 : GOSUB rd_row : #tmp2 = #tmp2 + #cnt
    #rseed = $8888 : #tmp = FR_PROBE1 : GOSUB rd_row : #tmp2 = #tmp2 + #cnt
    #rv1 = #fl_terase + #fl_twrite + #fl_tread : #rv2 = #tmp2 + #errs
    IF #rv2 = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
    ' Write twice: row 1 was erased with sector 0 above.
    #rseed = $00FF : FOR #kx = 0 TO ROW_WORDS - 1 : #rb(#kx) = $00FF : NEXT #kx
    #fl_row = FR_PROBE0 + 1 : #fl_addr = VARPTR #rb(0) : GOSUB fl_write
    FOR #kx = 0 TO ROW_WORDS - 1 : #rb(#kx) = $0F0F : NEXT #kx
    #fl_row = FR_PROBE0 + 1 : #fl_addr = VARPTR #rb(0) : GOSUB fl_write
    #tmp = FR_PROBE0 + 1 : #rseed = 0 : GOSUB rd_row
    #wr2x = 4
    #tmp2 = #rb(ROW_WORDS)
    IF #tmp2 = $00FF THEN #wr2x = 1
    IF #tmp2 = $0F0F THEN #wr2x = 2
    IF #tmp2 = $000F THEN #wr2x = 3
END

' B7: erase row 8 must erase sector 1 (rows 8-15) and leave sector 0 alone.
' A cart computing the sector as row MOD 8 erases sector 0 instead.
test_b7: PROCEDURE
    #tst = T_B7 : GOSUB running
    #errs = 0
    #fl_row = FR_PROBE1 : GOSUB fl_erase
    #rv1 = 0
    #rseed = $1111 : #tmp = FR_PROBE0 : GOSUB rd_row
    IF #cnt THEN #rv1 = 1
    #tmp = FR_PROBE1 : GOSUB rd_row
    #tmp2 = 0
    FOR #kx = 0 TO ROW_WORDS - 1
        IF #rb(ROW_WORDS + #kx) <> $FFFF THEN #tmp2 = #tmp2 + 1
    NEXT #kx
    IF #tmp2 THEN #rv1 = #rv1 + 2
    #rv2 = #errs
    IF #rv1 + #errs = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' B8: a READ whose 96-word destination runs past $9F7F into the
' accelerators must be refused. The slack area is filled with a marker
' first; it must still hold the marker afterwards.
test_b8: PROCEDURE
    #tst = T_B8 : GOSUB running
    #errs = 0
    #rbase = JLP_SLACK : #rnum = 64 : #rseed = $5A5A : ASM CALL RAM_FILL
    #fl_row = FR_PROBE0 : #fl_addr = JLP_SLACK
    GOSUB fl_read
    ASM CALL RAM_CHECK
    #rv1 = #rerr : #rv2 = #errs
    IF #rerr = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' B9: the same round trip through IntyBASIC's FLASH statements. Their
' command routine jumps by whatever the command register reads, so if any
' hand-driven command above read the key back, this would crash: skip it.
test_b9: PROCEDURE
    #tst = T_B9 : GOSUB running
    IF #key_total THEN
        #rcode = R_SKIP : #rv1 = #key_total : #rv2 = 0
        GOSUB set_res
        RETURN
    END IF
    #rseed = $3C3C : GOSUB fill_src
    FOR #kx = 0 TO ROW_WORDS - 1 : #rb(ROW_WORDS + #kx) = 0 : NEXT #kx
    #tmp = #first_row + FR_SPARE
    FLASH ERASE #tmp
    FLASH WRITE #tmp, VARPTR #rb(0)
    FLASH READ #tmp, VARPTR #rb(ROW_WORDS)
    GOSUB cmp_dst
    #rv1 = ROW_WORDS - #cnt : #rv2 = #cnt
    IF #cnt = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

march_seed:
    DATA $0000, $FFFF, $5555, $AAAA
mul_a:
    DATA 3, $FFFF, $8000, $7FFF, $1234, $FFFF, $8000, 0
mul_b:
    DATA 5, $FFFF, 2, $7FFF, $5678, 1, $8000, $FFFF
div_a:
    DATA 100, $FFFF, $FFFF, $8000, 7, $FFF6, 10, $8001
div_b:
    DATA 7, 1, $FFFF, 3, 100, 3, $FFFD, $FFFF
