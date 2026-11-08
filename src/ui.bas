' ui.bas -- result screens and controller input.
'
' Screen: row 0 title, rows 1-10 ten tests per page (three pages) or the
' details page, row 11 the tally. A result row is
'     A1 JLP RAM PASS   48
' id+name (10), space, status (4), value (5, right-aligned; hex for some).
'
' Input reads the raw controller byte and compares whole bytes: a keypad
' key sets one row bit and one column bit, an action button two row bits,
' the disc only bits 0-4. CONT.KEY and the disc helpers misread
' combinations, so they are not used.

' set_res: store #rcode/#rv1/#rv2 for test #tst and redraw its row.
set_res: PROCEDURE
    #tres(#tst) = #rcode
    #tval(#tst) = #rv1
    #tval2(#tst) = #rv2
    IF #page < 3 THEN
        #row = #tst - #page * PAGE_ROWS
        IF #row >= 0 THEN
            IF #row < PAGE_ROWS THEN GOSUB draw_test
        END IF
    END IF
END

' draw_test: test #tst on screen row #row + 1.
draw_test: PROCEDURE
    #pos = (#row + 1) * 20
    #color = CS_WHITE
    FOR #kx = 0 TO 9
        #BACKTAB(#pos + #kx) = tname(#tst * 10 + #kx) * 8 + #color
    NEXT #kx
    #BACKTAB(#pos + 10) = 0
    #rcode = #tres(#tst)
    #color = rescol(#rcode)
    FOR #kx = 0 TO 3
        #BACKTAB(#pos + 11 + #kx) = resname(#rcode * 4 + #kx) * 8 + #color
    NEXT #kx
    #pos = #pos + 15
    IF #rcode = R_NONE THEN
        PRINT AT #pos, "     "
    ELSEIF tfmt(#tst) THEN
        #BACKTAB(#pos) = 0
        #pos = #pos + 1
        #hexval = #tval(#tst)
        #color = CS_TAN
        GOSUB put_hex
    ELSE
        #hexval = #tval(#tst) : #cnt = 5 : #color = CS_TAN
        GOSUB put_dec
    END IF
END

' put_dec: #hexval in decimal, right-aligned in #cnt (1-5) cells at #pos,
' in #color; #pd_zero = 1 pads with zeros instead of spaces. Leaves #pos
' after the field. Repeated subtraction, so no divide: with --jlp that
' would be an accelerator access.
put_dec: PROCEDURE
    #pd_v = #hexval
    #pd_on = #pd_zero
    FOR #pd_i = 0 TO 4
        #pd_d = 0
        WHILE #pd_v >= pow10(#pd_i)
            #pd_v = #pd_v - pow10(#pd_i)
            #pd_d = #pd_d + 1
        WEND
        IF #pd_d THEN #pd_on = 1
        IF #pd_i = 4 THEN #pd_on = 1
        IF #pd_i + #cnt >= 5 THEN
            IF #pd_on THEN
                #BACKTAB(#pos) = (#pd_d + 16) * 8 + #color
            ELSE
                #BACKTAB(#pos) = 0
            END IF
            #pos = #pos + 1
        END IF
    NEXT #pd_i
    #pd_zero = 0
END

' put_hex: 4 hex digits of #hexval at #pos in #color; leaves #pos after.
put_hex: PROCEDURE
    FOR #kx = 0 TO 3
        #ch = (#hexval / 4096) AND 15
        IF #ch < 10 THEN #ch = #ch + 16 ELSE #ch = #ch + 23
        #BACKTAB(#pos) = #ch * 8 + #color
        #pos = #pos + 1
        #hexval = #hexval * 16
    NEXT #kx
END

' put_ascii: #cnt ASCII codes from the array at #tmp2 (VARPTR) at #pos.
put_ascii: PROCEDURE
    FOR #kx = 0 TO #cnt - 1
        #ch = PEEK(#tmp2 + #kx) AND 255
        IF #ch < 32 THEN #ch = 32
        IF #ch > 126 THEN #ch = 32
        #BACKTAB(#pos + #kx) = (#ch - 32) * 8 + #color
    NEXT #kx
END

' draw_page: the whole screen for #page.
draw_page: PROCEDURE
    CLS
    PRINT AT 0 COLOR CS_YELLOW, "JLP+FUJINET TEST"
    PRINT AT 17 COLOR CS_TAN, <>#page + 1, "/4"
    IF #page < 3 THEN
        FOR #row = 0 TO PAGE_ROWS - 1
            #tst = #page * PAGE_ROWS + #row
            IF #tst < T_COUNT THEN GOSUB draw_test
        NEXT #row
        GOSUB draw_tally
    ELSE
        GOSUB draw_details
    END IF
END

' draw_tally: row 11.
draw_tally: PROCEDURE
    #n_pass = 0 : #n_fail = 0 : #n_skip = 0 : #n_info = 0
    FOR #kx = 0 TO T_COUNT - 1
        IF #tres(#kx) = R_PASS THEN #n_pass = #n_pass + 1
        IF #tres(#kx) = R_FAIL THEN #n_fail = #n_fail + 1
        IF #tres(#kx) = R_SKIP THEN #n_skip = #n_skip + 1
        IF #tres(#kx) = R_INFO THEN #n_info = #n_info + 1
    NEXT #kx
    PRINT AT 220 COLOR CS_GREEN, "P   F   S   I      "
    #cnt = 2
    #pos = 221 : #hexval = #n_pass : #color = CS_GREEN : GOSUB put_dec
    #pos = 225 : #hexval = #n_fail : #color = CS_RED : GOSUB put_dec
    #pos = 229 : #hexval = #n_skip : #color = CS_YELLOW : GOSUB put_dec
    #pos = 233 : #hexval = #n_info : #color = CS_WHITE : GOSUB put_dec
    #BACKTAB(224) = (70 - 32) * 8 + CS_RED
    #BACKTAB(228) = (83 - 32) * 8 + CS_YELLOW
    #BACKTAB(232) = (73 - 32) * 8 + CS_WHITE
END

' running: row 11 shows which test is in progress, so a hang has a name.
running: PROCEDURE
    PRINT AT 220 COLOR CS_WHITE, "RUN "
    FOR #kx = 0 TO 9
        #BACKTAB(224 + #kx) = tname(#tst * 10 + #kx) * 8 + CS_WHITE
    NEXT #kx
    PRINT AT 234, "      "
END

' draw_details: page 4.
draw_details: PROCEDURE
    #color = CS_WHITE
    PRINT AT 20 COLOR CS_TAN, "SSID"
    #pos = 25 : #tmp2 = VARPTR #ssid(0) : #cnt = 15 : GOSUB put_ascii
    PRINT AT 40 COLOR CS_TAN, "IP"
    #pos = 45 : #tmp2 = VARPTR #ipstr(0) : #cnt = 15 : GOSUB put_ascii
    PRINT AT 60 COLOR CS_TAN, "FW"
    #pos = 65 : #tmp2 = VARPTR #fwver(0) : #cnt = 15 : GOSUB put_ascii
    PRINT AT 80 COLOR CS_TAN, "TIME   -  -     :"
    #cnt = 2 : #color = CS_WHITE
    #pos = 85 : #hexval = #clk(2) : #pd_zero = 1 : GOSUB put_dec
    #pos = 88 : #hexval = #clk(1) : #pd_zero = 1 : GOSUB put_dec
    #pos = 91 : #hexval = #clk(0) : #pd_zero = 1 : GOSUB put_dec
    #pos = 94 : #hexval = #clk(3) : #pd_zero = 1 : GOSUB put_dec
    #pos = 97 : #hexval = #clk(4) : #pd_zero = 1 : GOSUB put_dec
    PRINT AT 100 COLOR CS_TAN, "BOOT      KEYSEEN"
    #cnt = 4
    #pos = 104 : #hexval = #boot_count : GOSUB put_dec
    #cnt = 3
    #pos = 117 : #hexval = #key_total : GOSUB put_dec
    PRINT AT 120 COLOR CS_TAN, "FL E    W    R"
    #pos = 124 : #hexval = #fl_terase : GOSUB put_dec
    #pos = 129 : #hexval = #fl_twrite : GOSUB put_dec
    #pos = 134 : #hexval = #fl_tread : GOSUB put_dec
    PRINT AT 140 COLOR CS_TAN, "TXN IDLE    LOAD"
    #pos = 148 : #hexval = #txn_idle : GOSUB put_dec
    #pos = 156 : #hexval = #txn_load : GOSUB put_dec
    PRINT AT 160 COLOR CS_TAN, "OPS       ERR"
    #cnt = 5
    #pos = 163 : #hexval = #ju_ops : GOSUB put_dec
    #pos = 173 : #hexval = #ju_err : GOSUB put_dec
    PRINT AT 180 COLOR CS_TAN, "RNGREP"
    #cnt = 3
    #pos = 186 : #hexval = #rng_rep : GOSUB put_dec
    PRINT AT 191 COLOR CS_TAN, "2XW "
    #pos = 195 : #color = CS_WHITE
    FOR #kx = 0 TO 4
        #BACKTAB(#pos + #kx) = wr2xname(#wr2x * 5 + #kx) * 8 + #color
    NEXT #kx
    PRINT AT 200 COLOR CS_TAN, "VARS END "
    #pos = 209 : #hexval = #sys_end : #color = CS_WHITE : GOSUB put_hex
    PRINT AT 220 COLOR CS_GREEN, "1:RUN 2:STRESS 3:PG"
END

' in_poll: #ch = new controller byte (0 if nothing new was pressed).
in_poll: PROCEDURE
    in_c = CONT
    ' tools/jzrun.py --keys breaks here and stores a controller byte in in_c.
    ASM IN_POLL_HOOK:
    #ch = 0
    IF in_c <> in_last THEN
        in_last = in_c
        #ch = in_c
    END IF
END

' next_page: on disc or key 3.
next_page: PROCEDURE
    #page = #page + 1
    IF #page >= PAGE_COUNT THEN #page = 0
    GOSUB draw_page
END

' Tables. Names are 10 characters: two-character id, space, seven.
tname:
    DATA "A1 JLP RAM", "A2 MAILBOX", "A3 VAR TOP", "A4 MBXSAFE"
    DATA "A5 SLACK  ", "A6 JLP OFF", "B1 MARCH  ", "B2 MULTPLY"
    DATA "B3 DIVIDE ", "B4 CRC16  ", "B5 RANDOM ", "B6 FLASH  "
    DATA "B7 ERASE  ", "B8 RANGE  ", "B9 BASICFL", "C1 WIFI   "
    DATA "C2 ADAPTER", "C3 CLOCK  ", "C4 APPKEY ", "C5 HTTPGET"
    DATA "D1 ASYNC  ", "D2 NET CRC", "D3 NET>FL ", "D4 PERSIST"
pow10:
    DATA 10000, 1000, 100, 10, 1
resname:
    DATA "....PASSFAILSKIPINFO"
rescol:
    DATA CS_DARKGREEN, CS_GREEN, CS_RED, CS_YELLOW, CS_WHITE
' 1 = show the value in hex (A3 address, D2 CRC).
tfmt:
    DATA 0,0,1,0,0,0, 0,0,0,0,0,0,0,0,0, 0,0,0,0,0, 0,1,0,0
' Write-twice outcome (B6): 0 not run, 1 refused, 2 overwritten,
' 3 ANDed (real flash), 4 something else.
wr2xname:
    DATA "-    REFUSEOVERWAND  ODD  "
