# RFSoC_RX（z1，47dr1）— MTS 相關電路設計

- 適用版本：PJ22045 v1.0.0 / v1.0.0_Debug7（`source_code_*/RFSoC_RX/PL/RFSoC_RX.xpr`，兩個版本的 RFSoC_RX 逐檔相同）
- 文件版本：v0.1（2026-10-18）
- 資料來源：`design_1.bd`、`constrs_1/*.xdc`、`sources_1` RTL、`RFSoC_RX/PS_Integrated/app_rx/src/platform/rfdc.c / rfdc.h / iic.h`、Vivado 讀出的 RFDC 參數（rev0.1 `docs/tools/rfdc_params_RX.txt`）、BMC `bmc_unified-3.1.5`（`hardware/mts/sync.go`、`clock_config.go`、`docs/features/47_RF_多板同步功能.md`）
- 產生方式：`design_document/tools/mk_mts_design.py`（RX / TX 共用模板，差異見 §10）
- 對照：RFSoC_TX 的同名文件 `02_RFSoC_TX/MTS_Design.md`

## 1. 架構總覽

MTS（Multi-Tile Synchronization）由三部分組成：**RFDC IP 內建的 MTS**（tile 之間的 SYSREF 對齊、latency 對齊）、**PL 端的 SYSREF 路徑**（把 PL_SYSREF 送進 RFDC 的 `user_sysref_adc/dac`，並啟動本板的 40-bit timer），以及 **PS 軟體 + BMC** 的開機 / 同步流程（I2C 指令 1 → 2 → 3 → 5 → 6 → 4）。

```
                 ┌──────────── 時鐘板 LMK04828（多板）/ 本板 LMK04828（Bypass）────────────┐
                 │ DCLK 256 MHz                                   SDCLK（SYSREF）8 MHz       │
                 ▼                                                ▼                          │
 adc1_clk ─► RFDC ADC tile1 PLL ─(3840 MHz 分配)─► ADC tile0/2/3        sysref_in ─► RFDC（analog SYSREF）
 dac0_clk ─► RFDC DAC tile0 PLL ─(refclk 256 分配)─► DAC tile1/2/3 各自 PLL
 FPGA_clk（256 MHz，AP8/AR8）─► util_ds_buf_0 ─► 全部 PL AXIS / SYSREF 取樣時脈
 PL_SYSREF（AP9/AR9）─► util_ds_buf_3 ─┬─► pl_sysref_int_0 ─► regs_4_sysref_0（16 級）─► RFDC user_sysref_adc / user_sysref_dac
                                       │                    └─► hier_mts（SYSREF 偵測 / sync_out 監測，debug）
                                       └─► sync_pulse_to_level_1 ─(level_ref)─► timer_1/start（40-bit timestamp）
 PS ─ I2C slave 0x45（bus 3 / 4）◄── BMC：cmd 1 init → 2 reset_dc → 3 MTS → 5/6 PL reset → 4 mbs_prep
```

## 2. 時脈與 SYSREF 輸入

| 訊號 | 腳位 / 介面 | 頻率 | 去向 | 來源 |
|---|---|---|---|---|
| `adc1_clk` | ADC_CLK_225（AD5 / AD4） | 256 MHz | RFDC ADC tile1 PLL（ADC 的時脈源 tile） | BD 介面 `adc1_clk`；腳位取自 BMC 原始碼註記 |
| `dac0_clk` | DAC_CLK_228（R5 / R4） | 256 MHz | RFDC DAC tile0 PLL（DAC 的時脈源 tile） | BD 介面 `dac0_clk`；腳位同上 |
| `sysref_in` | SYSREF_228（U5 / U4） | 8 MHz（LMK SDCLKout） | RFDC 類比 SYSREF | BD 介面 `sysref_in` |
| `FPGA_clk_p/n_0` | bank 65 GC，AP8 / AR8，LVDS | 256 MHz（`create_clock -period 3.90625 -name FPGA_clk`） | `util_ds_buf_0` → RFDC m/s_axis_aclk、pl_sysref_int、regs_4_sysref、timer_1、sync_pulse_to_level、hier_mts/clk1、`dac_rst1` | `overvoltage_sign.xdc` |
| `PL_SYSREF_clk_p/n` | AP9 / AR9，LVDS | 8 MHz | `util_ds_buf_3` → `pl_sysref_int_0/pl_sysref_captured`、`sync_pulse_to_level_1/pulse_ref` | `overvoltage_sign.xdc`（**沒有 create_clock / input delay**） |
| `fpga_clk_100mhz` | AN10，DIFF_HSTL_I_18 | 100 MHz（`sys_clk`） | Aurora init_clk、`xpm_cdc_gen_0`（pma_rst） | `design.xdc` |

