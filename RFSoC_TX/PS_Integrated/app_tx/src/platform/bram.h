#ifndef __BRAM_H__
#define __BRAM_H__

#include "xparameters.h"
#include "xbram.h"

//#define BRAM_BASE           0xA0000000
//#define BRAM_HIGH           0xA0001FFF

// cal_plus_gain_control_ch1 ~ ch8 gain table BRAM (PJ22045_1R8T XSA pj22045_1r8t_cal8ch_02, 2026-10-15)
//   ch1 0xA009_A000, ch2 0xA009_C000, ... ch8 0xA00A_8000 (各 8 KB)
#define GAIN_OFFSET_CH_NUM              8
#define GAIN_OFFSET_CH1_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH1_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH2_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH2_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH3_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH3_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH4_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH4_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH5_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH5_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH6_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH6_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH7_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH7_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR
#define GAIN_OFFSET_CH8_BRAM_BASE       XPAR_CAL_PLUS_GAIN_CONTROL_CH8_CALIBRATION_AXI_BRAM_CTRL_0_BASEADDR


#define START_ADDR          0  // RAM 起始地址 范围：0 ~ 4095
#define BRAM_DATA_BYTE      4  // BRAM 数据字节个数

#define GAIN_TBL_SIZE   2048
#define BRAM_MAX_SIZE   8192
#define BRAM_OFFSET     0

extern uint32_t GAIN_OFFSET_TBL[GAIN_TBL_SIZE];


//函数声明
//int BramPsWrite_uint32(uint32_t *pdata, uint32_t offset, uint32_t length);
//int BramPsRead_uint32(uint32_t *pbuff, uint32_t offset, uint32_t length);
//int BramPlReadSet(uint32_t length, uint32_t freq);
//int BramPlReadStart(void);
//int BramPlReadStop(void);

void gain_offset_tabel_initialize(void);
int BramPsWrite_uint32(uint32_t *pdata, uint32_t offset, uint32_t length, uint32_t bram_base);


#endif