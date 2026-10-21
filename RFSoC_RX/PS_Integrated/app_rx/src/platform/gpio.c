#include "gpio.h"

#include <stdbool.h>
#include <stdio.h>
#include <xparameters.h>
#include <xstatus.h>

#define GPIO_CMD_N_PIN_ID (78 + 4)
#define GPIO_CMD_P_PIN_ID (78 + 5)
#define GPIO_ACK_N_PIN_ID (78 + 6)
#define GPIO_ACK_P_PIN_ID (78 + 7)

int gpio_axi_init(u32 XGpioBaseAddress, XGpio *XGpioInstPtr, u32 Channel, u32 DirectionMask)
{
    XGpio_Config *XGpioConfigPtr;
    if (!(XGpioConfigPtr = XGpio_LookupConfig(XGpioBaseAddress)))
    {
        printf("Unable to lookup config for %08x.\r\n", XGpioBaseAddress);
        return XST_FAILURE;
    }

    if (!XGpioInstPtr)
    {
        printf("XGpioInstPtr is null.\r\n");
        return XST_SUCCESS;
    }
    if (XGpio_CfgInitialize(XGpioInstPtr, XGpioConfigPtr, XGpioConfigPtr->BaseAddress) != XST_SUCCESS)
    {
        printf("Can not configure and initialize XGpioInstPtr.\r\n");
        return XST_FAILURE;
    }

    // Outputs keep their current level (C_DOUT_DEFAULT after configuration), only the direction is set
    XGpio_SetDataDirection(XGpioInstPtr, Channel, DirectionMask);

    return XST_SUCCESS;
}

int gpio_emio_init(u32 XGpioPsBaseAddr, XGpioPs *XGpioPsInstPtr)
{
    XGpioPs_Config *XGpioPsConfigPtr;
    if (!(XGpioPsConfigPtr = XGpioPs_LookupConfig(XGpioPsBaseAddr)))
    {
        printf("Unable to lookup config for %08x.\r\n", XGpioPsBaseAddr);
        return XST_FAILURE;
    }

    if (!XGpioPsInstPtr)
    {
        printf("XGpioPsInstPtr is null.\r\n");
        return XST_SUCCESS;
    }
    else if (XGpioPs_CfgInitialize(XGpioPsInstPtr, XGpioPsConfigPtr, XGpioPsConfigPtr->BaseAddr) != XST_SUCCESS)
    {
        printf("Can not configure and initialize XGpioPsInstPtr.\r\n");
        return XST_FAILURE;
    }

    XGpioPs_SetDirectionPin(XGpioPsInstPtr, GPIO_CMD_N_PIN_ID, 0);
    XGpioPs_SetDirectionPin(XGpioPsInstPtr, GPIO_CMD_P_PIN_ID, 0);
    XGpioPs_SetDirectionPin(XGpioPsInstPtr, GPIO_ACK_N_PIN_ID, 1);
    XGpioPs_SetDirectionPin(XGpioPsInstPtr, GPIO_ACK_P_PIN_ID, 1);
    XGpioPs_SetOutputEnablePin(XGpioPsInstPtr, GPIO_ACK_N_PIN_ID, true);
    XGpioPs_SetOutputEnablePin(XGpioPsInstPtr, GPIO_ACK_P_PIN_ID, true);
    XGpioPs_WritePin(XGpioPsInstPtr, GPIO_ACK_N_PIN_ID, 0);
    XGpioPs_WritePin(XGpioPsInstPtr, GPIO_ACK_P_PIN_ID, 0);

    return XST_SUCCESS;
}

void gpio_handshake(XGpioPs *XGpioPsInstPtr)
{
    // ACK = 1
    XGpioPs_WritePin(XGpioPsInstPtr, GPIO_ACK_N_PIN_ID, 1);
    XGpioPs_WritePin(XGpioPsInstPtr, GPIO_ACK_P_PIN_ID, 1);
    printf("############################## ACK = 1 ##############################\r\n");

    // Wait for CMD = 1
    while (!XGpioPs_ReadPin(XGpioPsInstPtr, GPIO_CMD_N_PIN_ID) &&
           !XGpioPs_ReadPin(XGpioPsInstPtr, GPIO_CMD_P_PIN_ID));
    printf("############################## CMD = 1 ##############################\r\n");

    // ACK = 0
    XGpioPs_WritePin(XGpioPsInstPtr, GPIO_ACK_N_PIN_ID, 0);
    XGpioPs_WritePin(XGpioPsInstPtr, GPIO_ACK_P_PIN_ID, 0);
    printf("############################## ACK = 0 ##############################\r\n");

    // Wait for CMD = 0
    while (XGpioPs_ReadPin(XGpioPsInstPtr, GPIO_CMD_N_PIN_ID) &&
           XGpioPs_ReadPin(XGpioPsInstPtr, GPIO_CMD_P_PIN_ID));
    printf("############################## CMD = 0 ##############################\r\n");
}