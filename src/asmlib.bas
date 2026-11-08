' asmlib.bas -- CP-1610 routines the tests call with ASM CALL.
'
' Two rules shape this file:
'  * Software references (SW_*) never touch the JLP accelerators, so a test
'    can compare hardware against an answer it computed independently.
'  * Every deliberate accelerator access lives here, written with $9Fxx
'    addresses. tools/lint_accel.py rejects any accelerator address the
'    compiler emits itself (it writes them in decimal) outside
'    jlp_basic_ops, so the harness's own arithmetic can't be fooled by the
'    hardware it is testing.
'
' Each routine pushes R5 and returns with PULR PC; R0-R5 are scratch. The
' interface is a set of 16-bit variables declared in vars.bas.

' ---- SW_MPYUU: #ma * #mb (unsigned) -> #phi:#plo, shift-and-add.
    ASM SW_MPYUU: PROC
    ASM     PSHR R5
    ASM     MVI var_&MA,R0
    ASM     CLRR R1
    ASM     MVI var_&MB,R2
    ASM     CLRR R3
    ASM     CLRR R4
    ASM     MVII #16,R5
    ASM @@lp: SARC R2,1
    ASM     BNC @@sk
    ASM     ADDR R0,R3
    ASM     ADCR R4
    ASM     ADDR R1,R4
    ASM @@sk: SLLC R0,1
    ASM     RLC R1,1
    ASM     DECR R5
    ASM     BNEQ @@lp
    ASM     MVO R3,var_&PLO
    ASM     MVO R4,var_&PHI
    ASM     PULR PC
    ASM     ENDP

' ---- SW_DIVUU: #dn / #dd (unsigned, #dd <> 0) -> #dq, remainder #dr.
    ASM SW_DIVUU: PROC
    ASM     PSHR R5
    ASM     MVI var_&DN,R0
    ASM     MVI var_&DD,R1
    ASM     CLRR R2
    ASM     MVII #16,R5
    ASM @@lp: SLLC R0,1
    ASM     RLC R2,1
    ASM     BC @@sb
    ASM     CMPR R1,R2
    ASM     BNC @@nx
    ASM @@sb: SUBR R1,R2
    ASM     INCR R0
    ASM @@nx: DECR R5
    ASM     BNEQ @@lp
    ASM     MVO R0,var_&DQ
    ASM     MVO R2,var_&DR
    ASM     PULR PC
    ASM     ENDP

' ---- SW_CRC: one CRC-16 step, the JLP way: #crc = step(#crc XOR #cdat).
    ASM SW_CRC: PROC
    ASM     PSHR R5
    ASM     MVI var_&CRC,R0
    ASM     XOR var_&CDAT,R0
    ASM     MVII #16,R5
    ASM @@lp: MOVR R0,R1
    ASM     SLR R0,1
    ASM     ANDI #1,R1
    ASM     BEQ @@nx
    ASM     XORI #$AD52,R0
    ASM @@nx: DECR R5
    ASM     BNEQ @@lp
    ASM     MVO R0,var_&CRC
    ASM     PULR PC
    ASM     ENDP

' ---- SW_CRCBUF: run SW_CRC's step over #rnum words from #rbase into #crc.
    ASM SW_CRCBUF: PROC
    ASM     PSHR R5
    ASM     MVI var_&RBASE,R4
    ASM     MVI var_&RNUM,R3
    ASM     MVI var_&CRC,R0
    ASM @@wd: XOR@ R4,R0
    ASM     MVII #16,R2
    ASM @@lp: MOVR R0,R1
    ASM     SLR R0,1
    ASM     ANDI #1,R1
    ASM     BEQ @@nx
    ASM     XORI #$AD52,R0
    ASM @@nx: DECR R2
    ASM     BNEQ @@lp
    ASM     DECR R3
    ASM     BNEQ @@wd
    ASM     MVO R0,var_&CRC
    ASM     PULR PC
    ASM     ENDP

