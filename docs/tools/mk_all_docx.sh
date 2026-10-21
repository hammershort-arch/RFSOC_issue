#!/bin/bash
# mk_all_docx.sh : 產生本 release 所有 md 的 docx（2026-10-16；同日改為 docs/ 分層目錄）
# Debug_009（2026-10-20）：加 05_Diff / 06_Debug7 / 07_Debug008 / 08_Debug009 資料夾
# reference_rev0.12/ 不轉（同事原檔）。
# 頂層架構圖改了 fig_src/*.dot 才需要重畫：dot -Tpng fig_src/tx_top.dot -o ../02_RFSoC_TX/fig/tx_top.png（rx → ../03_RFSoC_RX/fig/rx_top.png）
set -e
cd "$(dirname "$0")"
D=$(cd .. && pwd)
for md in "$D"/*.md "$D"/01_System/*.md "$D"/02_RFSoC_TX/*.md "$D"/02_RFSoC_TX/history/*.md "$D"/03_RFSoC_RX/*.md \
          "$D"/05_*/*.md "$D"/06_*/*.md "$D"/07_*/*.md "$D"/08_*/*.md; do
  node md2docx.js "$md" "${md%.md}.docx"
done