- LMK04828 設定（BMC `HexRegisterValues.Native/Bypass.txt`）：7 個 DCLKout 都是 256 MHz，所有 SDCLKout 都是 8 MHz SYSREF。單板（Native）用板上 LMK 自己的 PLL（VCXO 160 MHz）；多板（Bypass）時 PLL1 / VCO / OSCin 關閉，時鐘板的 DCLK 從 CLKin1（J17 / J18）直通到所有 DCLKout。
- 哪一個 DCLKout 接到哪一支 RFSoC 腳位，repo 裡沒有資料（需要電路圖）。

## 3. RFDC MTS 設定（`usp_rf_data_converter_1`，Vivado 讀出）

| Tile | Sampling | PLL | Refclk | Clock_Source | Clock_Dist | Multi_Tile_Sync | Fabric | Outclk |
|---|---|---|---|---|---|---|---|---|
| ADC0（224） | 3.84 GSPS | 關 | 3840 MHz | 1（ADC1） | 0 | true | 256 MHz | 30 MHz |
| **ADC1（225）** | 3.84 GSPS | **開** | **256 MHz** | 1（自己） | **2** | true | 256 MHz | 30 MHz |
| ADC2（226） | 3.84 GSPS | 關 | 3840 MHz | 1（ADC1） | 0 | true | 256 MHz | 30 MHz |
| ADC3（227） | 3.84 GSPS | 關 | 3840 MHz | 1（ADC1） | 0 | true | 256 MHz | 30 MHz |
| **DAC0（228）** | 3.84 GSPS | **開** | **256 MHz** | 4（自己） | **1** | true | 256 MHz | 240 MHz |
| DAC1（229） | 3.84 GSPS | 開 | 256 MHz | 4（DAC0） | 0 | true | 256 MHz | 240 MHz |
| DAC2（230） | 3.84 GSPS | 開 | 256 MHz | 4（DAC0） | 0 | true | 256 MHz | 240 MHz |
| DAC3（231） | 3.84 GSPS | 開 | 256 MHz | 4（DAC0） | 0 | true | 256 MHz | 240 MHz |

- `Sysref_Source = 1`，`ADC/DAC_MTS_Variable_Fabric_Width = false`。
- 依參數判讀時脈分配：**ADC1** 用 PLL 把 256 MHz 倍頻成 3840 MHz，再把**取樣時脈**分配給 ADC0 / 2 / 3（這三個 tile 的 PLL 關閉，refclk = 3840）。**DAC0** 把 **256 MHz refclk** 分配給 DAC1～3，四個 DAC tile 各自用 PLL 倍頻。所以 **ADC1 與 DAC0 是時脈源 tile**，它們的 PLL 沒有 lock，整個 ADC / DAC 群組都無法啟動。
- ADC0~3 Outclk 30 MHz（同事原設定；只有 clk_adc0 有接，給 hier_mts）。
- AXIS：m0~3 / s0~3_axis_aclk 都是 FPGA_clk 256 MHz（`util_ds_buf_0`），reset 由 `dac_rst1`（proc_sys_reset，slowest_sync_clk = FPGA_clk）提供。
- 解碼 / 插值 3×（3.84 GSPS → 1.28 GSPS，5 IQ / clk @ 256 MHz），NCO ADC 1.04 / DAC −1.04 GHz（詳見 `RFDC_Configuration.md`）。

## 4. PL 端 SYSREF 路徑（RTL 在 `sources_1/new`、`sources_1/imports/new`，RX / TX 逐檔相同）

