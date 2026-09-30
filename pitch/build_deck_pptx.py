"""
build_deck_pptx.py - build an editable PowerPoint version of the DRISHTI deck.

WHY THIS EXISTS
    The presentation artifact of record is `pitch/deck.pdf`, rendered from
    `pitch/deck.html` (11 slides). A PDF is not editable, and the deck has two
    deliberate blanks the team must fill in before submitting: "SIH Team ID"
    on slides 1 and 11. The project documentation also recorded that no
    PowerPoint automation was available, which turned out to be stale - this
    machine has both PowerPoint (COM) and `python-pptx`.

    This script produces `pitch/deck.pptx`: a NATIVE, fully editable deck with
    the same 11 slides, the same approved wording, the same figures and the
    same design language as the HTML/PDF. Nothing here invents content - every
    string is taken from `deck.html` and every figure is embedded from
    `results/`.

    `deck.pdf` remains the artifact of record for presenting. This is the
    editable companion.

USAGE
    python pitch/build_deck_pptx.py
    (run from the repository root)

Design tokens are taken from the `deck.html` stylesheet:
    1280x720 px canvas, Segoe UI, #FFFFFF ground, #0F2A4A headings,
    #40505F body, #7C8B9A eyebrow/muted, #E4E9EE rules.
At 96 px/inch, 1 px == 9525 EMU exactly, so the HTML geometry maps 1:1.
"""

import os
import sys

from pptx import Presentation
from pptx.dml.color import RGBColor
from pptx.enum.shapes import MSO_SHAPE
from pptx.enum.text import MSO_ANCHOR, PP_ALIGN
from pptx.util import Emu, Pt

PX = 9525                      # EMU per px at 96 dpi
SLIDE_W, SLIDE_H = 1280, 720   # matches @page in deck.html
MARGIN_L, MARGIN_R = 56, 56
CONTENT_W = SLIDE_W - MARGIN_L - MARGIN_R

FONT = "Segoe UI"

C_GROUND = RGBColor(0xFF, 0xFF, 0xFF)
C_TEXT = RGBColor(0x1B, 0x24, 0x30)
C_TITLE = RGBColor(0x0F, 0x2A, 0x4A)
C_BODY = RGBColor(0x40, 0x50, 0x5F)
C_MUTED = RGBColor(0x7C, 0x8B, 0x9A)
C_RULE = RGBColor(0xE4, 0xE9, 0xEE)
C_TILE = RGBColor(0xF6, 0xF8, 0xFA)
C_EDGE = RGBColor(0xDD, 0xE4, 0xEA)
C_RED = RGBColor(0xB4, 0x2B, 0x2B)
C_GREEN = RGBColor(0x10, 0x65, 0x6D)
C_AMBER = RGBColor(0x8A, 0x62, 0x00)

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PITCH = os.path.join(ROOT, "pitch")
# Figures live in results/visual_qa/; the Simulink summary is in
# results/presentation/. Resolved per figure so a move is loud, not silent.
FIG_DIRS = [os.path.join(ROOT, "results", "visual_qa"),
            os.path.join(ROOT, "results", "presentation"),
            os.path.join(ROOT, "results")]

DISCLAIMER_SHORT = (
    "Engineering prototype. Not a clinical device. No clinical validation "
    "performed. Not for diagnosis or treatment decisions."
)


def px(v):
    return Emu(int(round(v * PX)))


PX_PER_PT = 0.75          # 96 px/inch / 72 pt/inch
CHAR_W = 0.50             # mean glyph advance as a fraction of font size (pt)
FONT_LINE = 1.25          # rendered line box / font size, for Segoe UI


