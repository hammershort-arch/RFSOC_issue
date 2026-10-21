#include <stdio.h>
#include "xparameters.h"
#include "xil_io.h"
#include "register_map.h"

/*
 * RegMap v8 + mem39 初始化 (system_reg_map + ch1 ~ ch8 addressable_reg_map), PJ22045_1R8T 2026-10-15
 *   (由 Calibration_Gain_Control 2026-10-10 / 2026-10-12 版改成 8 通道, 移除 rx_reg_map)
 *   初始值: reg_map_cfg.c (物理單位), 這裡負責換算 / 範圍檢查 / 寫入 / 讀回比對
 *   寫入順序: system -> 各 channel (FIR 先關 -> 係數 -> 參數 -> 模式 / enable 最後)
 */

static int g_err;   /* 目前 channel 的錯誤筆數 */

/* 寫入 raw (只保留 width bits) 並讀回比對 */
static void wr(UINTPTR base, u32 off, u32 raw, u32 width, const char *name)
{
    u32 mask = (width >= 32U) ? 0xFFFFFFFFU : ((1U << width) - 1U);
    u32 v = raw & mask;
    u32 rd;

    Xil_Out32(base + off, v);
    rd = Xil_In32(base + off);
    if (rd != v) {
        printf("  [ERR] %-30s 0x%02lX wr 0x%08lX rd 0x%08lX\n\r", name, (unsigned long)off, (unsigned long)v, (unsigned long)rd);
        g_err++;
    }
}

/* 無號整數, 超出 [lo, hi] 時夾住並提示 */
static u32 chk_u(u32 v, u32 lo, u32 hi, const char *name)
{
    if (v < lo || v > hi) {
        u32 c = (v < lo) ? lo : hi;
        printf("  [WARN] %s = %lu out of %lu ~ %lu -> %lu\n\r", name, (unsigned long)v, (unsigned long)lo, (unsigned long)hi, (unsigned long)c);
        g_err++;
        return c;
    }
    return v;
}

/* signed 定點 (frac 位小數, 總寬 width): 物理值 -> raw, 超出範圍時夾住並提示 */
static u32 enc_s(float val, u32 width, u32 frac, const char *name)
{
    float scaled = val * (float)(1U << frac);
    s32 raw = (s32)(scaled + ((scaled >= 0.0f) ? 0.5f : -0.5f));
    s32 lo = -(s32)(1U << (width - 1U));
    s32 hi = (s32)(1U << (width - 1U)) - 1;

    /* 不是 1/2^frac 的整數倍: 四捨五入, 只提示不計入錯誤 */
    if ((float)raw != scaled)
        printf("  [NOTE] %s = %.6f rounded to %.6f (step %.6f)\n\r", name, val,
               (double)raw / (double)(1U << frac), 1.0 / (double)(1U << frac));

    if (raw < lo || raw > hi) {
        s32 c = (raw < lo) ? lo : hi;
        printf("  [WARN] %s = %.4f out of range -> %.4f\n\r", name, val, (double)c / (double)(1U << frac));
        g_err++;
        raw = c;
    }
    return (u32)raw & ((1U << width) - 1U);
}

u32 register_map_build_version(void)
{
    return Xil_In32(REG_MAP_SYS_BASE + SYS_BUILD_VERSION);
}