### 4.1 `pl_sysref_int`（`pl_sysref_int.v`）

```
always @(posedge pl_clk_buf) pl_sysref_r <= pl_sysref_captured;      // 第 1 級（FPGA_clk）
always @(posedge pl_clk_adc) user_sysref_adc <= pl_sysref_r;          // 第 2 級
always @(posedge pl_clk_dac) user_sysref_dac <= pl_sysref_r;
```

- 本設計的 `pl_clk_buf`、`pl_clk_adc`、`pl_clk_dac` 三個輸入**都接 FPGA_clk**，所以就是兩級暫存器。第一級直接取樣非同步的 PL_SYSREF。
- 輸出 `user_sysref_adc` → `regs_4_sysref_0/sysref_adc` 與 `hier_mts/pl_sysref`；`user_sysref_dac` → `regs_4_sysref_0/sysref_dac` 與 `hier_mts/pl_sysref1`；`user_sysref_adc_1` 沒有接。

### 4.2 `regs_4_sysref`（`regs_4_sysref.vhd`）

- 在 FPGA_clk 上各做 **16 級移位暫存器**（`reg_adc(15:0)` / `reg_dac(15:0)`），再加一級輸出 → `usp_rf_data_converter_1/user_sysref_adc`、`user_sysref_dac`。
- 作用：延遲 / 重新註冊 PL SYSREF，讓送進 RFDC 的 user_sysref 跟 RFDC fabric clock（同為 FPGA_clk）同步（RFDC MTS 要求 PL SYSREF 用 PL clock 取樣）。

### 4.3 `sync_pulse_to_level` → `timer`

- `sync_pulse_to_level_1`（clk = FPGA_clk，rst_n = arstn）：`pulse_ref`（PL_SYSREF，直接來自 `util_ds_buf_3`，**沒有先過同步器**）第一次為 1 時，`level_ref` 拉高並保持，直到 reset。
- `level_ref` → `timer_1/start`、`axis_packetizer_0/start`。
- `timer_1`（40-bit，aclk = FPGA_clk，aresetn = arstn）：`start` = 1 之後每拍 +1。timestamp → `ilconcat_1/In0` → `axis_packetizer_0` 的 tuser（`{24'b0, timer[39:0]}`，每個 160-bit beat 都帶 timestamp 送 Aurora）。
- 角色：發送端：timer 是 ADC00 資料的時間戳，跟著資料經 Aurora 送到 TX 板。兩板的 timer 要對齊，前提是兩板 FPGA_clk 同源，並且兩板的 arstn 在同一個 PL_SYSREF 之前放開（同事 `DESIGN.md` §6 / `TIMING_SYNC.md`）。

### 4.4 Reset（`axi_gpio_arstn` / `axi_gpio_pma_rst`）

| 來源 | 同步 | 負載 | PS 控制 |
|---|---|---|---|
| `axi_gpio_arstn`（0xA001_0000，1 bit，預設 0） | `xpm_cdc_gen_1`（xpm_cdc_sync_rst）→ FPGA_clk | `timer_1`、`sync_pulse_to_level_1`、`axis_packetizer_0`、`system_ila_1` | cmd 5 `PL_RESET_HOLD` 清 0；cmd 6 `PL_RESET_RELEASE` 設 1 |
| `axi_gpio_pma_rst`（0xA002_0000） | `xpm_cdc_gen_0` → sys_clk 100 MHz | Aurora `ini_pma_rst`（pma_init）＋ `util_ds_buf_1`（OBUFDS）→ `PMA_RST` LVDS 輸出（AF17 / AF16，送 VU13P） | cmd 5 設 1；cmd 6 清 0 |

- 因為 `axi_gpio_arstn` 開機後是 0，**timer / level_ref 要到 MTS 流程的 cmd 6 才放開**，放開後第一個 PL_SYSREF 脈衝才開始計數。兩顆 RFSoC 由 BMC 在同一步（S4）送 cmd 5 → 6，再由時鐘板在 S5 輸出 SYSREF，兩板的 timer 就會從同一個 SYSREF 開始計數。

## 5. `hier_mts`（SYSREF 監測 / debug，與 RFDC MTS 本身無關）

