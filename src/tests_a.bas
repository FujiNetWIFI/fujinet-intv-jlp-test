' tests_a.bas -- A: JLP and the FujiNet mailbox sharing $8000-$9FFF.

' A1: JLP is here: 16-bit RAM (JLP_PROBE already passed, or we would not be
' running) and the flash size the .cfg asked for.
test_a1: PROCEDURE
    #tst = T_A1 : GOSUB running
    #first_row = PEEK(JLP_FIRST)
    #tmp = PEEK(JLP_LAST) - #first_row + 1
    #rv1 = #tmp : #rv2 = #first_row
    IF #tmp = FLASH_ROWS THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' A2: the mailbox. Its magic must read F,N,1, and LINK must be live: the
' cart rewrites LINK on every service pass, so a value it can't produce
' ($A5) must turn into 0 or 1 within a few frames. LINK alone still finds
' a mailbox whose header a JLP RAM clear wiped (IntyBASIC 1.5 --jlp).
test_a2: PROCEDURE
    #tst = T_A2 : GOSUB running
    #mbx_ok = 0 : #mbx_wiped = 0
    POKE MB_LINK, $A5
    FOR #ix = 1 TO 30
        WAIT
        #tmp = PEEK(MB_LINK) AND 255
        IF #tmp < 2 THEN #mbx_ok = 1 : EXIT FOR
    NEXT #ix
    #rv2 = #ix
    #rcode = R_SKIP : #rv1 = 0
    IF #mbx_ok THEN
        #rv1 = #tmp
        #rcode = R_INFO
        #mbx_wiped = 1
        IF (PEEK(MB_MAGIC0) AND 255) = 70 THEN
            IF (PEEK(MB_MAGIC1) AND 255) = 78 THEN
                IF (PEEK(MB_PROTO) AND 255) = 1 THEN #rcode = R_PASS : #mbx_wiped = 0
            END IF
        END IF
    END IF
    GOSUB set_res
END

' A3: IntyBASIC put every 16-bit variable below the mailbox.
test_a3: PROCEDURE
    #tst = T_A3 : GOSUB running
    #rv1 = #sys_end : #rv2 = 0
    IF #sys_end <= $9C00 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' A4: march every free JLP RAM word up to $9BFF and check the mailbox
' header didn't move: no stray SEQ, no transaction, no damage.
test_a4: PROCEDURE
    #tst = T_A4 : GOSUB running
    FOR #ix = 0 TO 31
        #work(#ix) = PEEK(MB_MAGIC0 + #ix) AND 255
    NEXT #ix
    #rbase = #sys_end : #rnum = JLP_RAMTOP - #sys_end + 1
    #errs = 0
    #rseed = $5A5A : ASM CALL RAM_FILL
    ASM CALL RAM_CHECK
    #errs = #errs + #rerr
    #rseed = $A5A5 : ASM CALL RAM_FILL
    ASM CALL RAM_CHECK
    #errs = #errs + #rerr
    #cnt = 0
    FOR #ix = 0 TO 31
        ' LINK may legitimately change; everything else must not.
        IF #ix <> 15 THEN
            IF (PEEK(MB_MAGIC0 + #ix) AND 255) <> #work(#ix) THEN #cnt = #cnt + 1
        END IF
    NEXT #ix
    #rv1 = #rnum : #rv2 = #errs + #cnt
    IF #rv2 = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' A5: the 64 words between the mailbox and the accelerators are ordinary
' 16-bit JLP RAM.
test_a5: PROCEDURE
    #tst = T_A5 : GOSUB running
    #rbase = JLP_SLACK : #rnum = 64 : #errs = 0
    #rseed = $1234 : ASM CALL RAM_FILL
    ASM CALL RAM_CHECK
    #errs = #errs + #rerr
    #rseed = $EDCB : ASM CALL RAM_FILL
    ASM CALL RAM_CHECK
    #errs = #errs + #rerr
    #rv1 = 64 : #rv2 = #errs
    IF #errs = 0 THEN #rcode = R_PASS ELSE #rcode = R_FAIL
    GOSUB set_res
END

' A6: accelerators off ($8034) and on again ($8033). The mailbox must stay
' reachable and our variables must come back. Whether JLP RAM stays
' visible while off differs (the cart keeps it when flash is present; JLP
' and jzIntv hide it), so that part is the value, not the verdict.
test_a6: PROCEDURE
    #tst = T_A6 : GOSUB running
    #tg_chk = $1234
    ASM CALL JLP_TOGGLE
    #rv1 = tg_ram : #rv2 = tg_mag
    #rcode = R_FAIL
    IF tg_back THEN
        IF #mbx_ok = 0 THEN
            #rcode = R_PASS
        ELSEIF #mbx_wiped THEN
            #rcode = R_PASS
        ELSEIF tg_mag = 70 THEN
            #rcode = R_PASS
        END IF
    END IF
    GOSUB set_res
END
