# =============================================================================
# mk_regmap_v8.py  PJ22045_1R8T rev0.12_dev 版 (2026-10-15)
#   由 Calibration_Gain_Control/doc/tools/mk_regmap_v8.py (2026-10-14) 複製後修改:
#     - base address 改成 PJ22045_1R8T design_1 (ch1~ch8 0xA009_0000 + 0x1000 x (N-1), system 0xA009_8000)
#     - 新增 Channel_Map 工作表 (8 通道位址 / 接線); 移除 RX (本專案沒有 rx_gain_control)
#   docs/02_RFSoC_TX/tools/regmap_def.py -> docs/02_RFSoC_TX/Reg_map/Reg_map_tx_ch_v<CH_VER>.xlsx / Reg_map_emu_sys_v<SYS_VER>.xlsx
#   版號規則: 內容有改才 +0.1; 已存在的同名檔案不覆蓋, 要重產請先把舊檔移走
#   Usage: python3 docs/02_RFSoC_TX/tools/mk_regmap_v8.py
# =============================================================================
import os, sys
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
from openpyxl.comments import Comment

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import regmap_def as D
DOC = os.path.dirname(HERE)
OUT = DOC     # Debug_008: tools/ 在 Reg_map/ 底下, xlsx 直接輸出到 Reg_map/
CH_VER, SYS_VER = "0.2", "0.1"     # 2026-10-19 Debug_008: tx_ch v0.2 = mem39 2-bit (2 / 3 = all_zero); system 不變     # 2026-10-15: PJ22045_1R8T 第一版 (暫存器定義 = Calibration_Gain_Control tx_ch v0.2 / emu_sys v0.1)

def save(wb, fname):
    path = os.path.join(OUT, fname)
    if os.path.exists(path):
        print("skip (exists):", path)
        return
    os.makedirs(OUT, exist_ok=True)
    wb.save(path)
    print("saved", path)

def F(**k):
    k.setdefault("size", 10)
    return Font(name="Arial", **k)
HDR_FILL = PatternFill("solid", fgColor="1F4E78")
FILLS = {"Calibration": PatternFill("solid", fgColor="F2F2F2"), "Gain Index": PatternFill("solid", fgColor="E2EFDA"),
         "AGC_EMU": PatternFill("solid", fgColor="E2EFDA"), "Status": PatternFill("solid", fgColor="DDEBF7"),
         "Power Fit": PatternFill("solid", fgColor="FFF2CC"), "System": PatternFill("solid", fgColor="DDEBF7"),
         "Reserved": PatternFill("solid", fgColor="FFFFFF"),
         "RX AGC": PatternFill("solid", fgColor="E2EFDA"), "RX Status": PatternFill("solid", fgColor="DDEBF7")}
IN_FILL = PatternFill("solid", fgColor="FFFF00")
thin = Side(style="thin", color="BFBFBF")
BOX = Border(left=thin, right=thin, top=thin, bottom=thin)
WRAP = Alignment(wrap_text=True, vertical="top")
CEN = Alignment(horizontal="center", vertical="top", wrap_text=True)

def header(ws, row, names, widths=None):
    for c, h in enumerate(names, 1):
        x = ws.cell(row, c, h); x.font = F(bold=True, color="FFFFFF"); x.fill = HDR_FILL; x.alignment = CEN; x.border = BOX
    if widths:
        for i, w in enumerate(widths, 1): ws.column_dimensions[get_column_letter(i)].width = w

def summary(ws, rows, base_comment):
    for r, (a, b) in enumerate(rows, 1):
        ws.cell(r, 1, a).font = F(bold=(b is None and a is not None) or r == 1, size=12 if r == 1 else 10)
        if b is not None:
            c = ws.cell(r, 2, b); c.font = F(); c.alignment = WRAP
    ws["B3"].fill = IN_FILL
    ws["B3"].comment = Comment(base_comment, "AGC_EMU")
    ws.column_dimensions["A"].width = 24; ws.column_dimensions["B"].width = 120