| Cell | 時脈 | 功能 |
|---|---|---|
| `sysref_trig_det_0` / `_1` | `clk_125` / `clk_625` / `clk_adc` 都接 FPGA_clk（hier pin `clk1`） | 取樣 `pl_sysref`（下降緣取樣、3 級）。開機後計數器數到 `cnt64[41:10] > 610351`（約 6.25×10⁸ 拍，在 256 MHz 下約 2.4 s；期間如果出現寬度 > 7 拍的脈衝，計數器就歸零）→ `waitsysref = 1`。之後再看到寬度 > 7 拍的 SYSREF 脈衝 → `trans_ena_*` = 1。`_0` 用 ADC 的 user_sysref，`_1` 用 DAC 的 user_sysref |
| `sync_out_latch_1` / `_0` | `clk_adc0`（30 MHz）/ `clk_dac0`（240 MHz） | `waitsysref` 經 4 級同步後，若 RFDC `adc0_sync_out` / `dac0_sync_out` = 1，就鎖存 `sync_reg` = 1 |
| `sig1_gen_0` | FPGA_clk | `trans_ena` 之後產生週期 160,000,000 拍的方波（DMA 擷取時序用） |
| `daq_timing_ctrl_0`、`adc_dma_ctrl_0`、`xlslice_0` | FPGA_clk / pl_clk0 | ADC DMA 擷取時序（`DMA_Ctrl` 的 up_s2mm_* 暫存器），不參與 MTS |

頂層 debug 輸出（`overvoltage_sign.xdc`）：

| Port | 腳位 | 內容 |
|---|---|---|
| `sync_reg_adc0` | AG14（LVCMOS18） | ADC0 sync_out 在 SYSREF 偵測後的鎖存結果 |
| `sync_reg_dac0` | AJ13（LVCMOS18） | DAC0 sync_out 鎖存結果 |
| `trans_check_0` | A9（LVCMOS33） | `sysref_trig_det_0/trans_ena_625` |
| `storage_ena_dbg` | C10（LVCMOS33） | `daq_timing_ctrl_0/storage_ena` |

## 6. XDC（MTS 相關）

```
# overvoltage_sign.xdc
create_clock -period 3.90625 -name FPGA_clk -waveform {0.000 1.953} [get_ports FPGA_clk_p_0]
set_property PACKAGE_PIN AP9 [get_ports PL_SYSREF_clk_p[0]] ; AR9 ; IOSTANDARD LVDS
# design.xdc（同事 D16：hier_mts 的 waitsysref → sync_out_latch 是非同步）
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *hier_mts/sysref_trig_det_*/inst/waitsysref_reg}] \
               -to   [get_cells -hierarchical -filter {NAME =~ *hier_mts/sync_out_latch_*/inst/waitforsysref_d1_reg}]
set_property ASYNC_REG TRUE [... sync_out_latch_*/inst/waitforsysref_d1_reg / _d2_reg]
```

- **PL_SYSREF 沒有 `set_input_delay`**（同事 D20：timer 的起點沒有時序約束）。PL_SYSREF 由 FPGA_clk 直接取樣，相位是否穩定取決於板上 SYSREF 與 FPGA_clk 的相位關係。
- 兩邊的 `overvoltage_sign.xdc` 逐檔相同；`design.xdc` 只差一行註解。
- **Debug_009（2026-10-20）**：兩邊 `overvoltage_sign.xdc` 補上 reference 的 `DIFF_TERM_ADV TERM_100`（PL_SYSREF 內部 100 Ω 終端）與 `set_input_delay -clock FPGA_clk -min 3.90625 / -max 3.93625`（PL_SYSREF 取樣開始有 setup / hold 分析）；另有 11 條 `set_max_delay` 因中間隔 `regs_4_sysref` 而沒有作用。上面「沒有 set_input_delay」是 v1.0.0 的狀態，詳見 `08_Debug009_XDC_change/XDC_Constraints_Debug_009.md`。

## 7. PS 軟體（`RFSoC_RX/PS_Integrated/app_rx/src`，RX / TX 的 `rfdc.c`、`iic.c`、`gpio.c` 逐檔相同）

