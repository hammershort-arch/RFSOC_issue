/*
 * adcGetThresh.h
 *
 *  Created on: Dec 17, 2020
 *      Author: fpinto
 */

#ifndef SRC_ADCGETTHRESH_H_
#define SRC_ADCGETTHRESH_H_

/***************************** Include Files *********************************/
#include "xil_types.h"
#include <xrfdc.h>


/************************** Constant Definitions *****************************/

/**************************** Type Definitions *******************************/

/***************** Macros (Inline Functions) Definitions *********************/

/************************** Function Prototypes ******************************/


int adcGetThresh(XRFdc *RFdcInstPtr, u32 *cmdVals);
int adcSetThresh(XRFdc *RFdcInstPtr, u32 *cmdVals);
int adcClearThresh(XRFdc *RFdcInstPtr, u32 *cmdVals);
int adcInitThresh(XRFdc *RFdcInstPtr);


/************************** Variable Definitions *****************************/



#endif /* SRC_ADCGETTHRESH_H_ */
