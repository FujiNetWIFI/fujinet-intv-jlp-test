// JLP + FujiNet: Sharing the Cartridge Window
// A companion to the FujiNet Programmer's Guide for Intellivision, in its
// house style. Build: make (in this directory).

#import "style.typ": *

// table cell text, the size wire() gives plain strings
#let t8(c) = text(size: 8pt, c)
#show: booklet

#set document(title: "JLP + FujiNet: Sharing the Cartridge Window",
  author: "Thomas Cherryhomes")

// ============================================================ COVER
#page(margin: 0pt, background: none, {
  place(rect(width: 100%, height: 100%, fill: silver))
  let stripes(at-top) = {
    let ys = ((6pt, 5pt), (15pt, 3.2pt), (22pt, 2pt), (27.5pt, 1.2pt))
    for (dy, th) in ys {
      if at-top {
        place(top, dy: dy, line(length: 100%, stroke: th + cover-red))
      } else {
        place(bottom, dy: -dy, line(length: 100%, stroke: th + cover-red))
      }
    }
  }
  stripes(true)
  stripes(false)
  place(top + right, dx: -46pt, dy: 64pt,
    box(fill: ink, inset: (x: 16pt, y: 7pt), radius: 2pt, {
      text(font: f-body, weight: 700, fill: white, size: 16pt,
        tracking: 0.06em, "FUJINET")
      h(8pt)
      text(font: f-body, weight: 400, fill: white, size: 7pt,
        tracking: 0.14em, "FOR THE INTELLIVISION")
    }))
  place(top + left, dy: 118pt, {
    let banner = box(fill: ink, inset: (x: 54pt, y: 13pt),
      text(font: f-body, weight: 700, fill: white, size: 25pt,
        tracking: 0.03em, [#box(fill: cover-red, inset: (x: 10pt, y: 4pt),
          radius: 2pt, "JLP + FUJINET")]))
    rotate(-2.2deg, banner)
  })
  place(top + left, dx: 58pt, dy: 196pt,
    text(font: f-body, weight: 500, size: 12pt, fill: ink,
      "Sharing the Cartridge Window"))
  place(bottom + center, dy: -44pt, align(center,
    text(font: f-body, size: 6.6pt, fill: ink, [
      A companion to the FujiNet Programmer's Guide for Intellivision.
      How JLP and the FujiNet mailbox share #hx("$8000")–#hx("$9FFF"),
      and the test cartridge that proves it.\
      FujiNet is a community project. Intellivision is a registered trademark
      of its respective owner; this booklet is not affiliated with or endorsed
      by Mattel.
    ])))
})

// ============================================================ CONTENTS
#page({
  align(center, box(fill: ink, radius: (top-left: 4pt, bottom-right: 4pt),
    inset: (x: 22pt, y: 6pt),
    text(font: f-body, weight: 700, fill: white, size: 12pt,
      tracking: 0.08em, "TABLE OF CONTENTS")))
  v(12pt)
  context {
    for h in query(heading.where(level: 1)) {
      let pg = counter(page).at(h.location()).first()
      block(above: 7pt, below: 0pt, {
        box(width: 74pt, box(fill: ink, radius: 2.6pt, inset: (x: 5pt, y: 2.6pt),
          text(font: f-body, weight: 700, fill: white, size: 6.4pt, h.supplement)))
        text(font: f-body, weight: 500, size: 9pt, h.body)
        box(width: 1fr, repeat(text(fill: magenta, size: 7pt, " .")))
        text(font: f-body, weight: 700, size: 9pt, fill: magenta-d, str(pg))
      })
    }
  }
  v(16pt)
  align(center, text(font: f-serif, style: "italic", size: 9pt,
    "Two tenants, one window, and a lease both of them can read."))
  counter(page).update(0)
})

// ############################################################################
#chapter("Chapter 1", "One Window, Two Tenants", [
  What JLP is, what the FujiNet mailbox is, and why they meet at the same
  addresses.
])

*JLP* is Joe Zbiciak's "Jean-Luc Project" cartridge board. Many homebrew
carts implement it, and IntyBASIC's #cd("--jlp") switch targets it. It gives
a game 8,000 words of 16-bit RAM at #hx("$8040")–#hx("$9F7F"), hardware
multiply and divide, a CRC-16 unit, a random-number register, and save-game
flash in rows of 96 words.