### 7.1 I2C 指令（PS I2C1 slave，位址 **0x45**，400 kHz；BMC bus 3 = RFSoC1 / 47DR1、bus 4 = RFSoC2 / 47DR2）

| Reg | 內容 |
|---|---|
| 0x00 STATUS | 1 BUSY、2 DONE、3 ERROR（唯讀） |
| 0x01 COMMAND | 寫入後執行；BUSY 時寫入會被忽略 |

| Cmd | 名稱 | 動作 |
|---|---|---|
| 0 | BOOT | 開機自動執行（I2C、metal、GPIO 初始化），不能由 master 寫入 |
| 1 | RFDC_INIT | `rfdc_dev_init`：`XRFdc_CfgInitialize` |
| 2 | RFDC_RESET_DC | `rfdc_reset_dc`：依序關掉 ADC tile（順序 3 → 2 → 0 → 1）、DAC tile（3 → 2 → 1 → 0），`sleep(1)`，再啟動 DAC 0 → 1 → 2 → 3、ADC **1 → 0 → 2 → 3**（先啟動時脈源 tile ADC1） |
| 3 | RFDC_MTS_EXEC | `rfdc_mts_exec`：DAC `XRFdc_MultiConverter_Sync`（Tiles = 0x0F，**Target_Latency = 666**），再做 ADC（Tiles = 0x0F，**Target_Latency = 390**），最後印出各 tile 的 Latency / Offset |
| 4 | RFDC_MBS_PREP | `rfdc_mbs_prep`：關 SYSREF → 所有 DAC（block 0 / 2）、ADC（block 0 / 1）的 Mixer / QMC / Coarse delay 的 EventSource 改成 SYSREF，Coarse delay = 0，QMC gain / phase 關閉 → `XRFdc_ResetNCOPhase` → 開 SYSREF |
| 5 | PL_RESET_HOLD | arstn = 0、pma_rst = 1 |
| 6 | PL_RESET_RELEASE | pma_rst = 0、arstn = 1 |

- 指令由 I2C ISR 收下、主迴圈執行；STATUS 在 ISR 裡先設成 BUSY，避免 master 讀到上一個指令的狀態。
- EMIO GPIO 78+4~7（CMD / ACK，`gpio_handshake()`）只在開機時初始化；`gpio_handshake()` 在 v1.0.0 沒有被呼叫，這是舊版 GPIO 交握流程留下的。
- Target latency 是韌體固定值（`rfdc.h`），多板時所有 RFSoC 必須相同（BMC 文件建議改成可由 I2C 設定）。

### 7.2 BMC 流程與 PS 指令的對應

| 流程 | 步驟 | 執行者 | 動作 |
|---|---|---|---|
| 單板（開機或 `StartSdrSingleBoardMts`） | — | BMC | RFSoC POR 拉低 → SPI 設定本板 LMK04828（Native）→ 放開 POR（boot mode QSPI）→ 等 cmd 0 DONE → 1 → 2 → 3（+ 本板 LMK handshake #2：0x0140=0x02、0x0144=0xFF、0x0143=0x53、0x0139=0x02）→ 5 → 6 → 4（+ handshake #3：0x013E=0x01 開 SYSREF） |
| 多板 | S0 configure | 時鐘板 agent（192.168.68.49:8090） | 時鐘板 LMK04828 reset，載入 256 MHz / 8 MHz 設定 |
| | S1 prepare | 每台 SDR | 本板 LMK04828 設成 Bypass → 放開 POR → cmd 0 → 1 → 2 |
| | S2 mts_exec | 每台 SDR | cmd 3 |
| | S3 handshake2 | 時鐘板 | 0x0140、0x0144、0x0143、0x0139 |
| | S4 finish | 每台 SDR | cmd 5 → 6 → 4 |
| | S5 sysref | 時鐘板 | 0x013E = 0x01，輸出 SYSREF |

每一步都要兩顆 RFSoC（多板時是所有 SDR）都 DONE，才會進入下一步（`forEachRFSoC`）。

## 8. 時序上的重點

