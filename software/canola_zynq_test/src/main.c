/**
 * @file   main.c
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Main source file for Zynq test firmware for Canola CAN controller
 */

#include "canola_axi_slave.h"
#include "canola_tests.h"
#include "canola.h"
#include "interrupt.h"
#include "gpio.h"
#include "platform.h"
#include "xil_printf.h"
#include "xgpio.h"
#include "xstatus.h"
#include "xil_hal.h"
#include "xparameters.h"
#include "sleep.h"
#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>


#define GPIO_LEDS_DEVICE_ID   XPAR_GPIO_1_DEVICE_ID
#define GPIO_SW_BTN_DEVICE_ID XPAR_GPIO_0_DEVICE_ID
#define INTC_DEVICE_ID        XPAR_SCUGIC_SINGLE_DEVICE_ID

#define GPIO_LEDS_CHANNEL 1
#define GPIO_SW_CHANNEL   1
#define GPIO_BTN_CHANNEL  2


int main()
{
  uint32_t sw = 0;
  unsigned int seed = 0;

  init_platform();

  printf("\n\r\n\rStarting...\n\r-------------------\n\r");

  printf("Initializing interrupts...\n\r");
  if(init_interrupts() != XST_SUCCESS)
    printf("Error initializing interrupts.\n\r");

  printf("Initializing GPIO...\n\r");
  init_gpio();

  printf("\n\rInitializing Canola CAN controllers...\n\r");
  printf("--------------------------------------\n\r");
  canola_init(0);
  canola_print_ctrl_regs(0);
  canola_print_status_regs(0);

  canola_init(1);
  canola_print_ctrl_regs(1);
  canola_print_status_regs(1);

  canola_init(2);
  canola_print_ctrl_regs(2);
  canola_print_status_regs(2);

  canola_init(3);
  canola_print_ctrl_regs(3);
  canola_print_status_regs(3);


  while(1) {
    sw = XGpio_DiscreteRead(&GpioSwBtn, GPIO_SW_CHANNEL);

    if(sw == 0x01)
      canola_manual_test();
    else if(sw == 0x02) {
      srand(seed);
      canola_continuous_send_test();
    } else if(sw == 0x04) {
      srand(seed);
      canola_sequence_send_test();
    } else if(sw == 0x08)
      ;

    seed++;
  }

  printf("Exiting...\n\r");

  cleanup_platform();
  return 0;
}
