#ifndef __IIC_H__
#define __IIC_H__

#include <xiicps.h>

#define IIC_SLAVE_ADDR 0x45
#define IIC_SCLK_RATE 400000

// Called from the ISR before a master write lands in the register map; return XST_SUCCESS (0) to accept it, non-zero to reject
typedef int (*IicRegWriteHook)(u8 Reg, u8 Value);

int iic_slave_init(u32, XIicPs *, volatile u8 *, u32, IicRegWriteHook);

#endif
