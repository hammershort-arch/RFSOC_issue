#include "rfdc.h"

#include <sleep.h>
#include <stdbool.h>
#include <stdio.h>
#include <xrfdc.h>

#include <xil_printf.h>

static uint8_t ADCTileSequence[4] = {1, 0, 2, 3};
static uint8_t DACTileSequence[4] = {0, 1, 2, 3};

int rfdc_dev_init(metal_phys_addr_t RFdcDeviceBaseAddr, XRFdc *RFdcInstPtr)
{
#ifndef __BAREMETAL__
    struct metal_device *devicePtr;
#endif
    XRFdc_Config *RFdcConfigPtr;
    if (!(RFdcConfigPtr = XRFdc_LookupConfig(RFdcDeviceBaseAddr)))
    {
        printf("Unable to lookup config for %08lx.\r\n", RFdcDeviceBaseAddr);
        return XRFDC_FAILURE;
    }

    if (!RFdcInstPtr)
    {
        printf("RFdcInstPtr is null.\r\n");
        return XRFDC_FAILURE;
    }

#ifndef __BAREMETAL__
    if (XRFdc_RegisterMetal(RFdcInstPtr, 0, &devicePtr) != XRFDC_SUCCESS)
    {
        printf("Unable to register metal for RFdcInstPtr.\r\n");
        return XRFDC_FAILURE;
    }
#endif

    if (XRFdc_CfgInitialize(RFdcInstPtr, RFdcConfigPtr) != XRFDC_SUCCESS)
    {
        printf("Can not configure and initialize RFdcInstPtr.\r\n");
        return XRFDC_FAILURE;
    }

    return XRFDC_SUCCESS;
}

int rfdc_reset_dc(XRFdc *RFdcInstPtr)
{
    if (!RFdcInstPtr)
    {
        printf("RFdcInstPtr is null.\r\n");
        return XRFDC_FAILURE;
    }

    if (RFdcInstPtr->IsReady != XRFDC_COMPONENT_IS_READY)
    {
        printf("RFdcInstPtr is not initialized.\r\n");
        return XRFDC_FAILURE;
    }

    XRFdc_IPStatus RFdcIPStatus;
    if (XRFdc_GetIPStatus(RFdcInstPtr, &RFdcIPStatus) != XRFDC_SUCCESS)
    {
        printf("Unable to get IP status.\r\n");
        return XRFDC_FAILURE;
    }

    for (int i = 4; i > 0; i--)
        if (RFdcIPStatus.ADCTileStatus[ADCTileSequence[i - 1]].IsEnabled)
        {
            if (XRFdc_Shutdown(RFdcInstPtr, XRFDC_ADC_TILE, ADCTileSequence[i - 1]) != XRFDC_SUCCESS)
                printf("Failure to shutdown ADC tile %d.\r\n", ADCTileSequence[i - 1]);
            else
                printf("Success to shutdown ADC tile %d.\r\n", ADCTileSequence[i - 1]);
        }

    for (int i = 4; i > 0; i--)
        if (RFdcIPStatus.DACTileStatus[DACTileSequence[i - 1]].IsEnabled)
        {
            if (XRFdc_Shutdown(RFdcInstPtr, XRFDC_DAC_TILE, DACTileSequence[i - 1]) != XRFDC_SUCCESS)
                printf("Failure to shutdown DAC tile %d.\r\n", DACTileSequence[i - 1]);
            else
                printf("Success to shutdown DAC tile %d.\r\n", DACTileSequence[i - 1]);
        }

    sleep(1);

    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.DACTileStatus[DACTileSequence[i - 0]].IsEnabled)
        {
            if (XRFdc_StartUp(RFdcInstPtr, XRFDC_DAC_TILE, DACTileSequence[i - 0]) != XRFDC_SUCCESS)
                printf("Failure to start up DAC tile %d.\r\n", DACTileSequence[i - 0]);
            else
                printf("Success to start up DAC tile %d.\r\n", DACTileSequence[i - 0]);
        }

    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.ADCTileStatus[ADCTileSequence[i - 0]].IsEnabled)
        {
            if (XRFdc_StartUp(RFdcInstPtr, XRFDC_ADC_TILE, ADCTileSequence[i - 0]) != XRFDC_SUCCESS)
                printf("Failure to start up ADC tile %d.\r\n", ADCTileSequence[i - 0]);
            else
                printf("Success to start up ADC tile %d.\r\n", ADCTileSequence[i - 0]);
        }

    return XRFDC_SUCCESS;
}

