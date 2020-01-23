/**
 * @file   interrupt.h
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Interrupt setup and interrupt handlers for Zynq test firmware
 *         for Canola CAN controller
 */

#ifndef INTERRUPT_H
#define INTERRUPT_H

#ifndef INTERRUPT_C
extern volatile unsigned int got_rx_msg[4];
extern volatile unsigned int got_tx_done[4];
extern volatile unsigned int got_gpio_event;
#endif

void IrqRxValidHandler(void *data);
void IrqTxDoneHandler(void *data);
void IrqGpioHandler(void *data);
unsigned int init_interrupts(void);

#endif