*FujiNet* reaches the Intellivision as a cartridge with two processors: an
RP2040 or RP2350 that answers the console's bus, and an ESP32-S3 running the
FujiNet firmware, joined by USB. Your program talks to FujiNet through the
*mailbox*: 832 words of cartridge RAM at #hx("$9C00")–#hx("$9F3F") with a
header, a 256-byte transmit buffer and a 512-byte receive buffer.

The cartridge emulates JLP as well, so JLP games run on it, and inside the
cartridge JLP RAM and the mailbox are one and the same array. A game that
wants both simply gives up the mailbox's 832 words of JLP RAM.

#wire(("Range", "Owner", "Notes"), widths: (62pt, 46pt, 1fr),
  (mono7("$8000-$803F"), "JLP", "Registers: flash rows, flash commands, accelerators on/off"),
  (mono7("$8040-$9BFF"), "JLP", "7,104 words of RAM for the game"),
  (mono7("$9C00-$9F3F"), "FujiNet", "The mailbox, when the game opts in; otherwise plain JLP RAM"),
  (mono7("$9F40-$9F7F"), "JLP", "64 more words of RAM"),
  (mono7("$9F80-$9FFF"), "JLP", "Multiply/divide, CRC-16, random numbers"),
)

#align(center, image("/img/memory-map.svg", height: 3.7in))

// ############################################################################
#chapter("Chapter 2", "How the Cartridge Decides", [
  The four ways the cart can map #hx("$8000")–#hx("$9FFF"), and the one
  line that chooses between them.
])

When CONFIG boots a game, the ESP32 pushes the ROM *and its .cfg file* to
the cartridge, and the cartridge maps the game from the .cfg. Three
#cd("[vars]") keys matter here: #cd("jlp"), #cd("jlpflash") and
#cd("fujinet").

