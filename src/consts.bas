' consts.bas -- every CONST in the program.
'
' IntyBASIC is single-pass, so this file is included first. Identifiers are
' case-insensitive, and a CONST silently shadows a variable of the same
' name, so CONSTs carry an upper-case group prefix (MB_, JLP_, T_, ...) that
' no variable uses.

    ' ---- FujiNet mailbox: fujinet-firmware pico/intellivision fuji_mailbox.h
    CONST MB_MAGIC0  = $9C00   ' 'F'
    CONST MB_MAGIC1  = $9C01   ' 'N'
    CONST MB_PROTO   = $9C02   ' 1
    CONST MB_SEQ     = $9C03   ' console: ACKSEQ+1, never 0
    CONST MB_ACKSEQ  = $9C04   ' cart: = SEQ, written last
    CONST MB_DEVICE  = $9C05
    CONST MB_CMD     = $9C06
    CONST MB_NPARAM  = $9C07
    CONST MB_TXLO    = $9C08
    CONST MB_TXHI    = $9C09
    CONST MB_STATUS  = $9C0A
    CONST MB_ERR     = $9C0B
    CONST MB_RXLO    = $9C0C
    CONST MB_RXHI    = $9C0D
    CONST MB_REPLY   = $9C0E   ' $06 ACK / $15 NAK
    CONST MB_LINK    = $9C0F   ' cart rewrites this every service pass
    CONST MB_PSIZE   = $9C10   ' 8 parameter sizes
    CONST MB_PVAL    = $9C20   ' 8 x 4-byte little-endian values
    CONST MB_TX      = $9C40   ' 256 bytes
    CONST MB_RX      = $9D40   ' 512 bytes, ends at $9F3F
    CONST MB_RX_MAX  = 512
    CONST MB_ACK     = $06
    CONST MB_TIMEOUT = 255     ' #fn_err value when the cart never answered

    ' ---- FujiNet devices and commands
    CONST DEV_FUJI      = $70
    CONST DEV_NET       = $71
    CONST DEV_CLOCK     = $45
    CONST FC_WIFISTATUS = $FA
    CONST FC_ADAPTERCFG = $C4  ' GET_ADAPTERCONFIG_EXTENDED, 240 bytes
    CONST FC_AK_OPEN    = $DC
    CONST FC_AK_READ    = $DD
    CONST FC_AK_WRITE   = $DE
    CONST FC_AK_CLOSE   = $DB
    CONST CLK_APETIME   = $93  ' day, month, yy, hour, minute, second
    CONST NC_OPEN       = $4F
    CONST NC_CLOSE      = $43
    CONST NC_READ       = $52
    CONST NC_STATUS     = $53
    CONST NET_EOF       = 136
    ' AppKey creator $0909 (tschak909), app 3 = this test, key 0.
    CONST AK_CREATOR_LO = $09
    CONST AK_CREATOR_HI = $09
    CONST AK_APP        = $03
    CONST AK_KEY        = $00
    CONST AK_LEN        = 64

    ' ---- JLP registers (accelerators are used from ASM only; see
    '      tools/lint_accel.py)
    CONST JLP_FIRST  = $8023   ' FLASH.FIRST: 0 on the cart, 224 in jzIntv
    CONST JLP_LAST   = $8024
    CONST JLP_WRITE  = $802D   ' key $C0DE: JLP RAM -> flash row
    CONST JLP_READ   = $802E   ' key $DEC0: flash row -> JLP RAM
    CONST JLP_ERASE  = $802F   ' key $BEEF: erase the row's 8-row sector
    CONST JLP_SLACK  = $9F40   ' 64 words of JLP RAM between mailbox and accelerators
    CONST JLP_RAMTOP = $9BFF   ' last JLP RAM word below the mailbox
    CONST JLP_MPYSS  = $9F80
    CONST JLP_MPYSU  = $9F82
    CONST JLP_MPYUS  = $9F84
    CONST JLP_MPYUU  = $9F86
    CONST JLP_DIVSS  = $9F88
    CONST JLP_DIVUU  = $9F8A
    CONST KEY_WRITE  = $C0DE
    CONST KEY_READ   = $DEC0
    CONST KEY_ERASE  = $BEEF
    CONST ROW_WORDS  = 96
    CONST FLASH_ROWS = 48      ' FLASH INIT SIZE 6 -> jlpflash = 6 sectors

    ' ---- Flash layout, rows counted from FLASH.FIRST
    CONST FR_PROBE0 = 0        ' sector 0: erase probe low half, write-twice row 1
    CONST FR_PROBE1 = 8        ' sector 1: erase probe high half
    CONST FR_PAY    = 16       ' sectors 2-3: the downloaded payload
    CONST FR_HDR    = 32       ' sector 4: persistence header
    CONST FR_SPARE  = 40       ' sector 5: IntyBASIC FLASH statement test
    CONST PAY_ROWS  = 16
    CONST HDR_MAGIC = $4A46    ' "JF"

    ' ---- Results
    CONST R_NONE = 0
    CONST R_PASS = 1
    CONST R_FAIL = 2
    CONST R_SKIP = 3
    CONST R_INFO = 4

    ' ---- Test numbers (index into #res / #val / #val2)
    CONST T_A1 = 0             ' JLP RAM present, 16 bits, 48 flash rows
    CONST T_A2 = 1             ' mailbox magic + live LINK
    CONST T_A3 = 2             ' IntyBASIC variables end below $9C00
    CONST T_A4 = 3             ' JLP RAM traffic leaves the mailbox alone
    CONST T_A5 = 4             ' $9F40-$9F7F is 16-bit JLP RAM
    CONST T_A6 = 5             ' JLP off/on keeps the mailbox and RAM
    CONST T_B1 = 6             ' RAM march test
    CONST T_B2 = 7             ' multiply
    CONST T_B3 = 8             ' divide
    CONST T_B4 = 9             ' CRC-16
    CONST T_B5 = 10            ' random numbers
    CONST T_B6 = 11            ' flash erase/write/read
    CONST T_B7 = 12            ' erase hits the right sector
    CONST T_B8 = 13            ' flash RAM address range check
    CONST T_B9 = 14            ' IntyBASIC FLASH statements
    CONST T_C1 = 15            ' WiFi status
    CONST T_C2 = 16            ' adapter config
    CONST T_C3 = 17            ' clock
    CONST T_C4 = 18            ' AppKey round trip
    CONST T_C5 = 19            ' N: HTTP download
    CONST T_D1 = 20            ' download with JLP work during every transaction
    CONST T_D2 = 21            ' JLP CRC unit checks the downloaded data
    CONST T_D3 = 22            ' downloaded data to flash and back
    CONST T_D4 = 23            ' last boot's flash copy survived
    CONST T_COUNT = 24

    ' ---- Screen
    CONST CS_BLACK     = 0
    CONST CS_BLUE      = 1
    CONST CS_RED       = 2
    CONST CS_TAN       = 3
    CONST CS_DARKGREEN = 4
    CONST CS_GREEN     = 5
    CONST CS_YELLOW    = 6
    CONST CS_WHITE     = 7
    CONST PAGE_ROWS    = 10
    CONST PAGE_COUNT   = 4     ' three of results, one of details

    ' ---- Controller bytes (whole-byte compares; see the input notes in ui.bas)
    CONST KP_1     = $81
    CONST KP_2     = $41
    CONST KP_3     = $21
    CONST KP_CLEAR = $88
    CONST KP_ENTER = $28
