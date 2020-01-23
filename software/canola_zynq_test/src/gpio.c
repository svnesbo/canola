/**
 * @file   gpio.c
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  GPIO setup for switches, buttons, and LEDs on the ZYBO board
 */

#define GPIO_C
#include "gpio.h"

#include "xil_printf.h"
#include "xstatus.h"
#include "xil_hal.h"
#include "xparameters.h"
#include <stdio.h>
#include <stdint.h>


#define GPIO_LEDS_DEVICE_ID   XPAR_GPIO_1_DEVICE_ID
#define GPIO_SW_BTN_DEVICE_ID XPAR_GPIO_0_DEVICE_ID

XGpio GpioLeds;
XGpio GpioSwBtn;


int init_gpio(void)
{
  int Status;
  uint8_t gpio = 0;

  //------------------------------------------------------------------------
  // Initialize GPIO driver for LEDs
  //------------------------------------------------------------------------
  Status = XGpio_Initialize(&GpioLeds, GPIO_LEDS_DEVICE_ID);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  /* Set the direction for all signals to be outputs */
  XGpio_SetDataDirection(&GpioLeds, GPIO_LEDS_CHANNEL, 0x00000000);

  gpio = 0xA;

  XGpio_DiscreteWrite(&GpioLeds, GPIO_LEDS_CHANNEL, gpio);

  //------------------------------------------------------------------------
  // Initialize GPIO driver for switches and buttons
  //------------------------------------------------------------------------
  Status = XGpio_Initialize(&GpioSwBtn, GPIO_SW_BTN_DEVICE_ID);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set the direction for all signals to be inputs
  XGpio_SetDataDirection(&GpioSwBtn, GPIO_SW_CHANNEL,  0x0000000F);
  XGpio_SetDataDirection(&GpioSwBtn, GPIO_BTN_CHANNEL, 0x0000000F);


  // Read and print status of GPIOs
  gpio = XGpio_DiscreteRead(&GpioSwBtn, GPIO_SW_CHANNEL);
  printf("SW: %x\n\r", gpio);
  gpio = XGpio_DiscreteRead(&GpioSwBtn, GPIO_BTN_CHANNEL);
  printf("BTN: %x\n\r", gpio);

  // Enable GPIO interrupts
  XGpio_InterruptEnable(&GpioSwBtn, XGPIO_IR_MASK);
  XGpio_InterruptGlobalEnable(&GpioSwBtn);

  return XST_SUCCESS;

}