def bits(r):
    return f"[{r['msb']}:0]" if r["msb"] else "[0]"

def reset_txt(r):
    if r["access"] in ("RO", "TRIG"): return "-"
    v = r["reset"]
    if v and r["signed"] and r["frac"]:
        w = r["msb"] + 1
        sv = v - (1 << w) if v >> (w - 1) else v
        return f"{v:X} ({sv / (1 << r['frac']):g})"
    return f"{v:X}"

def regmap_sheet(ws, regs, prefix, reserved=None):
    hdr = ["Index", "Offset (hex)", "Address", "Register Name", "Bits", "R/W", "Reset (hex)", "Format / Unit",
           "Range / Values", "Description", "Takes effect", "Used by (BD)", "Group"]
    header(ws, 1, hdr, [8, 11, 13, 30, 8, 6, 14, 26, 30, 64, 18, 36, 11])
    rows = list(regs)
    if reserved:
        rows.append(dict(idx=reserved[0], name=f"reserved ({prefix}{reserved[0]} ~ {prefix}{reserved[1]})", msb=31,
                         access="-", fmt="-", rng="-", desc="Reserved for future configuration registers: read 0, write ignored",
                         effect="-", used="-", group="Reserved", signed=False, frac=0, reset=0, last=reserved[1]))
    rows.sort(key=lambda r: r["idx"])
    r = 2
    for g in rows:
        acc = {"RW": "R/W", "RO": "R", "TRIG": "W1 / R", "-": "-"}[g["access"]]
        off = f"{4 * g['idx']:03X}" if "last" not in g else f"{4 * g['idx']:03X}~{4 * g['last']:03X}"
        vals = [f"{prefix}{g['idx']}" if "last" not in g else f"{prefix}{g['idx']}~{g['last']}", off,
                f'="0x"&DEC2HEX(HEX2DEC(Summary!$B$3)+{4 * g["idx"]},8)', g["name"], bits(g) if "last" not in g else "-",
                acc, reset_txt(g) if "last" not in g else "0", g["fmt"], g["rng"], g["desc"], g["effect"], g["used"], g["group"]]
        for c, v in enumerate(vals, 1):
            x = ws.cell(r, c, v); x.font = F(); x.border = BOX
            x.alignment = CEN if c in (1, 2, 3, 5, 6, 7, 13) else WRAP
            x.fill = FILLS.get(g["group"], FILLS["Reserved"])
        ws.cell(r, 2).number_format = "@"; ws.cell(r, 7).number_format = "@"
        r += 1
    ws.freeze_panes = "E2"
    ws.auto_filter.ref = f"A1:M{r-1}"

def examples(ws, rows, prefix):
    header(ws, 1, ["Step", "Register", "Address", "Write value (hex)", "Comment"], [8, 40, 13, 18, 90])
    r = 2
    for row in rows:
        if row[1] is None:
            ws.cell(r, 1, row[0]).font = F(bold=True)
        else:
            vals = [row[0], row[1], f'="0x"&DEC2HEX(HEX2DEC(Summary!$B$3)+{4 * row[2]},8)', row[3], row[4]]
            for c, v in enumerate(vals, 1):
                x = ws.cell(r, c, v); x.font = F(); x.border = BOX; x.alignment = WRAP
            ws.cell(r, 4).number_format = "@"
        r += 1