#wire(("The game's .cfg", "$8000-$9FFF", "Mailbox"), widths: (150pt, 90pt, 1fr),
  ("no jlp or jlpflash", "game ROM/RAM, if any", t8([at #hx("$9C00"), unless the game's own memory covers it])),
  ("jlp, no fujinet", "JLP", "off"),
  ("jlp and fujinet = 1", "JLP", t8([at #hx("$9C00")–#hx("$9F3F")])),
  (t8([jlp and #cd("[memattr]") RAM under #hx("$8000")–#hx("$9FFF")]), "—", "boot fails: JLP CONFLICT"),
)

#note[A JLP game that knows nothing of FujiNet never sees a mailbox, so
nothing it writes to high JLP RAM can start a network transaction. A game
that does know asks for one with #cd("fujinet = 1").]

#warn[Ship a #cd(".bin") and #cd(".cfg"), not a #cd(".rom"). The cart
ignores the metadata in an Intellicart #cd(".rom") when booting over the
network, so a #cd(".rom") gets neither JLP nor the mailbox opt-in.]

#align(center, image("/img/boot-decision.svg", height: 3.7in))

// ############################################################################
#chapter("Chapter 3", "Inside the Cartridge", [
  Which processor answers which address, and what that means for timing.
])

#align(center, image("/img/data-path.svg", height: 3.3in))

Core 1 of the RP2040 or RP2350 does nothing but answer the bus, in time,
every cycle. It serves JLP RAM and the mailbox from the same array, and it
runs the CRC-16 step itself. Everything slower goes to core 0: the multiply
and divide results, the random-number buffer, flash commands (each one a
file operation on the cart's own flash, in #cd("/fl/<game>.save")), and the
mailbox service that ships requests to the ESP32.

How core 0 hears about JLP work depends on the chip:

- *RP2350* (the FujiNet INTV board) rings a doorbell interrupt on every JLP
  register access, so the accelerators answer even while core 0 waits for
  the ESP32.
- *RP2040* (PiRTO II boards) checks for JLP work once per pass of its main
  loop. While it waits on a FujiNet transaction it doesn't check, so
  multiply and divide results and flash commands stall for as long as the
  transaction lasts.

A flash command keeps core 0 busy on both chips; the mailbox simply waits
for it.

// ############################################################################
#chapter("Chapter 4", "Writing a FujiNet-Aware JLP Game", [
  Seven rules, all of them checkable at build time or at boot.
])

#stmt("intybasic --jlp game.bas game.asm", [Build with JLP support. 16-bit
variables move into JLP RAM, starting at #hx("$8040").])

#stmt("FLASH INIT SIZE 6", [If you use save-game flash, size it. IntyBASIC
then writes #cd("jlp = 3") and #cd("jlpflash = 6") into the .cfg.])

#stmt("ASM CFGVAR \"fujinet\" = 1", [Ask for the mailbox. as1600 copies this
into #cd("[vars]") beside #cd("jlp"); the cartridge and jzIntv both read it
there.])

#stmt("as1600 -o game game.asm", [No extension: as1600 writes #cd("game.bin"),
#cd("game.cfg") and #cd("game.rom"). Put the .bin and .cfg side by side on
your FujiNet host.])

#ssect("No MEMATTR")
The FujiNet transport that the non-JLP games share starts with
#cd("ASM MEMATTR $8000, $9BFF, \"+RWN\""). Leave it out: JLP already provides
RAM there, and a #cd("[memattr]") under #hx("$8000")–#hx("$9FFF") stops a JLP
game from booting. The test cartridge's #cd("src/fujinet.bas") is a transport
without it.

#ssect("Stay below $9C00")
IntyBASIC only warns when variables pass #hx("$9F80"), so a large #cd("DIM")
can run straight across the mailbox. Look up #cd("_SYSTEM2") in the .sym
file; it must not exceed #hx("$9C00").

#ssect("SEQ comes from the cart")
#stmt("#fn_seq = (PEEK($9C04) AND 255) + 1\nIF #fn_seq > 255 THEN #fn_seq = 1\nPOKE $9C03, #fn_seq",
  [A console reset restarts your program but not the cartridge, so derive
  each sequence number from the cart's #cd("ACKSEQ"), skipping 0.])

#ssect("Flash rows start at FLASH.FIRST")
The first row is 0 on the cartridge and 224 in jzIntv. Count from
#cd("FLASH.FIRST"), and never point a flash command's RAM address into the
mailbox.

#ssect("Things worth knowing")
- *IntyBASIC 1.5* clears all of #hx("$8040")–#hx("$9F7F") at startup with
  #cd("--jlp"), mailbox header included; 1.4.2 clears only its own
  variables. The mailbox still works, but its #cd("F"), #cd("N") magic is
  gone. The cart rewrites #cd("LINK") (#hx("$9C0F")) on every pass, so a
  #hx("$A5") written there turning back into 0 or 1 proves a live mailbox.
- *Accelerators off* (#hx("$8034")) leaves the mailbox working. On the cart,
  JLP RAM stays visible while they are off if the game has flash; real JLP
  and jzIntv hide it.
- *Multiplication is an accelerator access.* With #cd("--jlp"), #cd("*") by
  anything but a small constant, #cd("/") and #cd("MOD") become JLP register
  accesses. On an RP2040 cart that matters while a transaction is in flight.

// ############################################################################
#chapter("Chapter 5", "The Test Cartridge", [
  Twenty-four tests in four groups, run at power-up.
])

Boot #cd("jlpfn.bin") from CONFIG. The tests run at once, ten to a screen:

#grid(columns: (1fr, 1fr), gutter: 14pt,
  tv("JLP+FUJINET TEST 1/4\nA1 JLP RAM PASS   48\nA2 MAILBOX PASS    1\nA3 VAR TOP PASS 8DDE\nA4 MBXSAFE PASS 3618\nA5 SLACK   PASS   64\nA6 JLP OFF PASS    2\nB1 MARCH   PASS 3618\nB2 MULTPLY PASS   96\nB3 DIVIDE  PASS   48\nB4 CRC16   PASS    8\nP23 F 0 S 0 I 1", size: 6.6pt),
  tv("STRESS  CLEAR=STOP\n\nPASSES     39\nFAILED      0\nJLP OPS   998\nJLP ERR     0\nLAST        0\nTXN FR      1\n\n\n\n", size: 6.6pt),
)

Each test shows PASS, FAIL, SKIP or INFO and one value. Press #kcap("1") to
run them again, #kcap("2") for the stress loop, #kcap("3") or the disc to
turn the page. The fourth page shows the SSID, IP address, firmware
version, time, and flash and transaction timings.

