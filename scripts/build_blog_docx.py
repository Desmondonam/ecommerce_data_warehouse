"""
Convert docs/blog_post.md into docs/blog_post.docx with proper Word formatting.
Run: python scripts/build_blog_docx.py
"""

import re
from pathlib import Path
from docx import Document
from docx.shared import Pt, RGBColor, Inches, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.style import WD_STYLE_TYPE
from docx.oxml.ns import qn
from docx.oxml import OxmlElement


# ── helpers ──────────────────────────────────────────────────────────────────

def set_cell_bg(cell, hex_color: str):
    """Fill a table cell with a background colour."""
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), hex_color)
    tcPr.append(shd)


def add_horizontal_rule(doc):
    """Insert a thin paragraph border that acts as a visual divider."""
    p = doc.add_paragraph()
    pPr = p._p.get_or_add_pPr()
    pBdr = OxmlElement("w:pBdr")
    bottom = OxmlElement("w:bottom")
    bottom.set(qn("w:val"), "single")
    bottom.set(qn("w:sz"), "6")
    bottom.set(qn("w:space"), "1")
    bottom.set(qn("w:color"), "CCCCCC")
    pBdr.append(bottom)
    pPr.append(pBdr)
    p.paragraph_format.space_before = Pt(4)
    p.paragraph_format.space_after = Pt(4)


def apply_inline(run, text: str):
    """Bold / italic / inline-code within a run."""
    run.text = text


def add_paragraph_with_inline(doc, raw: str, style_name: str = "Normal"):
    """
    Add a paragraph that handles **bold**, *italic*, and `code` inline markers,
    plus hyperlinks rendered as underlined blue text.
    """
    p = doc.add_paragraph(style=style_name)
    # Tokenise inline markers: **bold**, *italic*, `code`, [text](url)
    pattern = re.compile(
        r"\*\*(.+?)\*\*"          # **bold**
        r"|\*(.+?)\*"             # *italic*
        r"|`([^`]+)`"             # `code`
        r"|\[([^\]]+)\]\([^)]+\)" # [text](url)  – render as underlined
    )
    last = 0
    for m in pattern.finditer(raw):
        # Plain text before this match
        if m.start() > last:
            p.add_run(raw[last:m.start()])
        bold_text, italic_text, code_text, link_text = m.groups()
        if bold_text:
            r = p.add_run(bold_text)
            r.bold = True
        elif italic_text:
            r = p.add_run(italic_text)
            r.italic = True
        elif code_text:
            r = p.add_run(code_text)
            r.font.name = "Courier New"
            r.font.size = Pt(9.5)
            r.font.color.rgb = RGBColor(0xC7, 0x25, 0x4E)
        elif link_text:
            r = p.add_run(link_text)
            r.font.color.rgb = RGBColor(0x1A, 0x73, 0xE8)
            r.underline = True
        last = m.end()
    if last < len(raw):
        p.add_run(raw[last:])
    return p


def add_code_block(doc, lines: list[str]):
    """Render a fenced code block as a shaded table with monospace text."""
    code = "\n".join(lines)
    tbl = doc.add_table(rows=1, cols=1)
    tbl.style = "Table Grid"
    cell = tbl.rows[0].cells[0]
    set_cell_bg(cell, "F3F4F6")
    cell.paragraphs[0].clear()
    run = cell.paragraphs[0].add_run(code)
    run.font.name = "Courier New"
    run.font.size = Pt(8.5)
    run.font.color.rgb = RGBColor(0x1F, 0x29, 0x37)
    cell.paragraphs[0].paragraph_format.space_before = Pt(2)
    cell.paragraphs[0].paragraph_format.space_after = Pt(2)
    doc.add_paragraph()  # breathing room after block


def add_markdown_table(doc, rows: list[list[str]]):
    """Render a markdown pipe table as a Word table."""
    if not rows:
        return
    # rows[1] is the separator line (---|---) — skip it
    data_rows = [r for r in rows if not re.match(r"^[\s|:\-]+$", "|".join(r))]
    if len(data_rows) < 1:
        return
    col_count = len(data_rows[0])
    tbl = doc.add_table(rows=len(data_rows), cols=col_count)
    tbl.style = "Table Grid"
    for i, row in enumerate(data_rows):
        for j, cell_text in enumerate(row):
            cell = tbl.rows[i].cells[j]
            cell.text = ""
            p = cell.paragraphs[0]
            # Strip inline code markers for simplicity in table cells
            cleaned = re.sub(r"`([^`]+)`", r"\1", cell_text.strip())
            cleaned = re.sub(r"\*\*(.+?)\*\*", r"\1", cleaned)
            run = p.add_run(cleaned)
            run.font.size = Pt(9)
            if i == 0:
                run.bold = True
                set_cell_bg(cell, "1A56DB")
                run.font.color.rgb = RGBColor(0xFF, 0xFF, 0xFF)
            elif i % 2 == 0:
                set_cell_bg(cell, "EFF6FF")
    doc.add_paragraph()