# ============================================================================= channel
wb = Workbook()
ws = wb.active; ws.title = "Summary"
summary(ws, [
    (f"PJ22045_1R8T Channel Register Map v{CH_VER} (RegMap v8 + mem39, cal_plus_gain_control_ch1~8 / addressable_reg_map)", None),
    (None, None),
    ("Base address (hex)", "A0090000"),
    ("Channel bases", "ch1~ch8 = 0xA009_0000 + 0x1000 x (N-1) (ch1 0xA009_0000 ... ch8 0xA009_7000); gain BRAM 0xA009_A000 + 0x2000 x (N-1); "
                      "see sheet Channel_Map (design_1 Address Editor, build 02)"),
    ("AXI-Lite range", "4 KB window, 128 x 32-bit registers (mem0~127), 9-bit address"),
    ("Clock", "S_AXI_ACLK = pl_clk0 (100 MHz)"),
    ("Version", "v0.2 (2026-10-19, Debug_008): mem39 signal_source_select 1 -> 2 bit, 2 / 3 = all_zero (160'd0, tvalid = 1). "
                "v0.1 (2026-10-15, PJ22045_1R8T build 02): register definition = Calibration_Gain_Control Reg_map_tx_ch_v0.2 (RegMap v8)."),
    ("Source", "docs/02_RFSoC_TX/tools/regmap_def.py (copy of Calibration_Gain_Control/doc/tools/regmap_def.py) -> docs/02_RFSoC_TX/tools/mk_regmap_v8.py (this file)"),
    (None, None),
    ("Legend", None),
    ("Yellow cell", "Input: change the base address here (e.g. A0092000 for ch3); all addresses follow"),
    ("Grey / green rows", "Configuration registers (R/W)"),
    ("Blue rows", "Status registers: write status_snapshot (mem64) = 1, then read mem65~70 (one consistent snapshot)"),
    (None, None),
    ("Notes", None),
    ("1", "All configuration registers are R/W 32-bit; unused upper bits read back what was written and are ignored by the hardware."),
    ("2", "Non-zero reset: dac_output_ref_dbm (mem25) = 0x670 (-25 dBm), goal_ref_dbfs (mem26) = 0x7A0 (-6.0 dBFS), agc_reg5 (mem27) = 0x80 (RX mode)."),
    ("3", "dBFS: 16384 = 0 dBFS. S6.4 = 11-bit two's complement, 1/16 dB (e.g. -6.0 dB = -96 = 0x7A0)."),
    ("4", "Status: status_snapshot read value = completed snapshot count [15:0]; it increments when both clk (256 MHz) and adc_clk (240 MHz) "
          "domains have latched. Signed status fields are sign-extended to 32 bit."),
    ("6", "bypass_axis_iq (mem38) = 1: m_axis_iq = Signal Source Mux output (FIR / calibration / gain control bypassed, 0 latency mux); "
          "the normal path keeps running so AGC / Power Fit status is still valid. Debug only."),
    ("8", "PJ22045_1R8T: s_axis_iq_in_0 = Aurora (hier_rx_x0yN/M_AXIS_Cx), s_axis_iq_in_1 = local ADC (rfdc_iq_combine_chN). "
          "Boot default (software reg_map_cfg.c): mem39 = 0 (Aurora), mem38 = 0, FIR = impulse response (tap7 I = 0x7FFF). "
          "Debug_008 PS: ch1 only mem39 = 2 (all_zero) + mem38 = 1; ch2~ch8 = 0 / 0."),
    ("7", "signal_source_select (mem39): Signal Source Mux in front of the mem38 bypass. 0 = s_axis_iq_in_0, 1 = s_axis_iq_in_1, 2 / 3 = all_zero (Debug_008, 160'd0 with tvalid = 1); "
          "the selected stream feeds Power Fit / Calibration (and the bypass path). 0 latency mux; unselected inputs are dropped (tready = 1). All on clk (256 MHz)."),
    ("5", "Moved to system_reg_map (v7 -> v8): signal_mode_select (mem26), power_limit_margin (mem27), cw_mode_goal_amp (mem20 -> cw_mode_goal_dbfs), "
          "digital_apply_delay (mem30), agc_tx_power_mode (mem36), agc_rx_*_cycle (mem44~49), agc_sr_update_period (mem50), agc_mode_settle_cycle (mem51)."),
], "Base address of cal_plus_gain_control_chN/addressable_reg_map (SEG_addressable_reg_map_reg0 = ch1)")

regmap_sheet(wb.create_sheet("Register_Map"), D.CHANNEL + D.CH_STATUS, "mem", D.CH_RESERVED)

