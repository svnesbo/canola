/**
 * @file   gpio.h
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  GPIO setup for switches, buttons, and LEDs on the ZYBO board
 */

#ifndef GPIO_H
#define GPIO_H

#include "xgpio.h"

#define GPIO_LEDS_CHANNEL 1
#define GPIO_SW_CHANNEL   1
#define GPIO_BTN_CHANNEL  2

int init_gpio(void);

#ifndef GPIO_C
extern XGpio GpioLeds;
extern XGpio GpioSwBtn;
#endif

#endif