int register_map_apply_sys(const reg_map_sys_cfg_t *c)
{
    UINTPTR b = REG_MAP_SYS_BASE;

    g_err = 0;
    printf("=== System register map (base 0x%08lX, build_version %lu) ===\n\r", (unsigned long)b,
           (unsigned long)register_map_build_version());

    /* Power Fit */
    wr(b, SYS_POWER_LIMIT_MARGIN,        chk_u(c->power_limit_margin_db, 0, 7, "power_limit_margin_db"), 3, "power_limit_margin");
    if (c->cw_mode_goal_dbfs > -(float)c->power_limit_margin_db)
        printf("  [NOTE] cw_mode_goal_dbfs = %.4f above -margin, HW limits it to %d dBFS\n\r", c->cw_mode_goal_dbfs, -(int)c->power_limit_margin_db);
    wr(b, SYS_CW_MODE_GOAL_DBFS,         enc_s(c->cw_mode_goal_dbfs, 11, 4, "cw_mode_goal_dbfs"), 11, "cw_mode_goal_dbfs");
    wr(b, SYS_PULSE_UPDATE_STABLE_CYCLE, chk_u(c->pulse_update_stable_cycle, 0, 15, "pulse_update_stable_cycle"), 4, "pulse_update_stable_cycle");
    wr(b, SYS_CW_POWER_AVG_LOG2,         chk_u(c->cw_power_avg_log2, 0, 12, "cw_power_avg_log2"), 4, "cw_power_avg_log2");

    /* AGC 週期設定 */
    wr(b, SYS_AGC_RX_WATCH_CYCLE,      chk_u(c->agc_rx_watch_cycle, 1, 0xFFFFFFFFU, "agc_rx_watch_cycle"), 32, "agc_rx_watch_cycle");
    wr(b, SYS_AGC_RX_WAIT_DSA_CYCLE,   chk_u(c->agc_rx_wait_dsa_cycle, 1, 255, "agc_rx_wait_dsa_cycle"), 8, "agc_rx_wait_dsa_cycle");
    wr(b, SYS_AGC_RX_SET_DSA_CYCLE,    chk_u(c->agc_rx_set_dsa_cycle, 1, 255, "agc_rx_set_dsa_cycle"), 8, "agc_rx_set_dsa_cycle");
    wr(b, SYS_AGC_RX_WAIT_CYCLE,       chk_u(c->agc_rx_wait_cycle, 1, 255, "agc_rx_wait_cycle"), 8, "agc_rx_wait_cycle");
    wr(b, SYS_AGC_RX_SET_CLEAR_CYCLE,  chk_u(c->agc_rx_set_clear_cycle, 6, 255, "agc_rx_set_clear_cycle"), 8, "agc_rx_set_clear_cycle");
    wr(b, SYS_AGC_RX_WAIT_CLEAR_CYCLE, chk_u(c->agc_rx_wait_clear_cycle, 1, 255, "agc_rx_wait_clear_cycle"), 8, "agc_rx_wait_clear_cycle");
    wr(b, SYS_AGC_SR_UPDATE_PERIOD,    chk_u(c->agc_sr_update_period, 50, 255, "agc_sr_update_period"), 8, "agc_sr_update_period");
    wr(b, SYS_AGC_MODE_SETTLE_CYCLE,   chk_u(c->agc_mode_settle_cycle, 1, 65535, "agc_mode_settle_cycle"), 16, "agc_mode_settle_cycle");
    if (c->digital_apply_delay >= c->agc_sr_update_period)
        printf("  [WARN] digital_apply_delay %u >= agc_sr_update_period %u\n\r", c->digital_apply_delay, c->agc_sr_update_period);
    wr(b, SYS_DIGITAL_APPLY_DELAY,     c->digital_apply_delay, 8, "digital_apply_delay");
    if (c->agc_tx_att_hysteresis_db < 0.0f)
        printf("  [WARN] agc_tx_att_hysteresis_db %.4f < 0 -> 0\n\r", c->agc_tx_att_hysteresis_db);
    wr(b, SYS_AGC_TX_ATT_HYSTERESIS,   enc_s(c->agc_tx_att_hysteresis_db < 0.0f ? 0.0f : c->agc_tx_att_hysteresis_db, 9, 4, "agc_tx_att_hysteresis_db") & 0xFFU, 8, "agc_tx_att_hysteresis");

    /* 模式 (最後) */
    wr(b, SYS_AGC_TX_POWER_MODE,       chk_u(c->agc_tx_power_mode, 0, 1, "agc_tx_power_mode"), 1, "agc_tx_power_mode");
    wr(b, SYS_SIGNAL_MODE_SELECT,      chk_u(c->signal_mode_select, 0, 1, "signal_mode_select"), 1, "signal_mode_select");

    printf("=== System register map done: %d error(s) / warning(s) ===\n\r", g_err);
    return g_err;
}

