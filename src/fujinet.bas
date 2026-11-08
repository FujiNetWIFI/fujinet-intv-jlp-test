' fujinet.bas -- FujiNet mailbox transport for a JLP game.
'
' Derived from the Intellivision FujiNet programmer's guide transport
' (fujinet-manuals intv/fujinet-programmers-guide/listings/fujinet.bas) and
' fujinet-config's intv/fujinet.bas, with three changes for JLP:
'
'  * No ASM MEMATTR line. On a JLP cart $8000-$9FFF is already JLP RAM;
'    declaring [memattr] RAM there makes the cart refuse to boot the game
'    (CONFIG shows JLP CONFLICT).
'  * A transaction is split into fn_begin and fn_poll, so the caller can do
'    JLP work while the cart talks to the ESP32 (fn_transact still blocks).
'  * No multiply, divide or modulo by anything but a power of two: with
'    --jlp those compile to the JLP accelerators, and this transport must
'    keep working while the test is finding out whether they do.
'
' Cells are bytes; always AND 255 on read. SEQ is derived from the cart's
' ACKSEQ, never from a counter of ours: a console reset restarts this
' program but not the cart, so a counter would repeat a stale SEQ.

' fn_begin: start the transaction described by #fn_dev, #fn_cmd, #fn_np,
' #fn_txlen (payload already at MB_TX, parameters already staged).
fn_begin: PROCEDURE
    POKE MB_DEVICE, #fn_dev
    POKE MB_CMD, #fn_cmd
    POKE MB_NPARAM, #fn_np
    POKE MB_TXLO, #fn_txlen AND 255
    POKE MB_TXHI, #fn_txlen / 256
    #fn_seq = (PEEK(MB_ACKSEQ) AND 255) + 1
    IF #fn_seq > 255 THEN #fn_seq = 1
    #fn_t0 = FRAME
    #fn_busy = 1
    #fn_ok = 0
    #fn_err = 0
    POKE MB_SEQ, #fn_seq
END

' fn_poll: one look at the mailbox. Clears #fn_busy when the cart has
' answered (#fn_ok = 1 on ACK, else #fn_err = the cart's FB error) or the
' #fn_limit frame budget ran out (#fn_err = MB_TIMEOUT).
fn_poll: PROCEDURE
    #fn_frames = FRAME - #fn_t0
    IF (PEEK(MB_ACKSEQ) AND 255) = #fn_seq THEN
        #fn_busy = 0
        #fn_rxlen = (PEEK(MB_RXLO) AND 255) + (PEEK(MB_RXHI) AND 255) * 256
        IF (PEEK(MB_REPLY) AND 255) = MB_ACK THEN
            #fn_ok = 1
        ELSE
            #fn_err = (PEEK(MB_ERR) AND 255)
            IF #fn_err = 0 THEN #fn_err = 254
        END IF
        RETURN
    END IF
    IF #fn_frames > #fn_limit THEN
        #fn_busy = 0
        #fn_err = MB_TIMEOUT
        #fn_rxlen = 0
    END IF
END

' fn_transact: fn_begin, then wait a frame at a time for the answer.
fn_transact: PROCEDURE
    GOSUB fn_begin
    WHILE #fn_busy
        WAIT
        GOSUB fn_poll
    WEND
END

' fn_param: parameter #pm_i (0-7), #pm_sz bytes (1, 2 or 4), value #pm_val.
fn_param: PROCEDURE
    POKE MB_PSIZE + #pm_i, #pm_sz
    #tmp3 = MB_PVAL + #pm_i * 4
    POKE #tmp3, #pm_val AND 255
    POKE #tmp3 + 1, #pm_val / 256
    POKE #tmp3 + 2, 0
    POKE #tmp3 + 3, 0
END

' fn_simple: a command with no parameters and no payload.
fn_simple: PROCEDURE
    #fn_np = 0
    #fn_txlen = 0
    GOSUB fn_transact
END

' ---- N: network device -------------------------------------------------

' net_open: open the devicespec in url_text for reading (HTTP GET), no
' end-of-line translation, so binary data arrives intact.
net_open: PROCEDURE
    FOR #ix = 0 TO URL_LEN - 1
        POKE MB_TX + #ix, url_text(#ix)
    NEXT #ix
    #fn_txlen = URL_LEN
    #pm_i = 0 : #pm_sz = 1 : #pm_val = 4 : GOSUB fn_param
    #pm_i = 1 : #pm_sz = 1 : #pm_val = 0 : GOSUB fn_param
    #fn_dev = DEV_NET : #fn_cmd = NC_OPEN : #fn_np = 2
    GOSUB fn_transact
END

' net_status: #net_avail = bytes waiting, #net_err = channel status
' (1 = OK, 136 = end of file). For HTTP the GET itself happens here.
net_status: PROCEDURE
    #pm_i = 0 : #pm_sz = 1 : #pm_val = 0 : GOSUB fn_param
    #pm_i = 1 : #pm_sz = 1 : #pm_val = 0 : GOSUB fn_param
    #fn_dev = DEV_NET : #fn_cmd = NC_STATUS : #fn_np = 2 : #fn_txlen = 0
    GOSUB fn_transact
    #net_avail = 0
    #net_err = 0
    IF #fn_ok THEN
        #net_avail = (PEEK(MB_RX) AND 255) + (PEEK(MB_RX + 1) AND 255) * 256
        #net_err = (PEEK(MB_RX + 3) AND 255)
    END IF
END

' net_read_begin: start a READ of #net_want bytes; the caller finishes it
' with fn_poll (or calls fn_transact's loop itself).
net_read_begin: PROCEDURE
    #pm_i = 0 : #pm_sz = 2 : #pm_val = #net_want : GOSUB fn_param
    #fn_dev = DEV_NET : #fn_cmd = NC_READ : #fn_np = 1 : #fn_txlen = 0
    GOSUB fn_begin
END

net_close: PROCEDURE
    #fn_dev = DEV_NET : #fn_cmd = NC_CLOSE
    GOSUB fn_simple
END

' ---- AppKeys ----------------------------------------------------------
' Open sends the 6-byte struct: creator lo, creator hi, app, key, mode,
' reserved (all six, or the firmware waits for the missing byte). A read
' reply starts with a 2-byte little-endian length.
ak_open: PROCEDURE   ' #tmp = mode: 0 read, 1 write
    POKE MB_TX, AK_CREATOR_LO
    POKE MB_TX + 1, AK_CREATOR_HI
    POKE MB_TX + 2, AK_APP
    POKE MB_TX + 3, AK_KEY
    POKE MB_TX + 4, #tmp
    POKE MB_TX + 5, 0
    #fn_dev = DEV_FUJI : #fn_cmd = FC_AK_OPEN : #fn_np = 0 : #fn_txlen = 6
    GOSUB fn_transact
END
