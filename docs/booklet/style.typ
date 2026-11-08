// style.typ -- the house style of the FujiNet Programmer's Guide for
// Intellivision (fujinet-manuals intv/fujinet-programmers-guide/manual.typ),
// after the 1983 Mattel Computer Module Owner's Guide. Copied from that
// file's preamble; its set and show rules are wrapped in booklet() because
// rules don't carry across an import.

// ============================================================ palette/fonts
#let magenta   = rgb(210, 38, 84)     // interior frame, heads, code lines
#let magenta-d = rgb(166, 22, 60)
#let pink-pale = rgb(248, 224, 231)   // table shading
#let pink-scr  = rgb(243, 202, 212)   // TV screen mockups
#let cover-red = rgb(203, 21, 44)     // cover stripe red
#let silver    = rgb(219, 216, 211)   // cover ground
#let ink       = rgb(28, 26, 26)

#let f-body  = "ITC Benguiat Gothic Std"
#let f-serif = "C059"
#let f-grom  = "Intellivision GROM"
#let f-mono  = "DejaVu Sans Mono"

#let page-w = 8.67in
#let page-h = 5.71in

// ============================================================ states
#let ch-state  = state("chapter", none)   // (label:, no:, title:) once ch 1 starts

// ============================================================ helpers
#let co(n) = box(baseline: 28%, circle(
  radius: 4pt, fill: magenta,
  align(center + horizon, text(font: f-body, weight: 700, fill: white,
    size: 5.4pt, str(n)))))

#let kcap(l) = box(stroke: 1.1pt + magenta, fill: white,
  inset: (x: 3.6pt, y: 2.2pt), radius: 2.4pt, baseline: 22%,
  text(font: f-body, weight: 700, size: 7.4pt, fill: ink, l))

#let arrow-r = box(baseline: 22%, inset: (x: 2pt), stack(dir: ltr, spacing: 0pt,
  box(height: 7pt, align(horizon, line(length: 14pt, stroke: 1.6pt + ink))),
  polygon(fill: ink, (0pt, 0pt), (0pt, 7pt), (5.5pt, 3.5pt))))

#let arrow-lr = box(baseline: 22%, inset: (x: 2pt), stack(dir: ltr, spacing: 0pt,
  polygon(fill: ink, (5.5pt, 0pt), (5.5pt, 7pt), (0pt, 3.5pt)),
  box(height: 7pt, align(horizon, line(length: 12pt, stroke: 1.6pt + ink))),
  polygon(fill: ink, (0pt, 0pt), (0pt, 7pt), (5.5pt, 3.5pt))))

// hexadecimal in prose
#let hx(s) = text(font: f-mono, size: 0.92em, s)

// inline code
#let cd(s) = text(font: f-mono, size: 0.9em, s)

// period-style program statement + serif-italic explanation
#let stmt(code, expl) = block(breakable: false, above: 9pt, below: 9pt, {
  set par(justify: false)
  show raw: set text(font: f-body, weight: 700, fill: magenta, size: 9.2pt)
  raw(code, block: true)
  v(2.5pt)
  pad(left: 15pt, text(font: f-serif, style: "italic", size: 8.7pt, fill: ink, expl))
})

// TV screen mockup in the GROM font
#let tv(txt, size: 7.4pt, title: none) = align(center, block(
  fill: pink-scr, radius: 6pt, inset: (x: 13pt, y: 10pt),
  stroke: 1.2pt + magenta, breakable: false, {
    set align(left)
    show raw: set text(font: f-grom, size: size, fill: rgb(46, 22, 30))
    set par(leading: 0.32em, justify: false)
    raw(txt, block: true)
  }))

// inline code panel with LISTING-style caption
#let lst-counter = counter("inline-listing")
#let codepanel(title, body-txt, size: 6.6pt) = block(breakable: true,
  above: 11pt, below: 11pt, {
  block(breakable: false, below: 5pt, {
    line(length: 100%, stroke: 2.4pt + magenta)
    v(2.5pt)
    text(font: f-body, weight: 700, fill: magenta, size: 8pt,
      tracking: 0.06em, upper(title))
  })
  show raw: set text(font: f-mono, size: size, fill: ink)
  set par(justify: false, leading: 0.44em, hanging-indent: 12pt)
  raw(body-txt, block: true)
  v(2pt)
  line(length: 100%, stroke: 0.9pt + magenta)
})

