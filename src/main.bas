' main.bas -- JLP + FujiNet coexistence test for the Intellivision.
'
' Exercises JLP (16-bit RAM, multiply/divide, CRC-16, random numbers, save
' flash) and the FujiNet cartridge mailbox in the same $8000-$9FFF window,
' first separately, then at the same time. See README.md and
' docs/JLP-and-FujiNet.md.
'
' Build: make (IntyBASIC 1.4.2 --jlp, as1600). Boot the .bin + .cfg: the
' .cfg carries [vars] jlp = 3, jlpflash = 6 and fujinet = 1; without the
' last one a FujiNet cart switches the mailbox off for a JLP game.
'
' Copyright (C) 2026 Thomas Cherryhomes. GPL-3.0-or-later; see LICENSE.

    GOTO start

    ' Everything below up to start: is declarations, DATA and procedures.
    ' IntyBASIC pastes INCLUDEs in place, so nothing here may be reached by
    ' falling through.
    INCLUDE "src/consts.bas"
    INCLUDE "build/pattern.bas"
    INCLUDE "build/url.bas"
    INCLUDE "src/vars.bas"
    INCLUDE "src/asmlib.bas"
    INCLUDE "src/fujinet.bas"
    INCLUDE "src/ui.bas"
    INCLUDE "src/tests_a.bas"
    INCLUDE "src/tests_b.bas"

    ' $5000-$6FFF ends near here. $7000 must stay unmapped (the EXEC runs
    ' whatever sits there at boot), $8000-$9FFF is JLP's and $E000 the
    ' ECS's, so the rest goes to $D000. make check enforces all of that.
    ASM ORG $D000
    INCLUDE "src/tests_cd.bas"

' jlp_basic_ops: IntyBASIC's own *, / and MOD, which --jlp compiles into
' the accelerators. This is the only procedure where compiled code may
' touch them (tools/lint_accel.py). #bo_mode 0: multiply; 1: divide and
' remainder (#mb <> 0).
jlp_basic_ops: PROCEDURE
    IF #bo_mode = 0 THEN
        #bo_mul = #ma * #mb
    ELSE
        #bo_div = #ma / #mb
        #bo_mod = #ma % #mb
    END IF
END

start:
    ' Nothing may trust a 16-bit variable until this says JLP RAM is here.
    ASM CALL JLP_PROBE
    IF jram_ok = 0 THEN GOTO no_jlp

    FLASH INIT SIZE 6
    ASM CFGVAR "fujinet" = 1
    ASM CALL GET_SYSEND
    #lfsr = $ACE1
    #page = 0
    in_last = CONT

run_all:
    FOR #ix = 0 TO T_COUNT - 1
        #tres(#ix) = R_NONE : #tval(#ix) = 0 : #tval2(#ix) = 0
    NEXT #ix
    #run_done = 0 : #key_total = 0 : #stop_req = 0
    GOSUB draw_page
    GOSUB test_a1
    GOSUB test_a2
    GOSUB test_a3
    GOSUB test_a4
    GOSUB test_a5
    GOSUB test_a6
    GOSUB test_b1
    GOSUB test_b2
    GOSUB test_b3
    GOSUB test_b4
    GOSUB test_b5
    GOSUB test_b6
    GOSUB test_b7
    GOSUB test_b8
    GOSUB test_b9
    GOSUB test_d4
    GOSUB test_c1
    GOSUB test_c2
    GOSUB test_c3
    GOSUB test_c4
    GOSUB test_c5
    GOSUB test_d1
    GOSUB test_d2
    GOSUB test_d3
    GOSUB draw_page
    #run_done = 1

main_loop:
    WAIT
    GOSUB in_poll
    IF #ch = 0 THEN GOTO main_loop
    IF #ch = KP_1 THEN GOTO run_all
    IF #ch = KP_2 THEN GOTO stress
    IF #ch = KP_3 THEN GOSUB next_page : GOTO main_loop
    IF (#ch AND $E0) = 0 THEN GOSUB next_page
    GOTO main_loop

' stress: download with JLP work until CLEAR; every eighth pass also goes
' through flash. Counters: passes, failed passes, JLP ops, JLP errors.
stress:
    #st_pass = 0 : #st_fail = 0 : #st_ops = 0 : #st_errs = 0 : #stop_req = 0
    CLS
    PRINT AT 0 COLOR CS_YELLOW, "STRESS  CLEAR=STOP"
    IF #mbx_ok = 0 THEN
        PRINT AT 40 COLOR CS_RED, "NO MAILBOX"
        GOTO stress_end
    END IF
stress_loop:
    #ju_ops = 0 : #ju_err = 0
    #dl_async = 1
    GOSUB dl_run
    #st_ops = #st_ops + #ju_ops
    #st_errs = #st_errs + #ju_err
    #tmp = 0
    IF #dl_fail THEN #tmp = 1
    IF #dl_bad THEN #tmp = 1
    IF #ju_err THEN #tmp = 1
    IF #tmp = 0 THEN
        #crc = CRC_INIT : #rbase = VARPTR #pay(0) : #rnum = PAT_WORDS
        ASM CALL HW_CRC
        IF #crc <> PAT_CRC THEN #tmp = 1
    END IF
    IF #tmp = 0 THEN
        IF (#st_pass AND 7) = 7 THEN
            GOSUB pay_to_flash
            IF #cnt + #errs THEN #tmp = 1
        END IF
    END IF
    #st_pass = #st_pass + 1
    #st_fail = #st_fail + #tmp
    PRINT AT 40 COLOR CS_TAN, "PASSES"
    PRINT AT 60 COLOR CS_TAN, "FAILED"
    PRINT AT 80 COLOR CS_TAN, "JLP OPS"
    PRINT AT 100 COLOR CS_TAN, "JLP ERR"
    PRINT AT 120 COLOR CS_TAN, "LAST"
    PRINT AT 140 COLOR CS_TAN, "TXN FR"
    #cnt = 5
    #pos = 48 : #hexval = #st_pass : #color = CS_WHITE : GOSUB put_dec
    #pos = 68 : #hexval = #st_fail : #color = CS_RED : GOSUB put_dec
    #pos = 88 : #hexval = #st_ops : #color = CS_WHITE : GOSUB put_dec
    #pos = 108 : #hexval = #st_errs : #color = CS_RED : GOSUB put_dec
    #pos = 128 : #hexval = #dl_fail : #color = CS_WHITE : GOSUB put_dec
    #pos = 148 : #hexval = #dl_txframes : #color = CS_WHITE : GOSUB put_dec
    IF #stop_req THEN GOTO stress_end
    in_c = CONT
    IF in_c = KP_CLEAR THEN GOTO stress_end
    GOTO stress_loop
stress_end:
    PRINT AT 220 COLOR CS_GREEN, "STOPPED. ANY KEY  "
    #stop_req = 0
    DO
        WAIT
        GOSUB in_poll
    LOOP WHILE #ch = 0
    GOSUB draw_page
    GOTO main_loop

no_jlp:
    ' 16-bit variables are unusable here; PRINT literals only.
    CLS
    PRINT AT 0 COLOR CS_RED, "NO JLP RAM AT $8040"
    PRINT AT 40 COLOR CS_WHITE, "BOOT THE .BIN + .CFG"
    PRINT AT 60 COLOR CS_WHITE, "NOT THE .ROM, SO THE"
    PRINT AT 80 COLOR CS_WHITE, "CART SEES JLP = 3."
no_jlp_halt:
    WAIT
    GOTO no_jlp_halt
