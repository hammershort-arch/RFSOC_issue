#include "iic.h"
#include "rfdc.h"
#include "gpio.h"
#include <metal/log.h>
#include <metal/sys.h>
#include <xil_printf.h>
#include <xparameters.h>

typedef enum IicRegister_t IicRegister;
enum IicRegister_t
{
    IIC_REG_STATUS = 0x00,  // R : IicStatus of the current / last command
    IIC_REG_COMMAND = 0x01, // RW: current / last IicCommand, writes are ignored while BUSY
    IIC_REG_COUNT,
};

typedef enum IicStatus_t IicStatus;
enum IicStatus_t
{
    // 0 is never used, reading it means something is wrong
    IIC_STATUS_BUSY = 1,
    IIC_STATUS_DONE = 2,
    IIC_STATUS_ERROR = 3,
};

typedef enum IicCommand_t IicCommand;
enum IicCommand_t
{
    IIC_COMMAND_BOOT = 0, // run once at power-up, not writable by the master
    IIC_COMMAND_DO_RFDC_INIT = 1,
    IIC_COMMAND_DO_RFDC_RESET_DC = 2,
    IIC_COMMAND_DO_RFDC_MTS_EXEC = 3,
    IIC_COMMAND_DO_RFDC_MBS_PREP = 4,
    IIC_COMMAND_DO_PL_RESET_HOLD = 5,
    IIC_COMMAND_DO_PL_RESET_RELEASE = 6,
};

int IicRegWrite(u8 reg, u8 value);
int ExecuteIicCmd(u8 cmd);

static XIicPs IicInst;
static XRFdc RFdcInst;
static XGpio GpioArstn;
static XGpio GpioPmaRst;
static XGpioPs GpioPsInst;

volatile u8 IicRegs[IIC_REG_COUNT] = {[IIC_REG_STATUS] = IIC_STATUS_BUSY, [IIC_REG_COMMAND] = IIC_COMMAND_BOOT};
volatile int iicCommandPending;

int main()
{
    print("Start LMK04828 Synchronization for XCZU47DR\n\r");

    // Boot (command 0): IIC first so the master can watch the BUSY -> DONE / ERROR transition
    if (iic_slave_init(XPAR_XIICPS_1_BASEADDR, &IicInst, IicRegs, sizeof(IicRegs), IicRegWrite) != XST_SUCCESS)
    {
        print("IIC slave init failed.\n\r");
    }

    int bootStatus = XST_SUCCESS;

    struct metal_init_params init_param = METAL_INIT_DEFAULTS;
    if (metal_init(&init_param))
    {
        print("Metal init failed.\n\r");
        bootStatus = XST_FAILURE;
    }
    else
    {
        metal_set_log_level(METAL_LOG_DEBUG);
    }

    if (gpio_axi_init(XPAR_AXI_GPIO_ARSTN_BASEADDR, &GpioArstn, AXI_GPIO_CH1, AXI_GPIO_DIR_ALL_OUTPUT) != XST_SUCCESS)
    {
        print("GPIO AXI (arstn) init failed.\n\r");
        bootStatus = XST_FAILURE;
    }

    if (gpio_axi_init(XPAR_AXI_GPIO_PMA_RST_BASEADDR, &GpioPmaRst, AXI_GPIO_CH1, AXI_GPIO_DIR_ALL_OUTPUT) != XST_SUCCESS)
    {
        print("GPIO AXI (pma_rst) init failed.\n\r");
        bootStatus = XST_FAILURE;
    }

    if (gpio_emio_init(XPAR_XGPIOPS_0_BASEADDR, &GpioPsInst) != XST_SUCCESS)
    {
        print("GPIO EMIO init failed.\n\r");
        bootStatus = XST_FAILURE;
    }

    IicRegs[IIC_REG_STATUS] = (bootStatus == XST_SUCCESS) ? IIC_STATUS_DONE : IIC_STATUS_ERROR;

    // The ISR answers the master at any time; the main loop only executes commands accepted by IicRegWrite
    while (1)
    {
        if (iicCommandPending)
        {
            iicCommandPending = 0;
            if (ExecuteIicCmd(IicRegs[IIC_REG_COMMAND]) == XST_SUCCESS)
            {
                IicRegs[IIC_REG_STATUS] = IIC_STATUS_DONE;
            }
            else
            {
                IicRegs[IIC_REG_STATUS] = IIC_STATUS_ERROR;
            }
        }
    }

    // Return
    return XST_SUCCESS;
}

// Runs in the IIC ISR
int IicRegWrite(u8 reg, u8 value)
{
    // STATUS is read-only, COMMAND is locked while a command (including boot) is running
    if (reg != IIC_REG_COMMAND || IicRegs[IIC_REG_STATUS] == IIC_STATUS_BUSY)
    {
        return XST_FAILURE;
    }

    // Boot only runs at power-up
    if (value == IIC_COMMAND_BOOT)
    {
        return XST_FAILURE;
    }

    // Set BUSY here, not in the main loop, so the master never reads the previous command's status
    IicRegs[IIC_REG_STATUS] = IIC_STATUS_BUSY;
    iicCommandPending = 1;
    return XST_SUCCESS;
}

int ExecuteIicCmd(u8 cmd)
{
    switch (cmd)
    {
        case IIC_COMMAND_DO_RFDC_INIT:
            if (rfdc_dev_init(XPAR_XRFDC_0_BASEADDR, &RFdcInst) != XRFDC_SUCCESS)
            {
                print("rfdc_dev_init failed.\n\r");
                return XST_FAILURE;
            }
            return XST_SUCCESS;

        case IIC_COMMAND_DO_RFDC_RESET_DC:
            if (rfdc_reset_dc(&RFdcInst) != XRFDC_SUCCESS)
            {
                print("rfdc_reset_dc failed.\n\r");
                return XST_FAILURE;
            }
            return XST_SUCCESS;

        case IIC_COMMAND_DO_RFDC_MTS_EXEC:
            if (rfdc_mts_exec(&RFdcInst) != XRFDC_SUCCESS)
            {
                print("rfdc_mts_exec failed.\n\r");
                return XST_FAILURE;
            }
            return XST_SUCCESS;

        case IIC_COMMAND_DO_RFDC_MBS_PREP:
            if (rfdc_mbs_prep(&RFdcInst) != XRFDC_SUCCESS)
            {
                print("rfdc_mbs_prep failed.\n\r");
                return XST_FAILURE;
            }
            return XST_SUCCESS;

        case IIC_COMMAND_DO_PL_RESET_HOLD:
            XGpio_DiscreteClear(&GpioArstn, AXI_GPIO_CH1, AXI_GPIO_PIN(0));
            XGpio_DiscreteSet(&GpioPmaRst, AXI_GPIO_CH1, AXI_GPIO_PIN(0));
            return XST_SUCCESS;

        case IIC_COMMAND_DO_PL_RESET_RELEASE:
            XGpio_DiscreteClear(&GpioPmaRst, AXI_GPIO_CH1, AXI_GPIO_PIN(0));
            XGpio_DiscreteSet(&GpioArstn, AXI_GPIO_CH1, AXI_GPIO_PIN(0));
            return XST_SUCCESS;

        default:
            print("Unknown command.\n\r");
            return XST_FAILURE;
    }
}
