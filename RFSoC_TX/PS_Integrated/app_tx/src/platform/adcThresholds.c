/*
 * adcThresholds.c
 *
 *  Created on: Dec 17, 2020
 *      Author: fpinto
 */


/***************************** Include Files *********************************/
#include "xil_io.h"
#include "xil_types.h"
#include <stdio.h>
#include <string.h>
#include "xparameters.h"
#include "xrfdc.h"
#include "adcThresholds.h"


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/

/************************** Variable Definitions *****************************/

/************************** Function Definitions ******************************/


/*****************************************************************************/
/**
*
* adcSetThresh ADC Set Threshold
*
* @param	RFdcInstPtr, cmdVals
*
* @return	XRFDC_SUCCESS / XRFDC_FAILURE
*
* @note		TBD
*
******************************************************************************/
int adcSetThresh (XRFdc *RFdcInstPtr, u32 *cmdVals)
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

  // // Initial Setup
  // XRFdc_Threshold_Settings Threshold_Settings;
  // // Setup values for threshold 0 and 1
  // Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_BOTH; 
  // // Set threshold0 mode to Sticky Under
  // Threshold_Settings.ThresholdMode[0] = XRFDC_TRSHD_STICKY_UNDER; 
  // // Measured in 14-bit unsigned LSBs
  // Threshold_Settings.ThresholdUnderVal[0] = 1000; 
  // // Data must be below lower threshold for 10*8 4 GSPS RF-ADC samples
  // Threshold_Settings.ThresholdAvgVal[0] = 10; 
  // // Write threshold values to the selected Tile / RF-ADC
  // XRFdc_SetThresholdSettings(ptr, Tile, Block, &Threshold_Settings);


	u32 Tile_Id;
	u32 Block_Id;
	u32 Num;
	u32 Mode;
	u32 OverVal;
	u32 UnderVal;
	u32 AvgVal;
	u32 ThreshMode;
	u32 Idx;
	char* threshmode;

	//int Status;
	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Num = cmdVals[2];
	Mode = cmdVals[3];
	UnderVal = cmdVals[4];
	OverVal = cmdVals[5];
	AvgVal = cmdVals[6];

	XRFdc_IPStatus ipStatus;


    XRFdc_Threshold_Settings Threshold_Settings;

    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Set Threshold Settings ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

		switch(Num) {
		case 0 :
			Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_0;
			break;
		case 1 :
			Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_1;
			break;
		case 3 :
			Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_BOTH;
			break;
		default :
			xil_printf("ERROR: Invalid <num> Value - supported values are [0 1 3]. Aborting command...\r\n\n");
			return XRFDC_FAILURE;
		}

		switch(Mode) {
		case 0 :
			ThreshMode = XRFDC_TRSHD_OFF;
			threshmode = "XRFDC_TRSHD_OFF";
			break;
		case 1 :
			ThreshMode = XRFDC_TRSHD_STICKY_OVER;
			threshmode = "XRFDC_TRSHD_STICKY_OVER";
			break;
		case 2 :
			ThreshMode = XRFDC_TRSHD_STICKY_UNDER;
			threshmode = "XRFDC_TRSHD_STICKY_UNDER";
			break;
		case 3 :
			ThreshMode = XRFDC_TRSHD_HYSTERISIS;
			threshmode = "XRFDC_TRSHD_HYSTERISIS";
			break;
		default :
			xil_printf("ERROR: Invalid <mode> Value - supported values are [0,1,2,3]. Aborting command...\r\n\n");
			return XRFDC_FAILURE;
		}

		// <num> = 3 (XRFDC_UPDATE_THRESHOLD_BOTH = 0x4): threshold 0 / 1 寫入相同設定
		// (原本以 [Num] 取 index, Num = 3 時會超出 ThresholdMode[2] 等陣列)
		for (Idx = 0; Idx < 2; Idx++) {
			if ((Num != 3) && (Idx != Num))
				continue;
			Threshold_Settings.ThresholdMode[Idx] = ThreshMode;
			Threshold_Settings.ThresholdUnderVal[Idx] = UnderVal;
			Threshold_Settings.ThresholdOverVal[Idx] = OverVal;
			// Data must be below lower threshold for AvgVal*8 Fs RF-ADC samples
			Threshold_Settings.ThresholdAvgVal[Idx] = AvgVal;
		}

        // Write threshold values to the selected Tile / RF-ADC
		xil_printf("Calling XRFdc_SetThresholdSettings for Tile%d ch%d\r\n", Tile_Id, Block_Id);
		xil_printf("   UpdateThreshold       = %d (Port %d)\r\n",Num, Num+1);
		xil_printf("   ThresholdMode[%d]      = %d (%s)\r\n ", Num, Mode,threshmode );
		xil_printf("  ThresholdUnderVal[%d]  = %d\r\n", Num, UnderVal);
		xil_printf("   ThresholdOverVal[%d]   = %d\r\n", Num, OverVal);
		xil_printf("   ThresholdAvgVal[%d]    = %d\r\n", Num, AvgVal);

        if (XRFdc_SetThresholdSettings(RFdcInstPtr, Tile_Id, Block_Id, &Threshold_Settings) != XRFDC_SUCCESS)
        {
            printf("Unable to set threshold settings for ADC tile%d, block%d.\r\n", Tile_Id, Block_Id);
            return XRFDC_FAILURE;
        }
	}
	else
	{
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
		return XRFDC_FAILURE;
	}

	xil_printf("###############################################\r\n\n");


	return XRFDC_SUCCESS;
}