' ---- HW_OP: write #ma, #mb to the accelerator pair at #mop, read the
'      result words $9F8E/$9F8F into #hlo/#hhi. Same access pattern as
'      IntyBASIC's own multiply: write, write, read at once.
    ASM HW_OP: PROC
    ASM     PSHR R5
    ASM     MVI var_&MOP,R4
    ASM     MVI var_&MA,R0
    ASM     MVO@ R0,R4
    ASM     MVI var_&MB,R0
    ASM     MVO@ R0,R4
    ASM     MVI $9F8E,R0
    ASM     MVO R0,var_&HLO
    ASM     MVI $9F8F,R0
    ASM     MVO R0,var_&HHI
    ASM     PULR PC
    ASM     ENDP

' ---- HW_CRC: JLP CRC unit: $9FFD = #crc, then #rnum words from #rbase
'      into $9FFC, result back into #crc.
    ASM HW_CRC: PROC
    ASM     PSHR R5
    ASM     MVI var_&CRC,R0
    ASM     MVO R0,$9FFD
    ASM     MVI var_&RBASE,R4
    ASM     MVI var_&RNUM,R1
    ASM @@lp: MVI@ R4,R0
    ASM     MVO R0,$9FFC
    ASM     DECR R1
    ASM     BNEQ @@lp
    ASM     MVI $9FFD,R0
    ASM     MVO R0,var_&CRC
    ASM     PULR PC
    ASM     ENDP

' ---- HW_RNG: #rnum reads of $9FFE into the array at #rbase.
    ASM HW_RNG: PROC
    ASM     PSHR R5
    ASM     MVI var_&RBASE,R4
    ASM     MVI var_&RNUM,R1
    ASM @@lp: MVI $9FFE,R0
    ASM     MVO@ R0,R4
    ASM     DECR R1
    ASM     BNEQ @@lp
    ASM     PULR PC
    ASM     ENDP

' ---- RAM_FILL / RAM_CHECK: #rnum words from #rbase hold (address XOR
'      #rseed). CHECK counts mismatches into #rerr and keeps the first bad
'      address in #rfirst. Address-dependent data catches aliasing.
    ASM RAM_FILL: PROC
    ASM     PSHR R5
    ASM     MVI var_&RBASE,R4
    ASM     MVI var_&RNUM,R1
    ASM     MVI var_&RSEED,R2
    ASM @@lp: MOVR R4,R0
    ASM     XORR R2,R0
    ASM     MVO@ R0,R4
    ASM     DECR R1
    ASM     BNEQ @@lp
    ASM     PULR PC
    ASM     ENDP

    ASM RAM_CHECK: PROC
    ASM     PSHR R5
    ASM     MVI var_&RBASE,R4
    ASM     MVI var_&RNUM,R1
    ASM     MVI var_&RSEED,R2
    ASM     CLRR R3
    ASM @@lp: MOVR R4,R0
    ASM     XORR R2,R0
    ASM     CMP@ R4,R0
    ASM     BEQ @@ok
    ASM     TSTR R3
    ASM     BNEQ @@cnt
    ASM     MOVR R4,R5
    ASM     DECR R5
    ASM     MVO R5,var_&RFIRST
    ASM @@cnt: INCR R3
    ASM @@ok: DECR R1
    ASM     BNEQ @@lp
    ASM     MVO R3,var_&RERR
    ASM     PULR PC
    ASM     ENDP