# Channel map (PJ22045_1R8T)
cm = wb.create_sheet("Channel_Map", 1)
header(cm, 1, ["Ch", "Reg map base", "Gain BRAM base", "in_0 (Aurora)", "in_1 (ADC -> combiner)", "DAC", "adc_clk",
               "RFDC flag / clear", "VIO probe_out"], [6, 14, 16, 26, 22, 8, 10, 18, 14])
CHMAP = [(1, "hier_rx_x0y2 / M_AXIS_C0", "m00 / m01", "s00", "clk_adc0", "adc0_01"),
         (2, "hier_rx_x0y2 / M_AXIS_C1", "m02 / m03", "s02", "clk_adc0", "adc0_23"),
         (3, "hier_rx_x0y1 / M_AXIS_C0", "m10 / m11", "s10", "clk_adc1", "adc1_01"),
         (4, "hier_rx_x0y1 / M_AXIS_C1", "m12 / m13", "s12", "clk_adc1", "adc1_23"),
         (5, "hier_rx_x0y3 / M_AXIS_C0", "m20 / m21", "s20", "clk_adc2", "adc2_01"),
         (6, "hier_rx_x0y3 / M_AXIS_C1", "m22 / m23", "s22", "clk_adc2", "adc2_23"),
         (7, "hier_rx_x0y4 / M_AXIS_C0", "m30 / m31", "s30", "clk_adc3", "adc3_01"),
         (8, "hier_rx_x0y4 / M_AXIS_C1", "m32 / m33", "s32", "clk_adc3", "adc3_23")]
for i, (n, a, adc, dac, ck, fl) in enumerate(CHMAP):
    row = [f"ch{n}", f"0x{0xA0090000 + 0x1000 * (n - 1):08X}", f"0x{0xA009A000 + 0x2000 * (n - 1):08X}", a, adc, dac, ck, fl,
           f"{4 * (n - 1)} ~ {4 * (n - 1) + 3}"]
    for c, v in enumerate(row, 1):
        x = cm.cell(2 + i, c, v); x.font = F(); x.border = BOX; x.alignment = WRAP
r0 = 2 + len(CHMAP) + 1
for k, t in enumerate(["system_reg_map: 0xA009_8000 (sheet in Reg_map_emu_sys).",
                       "All channels: clk = FPGA_clk 256 MHz, S_AXI_ACLK = pl_clk0 100 MHz, adc_clk = clk_adcN 240 MHz.",
                       "VIO probes per channel: rx_att_index[2:0], algo_analog_att_db[8:0], pulse_avg_amp[15:0], pulse_papr[8:0]."]):
    cm.cell(r0 + k, 1, t).font = F()