/*****************************************************************************/
/**
*
* adcGetThresh TBD
*
* @param	RFdcInstPtr, cmdVals
*
* @return	XRFDC_SUCCESS / XRFDC_FAILURE
*
* @note		TBD
*
******************************************************************************/
int adcGetThresh (XRFdc *RFdcInstPtr, u32 *cmdVals)
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

  // // Initial Setup
  // XRFdc_Threshold_Settings Threshold_Settings;
  // // Setup values for threshold 0 and 1
  // Threshold_Settings.UpdateThreshold = XRFDC_UPDATE_THRESHOLD_BOTH; 
  // // Set threshold0 mode to Sticky Under
  // Threshold_Settings.ThresholdMode[0] = XRFDC_TRSHD_STICKY_UNDER; 
  // // Measured in 14-bit unsigned LSBs
  // Threshold_Settings.ThresholdUnderVal[0] = 1000; 
  // // Data must be below lower threshold for 10*8 4 GSPS RF-ADC samples
  // Threshold_Settings.ThresholdAvgVal[0] = 10; 
  // // Write threshold values to the selected Tile / RF-ADC
  // XRFdc_SetThresholdSettings(ptr, Tile, Block, &Threshold_Settings);

	u32 Tile_Id;
	u32 Block_Id;

	//int Status;
	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];


	XRFdc_IPStatus ipStatus;


    XRFdc_Threshold_Settings Threshold_Settings;


    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Get Threshold Settings ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id)) {

		if (XRFdc_GetThresholdSettings(RFdcInstPtr, Tile_Id, Block_Id, &Threshold_Settings) != XRFDC_SUCCESS)
		{
			printf("Unable to get threshold settings for ADC tile%d, block%d.\r\n", Tile_Id, Block_Id);
			return XRFDC_FAILURE;
		}
		xil_printf("    ADC Tile%d ch%d\n\r", Tile_Id, Block_Id);
		xil_printf("    -------------------------------------------\n\r");

		switch(Threshold_Settings.ThresholdMode[0]) {
		case XRFDC_TRSHD_OFF :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_OFF)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		case XRFDC_TRSHD_STICKY_OVER :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_STICKY_OVER)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		case XRFDC_TRSHD_STICKY_UNDER :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_STICKY_UNDER)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		case XRFDC_TRSHD_HYSTERISIS :
			xil_printf("    ThresholdMode[0]     = %d (XRFDC_TRSHD_HYSTERISIS)\n\r", Threshold_Settings.ThresholdMode[0]);
			break;
		default : // shouldn't get here but print out value just in case
			xil_printf("    ThresholdMode[0]     = %d\n\r", Threshold_Settings.ThresholdMode[0]);
		}

	    xil_printf("    ThresholdUnderVal[0] = %d\n\r", Threshold_Settings.ThresholdUnderVal[0]);
	    xil_printf("    ThresholdOverVal[0]  = %d\n\r", Threshold_Settings.ThresholdOverVal[0]);
	    xil_printf("    ThresholdAvgVal[0]   = %d\n\r", Threshold_Settings.ThresholdAvgVal[0]);
	    xil_printf("    -------------------------------------------\n\r");

	    switch(Threshold_Settings.ThresholdMode[1]) {
		case XRFDC_TRSHD_OFF :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_OFF)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		case XRFDC_TRSHD_STICKY_OVER :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_STICKY_OVER)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		case XRFDC_TRSHD_STICKY_UNDER :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_STICKY_UNDER)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		case XRFDC_TRSHD_HYSTERISIS :
			xil_printf("    ThresholdMode[1]     = %d (XRFDC_TRSHD_HYSTERISIS)\n\r", Threshold_Settings.ThresholdMode[1]);
			break;
		default : // shouldn't get here but print out value just in case
			xil_printf("    ThresholdMode[1] = %d\n\r", Threshold_Settings.ThresholdMode[1]);
		}

	    xil_printf("    ThresholdUnderVal[1] = %d\n\r", Threshold_Settings.ThresholdUnderVal[1]);
	    xil_printf("    ThresholdOverVal[1]  = %d\n\r", Threshold_Settings.ThresholdOverVal[1]);
	    xil_printf("    ThresholdAvgVal[1]   = %d\n\r", Threshold_Settings.ThresholdAvgVal[1]);
	    xil_printf("    -------------------------------------------\n\r");
	}
	else
	{
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
		return XRFDC_FAILURE;
	}

	xil_printf("###############################################\r\n\n");



	return XRFDC_SUCCESS;
}

