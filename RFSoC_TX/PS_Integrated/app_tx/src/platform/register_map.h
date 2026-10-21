#ifndef __REGISTER_MAP_H__
#define __REGISTER_MAP_H__

/*
 * RegMap v8 + mem39 (PJ22045_1R8T rev0.12_dev, XSA pj22045_1r8t_cal8ch_02, 2026-10-15)
 *   由 Calibration_Gain_Control/software (build 14) 複製後改成 8 通道:
 *     - channel ch1 ~ ch8 (cal_plus_gain_control_ch1~8), mem39 signal_source_select
 *     - 本專案沒有 rx_gain_control (RX ch7 rx_reg_map 已移除)
 *   system_reg_map      : design_1, 8 通道共用的系統參數 (sys0~16)
 *   addressable_reg_map : 每個 channel 一份 (cal_plus_gain_control_ch1~8), 暫存器表相同, 只差 base address
 *                         mem0~39 設定, mem40~63 保留, mem64~70 狀態 (status_snapshot + st_*)
 *   開機初始值在 reg_map_cfg.c 填寫 (物理單位); 欄位定義 = Calibration_Gain_Control/doc/tools/regmap_def.py
 */
#include "xil_types.h"
#include "xparameters.h"

/* ---------------------------------------------------------------- base address */
#define REG_MAP_CH_NUM     8
#define REG_MAP_CH1_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH1_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_0000 */
#define REG_MAP_CH2_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH2_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_1000 */
#define REG_MAP_CH3_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH3_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_2000 */
#define REG_MAP_CH4_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH4_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_3000 */
#define REG_MAP_CH5_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH5_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_4000 */
#define REG_MAP_CH6_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH6_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_5000 */
#define REG_MAP_CH7_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH7_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_6000 */
#define REG_MAP_CH8_BASE   XPAR_CAL_PLUS_GAIN_CONTROL_CH8_ADDRESSABLE_REG_MAP_BASEADDR   /* 0xA009_7000 */
#define REG_MAP_SYS_BASE   XPAR_SYSTEM_REG_MAP_BASEADDR                                  /* 0xA009_8000 */

/* ---------------------------------------------------------------- system_reg_map (sysN -> N x 4) */
#define SYS_SIGNAL_MODE_SELECT              0x00  /* sys0   [0]     0: CW, 1: Pulse */
#define SYS_POWER_LIMIT_MARGIN              0x04  /* sys1   [2:0]   U3.0 dB, power limit = -margin dBFS */
#define SYS_CW_MODE_GOAL_DBFS               0x08  /* sys2   [10:0]  S6.4 dBFS (HW <= -margin) */
#define SYS_PULSE_UPDATE_STABLE_CYCLE       0x0C  /* sys3   [3:0]   clk, avg / PAPR 連續 M 拍不變才鎖存 */
#define SYS_AGC_TX_POWER_MODE               0x10  /* sys4   [0]     0: Linear, 1: Manual */
#define SYS_DIGITAL_APPLY_DELAY             0x14  /* sys5   [7:0]   adc_clk after SR start (35 = RCLK) */
#define SYS_AGC_SR_UPDATE_PERIOD            0x18  /* sys6   [7:0]   HW min 50 */
#define SYS_AGC_MODE_SETTLE_CYCLE           0x1C  /* sys7   [15:0] */
#define SYS_AGC_RX_WATCH_CYCLE              0x20  /* sys8   [31:0] */
#define SYS_AGC_RX_WAIT_DSA_CYCLE           0x24  /* sys9   [7:0] */
#define SYS_AGC_RX_SET_DSA_CYCLE            0x28  /* sys10  [7:0] */
#define SYS_AGC_RX_WAIT_CYCLE               0x2C  /* sys11  [7:0] */
#define SYS_AGC_RX_SET_CLEAR_CYCLE          0x30  /* sys12  [7:0]   HW min 6 */
#define SYS_AGC_RX_WAIT_CLEAR_CYCLE         0x34  /* sys13  [7:0] */
#define SYS_BUILD_VERSION                   0x38  /* sys14  [31:0]  唯讀, build 號 (= XSA / output_data index) */
#define SYS_CW_POWER_AVG_LOG2               0x3C  /* sys15  [3:0]   CW 平均 N = 2^k (0~12), build 13 */
#define SYS_AGC_TX_ATT_HYSTERESIS           0x40  /* sys16  [7:0]   U4.4 dB, TXAGC 換檔遲滯, build 13 */
#define SYS_LAST                            SYS_AGC_TX_ATT_HYSTERESIS

