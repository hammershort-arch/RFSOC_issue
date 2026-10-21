#ifndef __GPIO_H__
#define __GPIO_H__

#include <xgpio.h>
#include <xgpiops.h>

#define AXI_GPIO_CH1 1
#define AXI_GPIO_CH2 2
#define AXI_GPIO_PIN(n) (1UL << (n))

// Direction mask: bit = 1 is input, bit = 0 is output (mixed: e.g. AXI_GPIO_PIN(3) | AXI_GPIO_PIN(5) are inputs)
#define AXI_GPIO_DIR_ALL_OUTPUT 0x00000000UL
#define AXI_GPIO_DIR_ALL_INPUT 0xFFFFFFFFUL

int gpio_axi_init(u32, XGpio *, u32, u32);
int gpio_emio_init(u32, XGpioPs *);
void gpio_handshake(XGpioPs *);

#endif