# v7 -> v8 mapping
mp = wb.create_sheet("v7_to_v8")
header(mp, 1, ["v7 mem", "v7 name", "v8 location", "v8 name", "Note"], [9, 30, 14, 30, 50])
v7 = [(20, "cw_mode_goal_amp", "sys2", "cw_mode_goal_dbfs", "amplitude -> S6.4 dBFS"), (21, "gain_index_mode_sel", "mem20", "gain_index_mode_sel", ""),
      (22, "gain_index_manual", "mem21", "gain_index_manual", ""), (23, "gain_index_ch_offset", "mem22", "gain_index_ch_offset", ""),
      (24, "gain_index_rf_freq_offset", "mem23", "gain_index_rf_freq_offset", ""), (25, "gain_index_temperature_offset", "mem24", "gain_index_temperature_offset", ""),
      (26, "signal_mode_select", "sys0", "signal_mode_select", ""), (27, "power_limit_margin", "sys1", "power_limit_margin", ""),
      (28, "dac_output_ref_dbm", "mem25", "dac_output_ref_dbm", ""), (29, "goal_ref_amp", "mem26", "goal_ref_dbfs", "amplitude -> S6.4 dBFS"),
      (30, "digital_apply_delay", "sys5", "digital_apply_delay", ""), (31, "(reserved)", "-", "-", ""),
      (32, "agc_reg5", "mem27", "agc_reg5", ""), (33, "agc_bypass_agc", "mem28", "agc_bypass_agc", ""),
      (34, "agc_bypass_tx_att_state", "mem29", "agc_bypass_tx_att_state", ""), (35, "agc_bypass_sr_update", "mem30", "agc_bypass_sr_update", ""),
      (36, "agc_tx_power_mode", "sys4", "agc_tx_power_mode", ""), (37, "agc_manual_tx_att_en", "mem31", "agc_manual_tx_att_en", ""),
      (38, "agc_manual_tx_att_db", "mem32", "agc_manual_tx_att_db", ""), (39, "agc_target_power", "mem33", "agc_target_power", ""),
      (40, "agc_linear_mode_offset", "mem34", "agc_linear_mode_offset", ""), (41, "agc_manual_mode_offset", "mem35", "agc_manual_mode_offset", ""),
      (42, "agc_manual_rx_att_en", "mem36", "agc_manual_rx_att_en", ""), (43, "agc_manual_rx_att_state", "mem37", "agc_manual_rx_att_state", ""),
      (44, "agc_rx_watch_cycle", "sys8", "agc_rx_watch_cycle", ""), (45, "agc_rx_wait_dsa_cycle", "sys9", "agc_rx_wait_dsa_cycle", ""),
      (46, "agc_rx_set_dsa_cycle", "sys10", "agc_rx_set_dsa_cycle", ""), (47, "agc_rx_wait_cycle", "sys11", "agc_rx_wait_cycle", ""),
      (48, "agc_rx_set_clear_cycle", "sys12", "agc_rx_set_clear_cycle", ""), (49, "agc_rx_wait_clear_cycle", "sys13", "agc_rx_wait_clear_cycle", ""),
      (50, "agc_sr_update_period", "sys6", "agc_sr_update_period", ""), (51, "agc_mode_settle_cycle", "sys7", "agc_mode_settle_cycle", "")]
for i, row in enumerate(v7):
    for c, v in enumerate(row, 1):
        x = mp.cell(2 + i, c, v); x.font = F(); x.border = BOX; x.alignment = WRAP
mp.cell(2 + len(v7) + 1, 1, "mem0~19 (FIR, delay, phase) unchanged.").font = F()

# BD IO
bd = wb.create_sheet("BD_IO")
header(bd, 1, ["Port", "Direction", "Width", "Clock domain", "Connected to (design_1)", "Description"], [40, 11, 9, 20, 46, 80])
io = [("s_axis_iq_in_0 / s_axis_iq_in_1", "in", "AXIS [159:0] each", "clk (256 MHz)", "s_axis_iq_in_0: Aurora hier_rx_x0yN/M_AXIS_Cx; s_axis_iq_in_1: rfdc_iq_combine_chN (ADC)",
       "Signal Source Mux inputs (mem39 selects); 5 samples x {Q[15:0], I[15:0]} per beat"),
      ("m_axis_iq", "out", "AXIS [159:0]", "clk (256 MHz)", "RFDC DAC", "Calibrated output (or mux output when mem38 bypass = 1)"),
      ("reg_signal_mode_select / reg_power_limit_margin / reg_cw_mode_goal_dbfs / reg_pulse_update_stable_cycle", "in", "[31:0] each",
       "S_AXI_ACLK", "system_reg_map/sys0~3 (nets reg_<name>)", "System Power Fit settings -> cal_cdc_0"),
      ("reg_agc_tx_power_mode / reg_digital_apply_delay / reg_agc_sr_update_period / reg_agc_mode_settle_cycle / reg_agc_rx_*_cycle", "in",
       "[31:0] each", "S_AXI_ACLK", "system_reg_map/sys4~13", "System AGC settings -> agc_emu (agc_cdc_0)"),
      ("rx_att_index", "in", "[2:0]", "clk (256 MHz)", "vio_ext_inputs probe 4(N-1) (temporary)", "RSP RX attenuation index 0~6 x 10 dB"),
      ("algo_analog_att_db", "in", "[8:0]", "clk", "vio_ext_inputs (temporary)", "S8.0 dB extra analog attenuation"),
      ("pulse_avg_amp", "in", "[15:0]", "clk", "vio_ext_inputs (temporary)", "Pulse mode Power Fit input (auto update: latched together with PAPR after M stable clk)"),
      ("pulse_papr", "in", "[8:0]", "clk", "vio_ext_inputs (temporary)", "U5.4 dB; Pulse goal = -(margin + PAPR) dBFS"),
      ("adc_clk", "in", "1", "-", "RFDC clk_adcN (240 MHz)", "AGC clock"),
      ("over_voltage / over_range / over_threshold1 / over_threshold2", "in", "1 each", "adc_clk", "RFDC adcN_01_*", "RXAGC flags (also st_adc_flags)"),
      ("clear_or / clear_ov", "out", "1 each", "S_AXI_ACLK", "RFDC adcN_01_clear_*", "Flag clear"),
      ("Reg1~5_SER / SRCLK / RCLK", "out", "15", "adc_clk", "CHN_Reg1~5_* top ports", "74LVC595 pins")]