/*****************************************************************************/
/**
*
* adcClearOr ADC Clear Threshold
*
* @param	RFdcInstPtr, cmdVals
*
* @return	XRFDC_SUCCESS / XRFDC_FAILURE
*
* @note		TBD
*
******************************************************************************/
int adcClearThresh (XRFdc *RFdcInstPtr, u32 *cmdVals)
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

	u32 Tile_Id;
	u32 Block_Id;
	u32 Num;
	Tile_Id = cmdVals[0];
	Block_Id = cmdVals[1];
	Num = cmdVals[2];
    Num = Num + 1;

	XRFdc_IPStatus ipStatus;

    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Clear Threshold ===\n\r");

	if(XRFdc_IsADCBlockEnabled(RFdcInstPtr, Tile_Id, Block_Id) == 1) {
		if (XRFdc_SetThresholdClrMode(RFdcInstPtr, Tile_Id, Block_Id, Num,XRFDC_THRESHOLD_CLRMD_MANUAL_CLR) != XRFDC_SUCCESS)
		{
			printf("Unable to set threshold clear mode for ADC tile%d, block%d.\r\n", Tile_Id, Block_Id);
			return XRFDC_FAILURE;
		}
		if (XRFdc_ThresholdStickyClear(RFdcInstPtr, Tile_Id, Block_Id, Num) != XRFDC_SUCCESS)
		{
			printf("Unable to clear threshold for ADC tile%d, block%d.\r\n", Tile_Id, Block_Id);
			return XRFDC_FAILURE;
		}
    	xil_printf("   ADC Tile%d ch%d Threshold %d (Port %d) status has been cleared\r\n", Tile_Id, Block_Id, Num - 1, Num );
	}
	else
	{
		xil_printf("ADC Tile%d ch%d is not available.\n\r", Tile_Id, Block_Id);
		return XRFDC_FAILURE;
	}

	xil_printf("###############################################\r\n\n");

	return XRFDC_SUCCESS;
}