// reference entry for one bus command
#let cmd(name, dev: "", code: "", params: (), payload: none, reply: none, body) = {
  block(breakable: true, above: 13pt, below: 9pt, {
    block(breakable: false, {
      box(fill: magenta, radius: (top-left: 3.5pt, bottom-right: 3.5pt),
        inset: (x: 8pt, y: 4pt),
        text(font: f-body, weight: 700, fill: white, size: 9.6pt,
          tracking: 0.05em, upper(name)))
      h(1fr)
      box(fill: ink, radius: 2.6pt, inset: (x: 6pt, y: 3.6pt),
        text(font: f-mono, fill: white, size: 7pt, "DEV " + dev))
      h(3pt)
      box(fill: ink, radius: 2.6pt, inset: (x: 6pt, y: 3.6pt),
        text(font: f-mono, fill: white, size: 7pt, "CMD " + code))
    })
    v(4pt)
    let rows = ()
    for p in params {
      rows.push(text(font: f-mono, size: 7.4pt, p.at(0)))
      rows.push(text(font: f-mono, size: 7.4pt, p.at(1)))
      rows.push(text(size: 8.2pt, p.at(2)))
    }
    if params.len() > 0 {
      table(
        columns: (34pt, 30pt, 1fr),
        stroke: 0.5pt + magenta.lighten(35%),
        inset: (x: 5pt, y: 3.2pt),
        fill: (x, y) => if y == 0 { pink-pale } else { white },
        table.header(
          text(font: f-body, weight: 700, size: 7pt, fill: magenta-d, "PARAM"),
          text(font: f-body, weight: 700, size: 7pt, fill: magenta-d, "SIZE"),
          text(font: f-body, weight: 700, size: 7pt, fill: magenta-d, "VALUE"),
        ),
        ..rows)
      v(2pt)
    }
    if payload != none {
      block(text(size: 8.2pt, [#text(font: f-body, weight: 700, fill: magenta-d,
        size: 7.4pt, "PAYLOAD  ") #payload]))
    }
    if reply != none {
      block(text(size: 8.2pt, [#text(font: f-body, weight: 700, fill: magenta-d,
        size: 7.4pt, "REPLY  ") #reply]))
    }
    if payload != none or reply != none { v(2pt) }
    text(size: 8.6pt, body)
  })
}

// generic wire-format table
#let wire(headers, widths: none, ..rows) = {
  let n = headers.len()
  let cells = ()
  for h in headers {
    cells.push(text(font: f-body, weight: 700, size: 7pt, fill: magenta-d, upper(h)))
  }
  table(
    columns: if widths != none { widths }
             else if n == 4 { (50pt, 62pt, 52pt, 1fr) }
             else if n == 3 { (66pt, 108pt, 1fr) }
             else { (60pt, 1fr) },
    stroke: 0.5pt + magenta.lighten(35%),
    inset: (x: 5pt, y: 3.2pt),
    fill: (x, y) => if y == 0 { pink-pale } else { white },
    table.header(..cells),
    ..rows.pos().flatten().map(c => if type(c) == str {
      text(size: 8pt, c) } else { c }))
}
#let mono7(s) = text(font: f-mono, size: 7.4pt, s)

// note in the period voice
#let note(body) = block(breakable: false, above: 9pt, below: 9pt,
  inset: (left: 10pt), stroke: (left: 2.6pt + magenta),
  text(size: 8.6pt, [#text(font: f-body, weight: 700, fill: magenta-d, "NOTE:  ")#body]))

#let warn(body) = block(breakable: false, above: 9pt, below: 9pt,
  inset: 8pt, fill: pink-pale, radius: 4pt,
  text(size: 8.6pt, [#text(font: f-body, weight: 700, fill: magenta-d, "WATCH OUT:  ")#body]))

// listing appendix renderer with callouts
#let listing-counter = counter("listing")
#let code-listing(title, path, callouts: (:), size: 5.15pt) = {
  listing-counter.step()
  block(breakable: false, above: 14pt, below: 6pt, {
    context {
      box(fill: ink, radius: 3pt, inset: (x: 7pt, y: 4pt),
        text(font: f-body, weight: 700, fill: white, size: 8.6pt,
          "LISTING " + str(listing-counter.get().first())))
    }
    h(7pt)
    text(font: f-body, weight: 700, fill: magenta, size: 9.4pt, title)
  })
  {
    show raw: set text(font: f-mono, size: size, fill: ink)
    set par(justify: false, leading: 0.4em, hanging-indent: 15pt)
    show raw.line: it => {
      box(width: 11pt, align(right,
        text(size: 3.9pt, fill: luma(145), str(it.number))))
      h(3.5pt)
      it.body
      if str(it.number) in callouts {
        h(2.5pt); co(callouts.at(str(it.number)))
      }
    }
    // A comma gains a zero-width break opportunity so the games' long
    // space-free DATA lines can wrap inside a column instead of escaping it.
    columns(2, gutter: 13pt,
      raw(read(path).replace(",", ",\u{200b}"), block: true))
  }
}

// ============================================================ page frame
#let frame-bg = context {
  let phys = here().page()
  // which chapter owns this page: the last level-1 heading at or before it
  let label = none
  for h in query(heading.where(level: 1)) {
    if h.location().page() <= phys { label = h.supplement }
  }
  // ground
  place(rect(width: 100%, height: 100%, fill: white))
  // pinstripes, top and bottom
  for (dy, th) in ((5.2pt, 2.8pt), (10.4pt, 1.7pt), (14.4pt, 1pt)) {
    place(top, dy: dy, line(length: 100%, stroke: th + magenta))
    place(bottom, dy: -dy, line(length: 100%, stroke: th + magenta))
  }
  // magenta frame
  place(top + left, dx: 13pt, dy: 20pt,
    rect(width: page-w - 26pt, height: page-h - 40pt, radius: 12pt, fill: magenta))
  // white content panel
  place(top + left, dx: 21pt, dy: 28pt,
    rect(width: page-w - 42pt, height: page-h - 56pt, radius: 8pt, fill: white))
  if label != none {
    let pg = counter(page).at(here()).first()
    let pill = box(fill: ink, radius: 3.4pt, inset: (x: 8pt, y: 3.8pt),
      text(font: f-body, weight: 700, fill: white, size: 6.8pt,
        tracking: 0.09em, label))
    if calc.odd(pg) {
      place(top + right, dx: -30pt, dy: 24.2pt, pill)
    } else {
      place(top + left, dx: 30pt, dy: 24.2pt, pill)
    }
    // folio, bottom outer corner
    let folio = text(font: f-body, weight: 700, size: 12.5pt, fill: ink, str(pg))
    if calc.odd(pg) {
      place(bottom + right, dx: -32pt, dy: -30pt, folio)
    } else {
      place(bottom + left, dx: 32pt, dy: -30pt, folio)
    }
  }
}

// ============================================================ chapter/section
#let chapter(label, title, blurb) = {
  pagebreak(weak: true)
  ch-state.update((label: upper(label), title: title))
  heading(level: 1, supplement: [#upper(label)], title)
  if blurb != none {
    v(2pt)
    text(font: f-serif, style: "italic", size: 9.2pt, blurb)
    v(6pt)
  }
}

#let sect(t) = heading(level: 2, t)
#let ssect(t) = heading(level: 3, t)

// ============================================================ template
#let booklet(doc) = {
  show heading.where(level: 1): it => {
    block(above: 4pt, below: 10pt, {
      context {
        let ch = ch-state.get()
        if ch != none {
          text(font: f-body, weight: 700, size: 8.4pt, fill: magenta-d,
            tracking: 0.14em, ch.label)
          v(-2pt)
        }
      }
      block(fill: magenta, radius: (top-left: 5pt, bottom-right: 5pt),
        inset: (x: 12pt, y: 6.5pt), width: 100%,
        text(font: f-body, weight: 700, fill: white, size: 15pt,
          tracking: 0.04em, upper(it.body)))
    })
  }
  show heading.where(level: 2): it => block(above: 12pt, below: 7pt,
    box(fill: magenta, radius: (top-left: 3.5pt, bottom-right: 3.5pt),
      inset: (x: 9pt, y: 4.4pt),
      text(font: f-body, weight: 700, fill: white, size: 10pt,
        tracking: 0.05em, upper(it.body))))
  show heading.where(level: 3): it => block(above: 10pt, below: 5pt,
    text(font: f-body, weight: 700, fill: magenta-d, size: 9.6pt,
      tracking: 0.05em, upper(it.body)))
  set text(font: f-body, weight: 400, size: 9.2pt, fill: ink)
  set par(justify: false, leading: 0.52em, spacing: 0.9em)
  set page(width: page-w, height: page-h, margin: (x: 40pt, top: 46pt, bottom: 48pt),
    background: frame-bg)
  set list(marker: box(baseline: -1.5pt, rect(width: 4.6pt, height: 4.6pt, fill: magenta)),
    indent: 6pt, body-indent: 6pt)
  show "→": set text(font: f-mono)  // Benguiat has no arrow
  // Avoid digit-then-apostrophe in prose: smartquote makes it a prime,
  // which Benguiat lacks.
  set enum(indent: 6pt, body-indent: 6pt)
  set table(align: left + top)
  show emph: set text(font: f-serif, style: "italic")
  doc
}
