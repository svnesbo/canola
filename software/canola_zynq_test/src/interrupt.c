/**
 * @file   interrupt.c
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Interrupt setup and interrupt handlers for Zynq test firmware
 *         for Canola CAN controller
 */

#define INTERRUPT_C
#include "interrupt.h"
#include "gpio.h"

#include "canola_axi_slave.h"
#include "xil_printf.h"
#include "xstatus.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_hal.h"
#include "xparameters.h"
#include "sleep.h"
#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>

#define INTC_DEVICE_ID          XPAR_SCUGIC_SINGLE_DEVICE_ID

static XScuGic IntcInstance; /* Instance of the Interrupt Controller */

const unsigned int CanolaInstance0 = 0;
const unsigned int CanolaInstance1 = 1;
const unsigned int CanolaInstance2 = 2;
const unsigned int CanolaInstance3 = 3;

volatile unsigned int got_rx_msg[4] = {0,0,0,0};
volatile unsigned int got_tx_done[4] = {0,0,0,0};
volatile unsigned int got_gpio_event = 0;

void IrqRxValidHandler(void *data) {
  if(*(unsigned int*)data < 4)
    got_rx_msg[*(unsigned int*)data] = 1;
}

void IrqTxDoneHandler(void *data) {
  if(*(unsigned int*)data < 4)
    got_tx_done[*(unsigned int*)data] = 1;
}

void IrqGpioHandler(void *data) {
  got_gpio_event = 1;
  XGpio_InterruptClear(&GpioSwBtn, XGPIO_IR_MASK);
}


unsigned int init_interrupts(void)
{
  int Status;
  static XScuGic_Config *GicConfig;

  /*
   * Initialize the interrupt controller driver so that it is ready to
   * use.
   */
  GicConfig = XScuGic_LookupConfig(INTC_DEVICE_ID);
  if (NULL == GicConfig) {
    return XST_FAILURE;
  }

  Status = XScuGic_CfgInitialize(&IntcInstance, GicConfig,
                                 GicConfig->CpuBaseAddress);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up and enable exception handler
  Xil_ExceptionInit();
  Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                               (Xil_ExceptionHandler)XScuGic_InterruptHandler,
                               &IntcInstance);
  Xil_ExceptionEnable();

  // Set up interrupt handler for Rx valid signal for CAN controller 0
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_RX_VALID_IRQ_INTR,
                           (Xil_InterruptHandler)IrqRxValidHandler,
                           (void *) &CanolaInstance0);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Rx valid signal for CAN controller 1
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_RX_VALID_IRQ_INTR,
                           (Xil_InterruptHandler)IrqRxValidHandler,
                           (void *) &CanolaInstance1);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Rx valid signal for CAN controller 2
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_RX_VALID_IRQ_INTR,
                           (Xil_InterruptHandler)IrqRxValidHandler,
                           (void *) &CanolaInstance2);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Rx valid signal for CAN controller 3
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_RX_VALID_IRQ_INTR,
                           (Xil_InterruptHandler)IrqRxValidHandler,
                           (void *) &CanolaInstance3);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Tx done signal for CAN controller 0
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_TX_DONE_IRQ_INTR,
                           (Xil_InterruptHandler)IrqTxDoneHandler,
                           (void *) &CanolaInstance0);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Tx done signal for CAN controller 1
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_TX_DONE_IRQ_INTR,
                           (Xil_InterruptHandler)IrqTxDoneHandler,
                           (void *) &CanolaInstance1);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Tx done signal for CAN controller 2
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_TX_DONE_IRQ_INTR,
                           (Xil_InterruptHandler)IrqTxDoneHandler,
                           (void *) &CanolaInstance2);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for Tx done signal for CAN controller 3
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_TX_DONE_IRQ_INTR,
                           (Xil_InterruptHandler)IrqTxDoneHandler,
                           (void *) &CanolaInstance3);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // Set up interrupt handler for GPIO interrupts
  Status = XScuGic_Connect(&IntcInstance,
                           XPAR_FABRIC_AXI_GPIO_0_IP2INTC_IRPT_INTR,
                           (Xil_InterruptHandler)IrqGpioHandler,
                           (void *)0);
  if (Status != XST_SUCCESS) {
    return XST_FAILURE;
  }

  // For the interrupts from the CAN controller we need to set trigger type and map interrupts to the CPU
  // https://forums.xilinx.com/t5/Processor-System-Design/Using-Private-and-Shared-interrupts-on-Zynq/td-p/773135
  // It seems that this was not necessary for the GPIO interrupts.. perhaps it's already handled by the GPIO code
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_RX_VALID_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_RX_VALID_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_RX_VALID_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_RX_VALID_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_TX_DONE_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_TX_DONE_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_TX_DONE_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge
  XScuGic_SetPriorityTriggerType(&IntcInstance,
                                 XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_TX_DONE_IRQ_INTR,
                                 8,     // priority
                                 0b11); // rising edge

  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_RX_VALID_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_RX_VALID_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_RX_VALID_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_RX_VALID_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_TX_DONE_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_TX_DONE_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_TX_DONE_IRQ_INTR);
  XScuGic_InterruptMaptoCpu(&IntcInstance, 0, XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_TX_DONE_IRQ_INTR);

  // Enable the interrupts
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_RX_VALID_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_RX_VALID_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_RX_VALID_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_RX_VALID_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_0_CAN_TX_DONE_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_1_CAN_TX_DONE_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_2_CAN_TX_DONE_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_CANOLA_AXI_SLAVE_3_CAN_TX_DONE_IRQ_INTR);
  XScuGic_Enable(&IntcInstance, XPAR_FABRIC_AXI_GPIO_0_IP2INTC_IRPT_INTR);

  return XST_SUCCESS;
}