int rfdc_mts_exec(XRFdc *RFdcInstPtr)
{
    if (!RFdcInstPtr)
    {
        printf("RFdcInstPtr is null.\r\n");
        return XRFDC_FAILURE;
    }

    if (RFdcInstPtr->IsReady != XRFDC_COMPONENT_IS_READY)
    {
        printf("RFdcInstPtr is not initialized.\r\n");
        return XRFDC_FAILURE;
    }

    XRFdc_IPStatus RFdcIPStatus;
    if (XRFdc_GetIPStatus(RFdcInstPtr, &RFdcIPStatus) != XRFDC_SUCCESS)
    {
        printf("Unable to get IP status.\r\n");
        return XRFDC_FAILURE;
    }

    // DAC
    printf("Start multi-converter sync for DAC.\r\n");
    XRFdc_MultiConverter_Sync_Config RFdcSyncConfigDAC;
    if (XRFdc_MultiConverter_Init(&RFdcSyncConfigDAC, NULL, NULL, XRFDC_TILE_ID0) != XRFDC_MTS_OK)
    {
        printf("Unable to init RFdcSyncConfigDAC.\r\n");
        return XRFDC_FAILURE;
    }
    RFdcSyncConfigDAC.Tiles = 0x0F; // 0, 1, 2, 3
    RFdcSyncConfigDAC.Target_Latency = RFDC_DAC_TARGET_LATENCY;

    int RFdcStatusDAC = XRFDC_MTS_OK;
    if ((RFdcStatusDAC = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_DAC_TILE, &RFdcSyncConfigDAC)) != XRFDC_MTS_OK)
        printf("Failure to multi-tile sync (MTS) for DAC. Error code %d.\r\n", RFdcStatusDAC);
    else
        printf("Success to multi-tile sync (MTS) for DAC.\r\n");

    // ADC
    printf("Start multi-converter sync for ADC.\r\n");
    XRFdc_MultiConverter_Sync_Config RFdcSyncConfigADC;
    if (XRFdc_MultiConverter_Init(&RFdcSyncConfigADC, NULL, NULL, XRFDC_TILE_ID0) != XRFDC_MTS_OK)
    {
        printf("Unable to init RFdcSyncConfigADC.\r\n");
        return XRFDC_FAILURE;
    }
    RFdcSyncConfigADC.Tiles = 0x0F; // 0, 1, 2, 3
    RFdcSyncConfigADC.Target_Latency = RFDC_ADC_TARGET_LATENCY;

    int RFdcStatusADC = XRFDC_MTS_OK;
    if ((RFdcStatusADC = XRFdc_MultiConverter_Sync(RFdcInstPtr, XRFDC_ADC_TILE, &RFdcSyncConfigADC)) != XRFDC_MTS_OK)
        printf("Failure to multi-tile sync (MTS) for ADC. Error code %d.\r\n", RFdcStatusADC);
    else
        printf("Success to multi-tile sync (MTS) for ADC.\r\n");

    // Failure
    if (RFdcStatusDAC != XRFDC_MTS_OK || RFdcStatusADC != XRFDC_MTS_OK)
        return XRFDC_FAILURE;

    // Report DAC
    printf("============================== DAC Report ==============================\r\n");
    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.DACTileStatus[i].IsEnabled)
        {
            u32 factor;
            if (XRFdc_GetInterpolationFactor(RFdcInstPtr, i, 0, &factor) != XRFDC_SUCCESS)
                printf("Failure to get interpolation factor.\r\n");
            else
                printf("DAC%d: Latency(T1) = %03d, Adjusted Delay Offset (T%d) = %03d.\r\n", i, RFdcSyncConfigDAC.Latency[i], factor, RFdcSyncConfigDAC.Offset[i]);
        }

    // Report ADC
    printf("============================== ADC Report ==============================\r\n");
    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.ADCTileStatus[i].IsEnabled)
        {
            u32 factor;
            if (XRFdc_GetDecimationFactor(RFdcInstPtr, i, 0, &factor) != XRFDC_SUCCESS)
                printf("Failure to get interpolation factor.\r\n");
            else
                printf("ADC%d: Latency(T1) = %03d, Adjusted Delay Offset (T%d) = %03d.\r\n", i, RFdcSyncConfigADC.Latency[i], factor, RFdcSyncConfigADC.Offset[i]);
        }

    // End Report
    printf("============================== Report End ==============================\r\n");
    return XRFDC_SUCCESS;
}

