#ifndef __RFDC_H__
#define __RFDC_H__

#include <xrfdc.h>

#define RFDC_ADC_TARGET_LATENCY 390;
#define RFDC_DAC_TARGET_LATENCY 666;

int rfdc_dev_init(metal_phys_addr_t, XRFdc *);
int rfdc_reset_dc(XRFdc *);
int rfdc_mts_exec(XRFdc *);
int rfdc_mbs_prep(XRFdc *);

#endif
