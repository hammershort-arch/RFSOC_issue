/*
 * reg_map_cfg.c : RegMap v8 + mem39 開機初始值 (SYSTEM + CH1 ~ CH8), PJ22045_1R8T rev0.12_dev, 2026-10-15
 *   (由 Calibration_Gain_Control 的版本改成 8 通道; 本專案沒有 RX ch7)
 *
 *   只需要改這個檔案. 單位都是物理單位 (dB / dBFS / dBm / clk), register_map.c 會換算成 raw 並檢查範圍.
 *   欄位說明 / 範圍見 register_map.h 與 Calibration_Gain_Control/doc/Reg_map/ (Reg_map_tx_ch_v0.2 / Reg_map_emu_sys_v0.1);
 *   預設值 = 硬體 reset 值 (FIR 除外). SYSTEM 的參數 8 個通道共用.
 *   寫入順序: FIR 先關 -> 係數 -> 參數 -> 模式 / enable 最後.
 *
 *   FIR: 8 通道先填 impulse response (tap7 I = 0x7FFF, 其餘 0; 與 FIR disable 時硬體使用的係數相同),
 *        這塊板子量測後再換成各通道的係數. raw [15:0] I / [31:16] Q, 也可寫 FIR_IQ(I, Q) (signed 16-bit)
 *   phase_offset: raw (143 x degree), 也可寫 PHASE_DEG(30.0)
 *   Signal Source Mux (mem39): 0 = s_axis_iq_in_0 (Aurora hier_rx), 1 = s_axis_iq_in_1 (本板 ADC, loopback), 2 = all_zero
 *   Debug_008 (2026-10-19): CH1 預設 signal_source_select = 2 (all_zero) + bypass_axis_iq = 1 -> DAC s00 收到全 0;
 *                            CH2 ~ CH8 不變 (0 / 0)
 */
#include "register_map.h"

/* ---------------------------------------------------------------- SYSTEM (design_1/system_reg_map, 所有通道共用) */
const reg_map_sys_cfg_t REG_MAP_CFG_SYS = {
    /* Power Fit */
    .signal_mode_select        = 0,         /* 0: CW, 1: Pulse */
    .power_limit_margin_db     = 3,         /* power limit = -3 dBFS */
    .cw_mode_goal_dbfs         = -6.0f,     /* dBFS (16384 = 0 dBFS), HW <= -margin */
    .pulse_update_stable_cycle = 4,         /* avg / PAPR 連續 4 clk 不變才鎖存 */
    .cw_power_avg_log2         = 8,         /* CW 平均 2^8 = 256 拍 (約 1 us) */

    /* AGC_EMU */
    .agc_tx_power_mode         = 0,         /* 0: Linear, 1: Manual */
    .digital_apply_delay       = 35,        /* 35 = RCLK */
    .agc_sr_update_period      = 50,
    .agc_mode_settle_cycle     = 64,
    .agc_rx_watch_cycle        = 1000,
    .agc_rx_wait_dsa_cycle     = 6,
    .agc_rx_set_dsa_cycle      = 6,
    .agc_rx_wait_cycle         = 50,
    .agc_rx_set_clear_cycle    = 6,
    .agc_rx_wait_clear_cycle   = 16,
    .agc_tx_att_hysteresis_db  = 1.0f,      /* TXAGC 換檔遲滯 1 dB */
};

/* ---------------------------------------------------------------- CH1 ~ CH8 (cal_plus_gain_control_ch1~8)
 *   [n-1] = chN; in_0 = Aurora, in_1 = ADC (rfdc_iq_combine_chN), 輸出 = RFDC DAC
 */