/* ---------------------------------------------------------------- channel addressable_reg_map (memN -> N x 4) */
#define REG_IN_BAND_FIR_ENABLE              0x00  /* mem0   [0]     FIR enable */
#define REG_IN_BAND_FIR_COEF_TAP_0          0x04  /* mem1~16 [31:0] tap 0..15 at 0x04..0x40, [15:0] I / [31:16] Q */
#define REG_COARSE_DELAY_OFFSET             0x44  /* mem17  [3:0]   0~15 clk (256 MHz) */
#define REG_FRACTIONAL_DELAY_OFFSET         0x48  /* mem18  [2:0]   0~4 (x 1/5 clk) */
#define REG_PHASE_OFFSET                    0x4C  /* mem19  [15:0]  143 x degree, 2's comp */
#define REG_GAIN_INDEX_MODE_SEL             0x50  /* mem20  [0]     0: TXAGC (pf - R), 1: gain_index_manual */
#define REG_GAIN_INDEX_MANUAL               0x54  /* mem21  [10:0]  S6.4 dB */
#define REG_GAIN_INDEX_CH_OFFSET            0x58  /* mem22  [8:0]   S4.4 dB */
#define REG_GAIN_INDEX_RF_FREQ_OFFSET       0x5C  /* mem23  [7:0]   S3.4 dB */
#define REG_GAIN_INDEX_TEMPERATURE_OFFSET   0x60  /* mem24  [7:0]   S3.4 dB */
#define REG_DAC_OUTPUT_REF_DBM              0x64  /* mem25  [10:0]  S6.4 dBm (HW +10 ~ -40) */
#define REG_GOAL_REF_DBFS                   0x68  /* mem26  [10:0]  S6.4 dBFS */
#define REG_AGC_REG5                        0x6C  /* mem27  [7:0]   {TXRX_SW, Vc2, Vc1, Vc0, Vc3, Vc4, PA_VC_D, PA_VC_G} */
#define REG_AGC_BYPASS_AGC                  0x70  /* mem28  [0] */
#define REG_AGC_BYPASS_TX_ATT_STATE         0x74  /* mem29  [4:0]   0~27 */
#define REG_AGC_BYPASS_SR_UPDATE            0x78  /* mem30  [1:0]   rising edge: [0] Reg1~4, [1] Reg5 */
#define REG_AGC_MANUAL_TX_ATT_EN            0x7C  /* mem31  [0] */
#define REG_AGC_MANUAL_TX_ATT_DB            0x80  /* mem32  [7:0]   dB */
#define REG_AGC_TARGET_POWER                0x84  /* mem33  [7:0]   signed dBm */
#define REG_AGC_LINEAR_MODE_OFFSET          0x88  /* mem34  [11:0]  S7.4 dB */
#define REG_AGC_MANUAL_MODE_OFFSET          0x8C  /* mem35  [11:0]  S7.4 dB */
#define REG_AGC_MANUAL_RX_ATT_EN            0x90  /* mem36  [0] */
#define REG_AGC_MANUAL_RX_ATT_STATE         0x94  /* mem37  [2:0]   0~6 */
#define REG_BYPASS_AXIS_IQ                  0x98  /* mem38  [0]     1: m_axis_iq = Signal Source Mux 輸出 (除錯, FIR / calibration / gain 全部 bypass) */
#define REG_SIGNAL_SOURCE_SELECT            0x9C  /* mem39  [1:0]   Signal Source Mux: 0 = s_axis_iq_in_0 (Aurora), 1 = s_axis_iq_in_1 (ADC), 2 = all_zero (Debug_008) */
#define REG_CH_LAST                         REG_SIGNAL_SOURCE_SELECT
/* mem40~63 保留 (讀 0) */
#define REG_STATUS_SNAPSHOT                 0x100 /* mem64  W: 1 = 鎖存所有 st_*; R: [15:0] 完成的 snapshot 次數 */
#define REG_ST_POWER_AMP                    0x104 /* mem65  [15:0]  cw_power_calc 振幅 */
#define REG_ST_GAIN_INDEX_POWER_FIT         0x108 /* mem66  S5.4 dB (符號擴展) */
#define REG_ST_GOAL_DB                      0x10C /* mem67  S7.4 dBFS (符號擴展) */
#define REG_ST_GOAL_REL_DB                  0x110 /* mem68  S5.4 dB (符號擴展) */
#define REG_ST_GAIN_INDEX_TX                0x114 /* mem69  S7.4 dB (符號擴展) */
#define REG_ST_ADC_FLAGS                    0x118 /* mem70  [0] over_threshold1, [1] over_threshold2, [2] over_range, [3] over_voltage */

#define FIR_TAP_NUM   16

/* FIR tap 打包: I / Q 為 signed 16-bit */
#define FIR_IQ(i, q)  ((u32)((((u32)(q) & 0xFFFFU) << 16) | ((u32)(i) & 0xFFFFU)))
/* phase_offset: degree -> raw (143 x degree) */
#define PHASE_DEG(d)  ((s16)((d) * 143.0 + (((d) >= 0) ? 0.5 : -0.5)))