int register_map_apply(const reg_map_cfg_t *c)
{
    UINTPTR b = c->base;
    u32 t;

    g_err = 0;
    printf("=== Register map %s (base 0x%08lX) ===\n\r", c->name, (unsigned long)b);

    /* 1. FIR: 先關, 寫係數 (enable 最後才寫) */
    wr(b, REG_IN_BAND_FIR_ENABLE, 0, 1, "in_band_fir_enable");
    for (t = 0; t < FIR_TAP_NUM; t++)
        wr(b, REG_IN_BAND_FIR_COEF_TAP_0 + 4U * t, c->in_band_fir_coef_tap[t], 32, "in_band_fir_coef_tap");

    /* 2. Calibration */
    wr(b, REG_COARSE_DELAY_OFFSET,     chk_u(c->coarse_delay_offset, 0, 15, "coarse_delay_offset"), 4, "coarse_delay_offset");
    wr(b, REG_FRACTIONAL_DELAY_OFFSET, chk_u(c->fractional_delay_offset, 0, 4, "fractional_delay_offset"), 3, "fractional_delay_offset");
    wr(b, REG_PHASE_OFFSET,            (u32)(u16)c->phase_offset, 16, "phase_offset");

    /* 3. gain index / TXAGC 參考 */
    wr(b, REG_GAIN_INDEX_MANUAL,             enc_s(c->gain_index_manual_db, 11, 4, "gain_index_manual_db"), 11, "gain_index_manual");
    wr(b, REG_GAIN_INDEX_CH_OFFSET,          enc_s(c->gain_index_ch_offset_db, 9, 4, "gain_index_ch_offset_db"), 9, "gain_index_ch_offset");
    wr(b, REG_GAIN_INDEX_RF_FREQ_OFFSET,     enc_s(c->gain_index_rf_freq_offset_db, 8, 4, "gain_index_rf_freq_offset_db"), 8, "gain_index_rf_freq_offset");
    wr(b, REG_GAIN_INDEX_TEMPERATURE_OFFSET, enc_s(c->gain_index_temperature_offset_db, 8, 4, "gain_index_temperature_offset_db"), 8, "gain_index_temperature_offset");
    if (c->dac_output_ref_dbm > 10.0f || c->dac_output_ref_dbm < -40.0f)
        printf("  [WARN] dac_output_ref_dbm = %.4f outside HW limit -40 ~ +10 dBm (HW clamps)\n\r", c->dac_output_ref_dbm);
    wr(b, REG_DAC_OUTPUT_REF_DBM,            enc_s(c->dac_output_ref_dbm, 11, 4, "dac_output_ref_dbm"), 11, "dac_output_ref_dbm");
    wr(b, REG_GOAL_REF_DBFS,                 enc_s(c->goal_ref_dbfs, 11, 4, "goal_ref_dbfs"), 11, "goal_ref_dbfs");

    /* 4. AGC 參數 */
    wr(b, REG_AGC_BYPASS_TX_ATT_STATE, chk_u(c->agc_bypass_tx_att_state, 0, 27, "agc_bypass_tx_att_state"), 5, "agc_bypass_tx_att_state");
    if (c->agc_manual_tx_att_en && (c->agc_manual_tx_att_db < 5U || c->agc_manual_tx_att_db > 130U))
        printf("  [WARN] agc_manual_tx_att_db = %u outside analog range 5 ~ 130 dB (HW clamps)\n\r", c->agc_manual_tx_att_db);
    wr(b, REG_AGC_MANUAL_TX_ATT_DB,    c->agc_manual_tx_att_db, 8, "agc_manual_tx_att_db");
    wr(b, REG_AGC_MANUAL_RX_ATT_STATE, chk_u(c->agc_manual_rx_att_state, 0, 6, "agc_manual_rx_att_state"), 3, "agc_manual_rx_att_state");
    wr(b, REG_AGC_TARGET_POWER,        (u32)(u8)c->agc_target_power_dbm, 8, "agc_target_power");
    wr(b, REG_AGC_LINEAR_MODE_OFFSET,  enc_s(c->agc_linear_mode_offset_db, 12, 4, "agc_linear_mode_offset_db"), 12, "agc_linear_mode_offset");
    wr(b, REG_AGC_MANUAL_MODE_OFFSET,  enc_s(c->agc_manual_mode_offset_db, 12, 4, "agc_manual_mode_offset_db"), 12, "agc_manual_mode_offset");

    /* 5. 模式 / enable (最後) */
    wr(b, REG_AGC_MANUAL_RX_ATT_EN,    chk_u(c->agc_manual_rx_att_en, 0, 1, "agc_manual_rx_att_en"), 1, "agc_manual_rx_att_en");
    wr(b, REG_AGC_MANUAL_TX_ATT_EN,    chk_u(c->agc_manual_tx_att_en, 0, 1, "agc_manual_tx_att_en"), 1, "agc_manual_tx_att_en");
    wr(b, REG_AGC_BYPASS_AGC,          chk_u(c->agc_bypass_agc, 0, 1, "agc_bypass_agc"), 1, "agc_bypass_agc");
    wr(b, REG_AGC_BYPASS_SR_UPDATE,    0, 2, "agc_bypass_sr_update");
    wr(b, REG_AGC_REG5,                c->agc_reg5, 8, "agc_reg5");
    wr(b, REG_GAIN_INDEX_MODE_SEL,     chk_u(c->gain_index_mode_sel, 0, 1, "gain_index_mode_sel"), 1, "gain_index_mode_sel");
    wr(b, REG_SIGNAL_SOURCE_SELECT,    chk_u(c->signal_source_select, 0, 2, "signal_source_select"), 2, "signal_source_select");   /* Debug_008: 2 = all_zero */
    wr(b, REG_BYPASS_AXIS_IQ,          chk_u(c->bypass_axis_iq, 0, 1, "bypass_axis_iq"), 1, "bypass_axis_iq");
    wr(b, REG_IN_BAND_FIR_ENABLE,      chk_u(c->in_band_fir_enable, 0, 1, "in_band_fir_enable"), 1, "in_band_fir_enable");

    printf("=== Register map %s done: %d error(s) / warning(s) ===\n\r", c->name, g_err);
    return g_err;
}

