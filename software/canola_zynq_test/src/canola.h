/**
 * @file   canola.h
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Functions for interacting with Canola CAN controller
 *         AXI-slaves (e.g. send/receive), and utility functions
 *         to generate and check CAN messages
 */

#ifndef CANOLA_ZYNQ_H
#define CANOLA_ZYNQ_H

#include <stdint.h>
#include <stdbool.h>
#include "xil_types.h"
#include "xparameters.h"


typedef struct {
  uint32_t arb_id_a;
  uint32_t arb_id_b;
  bool remote_frame;
  bool ext_id;
  uint8_t payload[8];
  uint8_t data_length;
} can_msg_t;


UINTPTR canola_get_base_addr(unsigned int canola_dev_id);
void canola_print_status_regs(unsigned int canola_dev_id);
void canola_print_ctrl_regs(unsigned int canola_dev_id);
void canola_init(unsigned int canola_dev_id);
void canola_send_msg(unsigned int canola_dev_id, can_msg_t msg);
can_msg_t canola_get_msg(unsigned int canola_dev_id);
bool canola_compare_messages(can_msg_t msg1, can_msg_t msg2);
void canola_print_msg(can_msg_t msg);
can_msg_t canola_generate_rand_msg(void);
bool canola_is_busy(unsigned int canola_dev_id);

#endif