//void adcInitThresh (u32 *cmdVals)
int adcInitThresh (XRFdc *RFdcInstPtr)
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

    // 8 通道 (PJ22045_1R8T, 2026-10-15): chN -> ADC tile (N-1)/2, block (N-1)%2
    //   ch1 m00/m01 = tile0 block0, ch2 m02/m03 = tile0 block1, ... ch8 m32/m33 = tile3 block1

	XRFdc_IPStatus ipStatus;

    u32 Mode            = XRFDC_TRSHD_HYSTERISIS;
	u32 AvgVal          = 10;
	u32 thres1_UnderVal = 10950;   // -3.5 dBFS  (16384 = FS)
	u32 thres1_OverVal  = 11599;   // -3.0 dBFS
    u32 thres2_UnderVal = 2750;    // -15.5 dBFS
	u32 thres2_OverVal  = 2913;    // -15.0 dBFS

    u32  cmd[2];
    u32  ch;

    XRFdc_Threshold_Settings Threshold_0_Settings;
	XRFdc_Threshold_Settings Threshold_1_Settings;

    XRFdc_GetIPStatus(RFdcInstPtr, &ipStatus);
	xil_printf("\n\r###############################################\n\r");
	xil_printf("=== ADC Initial Threshold Settings ===\n\r");

    // threshold 0 setting
    Threshold_0_Settings.UpdateThreshold  = XRFDC_UPDATE_THRESHOLD_0;
    Threshold_0_Settings.ThresholdMode[0] = Mode;
	Threshold_0_Settings.ThresholdAvgVal[0] = AvgVal;
	Threshold_0_Settings.ThresholdUnderVal[0] = thres1_UnderVal;
    Threshold_0_Settings.ThresholdOverVal[0]  = thres1_OverVal;

	// threshold 1 setting
    Threshold_1_Settings.UpdateThreshold  = XRFDC_UPDATE_THRESHOLD_1;
    Threshold_1_Settings.ThresholdMode[1] = Mode;
	Threshold_1_Settings.ThresholdAvgVal[1] = AvgVal;
	Threshold_1_Settings.ThresholdUnderVal[1] = thres2_UnderVal;
    Threshold_1_Settings.ThresholdOverVal[1]  = thres2_OverVal;

    // ch1 ~ ch8: threshold 0 / threshold 1, 設定後讀回印出
    for (ch = 0; ch < 8; ch++) {
        cmd[0] = ch / 2;    /* Tile_Id  */
        cmd[1] = ch % 2;    /* Block_Id */
        if (!XRFdc_IsADCBlockEnabled(RFdcInstPtr, cmd[0], cmd[1])) {
            xil_printf("ch%d: ADC Tile%d block%d is not enabled, threshold not set\n\r", (int)(ch + 1), (int)cmd[0], (int)cmd[1]);
            continue;
        }
        xil_printf("ch%d: ADC Tile%d block%d\n\r", (int)(ch + 1), (int)cmd[0], (int)cmd[1]);
        if (XRFdc_SetThresholdSettings(RFdcInstPtr, cmd[0], cmd[1], &Threshold_0_Settings) != XRFDC_SUCCESS ||
            XRFdc_SetThresholdSettings(RFdcInstPtr, cmd[0], cmd[1], &Threshold_1_Settings) != XRFDC_SUCCESS)
        {
            printf("Unable to set threshold settings for ADC tile%d, block%d.\r\n", (int)cmd[0], (int)cmd[1]);
            return XRFDC_FAILURE;
        }
        if (adcGetThresh(RFdcInstPtr, &cmd[0]) != XRFDC_SUCCESS)
        {
            return XRFDC_FAILURE;
        }
    }

    return XRFDC_SUCCESS;
}


