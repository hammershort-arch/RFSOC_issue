#include "iic.h"

#include <stdio.h>
#include <xinterrupt_wrap.h>

/*
 * Register map slave
 *
 *   Write: [S] addr+W [reg] [data0] [data1] ... [P]   -> RegMap[reg] = data0, RegMap[reg+1] = data1, ...
 *   Read : [S] addr+W [reg] [Sr] addr+R [data0] [data1] ... [P]   -> data0 = RegMap[reg], data1 = RegMap[reg+1], ...
 *
 * The first byte of every master write sets the register pointer,
 * every data byte afterwards (written or read) auto-increments it.
 */
static volatile u8 *IicRegMap;
static u32 IicRegMapSize;
static IicRegWriteHook IicWriteHook;
static u8 IicRegPtr;
static int IicExpectRegAddr = 1;

static void IicSlaveRegMapIntrHandler(void *CallBackRef);

int iic_slave_init(u32 XIicPsBaseAddress, XIicPs *XIicPsInstPtr, volatile u8 *RegMap, u32 RegMapSize, IicRegWriteHook WriteHook)
{
    XIicPs_Config *XIicPsConfigPtr;
    if (!(XIicPsConfigPtr = XIicPs_LookupConfig(XIicPsBaseAddress)))
    {
        printf("Unable to lookup config for %08x.\r\n", XIicPsBaseAddress);
        return XST_FAILURE;
    }

    if (!XIicPsInstPtr)
    {
        printf("XIicPsInstPtr is null.\r\n");
        return XST_SUCCESS;
    }

    if (XIicPs_CfgInitialize(XIicPsInstPtr, XIicPsConfigPtr, XIicPsConfigPtr->BaseAddress) != XST_SUCCESS)
    {
        printf("Can not configure and initialize XIicPsInstPtr.\r\n");
        return XST_FAILURE;
    }

    if (XIicPs_SelfTest(XIicPsInstPtr) != XST_SUCCESS)
    {
        printf("XIicPsInstPtr self-test failed.\r\n");
        return XST_FAILURE;
    }

    IicRegMap = RegMap;
    IicRegMapSize = RegMapSize;
    IicWriteHook = WriteHook;

    if (XSetupInterruptSystem(XIicPsInstPtr, IicSlaveRegMapIntrHandler, XIicPsConfigPtr->IntrId, XIicPsConfigPtr->IntrParent, XINTERRUPT_DEFAULT_PRIORITY) != XST_SUCCESS)
    {
        printf("XIicPsInstPtr setup interrupt system failed.\r\n");
        return XST_FAILURE;
    }

    XIicPs_SetupSlave(XIicPsInstPtr, IIC_SLAVE_ADDR);
    XIicPs_SetSClk(XIicPsInstPtr, IIC_SCLK_RATE);

    // Always listening: no SlaveRecv / SlaveSend arming, the ISR serves both directions
    XIicPs_WriteReg(XIicPsConfigPtr->BaseAddress, XIICPS_ISR_OFFSET, XIICPS_IXR_ALL_INTR_MASK);
    XIicPs_EnableInterrupts(XIicPsConfigPtr->BaseAddress, XIICPS_IXR_DATA_MASK | XIICPS_IXR_COMP_MASK);
    return XST_SUCCESS;
}

static void IicSlaveRegMapIntrHandler(void *CallBackRef)
{
    XIicPs *InstancePtr = (XIicPs *)CallBackRef;
    UINTPTR BaseAddr = InstancePtr->Config.BaseAddress;

    u32 IntrStatus = XIicPs_ReadReg(BaseAddr, XIICPS_ISR_OFFSET);
    XIicPs_WriteReg(BaseAddr, XIICPS_ISR_OFFSET, IntrStatus);
    IntrStatus &= ~XIicPs_ReadReg(BaseAddr, XIICPS_IMR_OFFSET);

    // Master write: 1st byte -> register pointer, following bytes -> registers
    while (XIicPs_ReadReg(BaseAddr, XIICPS_SR_OFFSET) & XIICPS_SR_RXDV_MASK)
    {
        u8 Data = (u8)XIicPs_ReadReg(BaseAddr, XIICPS_DATA_OFFSET);
        if (IicExpectRegAddr)
        {
            IicRegPtr = Data;
            IicExpectRegAddr = 0;
        }
        else
        {
            if (IicRegPtr < IicRegMapSize && (!IicWriteHook || IicWriteHook(IicRegPtr, Data) == XST_SUCCESS))
            {
                IicRegMap[IicRegPtr] = Data;
            }
            IicRegPtr++;
        }
    }

    // Master read: hand out one register per DATA interrupt
    u32 Status = XIicPs_ReadReg(BaseAddr, XIICPS_SR_OFFSET);
    if ((IntrStatus & XIICPS_IXR_DATA_MASK) && (Status & XIICPS_SR_RXRW_MASK) && !(Status & XIICPS_SR_TXDV_MASK))
    {
        u8 Data = (IicRegPtr < IicRegMapSize) ? IicRegMap[IicRegPtr] : 0xFF;
        XIicPs_WriteReg(BaseAddr, XIICPS_DATA_OFFSET, Data);
        IicRegPtr++;
    }

    // STOP: transaction done, next write starts with a register address again
    if (IntrStatus & XIICPS_IXR_COMP_MASK)
    {
        IicExpectRegAddr = 1;
        // Drop the byte pre-loaded for a read the master did not take
        XIicPs_WriteReg(BaseAddr, XIICPS_CR_OFFSET, XIicPs_ReadReg(BaseAddr, XIICPS_CR_OFFSET) | XIICPS_CR_CLR_FIFO_MASK);
    }
}