' ---- JF_CMD: one JLP flash command by hand. Sets $8025 = #fl_addr,
'      $8026 = #fl_row, writes #fl_key to the command register #fl_reg, then
'      polls that register flat out until it reads 0.
'      #fl_last  = last value read (0 = done, else gave up after ~1M polls)
'      #fl_keyseen = polls that read the key back. IntyBASIC's own FLASH
'                 code jumps by whatever it reads there, so a key read-back
'                 means FLASH statements would crash on this cart.
'      #fl_polls, #fl_pollshi = poll count.
    ASM JF_CMD: PROC
    ASM     PSHR R5
    ASM     MVI var_&FL_ADDR,R0
    ASM     MVO R0,$8025
    ASM     MVI var_&FL_ROW,R0
    ASM     MVO R0,$8026
    ASM     MVI var_&FL_REG,R1
    ASM     MVI var_&FL_KEY,R5
    ASM     MVO@ R5,R1
    ASM     CLRR R2
    ASM     CLRR R3
    ASM     CLRR R4
    ASM @@lp: MVI@ R1,R0
    ASM     TSTR R0
    ASM     BEQ @@dn
    ASM     CMPR R5,R0
    ASM     BNEQ @@nk
    ASM     INCR R2
    ASM @@nk: INCR R3
    ASM     BNEQ @@lp
    ASM     INCR R4
    ASM     CMPI #16,R4
    ASM     BNEQ @@lp
    ASM @@dn: MVO R0,var_&FL_LAST
    ASM     MVO R2,var_&FL_KEYSEEN
    ASM     MVO R3,var_&FL_POLLS
    ASM     MVO R4,var_&FL_POLLSHI
    ASM     PULR PC
    ASM     ENDP

' ---- JLP_TOGGLE: turn the accelerators off ($8034), look around, turn them
'      back on ($8033). Interrupts stay off throughout and nothing here uses
'      16-bit variables while JLP is off, because those live in JLP RAM.
'      tg_mag  = low byte of $9C00 while off (70 = 'F': mailbox still there)
'      tg_ram  = what #tg_chk read while off: 1 = kept, 2 = $FFFF, 3 = other
'      tg_back = 1 if #tg_chk reads its value again after $8033
    ASM JLP_TOGGLE: PROC
    ASM     PSHR R5
    ASM     DIS
    ASM     MVII #$6A7A,R0
    ASM     MVO R0,$8034
    ASM     MVII #400,R1
    ASM @@w1: DECR R1
    ASM     BNEQ @@w1
    ASM     MVI $9C00,R0
    ASM     ANDI #$FF,R0
    ASM     MVO R0,var_TG_MAG
    ASM     MVI var_&TG_CHK,R0
    ASM     MVII #1,R2
    ASM     CMPI #$1234,R0
    ASM     BEQ @@st
    ASM     INCR R2
    ASM     CMPI #$FFFF,R0
    ASM     BEQ @@st
    ASM     INCR R2
    ASM @@st: MVO R2,var_TG_RAM
    ASM     MVII #$4A5A,R0
    ASM     MVO R0,$8033
    ASM     MVII #400,R1
    ASM @@w2: DECR R1
    ASM     BNEQ @@w2
    ASM     CLRR R2
    ASM     MVI var_&TG_CHK,R0
    ASM     CMPI #$1234,R0
    ASM     BNEQ @@nb
    ASM     INCR R2
    ASM @@nb: MVO R2,var_TG_BACK
    ASM     EIS
    ASM     PULR PC
    ASM     ENDP

' ---- JLP_PROBE: is there 16-bit JLP RAM at #j_chk? Run before anything
'      else trusts a 16-bit variable. jram_ok = 1 if both patterns read back.
    ASM JLP_PROBE: PROC
    ASM     PSHR R5
    ASM     CLRR R2
    ASM     MVII #$A55A,R0
    ASM     MVO R0,var_&J_CHK
    ASM     MVI var_&J_CHK,R1
    ASM     CMPR R0,R1
    ASM     BNEQ @@no
    ASM     MVII #$5AA5,R0
    ASM     MVO R0,var_&J_CHK
    ASM     MVI var_&J_CHK,R1
    ASM     CMPR R0,R1
    ASM     BNEQ @@no
    ASM     INCR R2
    ASM @@no: MVO R2,var_JRAM_OK
    ASM     PULR PC
    ASM     ENDP

' ---- GET_SYSEND: #sys_end = first JLP RAM word IntyBASIC did not allocate.
    ASM GET_SYSEND: PROC
    ASM     MVII #_SYSTEM2,R0
    ASM     MVO R0,var_&SYS_END
    ASM     JR R5
    ASM     ENDP
