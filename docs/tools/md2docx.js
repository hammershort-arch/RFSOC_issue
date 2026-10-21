// md2docx.js : Markdown (subset) -> .docx via docx-js
// 2026-10-16 Rex rev0.1 release: 由 Calibration_Gain_Control/doc/tools/md2docx.js 改寫
//   - 樣式對齊同事 rev0.12 docx（A4 橫向、navy 14213D 標題/表頭、F5F7FA 底色）
//   - 支援獨立一行的圖片 ![alt](fig/x.png)（PNG，依 md 所在目錄解析路徑）
//   - H2 不再強制換頁；頁尾 = 文件標題
// usage: node md2docx.js <in.md> <out.docx>   （批次：./mk_all_docx.sh）
// usage: (one-time, in doc/tools) npm install docx
//        node doc/tools/md2docx.js doc/Design_Document/PJ22045_06_RFSoC_TX_Vivado_Design_v0.X.md doc/Design_Document/PJ22045_06_RFSoC_TX_Vivado_Design_v0.X.docx
//        (2026-10-12: 文件改名 / 移到 doc/Design_Document/; 每次改版 +0.1, 舊版移到 doc/Design_Document/old/)
const fs = require('fs');
const D = require('docx');
const {
  Document, Packer, Paragraph, TextRun, HeadingLevel, Table, TableRow, TableCell, WidthType, ShadingType,
  BorderStyle, AlignmentType, LevelFormat, TableOfContents, Footer, PageNumber, TabStopType, ImageRun,
} = D;
const path = require('path');
const NAVY = '14213D', CODEBG = 'F5F7FA';

const [, , inPath, outPath] = process.argv;
const lines = fs.readFileSync(inPath, 'utf8').replace(/\r/g, '').split('\n');
const DOC_TITLE = ((lines.find(l => l.startsWith('# ')) || '# Design').slice(2).trim());

const FONT = { ascii: 'Calibri', hAnsi: 'Calibri', eastAsia: 'Microsoft JhengHei', cs: 'Calibri' };
const MONO = { ascii: 'Consolas', hAnsi: 'Consolas', eastAsia: 'Microsoft JhengHei', cs: 'Consolas' };
const PAGE_W = 16838, PAGE_H = 11906, MARGIN = 1000, CONTENT_W = PAGE_W - 2 * MARGIN;   // A4 landscape

// ---------- inline: **bold**, `code`
function inline(text, opts = {}) {
  const runs = [];
  const re = /(\*\*[^*]+?\*\*|`[^`]+`)/g;
  let last = 0, m;
  const size = opts.size;
  const push = (t, extra = {}) => { if (t) runs.push(new TextRun({ text: t, font: FONT, size, bold: opts.bold, italics: opts.italics, color: opts.color, ...extra })); };
  while ((m = re.exec(text)) !== null) {
    push(text.slice(last, m.index));
    const tok = m[0];
    if (tok.startsWith('**')) {
      // bold may contain code
      const inner = tok.slice(2, -2);
      const parts = inner.split(/(`[^`]+`)/);
      for (const p of parts) {
        if (p.startsWith('`')) runs.push(new TextRun({ text: p.slice(1, -1), font: MONO, size: size ? size - 1 : 19, bold: true, color: '9C2B2B' }));
        else push(p, { bold: true });
      }
    } else {
      runs.push(new TextRun({ text: tok.slice(1, -1), font: MONO, size: size ? size - 1 : 19, color: '9C2B2B' }));
    }
    last = m.index + tok.length;
  }
  push(text.slice(last));
  return runs.length ? runs : [new TextRun({ text: '', font: FONT, size })];
}