1. **RFDC 啟動**（cmd 1 / 2）：ADC1 / DAC0 的 PLL 必須先鎖住 256 MHz refclk，其他 tile 才有時脈（ADC 用分配的 3840 MHz，DAC 用分配的 refclk）。
2. **MTS**（cmd 3）：RFDC 用類比 `sysref_in` 和 PL `user_sysref_adc/dac`（FPGA_clk 取樣、經 regs_4_sysref 延遲）量測各 tile 的 latency，再補到 target（DAC 666 / ADC 390，單位是 RFDC 的 T1）。
3. **PL reset**（cmd 5 / 6）：放開 arstn 之後，timer 等第一個 PL_SYSREF 才開始計數。
4. **MBS**（cmd 4）＋ S5：所有 Mixer / QMC / delay 的更新都改成以 SYSREF 觸發，NCO 相位在 SYSREF 時一起 reset，多板之間的 NCO 相位因此對齊。

## 9. 量測紀錄（2026-10-17，.41，BMC 3.1.5，詳見 `PJ22045_Release_Debug/`）

| 實驗 | 47DR1（Z1） | 47DR2（Z2） | VU13P | 多板 MTS | 開機時 ADC1 / DAC0 PLL |
|---|---|---|---|---|---|
| Debug_003（組合 A） | RX | TX 8ch | rev0.12 | 0 / 11 | 兩顆都 UNLOCKED |
| Debug_004（組合 B） | RX | TX 1ch | rev0.12 | 9 / 10 | LOCKED |
| Debug_005 | RX | TX 8ch（mem39 = 1、mem38 = 1，不處理 Aurora 資料） | rev0.12 | 0 / 10 | UNLOCKED |
| F（交換） | TX 8ch | RX | rev0.12 | 5 / 5 | LOCKED |
| G（交換，Debug_007） | TX 8ch | RX | Debug_007 | 10 / 10 | LOCKED |

- 成功的 run 裡，reset_dc 時 ADC1 也都回報啟動停在 state 3（`tag=adc_startup_fail`），但 MTS 仍然成功；原因不明，A / B / F / G 每次都會出現。
- SysRef period 正常是 480。Z1（47DR1）在 Debug_004 / F 曾出現 465 / 495，G 的 20 次都是 480。
- 目前的判斷是「**TX 8ch 放在 47DR2 時，兩顆 RFSoC 的時脈源 tile PLL 都鎖不住**」。這和板子位置有關，跟資料活動無關（Debug_005）。原因還在追查中（時鐘板 / LMK Bypass / 電源），電路設計本身兩板完全相同。

## 10. RFSoC_RX 與 RFSoC_TX 在 MTS 相關電路上的差異

| 項目 | RFSoC_RX | RFSoC_TX |
|---|---|---|
| ADC0~3 Outclk | 30 MHz | 240 MHz |
| `clk_adc0` 負載 | 只有 hier_mts | hier_mts + cal_plus_gain_control ch1 / ch2（clk_adc1~3 → ch3~8） |
| `level_ref` 負載 | timer_1 + axis_packetizer_0（start） | timer_1 |
| timestamp 用途 | packetizer tuser（送 Aurora） | hier_rx_x0y1~4 / data_delay |
| arstn 負載 | timer、packetizer、ILA | timer、hier_rx × 4、axi_delay |
| PS cmd 0 / 1 | 只有基本初始化 | 加 BRAM gain 表、register map（cmd 0）、ADC threshold（cmd 1） |
| 其他（RFDC MTS 參數、pl_sysref_int / regs_4_sysref / hier_mts RTL、XDC、rfdc.c、I2C 協定、target latency） | 相同 | 相同 |

## 11. 待確認

- PL_SYSREF 沒有 input delay 約束（D20），timer 起點與 user_sysref 的取樣相位沒有被時序分析涵蓋。
- `sync_pulse_to_level` 直接用沒同步過的 PL_SYSREF（`pulse_ref`），理論上有 metastability 風險。
- 板上 LMK04828 各 DCLKout 對應到哪一支腳位，需要電路圖確認。
- Target latency（666 / 390）是固定值；多板量到的 DAC latency 是 618～660，要確認餘裕。
