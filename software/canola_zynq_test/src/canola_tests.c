/**
 * @file   canola_tests.c
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Test modes in Zynq tes firmware for Canola CAN controller
 */

#include "canola_tests.h"
#include "canola_axi_slave.h"
#include "canola.h"
#include "interrupt.h"
#include "gpio.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>
#include "xil_printf.h"
#include "xgpio.h"
#include "xstatus.h"
#include "xscugic.h"
#include "xil_exception.h"
#include "xil_hal.h"
#include "xparameters.h"
#include "sleep.h"



void canola_manual_test(void)
{
  unsigned int cycle_count = 0;
  uint32_t btn = 0;
  uint32_t sw = 0x01;

  can_msg_t msg_out_0 = {
    .arb_id_a = 0,
    .arb_id_b = 0xABC,
    .payload = {0x11, 0x22, 0x33, 0x44, 0x55, 0x66, 0x77, 0x88},
    .data_length = 8,
    .ext_id = true,
    .remote_frame = false
  };

  can_msg_t msg_out_1 = {
    .arb_id_a = 0,
    .arb_id_b = 0xDEF,
    .payload = {0x88, 0x77, 0x66, 0x55, 0x44, 0x33, 0x22, 0x11},
    .data_length = 8,
    .ext_id = true,
    .remote_frame = false
  };

  can_msg_t msg_out_2 = {
    .arb_id_a = 0,
    .arb_id_b = 0xFFF,
    .payload = {0x11, 0xAA, 0x22, 0xBB, 0x33, 0xCC, 0x44, 0xDD},
    .data_length = 8,
    .ext_id = true,
    .remote_frame = false
  };

  can_msg_t msg_out_3 = {
    .arb_id_a = 0,
    .arb_id_b = 0x000,
    .payload = {0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF, 0x12, 0x34},
    .data_length = 8,
    .ext_id = true,
    .remote_frame = false
  };


  while(sw == 0x01) {
    btn = XGpio_DiscreteRead(&GpioSwBtn, GPIO_BTN_CHANNEL);

    if(btn == 0x8) {
      canola_send_msg(0, msg_out_0);
      //canola_send_msg(3, msg_out_3);
      msg_out_0.arb_id_b++;
    } else if(btn == 0x4) {
      canola_send_msg(1, msg_out_1);
      msg_out_1.arb_id_b++;
    } else if(btn == 0x2) {
      canola_send_msg(2, msg_out_2);
      msg_out_2.arb_id_b++;
    } else if(btn == 0x1) {
      canola_send_msg(3, msg_out_3);
      msg_out_3.arb_id_b++;
    }

    for(unsigned int i = 0; i < 4; i++) {
      if(got_tx_done[i] == 1) {
        printf("Tx done CAN #%d.\n\r", i);
        got_tx_done[i] = 0;
      }
      if(got_rx_msg[i] == 1) {
        printf("Rx msg received CAN #%d.\n\r", i);
        got_rx_msg[i] = 0;
      }
    }


    if(got_gpio_event == 1) {
      printf("GPIO interrupt.\n\r");
      got_gpio_event = 0;
    }

    // Sleep 100 ms
    usleep(100000);

    cycle_count++;
    // Dump counters every 10 seconds
    if(cycle_count == 100) {
      canola_print_status_regs(0);
      canola_print_status_regs(1);
      canola_print_status_regs(2);
      canola_print_status_regs(3);
      cycle_count = 0;
    }

    sw = XGpio_DiscreteRead(&GpioSwBtn, GPIO_SW_CHANNEL);
  }
}


void canola_continuous_send_test(void)
{
  uint32_t sw = 0x02;

  unsigned int msg_sent_count = 0;

  //can_msg_t msg_out;

  printf("Starting send continuous test\n\r");

  while(sw == 0x02) {
    for(unsigned int i = 0; i < 4; i++) {
      if(got_tx_done[i] == 1) {
        printf("Tx done CAN #%d.\n\r", i);
        got_tx_done[i] = 0;
      }
      if(got_rx_msg[i] == 1) {
        printf("Rx msg received CAN #%d.\n\r", i);
        got_rx_msg[i] = 0;
      }
    }

    for(unsigned int i = 0; i < 4; i++) {
      if(!canola_is_busy(i)) {
        canola_send_msg(i, canola_generate_rand_msg());
        //msg_out.arb_id_b++;
        msg_sent_count++;
      }
    }

    if(msg_sent_count >= 10000) {
      canola_print_status_regs(0);
      canola_print_status_regs(1);
      canola_print_status_regs(2);
      canola_print_status_regs(3);
      msg_sent_count = 0;
    }

    sw = XGpio_DiscreteRead(&GpioSwBtn, GPIO_SW_CHANNEL);
  }
}


