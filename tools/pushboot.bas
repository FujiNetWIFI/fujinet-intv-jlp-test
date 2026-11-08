' pushboot.bas -- test helper, not part of the test ROM.
'
' Boots /jlpfn-test/jlpfn.bin from FujiNet host slot 1 the way CONFIG
' does (MOUNT_HOST, SET_DEVICE_FULLPATH, MOUNT_IMAGE), so tools/run-tests.sh
' can check a JLP game pushed over the network, not just one loaded from
' the command line. Built without --jlp; it only uses the mailbox.

    CONST MB_SEQ    = $9C03
    CONST MB_ACKSEQ = $9C04
    CONST MB_DEVICE = $9C05
    CONST MB_CMD    = $9C06
    CONST MB_NPARAM = $9C07
    CONST MB_TXLO   = $9C08
    CONST MB_TXHI   = $9C09
    CONST MB_ERR    = $9C0B
    CONST MB_REPLY  = $9C0E
    CONST MB_LINK   = $9C0F
    CONST MB_PSIZE  = $9C10
    CONST MB_PVAL   = $9C20
    CONST MB_TX     = $9C40
    CONST PATH_LEN  = 21

    DIM #seq, #t0, #ok, #ix, #txlen

    GOTO start

' send: transaction to device $70, command #ix, payload #txlen bytes at TX.
send: PROCEDURE
    POKE MB_DEVICE, $70
    POKE MB_CMD, #ix
    POKE MB_TXLO, #txlen AND 255
    POKE MB_TXHI, #txlen / 256
    #seq = (PEEK(MB_ACKSEQ) AND 255) + 1
    IF #seq > 255 THEN #seq = 1
    POKE MB_SEQ, #seq
    #t0 = FRAME
    #ok = 0
    WHILE (PEEK(MB_ACKSEQ) AND 255) <> #seq
        WAIT
        IF FRAME - #t0 > 4000 THEN RETURN
    WEND
    IF (PEEK(MB_REPLY) AND 255) = 6 THEN #ok = 1
END

start:
    CLS
    PRINT AT 0, "PUSHBOOT"
    #t0 = FRAME
    WHILE (PEEK(MB_LINK) AND 255) <> 1
        WAIT
        IF FRAME - #t0 > 900 THEN PRINT AT 40, "NO LINK" : GOTO halt
    WEND

    ' MOUNT_HOST slot 0
    POKE MB_NPARAM, 1 : POKE MB_PSIZE, 1 : POKE MB_PVAL, 0
    #ix = $F9 : #txlen = 0 : GOSUB send
    IF #ok = 0 THEN PRINT AT 40, "MOUNT HOST FAILED" : GOTO halt

    ' SET_DEVICE_FULLPATH device 0, host 0, read; path NUL-padded to 256
    POKE MB_NPARAM, 3
    POKE MB_PSIZE, 1 : POKE MB_PVAL, 0
    POKE MB_PSIZE + 1, 1 : POKE MB_PVAL + 4, 0
    POKE MB_PSIZE + 2, 1 : POKE MB_PVAL + 8, 1
    FOR #ix = 0 TO 255
        POKE MB_TX + #ix, 0
    NEXT #ix
    FOR #ix = 0 TO PATH_LEN - 1
        POKE MB_TX + #ix, boot_path(#ix)
    NEXT #ix
    #ix = $E2 : #txlen = 256 : GOSUB send
    IF #ok = 0 THEN PRINT AT 40, "SET PATH FAILED" : GOTO halt

    ' MOUNT_IMAGE device 0, read: FujiNet pushes the ROM and .cfg and the
    ' cart boots it. We only come back if that failed.
    PRINT AT 40, "PUSHING"
    POKE MB_NPARAM, 2
    POKE MB_PSIZE, 1 : POKE MB_PVAL, 0
    POKE MB_PSIZE + 1, 1 : POKE MB_PVAL + 4, 1
    #ix = $F8 : #txlen = 0 : GOSUB send
    PRINT AT 60, "BOOT FAILED ", <>PEEK(MB_ERR) AND 255

halt:
    WAIT
    GOTO halt

' "/jlpfn-test/jlpfn.bin"
boot_path:
    DATA 47,106,108,112,102,110,45,116,101,115,116,47,106,108,112,102,110,46,98,105,110