// display width (CJK = 2)
function dispLen(s) {
  s = s.replace(/\*\*|`/g, '');
  let n = 0;
  for (const ch of s) n += /[ᄀ-￿]/.test(ch) ? 2 : 1;
  return n;
}

const children = [];
const thinBorder = { style: BorderStyle.SINGLE, size: 4, color: 'BFBFBF' };
const cellBorders = { top: thinBorder, bottom: thinBorder, left: thinBorder, right: thinBorder };

function makeTable(rows) {
  const ncol = Math.max(...rows.map(r => r.length));
  rows = rows.map(r => { while (r.length < ncol) r.push(''); return r; });
  // column widths from content (header weighted), min share
  const want = [];
  for (let c = 0; c < ncol; c++) {
    let mx = 4;
    for (const r of rows) mx = Math.max(mx, Math.min(dispLen(r[c]), 70));
    want.push(Math.sqrt(mx) * 10 + mx);
  }
  const tot = want.reduce((a, b) => a + b, 0);
  let widths = want.map(w => Math.max(700, Math.floor(CONTENT_W * w / tot)));
  const sum = widths.reduce((a, b) => a + b, 0);
  widths = widths.map(w => Math.floor(w * CONTENT_W / sum));
  widths[ncol - 1] += CONTENT_W - widths.reduce((a, b) => a + b, 0);
  const trs = rows.map((r, ri) => new TableRow({
    tableHeader: ri === 0,
    children: r.map((cell, ci) => new TableCell({
      width: { size: widths[ci], type: WidthType.DXA },
      borders: cellBorders,
      shading: ri === 0 ? { type: ShadingType.CLEAR, color: 'auto', fill: NAVY } : undefined,
      margins: { top: 40, bottom: 40, left: 80, right: 80 },
      children: [new Paragraph({ spacing: { before: 0, after: 0, line: 260 },
        children: inline(cell.trim(), { size: 17, bold: ri === 0, color: ri === 0 ? 'FFFFFF' : undefined }) })],
    })),
  }));
  return new Table({ width: { size: CONTENT_W, type: WidthType.DXA }, columnWidths: widths, rows: trs });
}

function splitRow(line) {
  let s = line.trim();
  if (s.startsWith('|')) s = s.slice(1);
  if (s.endsWith('|')) s = s.slice(0, -1);
  // split on | not inside backticks
  const out = []; let cur = '', inCode = false;
  for (const ch of s) {
    if (ch === '`') inCode = !inCode;
    if (ch === '|' && !inCode) { out.push(cur); cur = ''; } else cur += ch;
  }
  out.push(cur);
  return out;
}