# ── main builder ─────────────────────────────────────────────────────────────

def build_docx(md_path: Path, out_path: Path):
    doc = Document()

    # ── page margins ──────────────────────────────────────────────────────────
    for section in doc.sections:
        section.top_margin    = Cm(2.5)
        section.bottom_margin = Cm(2.5)
        section.left_margin   = Cm(3.0)
        section.right_margin  = Cm(3.0)

    # ── default body font ─────────────────────────────────────────────────────
    style = doc.styles["Normal"]
    style.font.name = "Calibri"
    style.font.size = Pt(11)

    # ── heading colours ───────────────────────────────────────────────────────
    heading_colors = {
        "Heading 1": RGBColor(0x1A, 0x56, 0xDB),   # blue
        "Heading 2": RGBColor(0x1E, 0x40, 0xAF),   # darker blue
        "Heading 3": RGBColor(0x1D, 0x4E, 0x89),   # steel blue
        "Heading 4": RGBColor(0x37, 0x51, 0x6F),   # slate
    }
    heading_sizes = {"Heading 1": 22, "Heading 2": 16, "Heading 3": 13, "Heading 4": 11}
    for name, color in heading_colors.items():
        s = doc.styles[name]
        s.font.color.rgb = color
        s.font.size = Pt(heading_sizes[name])
        s.font.bold = True
        s.paragraph_format.space_before = Pt(14)
        s.paragraph_format.space_after  = Pt(4)

    # ── parse markdown ────────────────────────────────────────────────────────
    lines = md_path.read_text(encoding="utf-8").splitlines()
    i = 0

    while i < len(lines):
        line = lines[i]

        # ── horizontal rule ───────────────────────────────────────────────────
        if line.strip() == "---":
            add_horizontal_rule(doc)
            i += 1
            continue

        # ── fenced code block ─────────────────────────────────────────────────
        if line.startswith("```"):
            i += 1
            code_lines = []
            while i < len(lines) and not lines[i].startswith("```"):
                code_lines.append(lines[i])
                i += 1
            add_code_block(doc, code_lines)
            i += 1  # skip closing ```
            continue

        # ── markdown table ────────────────────────────────────────────────────
        if line.startswith("|"):
            table_rows = []
            while i < len(lines) and lines[i].startswith("|"):
                cells = [c.strip() for c in lines[i].strip().strip("|").split("|")]
                table_rows.append(cells)
                i += 1
            add_markdown_table(doc, table_rows)
            continue

        # ── headings ──────────────────────────────────────────────────────────
        if line.startswith("#### "):
            p = doc.add_paragraph(style="Heading 4")
            p.add_run(line[5:].strip())
            i += 1
            continue

        if line.startswith("### "):
            p = doc.add_paragraph(style="Heading 3")
            p.add_run(line[4:].strip())
            i += 1
            continue

        if line.startswith("## "):
            p = doc.add_paragraph(style="Heading 2")
            p.add_run(line[3:].strip())
            i += 1
            continue

        if line.startswith("# "):
            p = doc.add_paragraph(style="Heading 1")
            run = p.add_run(line[2:].strip())
            p.paragraph_format.space_before = Pt(0)
            i += 1
            continue

        # ── bullet list ───────────────────────────────────────────────────────
        if re.match(r"^[-*] ", line):
            raw = line[2:].strip()
            p = add_paragraph_with_inline(doc, raw, "List Bullet")
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after  = Pt(1)
            i += 1
            continue

        # ── numbered list ─────────────────────────────────────────────────────
        if re.match(r"^\d+\. ", line):
            raw = re.sub(r"^\d+\. ", "", line)
            p = add_paragraph_with_inline(doc, raw, "List Number")
            p.paragraph_format.space_before = Pt(1)
            p.paragraph_format.space_after  = Pt(1)
            i += 1
            continue

        # ── blockquote ────────────────────────────────────────────────────────
        if line.startswith("> "):
            raw = line[2:].strip()
            p = doc.add_paragraph()
            run = p.add_run(raw)
            run.italic = True
            run.font.color.rgb = RGBColor(0x6B, 0x72, 0x80)
            p.paragraph_format.left_indent  = Cm(1.0)
            p.paragraph_format.space_before = Pt(2)
            p.paragraph_format.space_after  = Pt(2)
            i += 1
            continue

        # ── metadata lines (bold: value) ──────────────────────────────────────
        if line.startswith("**") and ":**" not in line and line.count("**") == 2:
            # e.g. **Author:** Desmond Onam
            add_paragraph_with_inline(doc, line)
            i += 1
            continue

        # ── blank line ────────────────────────────────────────────────────────
        if line.strip() == "":
            i += 1
            continue

        # ── normal paragraph ──────────────────────────────────────────────────
        add_paragraph_with_inline(doc, line)
        i += 1

    doc.save(out_path)
    print(f"Saved: {out_path}  ({out_path.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    root = Path(__file__).parent.parent
    build_docx(
        md_path=root / "docs" / "blog_post.md",
        out_path=root / "docs" / "blog_post.docx",
    )