int rfdc_mbs_prep(XRFdc *RFdcInstPtr)
{
    if (!RFdcInstPtr)
    {
        printf("RFdcInstPtr is null\r\n");
        return XRFDC_FAILURE;
    }

    if (RFdcInstPtr->IsReady != XRFDC_COMPONENT_IS_READY)
    {
        printf("RFdcInstPtr is not initialized.\r\n");
        return XRFDC_FAILURE;
    }

    XRFdc_IPStatus RFdcIPStatus;
    if (XRFdc_GetIPStatus(RFdcInstPtr, &RFdcIPStatus) != XRFDC_SUCCESS)
    {
        printf("Unable to get IP status.\r\n");
        return XRFDC_FAILURE;
    }

    XRFdc_MultiConverter_Sync_Config RFdcSyncConfigDAC;
    XRFdc_MultiConverter_Sync_Config RFdcSyncConfigADC;

    // Turn off sysref
    if (XRFdc_MTS_Sysref_Config(RFdcInstPtr, &RFdcSyncConfigDAC, &RFdcSyncConfigADC, false) != XRFDC_MTS_OK)
    {
        printf("Unable to turn off MTS system reference.\r\n");
        return XRFDC_FAILURE;
    }

    // DAC
    int blockDAC[2] = {0, 2};
    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.DACTileStatus[i].IsEnabled)
        {
            for (int j = 0; j < 2; j++)
            {
                XRFdc_Mixer_Settings RFdcMixerSettingsDAC;

                if (XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j], &RFdcMixerSettingsDAC) != XRFDC_SUCCESS)
                {
                    printf("Unable to get mixer settings for DAC tile%d, block%d.\r\n", i, blockDAC[j]);
                    continue;
                }
                RFdcMixerSettingsDAC.EventSource = XRFDC_EVNT_SRC_SYSREF;
                if (XRFdc_SetMixerSettings(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j], &RFdcMixerSettingsDAC) != XRFDC_SUCCESS)
                {
                    printf("Unable to set mixer settings for DAC tile%d, block%d.\r\n", i, blockDAC[j]);
                    continue;
                }
            }

            for (int j = 0; j < 2; j++)
            {
                XRFdc_QMC_Settings RFdcQMCSettingsDAC;
                if (XRFdc_GetQMCSettings(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j], &RFdcQMCSettingsDAC) != XRFDC_SUCCESS)
                {
                    printf("Unable to get QMC settings for DAC tile%d, block%d.\r\n", i, blockDAC[j]);
                    continue;
                }
                RFdcQMCSettingsDAC.EnableGain = false;
                RFdcQMCSettingsDAC.EnablePhase = false;
                RFdcQMCSettingsDAC.EventSource = XRFDC_EVNT_SRC_SYSREF;
                if (XRFdc_SetQMCSettings(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j], &RFdcQMCSettingsDAC) != XRFDC_SUCCESS)
                {
                    printf("Unable to set QMC settings for DAC tile%d, block%d.\r\n", i, blockDAC[j]);
                    continue;
                }
            }

            for (int j = 0; j < 2; j++)
            {
                XRFdc_CoarseDelay_Settings RFdcCoarseDelaySettingsDAC;
                if (XRFdc_GetCoarseDelaySettings(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j], &RFdcCoarseDelaySettingsDAC) != XRFDC_SUCCESS)
                {
                    printf("Unable to get coarse delay settings for DAC tile%d, block%d.\r\n", i, blockDAC[j]);
                    continue;
                }
                RFdcCoarseDelaySettingsDAC.CoarseDelay = 0;
                RFdcCoarseDelaySettingsDAC.EventSource = XRFDC_EVNT_SRC_SYSREF;
                if (XRFdc_SetCoarseDelaySettings(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j], &RFdcCoarseDelaySettingsDAC) != XRFDC_SUCCESS)
                {
                    printf("Unable to set coarse delay settings for DAC tile%d, block%d.\r\n", i, blockDAC[j]);
                    continue;
                }
            }
        }

    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.DACTileStatus[i].IsEnabled)
            for (int j = 0; j < 2; j++)
                if (XRFdc_ResetNCOPhase(RFdcInstPtr, XRFDC_DAC_TILE, i, blockDAC[j]) != XRFDC_MTS_OK)
                    printf("Unable to reset NCO phase for DAC tile%d, block%d.\r\n", i, blockDAC[j]);

    // ADC
    int blockADC[2] = {0, 1};
    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.ADCTileStatus[i].IsEnabled)
        {
            for (int j = 0; j < 2; j++)
            {
                XRFdc_Mixer_Settings RFdcMixerSettingsADC;

                if (XRFdc_GetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j], &RFdcMixerSettingsADC) != XRFDC_SUCCESS)
                {
                    printf("Unable to get mixer settings for ADC tile%d, block%d.\r\n", i, blockADC[j]);
                    continue;
                }
                RFdcMixerSettingsADC.EventSource = XRFDC_EVNT_SRC_SYSREF;
                if (XRFdc_SetMixerSettings(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j], &RFdcMixerSettingsADC) != XRFDC_SUCCESS)
                {
                    printf("Unable to set mixer settings for ADC tile%d, block%d.\r\n", i, blockADC[j]);
                    continue;
                }
            }

            for (int j = 0; j < 2; j++)
            {
                XRFdc_QMC_Settings RFdcQMCSettingsADC;
                if (XRFdc_GetQMCSettings(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j], &RFdcQMCSettingsADC) != XRFDC_SUCCESS)
                {
                    printf("Unable to get QMC settings for ADC tile%d, block%d.\r\n", i, blockADC[j]);
                    continue;
                }
                RFdcQMCSettingsADC.EnableGain = false;
                RFdcQMCSettingsADC.EnablePhase = false;
                RFdcQMCSettingsADC.EventSource = XRFDC_EVNT_SRC_SYSREF;
                if (XRFdc_SetQMCSettings(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j], &RFdcQMCSettingsADC) != XRFDC_SUCCESS)
                {
                    printf("Unable to set QMC settings for ADC tile%d, block%d.\r\n", i, blockADC[j]);
                    continue;
                }
            }

            for (int j = 0; j < 2; j++)
            {
                XRFdc_CoarseDelay_Settings RFdcCoarseDelaySettingsADC;
                if (XRFdc_GetCoarseDelaySettings(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j], &RFdcCoarseDelaySettingsADC) != XRFDC_SUCCESS)
                {
                    printf("Unable to get coarse delay settings for ADC tile%d, block%d.\r\n", i, blockADC[j]);
                    continue;
                }
                RFdcCoarseDelaySettingsADC.CoarseDelay = 0;
                RFdcCoarseDelaySettingsADC.EventSource = XRFDC_EVNT_SRC_SYSREF;
                if (XRFdc_SetCoarseDelaySettings(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j], &RFdcCoarseDelaySettingsADC) != XRFDC_SUCCESS)
                {
                    printf("Unable to set coarse delay settings for ADC tile%d, block%d.\r\n", i, blockADC[j]);
                    continue;
                }
            }
        }

    for (int i = 0; i < 4; i++)
        if (RFdcIPStatus.ADCTileStatus[i].IsEnabled)
            for (int j = 0; j < 2; j++)
                if (XRFdc_ResetNCOPhase(RFdcInstPtr, XRFDC_ADC_TILE, i, blockADC[j]) != XRFDC_MTS_OK)
                    printf("Unable to reset NCO phase for ADC tile%d, block%d.\r\n", i, blockADC[j]);

    // Turn on sysref
    if (XRFdc_MTS_Sysref_Config(RFdcInstPtr, &RFdcSyncConfigDAC, &RFdcSyncConfigADC, true) != XRFDC_MTS_OK)
    {
        printf("Unable to turn on MTS system reference.\r\n");
        return XRFDC_FAILURE;
    }

    // Complete
    printf("MTS system reference prepare is completed.\r\n");

    return XRFDC_SUCCESS;
}