void register_map_dump_sys(void)
{
    u32 off;

    printf("--- system register dump (base 0x%08lX) ---\n\r", (unsigned long)REG_MAP_SYS_BASE);
    for (off = 0; off <= SYS_LAST; off += 4U)
        printf("  sys%-2lu 0x%02lX = 0x%08lX\n\r", (unsigned long)(off / 4U), (unsigned long)off,
               (unsigned long)Xil_In32(REG_MAP_SYS_BASE + off));
}

void register_map_dump(UINTPTR base, const char *name)
{
    u32 off;

    printf("--- %s register dump (base 0x%08lX) ---\n\r", name, (unsigned long)base);
    for (off = 0; off <= REG_CH_LAST; off += 4U)
        printf("  mem%-2lu 0x%03lX = 0x%08lX\n\r", (unsigned long)(off / 4U), (unsigned long)off, (unsigned long)Xil_In32(base + off));
}

/* 有號 S?.4 (已符號擴展) -> dB */
static double q4(u32 raw) { return (double)(s32)raw / 16.0; }

int register_map_status(UINTPTR base, const char *name)
{
    u32 cnt0 = Xil_In32(base + REG_STATUS_SNAPSHOT) & 0xFFFFU;
    u32 cnt, fl, n = 0;

    Xil_Out32(base + REG_STATUS_SNAPSHOT, 1U);
    do {                                      /* 兩個 domain 鎖存完成約 < 0.2 us */
        cnt = Xil_In32(base + REG_STATUS_SNAPSHOT) & 0xFFFFU;
    } while (cnt == cnt0 && ++n < 1000U);
    if (cnt == cnt0) {
        printf("  [ERR] %s status snapshot timeout\n\r", name);
        return -1;
    }
    fl = Xil_In32(base + REG_ST_ADC_FLAGS);
    printf("--- %s status (snapshot #%lu) ---\n\r", name, (unsigned long)cnt);
    printf("  power_amp            %lu\n\r", (unsigned long)Xil_In32(base + REG_ST_POWER_AMP));
    printf("  gain_index_power_fit %+.4f dB\n\r", q4(Xil_In32(base + REG_ST_GAIN_INDEX_POWER_FIT)));
    printf("  goal_db              %+.4f dBFS\n\r", q4(Xil_In32(base + REG_ST_GOAL_DB)));
    printf("  goal_rel_db          %+.4f dB\n\r", q4(Xil_In32(base + REG_ST_GOAL_REL_DB)));
    printf("  gain_index_tx        %+.4f dB\n\r", q4(Xil_In32(base + REG_ST_GAIN_INDEX_TX)));
    printf("  adc_flags            ot1 %lu ot2 %lu or %lu ov %lu\n\r", (unsigned long)(fl & 1U), (unsigned long)((fl >> 1) & 1U),
           (unsigned long)((fl >> 2) & 1U), (unsigned long)((fl >> 3) & 1U));
    return 0;
}

void register_map_init(void)
{
    int err = 0;
    int n;

    err += register_map_apply_sys(&REG_MAP_CFG_SYS);
    for (n = 0; n < REG_MAP_CH_NUM; n++)
        err += register_map_apply(&REG_MAP_CFG_CH[n]);
    if (err)
        printf("Register map init: %d error(s) / warning(s), check the log above\n\r", err);
    else
        printf("Register map init: system / ch1 ~ ch%d OK (build %lu)\n\r", REG_MAP_CH_NUM, (unsigned long)register_map_build_version());
}