for i, row in enumerate(io):
    for c, v in enumerate(row, 1):
        x = bd.cell(2 + i, c, v); x.font = F(); x.alignment = WRAP; x.border = BOX

examples(wb.create_sheet("Examples"), [
    ("A. Status snapshot (reg_rt.tcl: reg_dump)", None, None, None, None),
    (1, "status_snapshot (mem64)", 64, "00000001", "latch all st_* of this channel"),
    (2, "status_snapshot (mem64)", 64, "(read)", "count changed -> snapshot done"),
    (3, "st_power_amp ~ st_adc_flags (mem65~70)", 65, "(read)", "pf / goal / goal_rel / gain_index_tx: S?.4 sign-extended, /16 = dB"),
    ("B. TX Manual with DAC reference (goal -6 dBFS measured at -25 dBm), target -40 dBm", None, None, None, None),
    (1, "goal_ref_dbfs (mem26)", 26, "000007A0", "-6.0 dBFS"),
    (2, "dac_output_ref_dbm (mem25)", 25, "00000670", "-25 dBm (S6.4)"),
    (3, "agc_target_power (mem33)", 33, "000000D8", "-40 dBm; agc_tx_power_mode (system sys4) = 1"),
    ("C. Bypass", None, None, None, None),
    (1, "agc_bypass_agc (mem28)", 28, "00000001", "AGC paused"),
    (2, "agc_bypass_tx_att_state (mem29)", 29, "00000016", "TX state 22 (25 dB)"),
    (3, "agc_bypass_sr_update (mem30)", 30, "00000003", "rising edge: send Reg1~4 + Reg5"),
    (4, "agc_bypass_sr_update (mem30)", 30, "00000000", "clear"),
    (5, "agc_bypass_agc (mem28)", 28, "00000000", "back to AGC"),
    ("D. Manual TX 48 dB", None, None, None, None),
    (1, "agc_manual_tx_att_db (mem32)", 32, "00000030", "48 dB -> analog 45 dB + digital 3 dB"),
    (2, "agc_manual_tx_att_en (mem31)", 31, "00000001", ""),
    ("E. Debug: send the input directly to the DAC", None, None, None, None),
    (1, "bypass_axis_iq (mem38)", 38, "00000001", "m_axis_iq = mux output (no FIR / calibration / gain)"),
    (2, "bypass_axis_iq (mem38)", 38, "00000000", "back to the normal path"),
    ("F. Signal source", None, None, None, None),
    (1, "signal_source_select (mem39)", 39, "00000001", "Power Fit / Calibration use s_axis_iq_in_1"),
    (2, "signal_source_select (mem39)", 39, "00000000", "back to s_axis_iq_in_0"),
    ("G. Debug_008: all_zero to the DAC", None, None, None, None),
    (1, "signal_source_select (mem39)", 39, "00000002", "all_zero (160'd0, tvalid = 1)"),
    (2, "bypass_axis_iq (mem38)", 38, "00000001", "DAC receives all zeros directly (0 = through FIR / cal / gain)"),
], "mem")
save(wb, f"Reg_map_tx_ch_v{CH_VER}.xlsx")