let numInstance = 0;
let i = 0;
let titleDone = false;
while (i < lines.length) {
  let line = lines[i];
  if (/^\s*$/.test(line)) { i++; continue; }

  // code fence
  if (/^\s*```/.test(line)) {
    const indent = line.match(/^\s*/)[0].length;
    i++;
    const code = [];
    while (i < lines.length && !/^\s*```/.test(lines[i])) { code.push(lines[i].slice(Math.min(indent, lines[i].match(/^\s*/)[0].length))); i++; }
    i++;
    code.forEach((cl, k) => children.push(new Paragraph({
      spacing: { before: k === 0 ? 80 : 0, after: k === code.length - 1 ? 120 : 0, line: 240 },
      shading: { type: ShadingType.CLEAR, color: 'auto', fill: CODEBG },
      indent: { left: 200 + indent * 60 },
      children: [new TextRun({ text: cl.length ? cl : ' ', font: MONO, size: 16 })],
    })));
    continue;
  }

  // heading
  let m = line.match(/^(#{1,6})\s+(.*)$/);
  if (m) {
    const lvl = m[1].length, text = m[2].trim();
    if (text === '目錄') {   // markdown 內的簡短目錄清單: 由 Word TOC 取代
      i++;
      while (i < lines.length && !/^(#|\s*---+\s*$)/.test(lines[i])) i++;
      continue;
    }
    if (lvl === 1 && !titleDone) {
      titleDone = true;
      children.push(new Paragraph({ heading: HeadingLevel.TITLE, alignment: AlignmentType.CENTER, spacing: { after: 240 }, children: [new TextRun({ text, font: FONT, size: 40, bold: true, color: NAVY })] }));
    } else {
      const map = { 1: HeadingLevel.HEADING_1, 2: HeadingLevel.HEADING_1, 3: HeadingLevel.HEADING_2, 4: HeadingLevel.HEADING_3, 5: HeadingLevel.HEADING_4, 6: HeadingLevel.HEADING_4 };
      children.push(new Paragraph({ heading: map[lvl], children: inline(text) }));
      if (text === '目錄' || text.startsWith('目錄')) { /* keep markdown TOC list too */ }
    }
    i++; continue;
  }

  // image: ![alt](path) on its own line
  m = line.match(/^\s*!\[([^\]]*)\]\(([^)]+)\)\s*$/);
  if (m) {
    const ip = path.resolve(path.dirname(inPath), m[2]);
    const buf = fs.readFileSync(ip);
    let w = buf.readUInt32BE(16), h = buf.readUInt32BE(20);          // PNG IHDR
    const maxW = Math.floor(CONTENT_W / 15), maxH = 560;             // px @96dpi
    const k = Math.min(1, maxW / w, maxH / h);
    children.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { before: 120, after: 60, line: 240, lineRule: D.LineRuleType.AUTO },
      children: [new ImageRun({ type: 'png', data: buf, transformation: { width: Math.round(w * k), height: Math.round(h * k) } })] }));
    if (m[1]) children.push(new Paragraph({ alignment: AlignmentType.CENTER, spacing: { after: 160 },
      children: [new TextRun({ text: m[1], font: FONT, size: 17, italics: true, color: '3A4555' })] }));
    i++; continue;
  }

  // horizontal rule
  if (/^\s*---+\s*$/.test(line)) {
    children.push(new Paragraph({ border: { bottom: { style: BorderStyle.SINGLE, size: 6, color: 'BFBFBF', space: 1 } }, spacing: { after: 120 }, children: [] }));
    i++; continue;
  }

  // table
  if (/^\s*\|/.test(line)) {
    const rows = [];
    while (i < lines.length && /^\s*\|/.test(lines[i])) {
      const r = splitRow(lines[i]);
      if (!r.every(c => /^\s*:?-{2,}:?\s*$/.test(c))) rows.push(r);
      i++;
    }
    children.push(makeTable(rows));
    children.push(new Paragraph({ spacing: { after: 80 }, children: [] }));
    continue;
  }

  // blockquote
  if (/^>/.test(line)) {
    while (i < lines.length && /^>/.test(lines[i])) {
      const t = lines[i].replace(/^>\s?/, '');
      if (t.trim()) children.push(new Paragraph({
        indent: { left: 300 }, spacing: { after: 60 },
        border: { left: { style: BorderStyle.SINGLE, size: 18, color: '9DC3E6', space: 8 } },
        children: inline(t, { color: '404040', size: 19 }),
      }));
      i++;
    }
    continue;
  }

  // list (bullet / numbered), nesting by indent
  if (/^\s*([-*]|\d+\.)\s+/.test(line)) {
    numInstance++;
    const inst = numInstance;
    while (i < lines.length && (/^\s*([-*]|\d+\.)\s+/.test(lines[i]) || (/^\s{2,}\S/.test(lines[i]) && !/^\s*\|/.test(lines[i]) && !/^\s*```/.test(lines[i])))) {
      const l = lines[i];
      const lm = l.match(/^(\s*)([-*]|\d+\.)\s+(.*)$/);
      if (!lm) {   // continuation line of previous item
        children.push(new Paragraph({ indent: { left: 720 }, spacing: { after: 40 }, children: inline(l.trim()) }));
        i++; continue;
      }
      const level = Math.min(2, Math.floor(lm[1].length / 2));
      const numbered = /\d+\./.test(lm[2]);
      children.push(new Paragraph({
        numbering: numbered ? { reference: 'num', level, instance: inst } : { reference: 'bul', level },
        spacing: { after: 40 },
        children: inline(lm[3]),
      }));
      i++;
    }
    continue;
  }

  // paragraph (join consecutive plain lines)
  const para = [line.trim()];
  i++;
  while (i < lines.length && lines[i].trim() && !/^(#|\s*```|\s*\||>|\s*([-*]|\d+\.)\s+|\s*---+\s*$)/.test(lines[i])) {
    para.push(lines[i].trim()); i++;
  }
  const text = para.reduce((a, b) => a + (/[ᄀ-￿]$/.test(a) || /^[ᄀ-￿]/.test(b) ? '' : ' ') + b);
  children.push(new Paragraph({ spacing: { after: 100 }, children: inline(text) }));
}

// insert TOC after title / meta block (before first Heading 1)
const firstH = children.findIndex(p => p instanceof Paragraph && p.properties && JSON.stringify(p).includes('Heading1'));
const toc = [
  new Paragraph({ children: [new TextRun({ text: '目錄', font: FONT, bold: true, size: 28, color: NAVY })], spacing: { before: 200, after: 120 } }),
  new TableOfContents('目錄', { hyperlink: true, headingStyleRange: '1-3' }),
  new Paragraph({ children: [new TextRun({ text: '（若目錄沒有顯示：在 Word 中按右鍵 → 更新功能變數）', font: FONT, size: 16, color: '808080' })] }),
];
children.splice(firstH > 0 ? firstH : 1, 0, ...toc);

const bulLevels = [0, 1, 2].map(l => ({ level: l, format: LevelFormat.BULLET, text: ['•', '◦', '▪'][l], alignment: AlignmentType.LEFT,
  style: { paragraph: { indent: { left: 360 + l * 360, hanging: 260 } } } }));
const numLevels = [0, 1, 2].map(l => ({ level: l, format: [LevelFormat.DECIMAL, LevelFormat.LOWER_LETTER, LevelFormat.LOWER_ROMAN][l], text: `%${l + 1}.`, alignment: AlignmentType.LEFT,
  style: { paragraph: { indent: { left: 400 + l * 360, hanging: 320 } } } }));

const doc = new Document({
  creator: 'PJ22045_1R8T_release_Rex_rev0.1',
  title: DOC_TITLE,
  features: { updateFields: true },
  styles: {
    default: { document: { run: { font: FONT, size: 20 }, paragraph: { spacing: { line: 300 } } } },
    paragraphStyles: [
      { id: 'Heading1', name: 'Heading 1', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 32, bold: true, color: NAVY }, paragraph: { spacing: { before: 240, after: 160 }, outlineLevel: 0 } },
      { id: 'Heading2', name: 'Heading 2', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 26, bold: true, color: NAVY }, paragraph: { spacing: { before: 240, after: 120 }, outlineLevel: 1 } },
      { id: 'Heading3', name: 'Heading 3', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 22, bold: true, color: '3A4555' }, paragraph: { spacing: { before: 180, after: 80 }, outlineLevel: 2 } },
      { id: 'Heading4', name: 'Heading 4', basedOn: 'Normal', next: 'Normal', quickFormat: true,
        run: { font: FONT, size: 20, bold: true, italics: true }, paragraph: { spacing: { before: 120, after: 60 }, outlineLevel: 3 } },
    ],
  },
  numbering: { config: [{ reference: 'bul', levels: bulLevels }, { reference: 'num', levels: numLevels }] },
  sections: [{
    properties: { page: { size: { width: PAGE_H, height: PAGE_W, orientation: D.PageOrientation.LANDSCAPE }, margin: { top: 1000, bottom: 1000, left: MARGIN, right: MARGIN } } },
    footers: { default: new Footer({ children: [new Paragraph({ alignment: AlignmentType.CENTER,
      children: [new TextRun({ font: FONT, size: 16, color: '808080', children: [`PJ22045 1R8T Rex rev0.1 · ${DOC_TITLE}  —  `, PageNumber.CURRENT, ' / ', PageNumber.TOTAL_PAGES] })] })] }) },
    children,
  }],
});
Packer.toBuffer(doc).then(b => { fs.writeFileSync(outPath, b); console.log('written', outPath, children.length, 'blocks'); });