/* ---------------------------------------------------------------- 開機初始值 (物理單位), 見 reg_map_cfg.c */
typedef struct {
    /* Power Fit */
    u8    signal_mode_select;                 /* 0: CW, 1: Pulse */
    u8    power_limit_margin_db;              /* 0~7 */
    float cw_mode_goal_dbfs;                  /* -64 ~ 0 dBFS (HW <= -margin) */
    u8    pulse_update_stable_cycle;          /* 0~15 clk */
    u8    cw_power_avg_log2;                  /* CW 平均 N = 2^k, 0~12 */
    /* AGC_EMU */
    u8    agc_tx_power_mode;                  /* 0: Linear, 1: Manual */
    u8    digital_apply_delay;                /* adc_clk, 35 = RCLK */
    u8    agc_sr_update_period;               /* HW min 50 */
    u16   agc_mode_settle_cycle;
    u32   agc_rx_watch_cycle;
    u8    agc_rx_wait_dsa_cycle;
    u8    agc_rx_set_dsa_cycle;
    u8    agc_rx_wait_cycle;
    u8    agc_rx_set_clear_cycle;
    u8    agc_rx_wait_clear_cycle;
    float agc_tx_att_hysteresis_db;           /* 0 ~ 15.9375 dB, TXAGC 換檔遲滯 */
} reg_map_sys_cfg_t;

typedef struct {
    const char *name;
    UINTPTR     base;

    /* In-band FIR */
    u8    in_band_fir_enable;                 /* 0 / 1 */
    u32   in_band_fir_coef_tap[FIR_TAP_NUM];  /* raw [15:0] I, [31:16] Q (可用 FIR_IQ(i, q)) */
    /* Calibration */
    u8    coarse_delay_offset;                /* 0~15 clk */
    u8    fractional_delay_offset;            /* 0~4 */
    s16   phase_offset;                       /* raw (可用 PHASE_DEG(deg)) */
    /* Gain index / TXAGC 參考 */
    u8    gain_index_mode_sel;                /* 0: TXAGC, 1: manual */
    float gain_index_manual_db;               /* -64 ~ +63.9375 */
    float gain_index_ch_offset_db;            /* -16 ~ +15.9375 */
    float gain_index_rf_freq_offset_db;       /* -8 ~ +7.9375 */
    float gain_index_temperature_offset_db;   /* -8 ~ +7.9375 */
    float dac_output_ref_dbm;                 /* -40 ~ +10 (HW) */
    float goal_ref_dbfs;                      /* dac_output_ref_dbm 量測時的 goal (dBFS) */
    /* AGC_EMU */
    u8    agc_reg5;                           /* raw byte */
    u8    agc_bypass_agc;
    u8    agc_bypass_tx_att_state;            /* 0~27 */
    u8    agc_manual_tx_att_en;
    u8    agc_manual_tx_att_db;               /* 5~130 */
    s8    agc_target_power_dbm;
    float agc_linear_mode_offset_db;          /* -128 ~ +127.9375 */
    float agc_manual_mode_offset_db;          /* -128 ~ +127.9375 */
    u8    agc_manual_rx_att_en;
    u8    agc_manual_rx_att_state;            /* 0~6 */
    /* Signal Source Mux / Debug */
    u8    signal_source_select;               /* 0: s_axis_iq_in_0 (Aurora), 1: s_axis_iq_in_1 (ADC loopback), 2: all_zero (Debug_008) */
    u8    bypass_axis_iq;                     /* 1: Mux 輸出直接送 DAC (FIR / calibration / gain 全部 bypass) */
} reg_map_cfg_t;

extern const reg_map_sys_cfg_t REG_MAP_CFG_SYS;
extern const reg_map_cfg_t     REG_MAP_CFG_CH[REG_MAP_CH_NUM];   /* [0] = ch1 ... [7] = ch8 */

/* 讀 build 號 (sys14) */
u32  register_map_build_version(void);
/* 寫入系統初始值並讀回比對, 回傳不一致 / 超出範圍的筆數 */
int  register_map_apply_sys(const reg_map_sys_cfg_t *cfg);
/* 寫入一個 channel 的初始值並讀回比對, 回傳不一致 / 超出範圍的筆數 */
int  register_map_apply(const reg_map_cfg_t *cfg);
/* 開機初始化: system + ch1 ~ ch8 */
void register_map_init(void);
/* 印出暫存器值 (raw) */
void register_map_dump_sys(void);
void register_map_dump(UINTPTR base, const char *name);
/* snapshot 一個 channel 的狀態並印出 (物理單位) */
int  register_map_status(UINTPTR base, const char *name);

#endif