#wire(("Test", "What it proves"), widths: (62pt, 1fr),
  ("A1 JLP RAM", "16-bit JLP RAM is present and flash has the 48 rows the .cfg asked for."),
  ("A2 MAILBOX", t8([The mailbox answers inside the JLP window: magic, and a live #cd("LINK"). If not, every FujiNet test skips.])),
  ("A3 VAR TOP", t8([IntyBASIC's variables end below #hx("$9C00").])),
  ("A4 MBXSAFE", t8([Writing every free JLP RAM word up to #hx("$9BFF") leaves the mailbox header alone.])),
  ("A5 SLACK", t8([#hx("$9F40")–#hx("$9F7F") is full 16-bit JLP RAM.])),
  ("A6 JLP OFF", "Accelerators off and on again: the mailbox stays, variables survive."),
  ("B1 MARCH", "Four address-dependent patterns through all free JLP RAM."),
  ("B2 MULTPLY", t8([All four multiplies against software, plus IntyBASIC's #cd("*").])),
  ("B3 DIVIDE", t8([Signed and unsigned divide and remainder, plus #cd("/") and #cd("MOD").])),
  ("B4 CRC16", "Known answers computed on the host."),
  ("B5 RANDOM", "Not stuck, not repeating every four reads, not zeros."),
  ("B6 FLASH", "Erase, write and read back rows in two sectors, timed."),
  ("B7 ERASE", "Erasing row 8 erases sector 1, not sector 0."),
  ("B8 RANGE", t8([A flash read that would run past #hx("$9F7F") is refused.])),
  ("B9 BASICFL", t8([The same through IntyBASIC's #cd("FLASH") statements.])),
  ("C1–C3", t8([WiFi status, the adapter config, the clock device #hx("$45").])),
  ("C4 APPKEY", "64 fresh bytes written and read back (needs an SD card)."),
  ("C5 HTTPGET", "A 3,072-byte download into JLP RAM, every byte checked."),
  ("D1 ASYNC", "The same download with JLP work running during every READ, every result checked."),
  ("D2 NET CRC", "The JLP CRC unit checks the downloaded data against the host's CRC."),
  ("D3 NET>FL", "The downloaded data to flash and back."),
  ("D4 PERSIST", "At the next power-up, the previous run's flash copy is still there."),
)

// ############################################################################
#chapter("Chapter 6", "Emulators and Known Issues", [
  What jzIntv does now, and what the test cartridge found.
])

Since jzintv pull request 3, FujiNetWIFI's jzIntv models the cartridge,
and the FujiNet Go Intellivision apps follow: the FujiNet peripheral answers
#hx("$9C00")–#hx("$9F3F") only, a JLP game keeps the mailbox only with
#cd("fujinet = 1") in its .cfg (loaded from the command line or pushed by
FujiNet), JLP stands aside on the mailbox, and #cd("LINK") is refreshed
continuously.

Earlier builds put the mailbox on top of JLP. jzIntv ANDs together every
device that answers an address, so the handshake never completed and the
multiply, divide, CRC and random registers read zero. On such a build the
test cartridge finds no mailbox and fails A5, B2–B5 and B8.

#wire(("Issue", "Found by", "Status"), widths: (1fr, 46pt, 62pt),
  (t8([Flash erase picks the sector as row #cd("%") 8, not row / 8]), "B7", "in review (#2335)"),
  ("Flash row and RAM address are not range-checked", "B8", "in review (#2335)"),
  ("RP2040: JLP stalls during a FujiNet transaction", "D1, B9", "fix in progress"),
  ("jzIntv put the mailbox on top of JLP", "A2, A5, B2–B5", "fixed"),
  (t8([#cd("jlp = 2") means accelerators on to the cart, off to JLP]), "—", "open"),
  (t8([An Intellicart #cd(".rom") booted over the network gets no JLP]), "—", "open"),
  ("The cart lets a flash row be written twice without erasing", "B6", "open"),
  (t8([Without flash, #hx("$8033") can't turn the accelerators back on]), "—", "open"),
  ("IntyBASIC 1.5 clears the mailbox at startup", "A2", "open"),
)

#v(8pt)
#align(center, text(font: f-serif, style: "italic", size: 9pt,
  "Source, ROM and the latest version of this booklet:\ngithub.com/FujiNetWIFI/fujinet-intv-jlp-test"))
