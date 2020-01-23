/**
 * @file   canola.c
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Functions for interacting with Canola CAN controller
 *         AXI-slaves (e.g. send/receive), and utility functions
 *         to generate and check CAN messages
 */

#include "canola.h"
#include "canola_axi_slave.h"
#include "xil_io.h"
#include "xil_printf.h"
#include "xparameters.h"
#include <stdio.h>
#include <stdlib.h>


UINTPTR canola_get_base_addr(unsigned int canola_dev_id)
{
  UINTPTR canola_baseaddr = 0;

  switch(canola_dev_id) {
  case 0:
    canola_baseaddr = XPAR_CANOLA_AXI_SLAVE_0_BASEADDR;
    break;
  case 1:
    canola_baseaddr = XPAR_CANOLA_AXI_SLAVE_1_BASEADDR;
    break;
  case 2:
    canola_baseaddr = XPAR_CANOLA_AXI_SLAVE_2_BASEADDR;
    break;
  case 3:
    canola_baseaddr = XPAR_CANOLA_AXI_SLAVE_3_BASEADDR;
    break;
  }

  return canola_baseaddr;
}


void canola_print_status_regs(unsigned int canola_dev_id)
{
  UINTPTR canola_baseaddr = canola_get_base_addr(canola_dev_id);

  printf("\n\rDevice %d:", canola_dev_id);
  printf("\n\r-------------\n\r");
  printf("STATUS: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+STATUS_OFFSET));
  printf("TRANSMIT_ERROR_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+TRANSMIT_ERROR_COUNT_OFFSET));
  printf("RECEIVE_ERROR_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+RECEIVE_ERROR_COUNT_OFFSET));
  printf("TX_MSG_SENT_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+TX_MSG_SENT_COUNT_OFFSET));
  printf("TX_ACK_RECV_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+TX_ACK_RECV_COUNT_OFFSET));
  printf("TX_ARB_LOST_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+TX_ARB_LOST_COUNT_OFFSET));
  printf("TX_ERROR_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+TX_ERROR_COUNT_OFFSET));
  printf("RX_MSG_RECV_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+RX_MSG_RECV_COUNT_OFFSET));
  printf("RX_CRC_ERROR_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+RX_CRC_ERROR_COUNT_OFFSET));
  printf("RX_FORM_ERROR_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+RX_FORM_ERROR_COUNT_OFFSET));
  printf("RX_STUFF_ERROR_COUNT: %d\n\r", (unsigned int)Xil_In32(canola_baseaddr+RX_STUFF_ERROR_COUNT_OFFSET));
}

void canola_print_ctrl_regs(unsigned int canola_dev_id)
{
  UINTPTR canola_baseaddr = canola_get_base_addr(canola_dev_id);

  printf("CONTROL: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+CONTROL_OFFSET));
  printf("CONFIG: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+CONFIG_OFFSET));
  printf("STATUS: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+STATUS_OFFSET));
  printf("BTL_PROP_SEG: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+BTL_PROP_SEG_OFFSET));
  printf("BTL_PHASE_SEG1: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+BTL_PHASE_SEG1_OFFSET));
  printf("BTL_PHASE_SEG2: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+BTL_PHASE_SEG2_OFFSET));
  printf("BTL_SYNC_JUMP_WIDTH: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+BTL_SYNC_JUMP_WIDTH_OFFSET));
  printf("BTL_TIME_QUANTA_CLOCK_SCALE: %#010x\n\r", (unsigned int)Xil_In32(canola_baseaddr+BTL_TIME_QUANTA_CLOCK_SCALE_OFFSET));
}

void canola_init(unsigned int canola_dev_id)
{
  UINTPTR canola_baseaddr = canola_get_base_addr(canola_dev_id);

  Xil_Out32(canola_baseaddr+BTL_TIME_QUANTA_CLOCK_SCALE_OFFSET, 9);
}

void canola_send_msg(unsigned int canola_dev_id, can_msg_t msg)
{
  uint32_t canola_tx_msg_id_reg = 0;
  uint32_t canola_tx_payload_0_reg = 0;
  uint32_t canola_tx_payload_1_reg = 0;

  UINTPTR canola_baseaddr = canola_get_base_addr(canola_dev_id);

  // Set up arbitration ID register data
  canola_tx_msg_id_reg = (msg.arb_id_a << TX_MSG_ID_ARB_ID_A_OFFSET) |
    (msg.arb_id_b << TX_MSG_ID_ARB_ID_B_OFFSET);

  if(msg.ext_id)
    canola_tx_msg_id_reg |= (0x1 << TX_MSG_ID_EXT_ID_EN_OFFSET);

  if(msg.remote_frame)
    canola_tx_msg_id_reg |= (0x1 << TX_MSG_ID_RTR_EN_OFFSET);

  // Write arbitration ID register
  Xil_Out32(canola_baseaddr+TX_MSG_ID_OFFSET, canola_tx_msg_id_reg);

  // Set up payload data
  canola_tx_payload_0_reg = msg.payload[0] |
    (msg.payload[1] << 8) |
    (msg.payload[2] << 16) |
    (msg.payload[3] << 24);

  canola_tx_payload_1_reg = msg.payload[4] |
    (msg.payload[5] << 8) |
    (msg.payload[6] << 16) |
    (msg.payload[7] << 24);

  // Write payload and payload length registers
  Xil_Out32(canola_baseaddr+TX_PAYLOAD_0_OFFSET, canola_tx_payload_0_reg);
  Xil_Out32(canola_baseaddr+TX_PAYLOAD_1_OFFSET, canola_tx_payload_1_reg);
  Xil_Out32(canola_baseaddr+TX_PAYLOAD_LENGTH_OFFSET, msg.data_length);

  // Write to TX_START bit of control register to initiate transaction
  Xil_Out32(canola_baseaddr+CONTROL_OFFSET, (0x1 << CONTROL_TX_START_OFFSET));
}


can_msg_t canola_get_msg(unsigned int canola_dev_id)
{
  UINTPTR canola_baseaddr = canola_get_base_addr(canola_dev_id);
  can_msg_t msg;

  unsigned int rx_msg_id_reg      = (unsigned int)Xil_In32(canola_baseaddr+RX_MSG_ID_OFFSET);
  unsigned int rx_payload_len_reg = (unsigned int)Xil_In32(canola_baseaddr+RX_PAYLOAD_LENGTH_OFFSET);
  unsigned int rx_payload_0_reg   = (unsigned int)Xil_In32(canola_baseaddr+RX_PAYLOAD_0_OFFSET);
  unsigned int rx_payload_1_reg   = (unsigned int)Xil_In32(canola_baseaddr+RX_PAYLOAD_1_OFFSET);

  msg.arb_id_a = (rx_msg_id_reg & RX_MSG_ID_ARB_ID_A_MASK) >> RX_MSG_ID_ARB_ID_A_OFFSET;

  if(((rx_msg_id_reg & RX_MSG_ID_EXT_ID_EN_MASK) >> RX_MSG_ID_EXT_ID_EN_OFFSET) == 1) {
    msg.ext_id = true;
    msg.arb_id_b = (rx_msg_id_reg & RX_MSG_ID_ARB_ID_B_MASK) >> RX_MSG_ID_ARB_ID_B_OFFSET;
  } else {
    msg.ext_id = false;
    msg.arb_id_b = 0;
  }

  msg.data_length = rx_payload_len_reg;

  if(((rx_msg_id_reg & RX_MSG_ID_RTR_EN_MASK) >> RX_MSG_ID_RTR_EN_OFFSET) == 1) {
    msg.remote_frame = true;
    for(unsigned int i = 0; i < 8; i++) {
      msg.payload[i] = 0;
    }
  } else {
    msg.remote_frame = false;
    msg.payload[0] = (rx_payload_0_reg & RX_PAYLOAD_0_PAYLOAD_BYTE_0_MASK) >> RX_PAYLOAD_0_PAYLOAD_BYTE_0_OFFSET;
    msg.payload[1] = (rx_payload_0_reg & RX_PAYLOAD_0_PAYLOAD_BYTE_1_MASK) >> RX_PAYLOAD_0_PAYLOAD_BYTE_1_OFFSET;
    msg.payload[2] = (rx_payload_0_reg & RX_PAYLOAD_0_PAYLOAD_BYTE_2_MASK) >> RX_PAYLOAD_0_PAYLOAD_BYTE_2_OFFSET;
    msg.payload[3] = (rx_payload_0_reg & RX_PAYLOAD_0_PAYLOAD_BYTE_3_MASK) >> RX_PAYLOAD_0_PAYLOAD_BYTE_3_OFFSET;
    msg.payload[4] = (rx_payload_1_reg & RX_PAYLOAD_1_PAYLOAD_BYTE_4_MASK) >> RX_PAYLOAD_1_PAYLOAD_BYTE_4_OFFSET;
    msg.payload[5] = (rx_payload_1_reg & RX_PAYLOAD_1_PAYLOAD_BYTE_5_MASK) >> RX_PAYLOAD_1_PAYLOAD_BYTE_5_OFFSET;
    msg.payload[6] = (rx_payload_1_reg & RX_PAYLOAD_1_PAYLOAD_BYTE_6_MASK) >> RX_PAYLOAD_1_PAYLOAD_BYTE_6_OFFSET;
    msg.payload[7] = (rx_payload_1_reg & RX_PAYLOAD_1_PAYLOAD_BYTE_7_MASK) >> RX_PAYLOAD_1_PAYLOAD_BYTE_7_OFFSET;

    for(unsigned int i = 0; i < 8; i++) {
      // Set bytes not included in message to zero
      if(i >= msg.data_length)
        msg.payload[i] = 0;
    }
  }

  return msg;
}


bool canola_compare_messages(can_msg_t msg1, can_msg_t msg2)
{
  if(msg1.arb_id_a != msg2.arb_id_a) {
    printf("Arb ID A mismatch: %lx vs %lx\n\r", msg1.arb_id_a, msg2.arb_id_a);
    return false;
  }

  if(msg1.ext_id != msg2.ext_id) {
    printf("Ext ID mismatch\n\r");
    return false;
  }

  if(msg1.ext_id) {
    if(msg1.arb_id_b != msg2.arb_id_b) {
      printf("Arb ID B mismatch: %lx vs %lx\n\r", msg1.arb_id_b, msg2.arb_id_b);
      return false;
    }
  }

  if(msg1.remote_frame != msg2.remote_frame) {
    printf("RTR mismatch\n\r");
    return false;
  }

  if(msg1.data_length != msg2.data_length) {
    printf("DLC mismatch: %d vs %d\n\r", msg1.data_length, msg2.data_length);
    return false;
  }

  if(!msg1.remote_frame) {
    for(unsigned int i = 0; i < 8; i++) {
      if(i < msg1.data_length && msg1.payload[i] != msg2.payload[i]) {
        printf("Payload %d mismatch: %x vs %x\n\r", i, msg1.payload[i], msg2.payload[i]);
        return false;
      }
    }
  }

  return true;
}


void canola_print_msg(can_msg_t msg)
{
  printf("Ext ID: %s\n\r", msg.ext_id ? "true" : "false");
  printf("RTR: %s\n\r", msg.remote_frame ? "true" : "false");
  printf("DLC: %d\n\r", msg.data_length);
  printf("Arb ID A: %lx\n\r", msg.arb_id_a);

  if(msg.ext_id)
    printf("Arb ID B: %lx\n\r", msg.arb_id_b);

  if(!msg.remote_frame) {
    for(unsigned int i = 0; i < 8; i++)
      printf("Payload %d: %x\n\r", i, msg.payload[i]);
  }
}


can_msg_t canola_generate_rand_msg(void)
{
  can_msg_t msg_out;

  msg_out.arb_id_a = rand() % 2048; // 2^11 = 2048
  msg_out.arb_id_b = rand() % 262144; // 2^18 = 262144

  msg_out.ext_id = (rand() % 2) == 1 ? true : false;
  msg_out.remote_frame = (rand() % 2) == 1 ? true : false;
  msg_out.data_length = (rand() % 9);

  for(unsigned int i = 0; i < msg_out.data_length; i++) {
    if(i >= msg_out.data_length || msg_out.remote_frame)
      msg_out.payload[i] = 0;
    else
      msg_out.payload[i] = rand() % 256;
  }

  return msg_out;
}


bool canola_is_busy(unsigned int canola_dev_id)
{
  UINTPTR canola_baseaddr = canola_get_base_addr(canola_dev_id);

  unsigned int status_reg = (unsigned int)Xil_In32(canola_baseaddr+STATUS_OFFSET);

  if((status_reg & STATUS_TX_BUSY_MASK) == 0)
    return false;
  else
    return true;
}