def est_h(text, size_pt, width_px, line=1.3):
    """Estimated rendered height, in px, of `text` at `size_pt` wrapped to
    `width_px`.

    Font sizes are in points but geometry is in px, so a box sized from the
    font size alone is short by a factor of 1/PX_PER_PT. PowerPoint does not
    clip overflowing text - it draws past the box - so a short box is not
    cosmetic: it lets text run into whatever sits below it. Every multi-line
    body box in this builder is sized from this function so the declared box
    matches what the renderer will actually produce.

    FONT_LINE is the font's own line box relative to its point size; without it
    the estimate is ~25% short on multi-line paragraphs, which is what
    pitch/audit_deck_pptx.ps1 measures as a TEXT OVERFLOW.
    """
    char_px = CHAR_W * size_pt / PX_PER_PT
    per_line = max(1, int(width_px / char_px))
    lines = 0
    for para_text in str(text).split("\n"):
        lines += max(1, -(-len(para_text) // per_line))
    return lines * size_pt * FONT_LINE * line / PX_PER_PT


# --------------------------------------------------------------------------
# primitives
# --------------------------------------------------------------------------
def textbox(slide, x, y, w, h, align=PP_ALIGN.LEFT, anchor=MSO_ANCHOR.TOP):
    box = slide.shapes.add_textbox(px(x), px(y), px(w), px(h))
    tf = box.text_frame
    tf.word_wrap = True
    tf.margin_left = tf.margin_right = tf.margin_top = tf.margin_bottom = 0
    tf.vertical_anchor = anchor
    tf.paragraphs[0].alignment = align
    return box, tf


def para(tf, text, size, color=C_BODY, bold=False, first=False, space_before=0,
         line=None, align=PP_ALIGN.LEFT, italic=False, font=FONT):
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.alignment = align
    if line:
        p.line_spacing = line
    if space_before:
        p.space_before = Pt(space_before)
    r = p.add_run()
    r.text = text
    r.font.size = Pt(size)
    r.font.bold = bold
    r.font.italic = italic
    r.font.color.rgb = color
    r.font.name = font
    return p


def rich(tf, chunks, size, first=False, space_before=0, line=None,
         align=PP_ALIGN.LEFT):
    """chunks: list of (text, color, bold) tuples rendered as one paragraph."""
    p = tf.paragraphs[0] if first else tf.add_paragraph()
    p.alignment = align
    if line:
        p.line_spacing = line
    if space_before:
        p.space_before = Pt(space_before)
    for text, color, bold in chunks:
        r = p.add_run()
        r.text = text
        r.font.size = Pt(size)
        r.font.bold = bold
        r.font.color.rgb = color
        r.font.name = FONT
    return p


def rect(slide, x, y, w, h, fill=None, line=None, line_w=1.0):
    sh = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, px(x), px(y), px(w), px(h))
    sh.shadow.inherit = False
    if fill is None:
        sh.fill.background()
    else:
        sh.fill.solid()
        sh.fill.fore_color.rgb = fill
    if line is None:
        sh.line.fill.background()
    else:
        sh.line.color.rgb = line
        sh.line.width = Pt(line_w)
    sh.text_frame.text = ""
    return sh


def hrule(slide, x, y, w, color=C_RULE, h=1):
    return rect(slide, x, y, w, h, fill=color)


# --------------------------------------------------------------------------
# slide chrome
# --------------------------------------------------------------------------
def new_slide(prs):
    s = prs.slides.add_slide(prs.slide_layouts[6])   # blank
    bg = s.background.fill
    bg.solid()
    bg.fore_color.rgb = C_GROUND
    return s


def header(slide, eyebrow, title_runs):
    _, tf = textbox(slide, MARGIN_L, 38, CONTENT_W, 18)
    para(tf, eyebrow.upper(), 10.5, C_MUTED, bold=True, first=True)
    # Titles wrap to two lines at this measure, so the box is sized for two
    # lines of 23 pt (2 * 23 * 1.1 = 50.6 pt = 67 px) and the rule sits clear
    # of the rendered text, not merely clear of the nominal box.
    _, tf = textbox(slide, MARGIN_L, 58, CONTENT_W, 80)
    if isinstance(title_runs, str):
        para(tf, title_runs, 23, C_TITLE, bold=True, first=True, line=1.1)
    else:
        rich(tf, title_runs, 23, first=True, line=1.1)
    rect(slide, MARGIN_L, 142, 62, 3, fill=C_TITLE)


def lede(slide, y, text, w=CONTENT_W, size=12.0):
    h = est_h(text, size, w, line=1.4)
    _, tf = textbox(slide, MARGIN_L, y, w, h)
    para(tf, text, size, C_BODY, first=True, line=1.4)
    return y + h


def footer(slide, page, note=DISCLAIMER_SHORT):
    hrule(slide, MARGIN_L, SLIDE_H - 46, CONTENT_W)
    _, tf = textbox(slide, MARGIN_L, SLIDE_H - 38, CONTENT_W - 40, 26)
    para(tf, note, 7.5, C_MUTED, first=True, line=1.25)
    _, tf = textbox(slide, SLIDE_W - MARGIN_R - 30, SLIDE_H - 38, 30, 14,
                    align=PP_ALIGN.RIGHT)
    para(tf, str(page), 8.5, C_MUTED, bold=True, first=True)


# --------------------------------------------------------------------------
# content blocks
# --------------------------------------------------------------------------
def kpi(slide, x, y, w, h, value, label, vcolor=C_TITLE, vsize=19):
    """KPI tile. The value and label boxes are laid out against measured
    rendered heights so they cannot overlap: the value occupies the top band
    and the label the bottom band, with the split derived from vsize."""
    rect(slide, x, y, w, h, fill=C_TILE, line=C_EDGE)
    vh = vsize * 1.25 / PX_PER_PT          # rendered height of the value line
    _, tf = textbox(slide, x + 12, y + 8, w - 24, vh)
    para(tf, value, vsize, vcolor, bold=True, first=True)
    label_top = y + 8 + vh + 2
    lh = est_h(label, 8, w - 24, line=1.2)
    _, tf = textbox(slide, x + 12, label_top, w - 24, lh)
    para(tf, label, 8, C_MUTED, first=True, line=1.2)


def kpi_row(slide, y, h, items, cols=None, x0=MARGIN_L, total_w=CONTENT_W,
            gap=10, vsize=19):
    """items: (value, label) or (value, label, value_colour)."""
    cols = cols or len(items)
    w = (total_w - gap * (cols - 1)) / cols
    for i, item in enumerate(items):
        value, label = item[0], item[1]
        vcolor = item[2] if len(item) > 2 else C_TITLE
        kpi(slide, x0 + i * (w + gap), y, w, h, value, label, vcolor=vcolor,
            vsize=vsize)


def bullet_card(slide, x, y, w, h, head, body, accent=C_TITLE, head_size=10.5,
                body_size=9.0):
    rect(slide, x, y, w, h, fill=C_TILE, line=C_EDGE)
    rect(slide, x, y, 3, h, fill=accent)
    _, tf = textbox(slide, x + 14, y + 11, w - 26, 18)
    para(tf, head, head_size, C_TITLE, bold=True, first=True)
    _, tf = textbox(slide, x + 14, y + 32, w - 26, h - 42)
    para(tf, body, body_size, C_BODY, first=True, line=1.35)


def table(slide, x, y, w, col_w, rows, header_row, row_h=30, header_h=26,
          font_size=8.0, header_size=8.0):
    """Lightweight hand-drawn table: full control, no PowerPoint table styling."""
    n = len(col_w)
    scale = w / float(sum(col_w))
    widths = [int(c * scale) for c in col_w]
    # header
    rect(slide, x, y, w, header_h, fill=RGBColor(0xEF, 0xF3, 0xF7))
    cx = x
    for i, cell in enumerate(header_row):
        _, tf = textbox(slide, cx + 9, y + 7, widths[i] - 14, header_h - 10)
        para(tf, cell, header_size, C_MUTED, bold=True, first=True)
        cx += widths[i]
    # body
    ry = y + header_h
    for r_i, row in enumerate(rows):
        if r_i % 2 == 1:
            rect(slide, x, ry, w, row_h, fill=C_TILE)
        cx = x
        for i, cell in enumerate(row):
            _, tf = textbox(slide, cx + 9, ry + 6, widths[i] - 14,
                            row_h - 8, anchor=MSO_ANCHOR.TOP)
            bold = (i == 2)
            col = C_TEXT if bold else C_BODY
            para(tf, cell, font_size, col, bold=bold, first=True, line=1.25)
            cx += widths[i]
        hrule(slide, x, ry + row_h, w)
        ry += row_h
    return ry


def picture(slide, name, x, y, w, h):
    path = None
    for d in FIG_DIRS:
        cand = os.path.join(d, name)
        if os.path.exists(cand):
            path = cand
            break
    if path is None:
        print("  MISSING FIGURE: %s" % name)
        return None
    return slide.shapes.add_picture(path, px(x), px(y), px(w), px(h))


# ==========================================================================
# slides
# ==========================================================================
def slide1(prs):
    s = new_slide(prs)
    rect(s, 0, 0, SLIDE_W, 8, fill=C_GREEN)
    _, tf = textbox(s, MARGIN_L, 150, CONTENT_W, 20)
    para(tf, "SMART INDIA HACKATHON 2026  *  NATIONAL SCREENING STAGE", 11,
         C_MUTED, bold=True, first=True)
    _, tf = textbox(s, MARGIN_L, 176, CONTENT_W, 92)
    para(tf, "DrishtiCare", 54, C_TITLE, bold=True, first=True)
    rect(s, MARGIN_L, 278, 62, 3, fill=C_TITLE)
    sub1 = ("Quality-aware, explainable diabetic-retinopathy screening for "
            "rural healthcare workflows - built in MATLAB and Simulink.")
    _, tf = textbox(s, MARGIN_L, 298, 820, est_h(sub1, 14, 820, line=1.45))
    para(tf, sub1, 14, C_BODY, first=True, line=1.45)

    items = [("Problem statement", "SIH 26038"),
             ("Sponsor", "MathWorks"),
             ("Team", "6 members + mentors"),
             ("SIH Team ID", "________________")]
    w = (CONTENT_W - 12 * 3) / 4
    for i, (k, v) in enumerate(items):
        x = MARGIN_L + i * (w + 12)
        rect(s, x, 380, w, 62, fill=C_TILE, line=C_EDGE)
        _, tf = textbox(s, x + 12, 392, w - 24, 14)
        para(tf, k, 8, C_MUTED, first=True)
        _, tf = textbox(s, x + 12, 410, w - 24, 22)
        para(tf, v, 12, C_TITLE, bold=True, first=True)

    rect(s, MARGIN_L, 496, CONTENT_W, 74, fill=RGBColor(0xFD, 0xF2, 0xF2),
         line=RGBColor(0xE8, 0xC8, 0xC8))
    _, tf = textbox(s, MARGIN_L + 14, 510, CONTENT_W - 28, 52)
    rich(tf, [("ENGINEERING PROTOTYPE - NOT A CLINICAL DEVICE. ", C_RED, True),
              ("No clinical validation has been performed. Grades, Grad-CAM "
               "overlays, OOD flags and lesion candidate counts are "
               "engineering demonstrations and must not be used for diagnosis, "
               "treatment or triage decisions.", C_BODY, False)],
         9.5, first=True, line=1.4)
    return s


def slide2(prs):
    s = new_slide(prs)
    header(s, "The problem, and what we actually built",
           [("Diabetic retinopathy is found late, because ", C_TITLE, True),
            ("screening capacity is the constraint", C_MUTED, False)])
    y = lede(s, 162, "Where the load actually falls", size=12.0) + 18

    t1 = ("At the planning assumption of 100,000 patients a year, our own "
          "measured operating point generates 153.6 specialist referrals per "
          "working day - 38,406 a year.")
    t2 = ("General ophthalmology is not the binding constraint. For "
          "vitreoretinal grading it is retina specialists, at roughly one per "
          "1.26 million population.")
    h1 = est_h(t1, 11.5, 560, line=1.45)
    h2 = est_h(t2, 11.5, 560, line=1.45)
    _, tf = textbox(s, MARGIN_L, y, 560, h1)
    rich(tf, [("At the planning assumption of 100,000 patients a year, our own "
               "measured operating point generates ", C_BODY, False),
              ("153.6 specialist referrals per working day", C_TITLE, True),
              (" - 38,406 a year.", C_BODY, False)], 11.5, first=True,
         line=1.45)
    _, tf = textbox(s, MARGIN_L, y + h1 + 6, 560, h2)
    rich(tf, [("General ophthalmology is not the binding constraint. For "
               "vitreoretinal grading it is retina specialists, at roughly ",
               C_BODY, False),
              ("one per 1.26 million", C_TITLE, True),
              (" population.", C_BODY, False)], 11.5, first=True, line=1.45)

    # the reframed question
    q1 = ('So the useful question is not "can a CNN grade a retina". It is '
          'what does the system do with an image it should not answer?')
    qh = est_h(q1, 11, 556, line=1.4)
    rect(s, 640, y, 584, qh + 24, fill=C_TILE, line=C_EDGE)
    _, tf = textbox(s, 654, y + 12, 556, qh)
    rich(tf, [('So the useful question is not "can a CNN grade a retina". '
               'It is ', C_BODY, False),
              ("what does the system do with an image it should not answer?",
               C_TITLE, True)], 11, first=True, line=1.4)

    a1 = ("Our answer: a screening workflow whose quality gate runs before the "
          "model. A poor or unfamiliar image is withheld for recapture rather "
          "than graded. That refusal behaviour - not the classifier - is the "
          "product.")
    ah = est_h(a1, 10, 556, line=1.4)
    rect(s, 640, y + qh + 36, 584, ah + 24, fill=C_GROUND, line=C_GREEN,
         line_w=1.5)
    _, tf = textbox(s, 654, y + qh + 48, 556, ah)
    rich(tf, [("Our answer: ", C_GREEN, True),
              ("a screening workflow whose ", C_BODY, False),
              ("quality gate runs before the model", C_GREEN, True),
              (". A poor or unfamiliar image is withheld for recapture rather "
               "than graded. That refusal behaviour - not the classifier - is "
               "the product.", C_BODY, False)], 10, first=True, line=1.4)

    # the two real cases
    cardY = 404
    for i, (label, tone, note, img) in enumerate([
            ("Graded", C_GREEN,
             "Quality PASS. The image proceeds to grading, referral routing "
             "and evidence.", "04_PASS_fundus.png"),
            ("Withheld", C_RED,
             "Quality FAIL. The classifier is never invoked, no grade is "
             "produced, and the case is routed to recapture or manual review.",
             "04_FAIL_fundus.png")]):
        x = MARGIN_L + i * 300
        rect(s, x, cardY, 280, 212, fill=C_TILE, line=C_EDGE)
        picture(s, img, x + 10, cardY + 10, 260, 166)
        _, tf = textbox(s, x + 12, cardY + 184, 256, 16)
        para(tf, label, 10, tone, bold=True, first=True)
        _, tf = textbox(s, x + 12, cardY + 202, 256,
                        est_h(note, 8, 256, line=1.3))
        para(tf, note, 8, C_BODY, first=True, line=1.3)

    _, tf = textbox(s, 640, 404, 584, 60)
    para(tf, "Both images are real fundus photographs from the locked APTOS "
             "validation split, captured by the running application "
             "(results/visual_qa/).", 8.5, C_MUTED, first=True, line=1.35)
    _, tf = textbox(s, 640, 474, 584, 76)
    para(tf, "Referral demand: data/analysis/simulink_resource_simulation/"
             "scenario_results.csv, row D100. Workforce constraint: Vashist "
             "et al. 2021, citing WHO 2020. Full citations on the impact slide.",
         8.5, C_MUTED, first=True, line=1.35)

    footer(s, 2)
    return s


def slide3(prs):
    s = new_slide(prs)
    header(s, "The workflow",
           [("The quality gate runs ", C_TITLE, True),
            ("before", C_MUTED, False),
            (" the AI, not after it", C_TITLE, True)])
    lede(s, 162, "This ordering is the whole design. A screening system that "
                 "grades every image it is handed has no way to say "
                 "\u201cI don't know\u201d.", size=11.5)

    steps = [("IMAGE", "fundus photograph", C_TITLE),
             ("QUALITY", "focus * brightness * foreground fraction", C_TITLE),
             ("AI", "5-class grade + referable score", C_TITLE),
             ("REFERRAL", "referable rule locked at 0.60", C_TITLE),
             ("EVIDENCE", "model attention * lesion candidates", C_TITLE),
             ("HUMAN", "specialist review", C_GREEN)]
    w, gap = 186, 10
    for i, (name, sub, tone) in enumerate(steps):
        x = MARGIN_L + i * (w + gap)
        rect(s, x, 190, w, 74, fill=C_TILE, line=C_EDGE)
        _, tf = textbox(s, x + 12, 204, w - 24, 16)
        para(tf, name, 10, tone, bold=True, first=True)
        _, tf = textbox(s, x + 12, 224, w - 24, 36)
        para(tf, sub, 8, C_BODY, first=True, line=1.25)
        if i < len(steps) - 1:
            _, tf = textbox(s, x + w, 216, gap, 20, align=PP_ALIGN.CENTER)
            para(tf, ">", 12, C_MUTED, bold=True, first=True)

    rect(s, MARGIN_L, 278, CONTENT_W, 46, fill=RGBColor(0xFD, 0xF2, 0xF2),
         line=RGBColor(0xE8, 0xC8, 0xC8))
    _, tf = textbox(s, MARGIN_L + 14, 290, CONTENT_W - 28, 30)
    rich(tf, [("WITHHELD", C_RED, True),
              ("   AI never executed * grade stays NaN. RECAPTURE / MANUAL are "
               "the only safe outcomes for a FAIL image.", C_BODY, False)],
         10, first=True, line=1.35)

    notes = [
        ("Quality FAIL is a hard gate, not a display setting.",
         "The classifier is never invoked, no Grad-CAM is computed, and the "
         "output carries an explicit withheld state rather than a silent blank."),
        ("Referral is a locked rule.",
         "Referable is P(referable) >= 0.60. The threshold is provenance-pinned "
         "and was not retuned."),
        ("Uncertainty is routed, not averaged away.",
         "The cascade router sends borderline cases to REVIEW and the least "
         "confident to ABSTAIN."),
    ]
    bw = (CONTENT_W - 20 * 2) / 3
    for i, (h_, b_) in enumerate(notes):
        bullet_card(s, MARGIN_L + i * (bw + 20), 338, bw, 92, h_, b_,
                    accent=C_GREEN, head_size=9.5, body_size=8.5)

    picture(s, "05_report_preview.png", MARGIN_L, 444, 300, 200)
    _, tf = textbox(s, 400, 448, 824, 80)
    para(tf, "The branded A4 report is a real artifact written to disk from the "
             "same result struct that drives the screen - seven sections "
             "including the non-clinical disclaimer.", 10, C_BODY, first=True,
         line=1.4)
    _, tf = textbox(s, 400, 534, 824, 100)
    para(tf, "In the shipped path the model input is the raw resized image. "
             "Enhancement is a display aid only, because the A/B experiment "
             "showed enhancement measurably hurt grading "
             "(docs/task-tracker.md Task 9B).", 9, C_MUTED, first=True,
         line=1.4)

    footer(s, 3)
    return s


def slide4(prs):
    s = new_slide(prs)
    header(s, "Feasibility", [("What is built and measured, ", C_TITLE, True),
                              ("and what is not", C_MUTED, False)])
    lede(s, 162, "Built: running, measured, verified.   Planned / blocked: "
                 "named blocker, named owner - not hidden, not silently dropped.",
         size=11)

    built = [
        ("Hardening programme P0-P25", "230/230 checks PASS"),
        ("Image quality gate", "3,662 images: PASS 65.48% / WARNING 26.68% / "
                               "FAIL 7.84%"),
        ("5-class DR grader", "ResNet-18, EyePACS-pretrained. QWK 0.8914 on the "
                              "locked 733-image split"),
        ("Binary referable classifier", "sensitivity 0.9060 / specificity 0.9471 "
                                        "at the locked 0.60 threshold"),
        ("OOD advisory detector", "Mahalanobis, locked p99 34.22. Surfaces in the "
                                  "narrative; never alters a route"),
        ("Cascade router", "CLEAR 648 / REVIEW 75 / ABSTAIN 10"),
        ("Temperature calibration", "T = 2.5382, display-only"),
        ("Grad-CAM, lesion evidence, Branch B", "running, weaknesses documented"),
        ("Dashboard and branded A4 report", "headless verification 35/35 PASS; "
                                            "report verification PASS"),
        ("Simulink district model", "a genuine .slx reproducing its reference "
                                    "engine over 250 days; 11/11 checks PASS"),
        ("Unseen-input rehearsal harness", "19 foreign-camera images, 4/4 "
                                           "contract checks PASS"),
    ]
    _, tf = textbox(s, MARGIN_L, 198, 600, 20)
    para(tf, "BUILT", 10, C_GREEN, bold=True, first=True)
    y = 222
    for h_, b_ in built:
        rect(s, MARGIN_L, y, 3, 36, fill=C_GREEN)
        _, tf = textbox(s, MARGIN_L + 12, y + 1, 588, 16)
        para(tf, h_, 9, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, MARGIN_L + 12, y + 18, 588, 18)
        para(tf, b_, 8, C_BODY, first=True, line=1.25)
        y += 40

    blocked = [
        ("External validation - BLOCKED, not performed.",
         "Messidor-2 needs ADCIS registration; Sin-NP DR 2019 needs a data "
         "request. Owner: team, on dataset licensing. Harness written, 6/6."),
        ("Minority-recall experiments - deliberately switched off.",
         "Target-boosted weighting and targeted augmentation on Severe and "
         "Proliferative are disabled in the training script by operator "
         "decision. Owner: mentor approval."),
        ("Grad-CAM localisation agreement - measured, and weak.",
         "Saliency-in-lesion 3.1%, pointing game 7.4%, mean IoU 0.035. MACE not "
         "measured. We did not retrain to chase a better number."),
        ("Fovea localisation - failed.",
         "0 of 10 held-out images within 300 px. The pipeline therefore emits no "
         "fovea-derived distance. Revisit if fovea-labelled data appears."),
        ("Image enhancement - excluded on evidence.",
         "The A/B experiment showed it degraded grading, so the deployed path "
         "feeds the model the raw resized image."),
        ("Vessel segmentation in production - excluded on evidence.",
         "Adding vessel features reduced Branch-B AUC from 0.8969 to 0.8810, so "
         "the branch ships without them. Negative result kept in the record."),
    ]
    _, tf = textbox(s, 700, 198, 524, 20)
    para(tf, "PLANNED / BLOCKED", 10, C_AMBER, bold=True, first=True)
    y = 222
    for h_, b_ in blocked:
        rect(s, 700, y, 3, 60, fill=C_AMBER)
        _, tf = textbox(s, 712, y + 1, 512, 16)
        para(tf, h_, 9, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, 712, y + 18, 512, 42)
        para(tf, b_, 8, C_BODY, first=True, line=1.25)
        y += 64

    footer(s, 4)
    return s


def slide5(prs):
    s = new_slide(prs)
    header(s, "Measured performance", [("Locked 733-image validation split, ",
                                        C_TITLE, True),
                                       ("seed 42", C_MUTED, False)])
    lede(s, 162, "Every figure below is frozen under a written contract: no "
                 "retuning of the threshold or the calibration temperature, and "
                 "no use of the sealed official test set.", size=10.5)

    kpi_row(s, 190, 62, [
        ("0.8281", "Accuracy"), ("0.6805", "Macro F1"),
        ("0.8914", "Quadratic weighted kappa"), ("0.9060", "Sensitivity, referable DR"),
        ("0.9471", "Specificity, referable DR"), ("0.9796", "ROC-AUC"),
        ("0.7821", "PR-AUC"),
    ], vsize=17)
    kpi_row(s, 260, 54, [
        ("0.60", "Referral threshold - locked, provenance-pinned"),
        ("2.5382", "Calibration temperature - display-only"),
        ("733", "Validation images (2,929 train, seed 42)"),
    ], vsize=17)

    _, tf = textbox(s, MARGIN_L, 328, CONTENT_W, 20)
    para(tf, "PER-CLASS RECALL - WHERE THE WEAKNESS IS", 9.5, C_MUTED, bold=True,
         first=True)
    kpi_row(s, 350, 84, [
        ("0.9834", "No DR", C_TITLE),
        ("0.6081", "Mild NPDR", C_TITLE),
        ("0.7850", "Moderate NPDR", C_TITLE),
        ("0.4872", "Severe NPDR - weak, main 5-class weakness", C_RED),
        ("0.5254", "Proliferative DR - weak, experiments off", C_RED),
    ], vsize=16)

    _, tf = textbox(s, MARGIN_L, 446, CONTENT_W, 20)
    para(tf, "OPERATIONAL BEHAVIOUR, MEASURED", 9.5, C_MUTED, bold=True,
         first=True)
    kpi_row(s, 468, 56, [
        ("65.48 / 26.68 / 7.84 %", "Quality gate, n = 3,662"),
        ("648 / 75 / 10", "CLEAR / REVIEW / ABSTAIN"),
        ("34.22", "OOD bound (locked p99)"),
        ("0.1028 s/img", "Model-only inference"),
        ("11.03 s/img", "Full demo path, median"),
    ], vsize=13)
    _, tf = textbox(s, MARGIN_L, 534, 900, 18)
    para(tf, "Verdict on APTOS validation: internal, single-dataset.", 8.5,
         C_MUTED, italic=True, first=True)

    _, tf = textbox(s, MARGIN_L, 562, CONTENT_W, 44)
    para(tf, "The two latency figures are deliberately not conflated: 0.1028 "
             "s/img is model screening only, 11.03 s/img is the complete demo "
             "path. High-resolution fundus photographs are slower again - a "
             "judge supplying a full-resolution image should expect roughly "
             "30-45 s.", 9, C_MUTED, first=True, line=1.4)

    footer(s, 5, "Engineering prototype. APTOS-internal held-out validation "
                 "only; external validation is not performed. Not a clinical "
                 "device, not for diagnosis or treatment decisions.")
    return s


def slide6(prs):
    s = new_slide(prs)
    header(s, "The differentiator",
           [("It refuses. We tested that on ", C_TITLE, True),
            ("images it had never seen", C_MUTED, False)])
    lede(s, 162, "Every automated check in this project had run on the same "
                 "split the champions were selected on. We then ran the full "
                 "pipeline end to end on 19 unseen fundus images from three "
                 "foreign cameras - DRIVE test, the IDRiD B testing set, and "
                 "real-world web fundus from DRIMDB. Nothing was retrained or "
                 "tuned, the 0.60 rule was untouched, and the model hashes are "
                 "unchanged.", size=9.5)

    kpi_row(s, 200, 88, [
        ("19 / 19", "completed. No crash, no unhandled exception."),
        ("4 / 4", "contract checks PASS: valid route band, quality FAIL never "
                  "auto-answered, locked 0.60 rule still holds."),
        ("8", "quality FAIL images - every one withheld before any model "
              "execution."),
        ("42%", "of unseen images withheld, against 7.84% FAIL on APTOS. The "
                "gate over-rejects foreign cameras."),
    ], vsize=20)

    findings = [
        ("The safety contract is not an APTOS artefact.",
         "Every quality FAIL was withheld before the model ran, and the locked "
         "decision rule was reproduced on every image that did reach the "
         "classifier.", C_GREEN),
        ("The OOD detector genuinely fires out of distribution.",
         "It flagged unseen images above its locked 34.22 bound. It remains "
         "advisory only and altered no route in this run.", C_GREEN),
        ("Over-refusal is the safe direction to fail.",
         "A withheld image is never auto-answered. Expect \u201cAI grading "
         "skipped, please recapture\u201d - that is the designed behaviour.",
         C_GREEN),
        ("The honest negative finding.",
         "One DRIMDB image the dataset itself labels as ungradable passed the "
         "quality gate and came back a confident referable grade, routed CLEAR, "
         "with its OOD distance just under the bound. Neither gate caught it, and "
         "we are not tuning it away - the threshold and the OOD bound are "
         "provenance-pinned.", C_RED),
    ]
    y = 296
    for h_, b_, tone in findings:
        bh = est_h(b_, 8.5, 600, line=1.3)
        rect(s, MARGIN_L, y, 3, 18 + bh, fill=tone)
        _, tf = textbox(s, MARGIN_L + 12, y, 600, 16)
        para(tf, h_, 9.5, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, MARGIN_L + 12, y + 18, 600, bh)
        para(tf, b_, 8.5, C_BODY, first=True, line=1.3)
        y += 18 + bh + 10

    for i, (name, note) in enumerate([
            ("PASS", "graded and routed, with confidence and evidence."),
            ("WARNING", "proceeds, but flagged as borderline."),
            ("FAIL", "AI grading skipped; the model is never called.")]):
        y0 = 296 + i * 62
        rect(s, 660, y0, 564, 56, fill=C_TILE, line=C_EDGE)
        _, tf = textbox(s, 674, y0 + 10, 120, 18)
        para(tf, name, 10, C_GREEN if i == 0 else (C_AMBER if i == 1 else C_RED),
             bold=True, first=True)
        _, tf = textbox(s, 674, y0 + 30, 536, 20)
        para(tf, note, 8.5, C_BODY, first=True)
        picture(s, ["02_PASS_dashboard.png", "02_WARNING_dashboard.png",
                    "02_FAIL_dashboard.png"][i], 1090, y0 + 4, 130, 48)

    footer(s, 6)
    return s


def slide7(prs):
    s = new_slide(prs)
    header(s, "Explainability",
           [("Grad-CAM shows model attention. ", C_TITLE, True),
            ("It is not lesion localisation.", C_MUTED, False)])
    lede(s, 162, "Four views of one real case from the running application. The "
                 "heat-map is a statement about where the model looked, not "
                 "about where a lesion is - and we measured how far apart those "
                 "two things are.", size=10.5)

    views = [("03_PASS_Original.png", "Original", "the model input, unchanged."),
             ("03_PASS_Enhanced.png", "Enhanced",
              "display aid only. Not the model input."),
             ("03_PASS_Grad-CAM.png", "Grad-CAM",
              "regions that most influenced the decision."),
             ("03_PASS_Overlay.png", "Overlay",
              "for the reviewer's eye, not a finding.")]
    w, gap = 284, 12
    for i, (img, name, note) in enumerate(views):
        x = MARGIN_L + i * (w + gap)
        rect(s, x, 180, w, 224, fill=C_TILE, line=C_EDGE)
        picture(s, img, x + 10, 190, w - 20, 166)
        _, tf = textbox(s, x + 12, 364, w - 24, 16)
        para(tf, name, 10, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, x + 12, 382, w - 24, 18)
        para(tf, note, 8, C_BODY, first=True, line=1.25)

    _, tf = textbox(s, MARGIN_L, 418, CONTENT_W, 18)
    para(tf, "WE MEASURED OUR OWN EXPLAINABILITY AGAINST IDRID LESION MASKS",
         9.5, C_MUTED, bold=True, first=True)
    kpi_row(s, 440, 72, [
        ("3.1%", "saliency mass inside a lesion mask", C_RED),
        ("7.4%", "pointing-game accuracy", C_RED),
        ("0.035", "mean IoU, top-20% pixels", C_RED),
        ("n/m", "MACE - not measured", C_MUTED),
    ], vsize=20)

    _, tf = textbox(s, MARGIN_L, 512, 620, 70)
    para(tf, "Against an areal chance baseline of 0.0220, that is about 1.39x "
             "chance. The alignment is weak, and we did not retrain the model to "
             "improve a visualisation metric. We publish the number because a "
             "screening prototype that overstates its own evidence is not "
             "deployable.", 9, C_BODY, first=True, line=1.4)

    claims = [
        ("Say \u201cmodel attention\u201d, not \u201clesion localisation\u201d.",
         "The second claim is not supported by our own measurement and we do "
         "not make it."),
        ("Lesion counts are candidates, not findings.",
         "The microaneurysm detector has patch AUC 0.976 but detection recall "
         "of only 0.113, and the classical detectors over-fire on unfamiliar "
         "images."),
        ("Calibration is presentation-only.",
         "T = 2.5382 makes the displayed confidence usable; it is not evidence "
         "of external generalisation."),
    ]
    y = 512
    for h_, b_ in claims:
        _, tf = textbox(s, 700, y, 524, 16)
        para(tf, h_, 9, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, 700, y + 17, 524, 30)
        para(tf, b_, 8, C_BODY, first=True, line=1.3)
        y += 48

    footer(s, 7, "Engineering prototype. Grad-CAM is model attention, not lesion "
                 "localisation. Not a clinical device; not for diagnosis or "
                 "treatment decisions.")
    return s


def slide8(prs):
    s = new_slide(prs)
    header(s, "District-scale simulation",
           [("The bottleneck the model exposes is ", C_TITLE, True),
            ("specialist review, not AI processing", C_MUTED, False)])
    lede(s, 162, "Five panels from one simulation: patient flow, referral "
                 "demand, queue growth over the year, utilisation against the "
                 "capacity scenarios, and workload by referral threshold.",
         size=10.5)

    kpi_row(s, 216, 76, [
        ("96,081", "Images reaching AI screening"),
        ("38,406", "Referrals generated"),
        ("39.97%", "of screened never consume specialist time - 60.03%"),
        ("153.6", "Referrals per working day"),
        ("7.68", "Specialists implied, 20 exams/reviewer/day"),
    ], vsize=19)

    picture(s, "simulink_district_summary.png", MARGIN_L, 298, 700, 328)

    eng = ("Engineering resource-planning simulation. Not clinical validation "
           "and not a staffing prescription.")
    _, tf = textbox(s, 790, 300, 434, est_h(eng, 9.5, 434, line=1.4))
    rich(tf, [("Engineering resource-planning simulation. ", C_TITLE, True),
              ("Not clinical validation and not a staffing prescription.", C_BODY,
               False)], 9.5, first=True, line=1.4)
    meas = ("The measured input is our locked-split operating point "
            "(sensitivity 0.9060, specificity 0.9471 at threshold 0.60). "
            "Patient volume, prevalence, specialist capacity and the recapture "
            "rate are labelled assumptions, not measurements. The .slx "
            "reproduces its reference engine exactly over 250 days; 11/11 "
            "sanity checks pass.")
    _, tf = textbox(s, 790, 352, 434, est_h(meas, 8.5, 434, line=1.4))
    para(tf, meas, 8.5, C_BODY, first=True, line=1.4)

    rect(s, 790, 486, 434, 132, fill=C_TILE, line=C_EDGE)
    _, tf = textbox(s, 804, 498, 406, 18)
    para(tf, "THE BREAK POINT", 9, C_MUTED, bold=True, first=True)
    _, tf = textbox(s, 804, 520, 406, 90)
    rich(tf, [("At 60 reviews/day the year ends at a ", C_BODY, False),
              ("23,406", C_TITLE, True), (" backlog. At 120/day, still ", C_BODY,
                                          False),
              ("8,406", C_TITLE, True), (". Only at ", C_BODY, False),
              ("~180 reviews per day", C_TITLE, True),
              (" does the queue clear, at 85.3% utilisation. A second, "
               "independent discrete-event simulation reaches the same "
               "conclusion.", C_BODY, False)], 8.5, first=True, line=1.4)

    footer(s, 8, "Engineering prototype. Simulation outputs are not clinical or "
                 "operational claims. Not a clinical device; not for diagnosis "
                 "or treatment decisions.")
    return s


def slide9(prs):
    s = new_slide(prs)
    header(s, "Impact",
           [("Three national statistics, each carrying its ", C_TITLE, True),
            ("source and its year", C_MUTED, False)])
    lede(s, 162, "We verified every figure we quote. Where our own earlier draft "
                 "did not survive verification, we say so on the slide rather "
                 "than quietly swapping it.", size=10.5)

    stats = [
        ("74.2 million",
         "Indian adults aged 20-79 with diabetes, 2021. India's own "
         "ICMR-INDIAB-17 national survey puts the same year nearer 101 million - "
         "the two use different methods and are not interchangeable, so we name "
         "the body.",
         "IDF Diabetes Atlas, 10th ed. 2021 - Sun H. et al., Diabetes Res Clin "
         "Pract 2021;183:109119, doi:10.1016/j.diabres.2021.109119. "
         "ICMR-INDIAB-17 - Anjana R.M. et al., Lancet Diabetes Endocrinol 2023, "
         "doi:10.1016/S2213-8587(23)00119-5. "
         "Superseded: the widely quoted 77 million figure is the IDF 2019 "
         "estimate (9th ed.) and has been revised twice since. Do not present it "
         "as current."),
        ("16.9% - 18.1%",
         "Roughly 1 in 6 to 1 in 5 Indians with diabetes aged 50 and over have "
         "diabetic retinopathy. We give the range because two "
         "national-survey-grade sources disagree, and the honest reading is a "
         "band rather than a decimal.",
         "18.1% (95% CI 14.8-21.4), age 50 - Jotheeswaran A.T. et al., Indian J "
         "Endocrinol Metab 2016;20(Suppl 1):S51-S58, "
         "doi:10.4103/2230-8210.179774. 16.9% (95% CI 15.9-17.9) - MoHFW/NPCB "
         "National Survey 2015-19, Vashist P. et al., Indian J Ophthalmol 2021, "
         "doi:10.4103/ijo.IJO_1310_21. Not defensible for all adults: the same "
         "meta-analysis gives 14.9% for age 30, and the authors themselves flag "
         "their own denominator as weak."),
        ("1 : 65,221",
         "Indian ophthalmologists per person, about 15 per million, nationally. "
         "The binding constraint for automated vitreoretinal grading is roughly "
         "19x worse: about one retina specialist per 1.26 million people.",
         "Vashist P. et al., Human resources and infrastructure for ophthalmic "
         "services in India, Indian J Ophthalmol 2025;73(11):1679-1686, "
         "doi:10.4103/IJO.IJO_2816_24; data collected 2020-21, 20,944 "
         "ophthalmologists. Retina specialist density: WHO 2020, cited in "
         "Vashist et al. 2021. Verification note: a lower rural scarcity figure "
         "in our own earlier draft did not survive checking - it traces to a "
         "Vision 2020 planning target for Asia, not an Indian count."),
    ]
    y = 200
    for value, body, cite in stats:
        rect(s, MARGIN_L, y, CONTENT_W, 3, fill=C_RULE)
        _, tf = textbox(s, MARGIN_L, y + 14, 210, 26)
        para(tf, value, 17, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, 280, y + 14, 480, 70)
        para(tf, body, 8.5, C_BODY, first=True, line=1.35)
        _, tf = textbox(s, 780, y + 14, 444, 70)
        para(tf, cite, 7, C_MUTED, first=True, line=1.3)
        y += 96

    _, tf = textbox(s, MARGIN_L, 500, CONTENT_W, 18)
    para(tf, "MEASURED BY US", 9.5, C_MUTED, bold=True, first=True)
    kpi_row(s, 522, 58, [
        ("733", "held-out images, locked validation"),
        ("3,662", "images in the quality audit"),
        ("19", "unseen rehearsal images, 3 cameras"),
        ("250-day", "district simulation horizon"),
        ("230/230", "hardening programme checks PASS"),
    ], vsize=17)

    footer(s, 9)
    return s


def slide10(prs):
    s = new_slide(prs)
    header(s, "Limitations", [("What this system ", C_TITLE, True),
                              ("cannot do yet", C_MUTED, False)])
    lede(s, 162, "These are on the slide, not in the appendix. A prototype that "
                 "hides its measured negatives is not safe to hand to a screening "
                 "programme.", size=10.5)

    rows = [
        ("External validation",
         "Not performed. The reported 0.9060 / 0.9471 / 0.9796 / 0.7821 are "
         "APTOS-internal, on a single dataset.",
         "BLOCKED",
         "Messidor-2 (ADCIS registration) and Sin-NP DR 2019 (data request) both "
         "need a human download. Harness written, 6/6 checks pass."),
        ("Grad-CAM vs lesion masks",
         "Saliency-in-lesion 3.1%, pointing game 7.4%, mean IoU 0.035, about "
         "1.39x areal chance.",
         "MEASURED WEAK",
         "MACE not measured. We did not retrain to improve a visualisation "
         "metric."),
        ("Confident grade on an ungradable image",
         "One DRIMDB image the dataset labels Bad passed the quality gate and "
         "came back referable, routed CLEAR. Neither gate caught it.",
         "OPEN",
         "Recorded, not tuned away - the threshold and OOD bound are "
         "provenance-pinned."),
        ("Fovea localisation",
         "0 of 10 held-out images within 300 px of ground truth.",
         "FAILED",
         "No fovea-derived distance is emitted; the field stays unavailable with "
         "an explicit narrative line."),
        ("Severe / Proliferative recall",
         "0.4872 and 0.5254 - the main 5-class weakness.",
         "OFF BY DECISION",
         "Target-boosted weighting and targeted augmentation are disabled in the "
         "training script. Owner: mentor approval."),
        ("Microaneurysm detection",
         "Patch AUC 0.976, but detection recall only 0.113 at the evaluated "
         "threshold.",
         "LOW RECALL",
         "Counts are reported as candidates, never as findings."),
        ("Optic-disc generalisation",
         "Locates 9/10 within 300 px on IDRiD, but only 10.6% acceptance on "
         "APTOS validation.",
         "LIMITED",
         "Trained on a different camera set; the honest hardware-threshold "
         "refusal works as designed."),
        ("Image enhancement",
         "The A/B experiment showed it degraded grading.",
         "EXCLUDED ON EVIDENCE",
         "Excluded from the inference path; retained as a display aid only."),
        ("Vessel segmentation",
         "Adding vessel features moved Branch-B AUC from 0.8969 to 0.8810.",
         "EXCLUDED ON EVIDENCE",
         "Measured negative result, kept in the record rather than forced into "
         "production."),
    ]
    table(s, MARGIN_L, 196, CONTENT_W, [200, 340, 130, 300], rows,
          ["Item", "What we measured", "Status", "Blocker or owner"],
          row_h=42, header_h=24, font_size=7.5, header_size=8)

    footer(s, 10)
    return s


def slide11(prs):
    s = new_slide(prs)
    header(s, "Team, resources and references",
           [("Everything here is reproducible from a ", C_TITLE, True),
            ("public repository", C_MUTED, False)])

    entries = [("Entry", "Problem statement SIH 26038 * sponsor MathWorks"),
               ("Team", "6 members + mentors * SIH Team ID __________"),
               ("Repository", "github.com/Aryan41211/DrishtiCare"),
               ("Stack", "MATLAB and Simulink; ResNet-18 transfer learning, "
                         "EyePACS-pretrained, class-balanced"),
               ("Launch", "launchRetinaAI.m from the repository root"),
               ("Governance", "frozen model contract with SHA-256 hashes, a "
                              "decision log, and a per-task evidence record")]
    y = 164
    for k, v in entries:
        _, tf = textbox(s, MARGIN_L, y, 130, 16)
        para(tf, k, 9, C_MUTED, bold=True, first=True)
        _, tf = textbox(s, 196, y, 470, 30)
        para(tf, v, 8.5, C_BODY, first=True, line=1.3)
        y += 34

    _, tf = textbox(s, 700, 164, 524, 18)
    para(tf, "DATASETS, STATED PLAINLY", 9, C_MUTED, bold=True, first=True)
    ds = [("APTOS 2019", "grading data. Used."),
          ("IDRiD", "lesion and optic-disc ground truth. Used for evaluation, "
                    "not for classifier selection."),
          ("DRIVE", "vessel study. Used."),
          ("DRIMDB", "downloaded and licence-cleared, used only in the "
                     "unseen-input rehearsal. Not used in any reported result."),
          ("Messidor-2, Sin-NP DR 2019", "not obtained. External validation "
                                          "remains blocked.")]
    y = 186
    for k, v in ds:
        _, tf = textbox(s, 700, y, 180, 16)
        para(tf, k, 8.5, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, 890, y, 334, 30)
        para(tf, v, 8, C_BODY, first=True, line=1.3)
        y += 32

    _, tf = textbox(s, 700, 352, 524, 18)
    para(tf, "REFERENCES", 9, C_MUTED, bold=True, first=True)
    refs = [("Vashist P. et al. (2021)", "National survey of DR, 21 districts, "
                                         "n = 5,986 examined. Indian J "
                                         "Ophthalmol 69(11):3087-3094. "
                                         "doi:10.4103/ijo.IJO_1310_21"),
            ("Jotheeswaran A.T. et al. (2016)", "DR prevalence by age band, "
                                                 "systematic review. Indian J "
                                                 "Endocrinol Metab "
                                                 "20(Suppl 1):S51-S58. "
                                                 "doi:10.4103/2230-8210.179774"),
            ("Vashist P. et al. (2025)", "Ophthalmic workforce and "
                                         "infrastructure, national survey. "
                                         "Indian J Ophthalmol "
                                         "73(11):1679-1686. "
                                         "doi:10.4103/IJO.IJO_2816_24"),
            ("Sun H. et al. (2021)", "IDF Diabetes Atlas 10th edition, India "
                                     "estimate. Diabetes Res Clin Pract "
                                     "183:109119. doi:10.1016/j.diabres.2021.109119"),
            ("Anjana R.M. et al. (2023)", "ICMR-INDIAB-17 national diabetes "
                                          "survey. Lancet Diabetes Endocrinol. "
                                          "doi:10.1016/S2213-8587(23)00119-5"),
            ("Pradeepa R., Mohan V. (2021)", "Tabulation of the IDF 2019 India "
                                             "estimate. Indian J Ophthalmol "
                                             "69(11):2932-2938. "
                                             "doi:10.4103/ijo.IJO_1627_21")]
    y = 374
    for k, v in refs:
        _, tf = textbox(s, 700, y, 190, 16)
        para(tf, k, 8, C_TITLE, bold=True, first=True)
        _, tf = textbox(s, 900, y, 324, 30)
        para(tf, v, 7, C_BODY, first=True, line=1.25)
        y += 30

    rect(s, MARGIN_L, 386, 600, 132, fill=C_TILE, line=C_EDGE)
    _, tf = textbox(s, MARGIN_L + 16, 400, 568, 110)
    para(tf, "How to read every number in this deck.", 10, C_TITLE, bold=True,
         first=True)
    para(tf, "Each is traceable to a committed artifact - the frozen contract, "
             "the validation reports, the rehearsal record, the simulation CSV, "
             "or a cited publication with a DOI. Where a figure was only "
             "provisional, we labelled it provisional rather than dropping the "
             "caveat. Where our own earlier draft did not survive verification, "
             "we left it visible and marked it unsupported. We would rather show "
             "a weaker number we can defend than a stronger one we cannot.",
         8.5, C_BODY, space_before=6, line=1.4)

    footer(s, 11, "DrishtiCare is an engineering prototype for Smart India "
                  "Hackathon 2026. Not a clinical device. No clinical "
                  "validation has been performed. Not for diagnosis, treatment "
                  "or triage decisions.")
    return s


# ==========================================================================
def main():
    prs = Presentation()
    prs.slide_width = px(SLIDE_W)
    prs.slide_height = px(SLIDE_H)

    for fn in (slide1, slide2, slide3, slide4, slide5, slide6, slide7,
               slide8, slide9, slide10, slide11):
        fn(prs)
        print("  built %s" % fn.__name__)

    out = os.path.join(PITCH, "deck.pptx")
    prs.save(out)
    size = os.path.getsize(out)
    print("\nWROTE %s (%d slides, %d bytes)" % (out, len(prs.slides._sldIdLst),
                                                 size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