void canola_sequence_send_test(void)
{
  uint32_t sw = 0x04;

  can_msg_t msg_out;
  can_msg_t msg_in;

  unsigned int can_ctrl_num = 0;
  unsigned int tx_done_count = 0;
  unsigned int tx_not_done_count = 0;
  unsigned int rx_msg_count = 0;
  unsigned int rx_msg_ok_count = 0;
  unsigned int rx_msg_not_ok_count = 0;
  unsigned int success_count = 0;
  unsigned int fail_count = 0;
  unsigned int msg_sent_count = 0;

  bool test_ok;

  //can_msg_t msg_out;

  printf("Starting send in sequence test\n\r");

  while(sw == 0x04) {
    test_ok = true;

    while(canola_is_busy(can_ctrl_num)) {
      printf("Canola %d busy, waiting..", can_ctrl_num);
      // Sleep 2 ms
      usleep(2000);
    }

    msg_out = canola_generate_rand_msg();
    canola_send_msg(can_ctrl_num, msg_out);

    // Sleep 2 ms
    usleep(2000);

    // Check if message was sent
    if(got_tx_done[can_ctrl_num] == 1) {
      tx_done_count++;
    } else {
      printf("CAN %d failed to send message\n\r", can_ctrl_num);
      tx_not_done_count++;
      test_ok = false;
    }

    // Check if message was received by the other controllers
    for(unsigned int i = 0; i < 4; i++) {
      // Skip missing controller
      if(i == 2)
        continue;

      // Skip transmitting controller
      if(i == can_ctrl_num)
        continue;

      if(got_rx_msg[i] == 0) {
        printf("CAN %d failed to receive message from CAN %d\n\r", i, can_ctrl_num);
        test_ok = false;
      } else {
        msg_in = canola_get_msg(i);

        if(canola_compare_messages(msg_out, msg_in) == false) {
          test_ok = false;
          rx_msg_not_ok_count++;
          printf("Msg received by CAN #%d did not match msg sent by CAN #%d\n\r", i, can_ctrl_num);

          printf("Msg sent by CAN #%d\n\r", can_ctrl_num);
          canola_print_msg(msg_out);

          printf("\n\rMsg received by CAN #%d\n\r", i);
          canola_print_msg(msg_in);
          printf("\n\r");
        } else {
          rx_msg_ok_count++;
        }
      }
    }

    msg_sent_count++;
    if(msg_sent_count >= 10000) {
      canola_print_status_regs(0);
      canola_print_status_regs(1);
      //canola_print_status_regs(2);
      canola_print_status_regs(3);
      msg_sent_count = 0;
    }

    // Clear IRQ flags
    for(unsigned int i = 0; i < 4; i++) {
      got_tx_done[i] = 0;
      got_rx_msg[i] = 0;
    }

    if(test_ok)
      success_count++;
    else
      fail_count++;

    can_ctrl_num++;
    if(can_ctrl_num == 2)
      can_ctrl_num++; // Skip missing controller
    if(can_ctrl_num == 4)
      can_ctrl_num = 0;

    sw = XGpio_DiscreteRead(&GpioSwBtn, GPIO_SW_CHANNEL);
  }

  printf("tx_done_count: %d\n\r", tx_done_count);
  printf("tx_not_done_count: %d\n\r", tx_not_done_count);
  printf("rx_msg_count: %d\n\r", rx_msg_count);
  printf("rx_msg_ok_count: %d\n\r", rx_msg_ok_count);
  printf("rx_msg_not_ok_count: %d\n\r", rx_msg_not_ok_count);
  printf("success_count: %d\n\r", success_count);
  printf("fail_count: %d\n\r", fail_count);

  canola_print_status_regs(0);
  canola_print_status_regs(1);
  //canola_print_status_regs(2);
  canola_print_status_regs(3);
}