const reg_map_cfg_t REG_MAP_CFG_CH[REG_MAP_CH_NUM] = {
    /* ---- CH1: in_0 hier_rx_x0y2/M_AXIS_C0, in_1 ADC m00/m01, DAC s00 */
    {
        .name = "ch1",
        .base = REG_MAP_CH1_BASE,

        /* In-band FIR: impulse response (量測後換成 CH1 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 2,             /* Debug_008: 2 = all_zero (0: Aurora (in_0), 1: ADC loopback (in_1)) */
        .bypass_axis_iq            = 1,             /* Debug_008: 1 = Mux 輸出直接送 DAC (全 0 不經 FIR / calibration / gain) */
    },
    /* ---- CH2: in_0 hier_rx_x0y2/M_AXIS_C1, in_1 ADC m02/m03, DAC s02 */
    {
        .name = "ch2",
        .base = REG_MAP_CH2_BASE,

        /* In-band FIR: impulse response (量測後換成 CH2 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
    /* ---- CH3: in_0 hier_rx_x0y1/M_AXIS_C0, in_1 ADC m10/m11, DAC s10 */
    {
        .name = "ch3",
        .base = REG_MAP_CH3_BASE,

        /* In-band FIR: impulse response (量測後換成 CH3 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
    /* ---- CH4: in_0 hier_rx_x0y1/M_AXIS_C1, in_1 ADC m12/m13, DAC s12 */
    {
        .name = "ch4",
        .base = REG_MAP_CH4_BASE,

        /* In-band FIR: impulse response (量測後換成 CH4 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
    /* ---- CH5: in_0 hier_rx_x0y3/M_AXIS_C0, in_1 ADC m20/m21, DAC s20 */
    {
        .name = "ch5",
        .base = REG_MAP_CH5_BASE,

        /* In-band FIR: impulse response (量測後換成 CH5 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
    /* ---- CH6: in_0 hier_rx_x0y3/M_AXIS_C1, in_1 ADC m22/m23, DAC s22 */
    {
        .name = "ch6",
        .base = REG_MAP_CH6_BASE,

        /* In-band FIR: impulse response (量測後換成 CH6 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
    /* ---- CH7: in_0 hier_rx_x0y4/M_AXIS_C0, in_1 ADC m30/m31, DAC s30 */
    {
        .name = "ch7",
        .base = REG_MAP_CH7_BASE,

        /* In-band FIR: impulse response (量測後換成 CH7 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
    /* ---- CH8: in_0 hier_rx_x0y4/M_AXIS_C1, in_1 ADC m32/m33, DAC s32 */
    {
        .name = "ch8",
        .base = REG_MAP_CH8_BASE,

        /* In-band FIR: impulse response (量測後換成 CH8 的係數) */
        .in_band_fir_enable = 1,
        .in_band_fir_coef_tap = {
            0, 0, 0, 0,                                     /* tap 0~3   */
            0, 0, 0, FIR_IQ(0x7FFF, 0),                     /* tap 4~7   */
            0, 0, 0, 0,                                     /* tap 8~11  */
            0, 0, 0, 0,                                     /* tap 12~15 */
        },

        /* Calibration */
        .coarse_delay_offset     = 0,           /* 0~15 clk */
        .fractional_delay_offset = 0,           /* 0~4 (x 1/5 clk) */
        .phase_offset            = 0,           /* PHASE_DEG(deg) */

        /* gain index / TXAGC 參考 */
        .gain_index_mode_sel              = 0,      /* 0: TXAGC (pf - R), 1: manual */
        .gain_index_manual_db             = 0.0f,
        .gain_index_ch_offset_db          = 0.0f,
        .gain_index_rf_freq_offset_db     = 0.0f,
        .gain_index_temperature_offset_db = 0.0f,
        .dac_output_ref_dbm               = -25.0f,
        .goal_ref_dbfs                    = -6.0f,  /* dBFS, dac_output_ref_dbm 量測時的 goal */

        /* AGC_EMU */
        .agc_reg5                  = 0x80,          /* TXRX_SW = 1 (RX mode) */
        .agc_bypass_agc            = 0,
        .agc_bypass_tx_att_state   = 0,
        .agc_manual_tx_att_en      = 0,
        .agc_manual_tx_att_db      = 0,
        .agc_target_power_dbm      = 0,
        .agc_linear_mode_offset_db = 0.0f,
        .agc_manual_mode_offset_db = 0.0f,
        .agc_manual_rx_att_en      = 0,
        .agc_manual_rx_att_state   = 0,

        /* Signal Source Mux / Debug */
        .signal_source_select      = 0,             /* 0: Aurora (in_0), 1: ADC loopback (in_1) */
        .bypass_axis_iq            = 0,             /* 1: Mux 輸出直接送 DAC */
    },
};