# ============================================================================= system
wb = Workbook()
ws = wb.active; ws.title = "Summary"
summary(ws, [
    (f"PJ22045_1R8T System Register Map v{SYS_VER} (design_1 / system_reg_map, shared by all channels)", None),
    (None, None),
    ("Base address (hex)", "A0098000"),
    ("AXI-Lite range", "4 KB window (Address Editor), 64 x 32-bit registers (sys0~63), 8-bit address"),
    ("Clock", "S_AXI_ACLK = pl_clk0 (100 MHz)"),
    ("Version", "v0.1 (2026-10-15, PJ22045_1R8T build 02): register definition = Calibration_Gain_Control Reg_map_emu_sys_v0.1; only the base address differs."),
    ("Connection", "sysN -> net reg_<register name> -> cal_plus_gain_control_ch1~ch8 pin reg_<register name> (same value for all 8 channels)"),
    ("Source", "docs/02_RFSoC_TX/tools/regmap_def.py -> docs/02_RFSoC_TX/tools/mk_regmap_v8.py (this file)"),
    (None, None),
    ("Notes", None),
    ("1", "Non-zero reset: power_limit_margin = 3, cw_mode_goal_dbfs = 0x7A0 (-6.0 dBFS), pulse_update_stable_cycle = 4, digital_apply_delay = 35, "
          "agc_sr_update_period = 50, agc_mode_settle_cycle = 64, agc_rx_watch / wait_dsa / set_dsa / wait / set_clear / wait_clear = 1000 / 6 / 6 / 50 / 6 / 16."),
    ("2", "AGC cycle registers: a value below the hardware minimum is used as the minimum (read-back returns the written value)."),
    ("3", "Pulse auto update: pulse_avg_amp / pulse_papr (BD inputs, per channel) are latched together after they stay unchanged for "
          "pulse_update_stable_cycle clk; one Power Fit result (pf + goal_rel) is sent per update. t0 -> pf / goal_rel = M + 7 clk."),
    ("4", "build_version (sys14) is read-only; PJ22045_1R8T build 02 = 0 (BUILD_VERSION parameter not set yet)."),
], "Base address of design_1/system_reg_map (SEG_system_reg_map_reg0)")
regmap_sheet(wb.create_sheet("Register_Map"), D.SYSTEM, "sys", None)
examples(wb.create_sheet("Examples"), [
    ("A. Check the build on the board", None, None, None, None),
    (1, "build_version (sys14)", 14, "(read)", "12 = build _12"),
    ("B. Pulse mode", None, None, None, None),
    (1, "power_limit_margin (sys1)", 1, "00000003", "3 dB"),
    (2, "pulse_update_stable_cycle (sys3)", 3, "00000004", "avg / PAPR latched after 4 stable clk"),
    (3, "signal_mode_select (sys0)", 0, "00000001", "Pulse: goal = -(3 + PAPR) dBFS"),
    ("C. CW mode goal -6 dBFS", None, None, None, None),
    (1, "cw_mode_goal_dbfs (sys2)", 2, "000007A0", "-6.0 dBFS (HW limit: <= -margin)"),
    (2, "signal_mode_select (sys0)", 0, "00000000", "CW"),
    ("D. TX power mode / cycles", None, None, None, None),
    (1, "agc_tx_power_mode (sys4)", 4, "00000001", "Manual (all channels)"),
    (2, "agc_sr_update_period (sys6)", 6, "00000064", "SR round = 100 clk (417 ns)"),
    (3, "digital_apply_delay (sys5)", 5, "00000023", "35 = digital applied on RCLK"),
], "sys")
save(wb, f"Reg_map_emu_sys_v{SYS_VER}.xlsx")
