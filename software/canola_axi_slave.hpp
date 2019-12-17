#ifndef CANOLA_AXI_SLAVE_H
#define CANOLA_AXI_SLAVE_H

#include <cstdint>

namespace CANOLA_AXI_SLAVE
{
static const uint32_t BASEADDR = 0x0;

/* Register: STATUS */
static const uint32_t STATUS_OFFSET = 0x0;
static const uint32_t STATUS_RESET = 0x0;

/* Field: RX_MSG_VALID */
static const uint32_t STATUS_RX_MSG_VALID_OFFSET = 0;
static const uint32_t STATUS_RX_MSG_VALID_WIDTH = 1;
static const uint32_t STATUS_RX_MSG_VALID_RESET = 0x0;
static const uint32_t STATUS_RX_MSG_VALID_MASK = 0x1;

/* Field: TX_BUSY */
static const uint32_t STATUS_TX_BUSY_OFFSET = 1;
static const uint32_t STATUS_TX_BUSY_WIDTH = 1;
static const uint32_t STATUS_TX_BUSY_RESET = 0x0;
static const uint32_t STATUS_TX_BUSY_MASK = 0x2;

/* Field: TX_DONE */
static const uint32_t STATUS_TX_DONE_OFFSET = 2;
static const uint32_t STATUS_TX_DONE_WIDTH = 1;
static const uint32_t STATUS_TX_DONE_RESET = 0x0;
static const uint32_t STATUS_TX_DONE_MASK = 0x4;

/* Field: TX_FAILED */
static const uint32_t STATUS_TX_FAILED_OFFSET = 3;
static const uint32_t STATUS_TX_FAILED_WIDTH = 1;
static const uint32_t STATUS_TX_FAILED_RESET = 0x0;
static const uint32_t STATUS_TX_FAILED_MASK = 0x8;

/* Field: ERROR_STATE */
static const uint32_t STATUS_ERROR_STATE_OFFSET = 4;
static const uint32_t STATUS_ERROR_STATE_WIDTH = 2;
static const uint32_t STATUS_ERROR_STATE_RESET = 0x0;
static const uint32_t STATUS_ERROR_STATE_MASK = 0x30;

/* Register: CONTROL */
static const uint32_t CONTROL_OFFSET = 0x4;
static const uint32_t CONTROL_RESET = 0x0;

/* Field: TX_START */
static const uint32_t CONTROL_TX_START_OFFSET = 0;
static const uint32_t CONTROL_TX_START_WIDTH = 1;
static const uint32_t CONTROL_TX_START_RESET = 0x0;
static const uint32_t CONTROL_TX_START_MASK = 0x1;

/* Register: CONFIG */
static const uint32_t CONFIG_OFFSET = 0x8;
static const uint32_t CONFIG_RESET = 0x0;

/* Field: TX_RETRANSMIT_EN */
static const uint32_t CONFIG_TX_RETRANSMIT_EN_OFFSET = 0;
static const uint32_t CONFIG_TX_RETRANSMIT_EN_WIDTH = 1;
static const uint32_t CONFIG_TX_RETRANSMIT_EN_RESET = 0x0;
static const uint32_t CONFIG_TX_RETRANSMIT_EN_MASK = 0x1;

/* Field: BTL_TRIPLE_SAMPLING_EN */
static const uint32_t CONFIG_BTL_TRIPLE_SAMPLING_EN_OFFSET = 1;
static const uint32_t CONFIG_BTL_TRIPLE_SAMPLING_EN_WIDTH = 1;
static const uint32_t CONFIG_BTL_TRIPLE_SAMPLING_EN_RESET = 0x0;
static const uint32_t CONFIG_BTL_TRIPLE_SAMPLING_EN_MASK = 0x2;

/* Register: BTL_PROP_SEG */
static const uint32_t BTL_PROP_SEG_OFFSET = 0x20;
static const uint32_t BTL_PROP_SEG_RESET = 0x0;

/* Register: BTL_PHASE_SEG1 */
static const uint32_t BTL_PHASE_SEG1_OFFSET = 0x24;
static const uint32_t BTL_PHASE_SEG1_RESET = 0x0;

/* Register: BTL_PHASE_SEG2 */
static const uint32_t BTL_PHASE_SEG2_OFFSET = 0x28;
static const uint32_t BTL_PHASE_SEG2_RESET = 0x0;

/* Register: BTL_SYNC_JUMP_WIDTH */
static const uint32_t BTL_SYNC_JUMP_WIDTH_OFFSET = 0x2c;
static const uint32_t BTL_SYNC_JUMP_WIDTH_RESET = 0x0;

/* Register: BTL_TIME_QUANTA_CLOCK_SCALE */
static const uint32_t BTL_TIME_QUANTA_CLOCK_SCALE_OFFSET = 0x30;
static const uint32_t BTL_TIME_QUANTA_CLOCK_SCALE_RESET = 0x0;

/* Register: TRANSMIT_ERROR_COUNT */
static const uint32_t TRANSMIT_ERROR_COUNT_OFFSET = 0x34;
static const uint32_t TRANSMIT_ERROR_COUNT_RESET = 0x0;

/* Register: RECEIVE_ERROR_COUNT */
static const uint32_t RECEIVE_ERROR_COUNT_OFFSET = 0x38;
static const uint32_t RECEIVE_ERROR_COUNT_RESET = 0x0;

/* Register: TX_MSG_SENT_COUNT */
static const uint32_t TX_MSG_SENT_COUNT_OFFSET = 0x3c;
static const uint32_t TX_MSG_SENT_COUNT_RESET = 0x0;

/* Register: TX_ACK_RECV_COUNT */
static const uint32_t TX_ACK_RECV_COUNT_OFFSET = 0x40;
static const uint32_t TX_ACK_RECV_COUNT_RESET = 0x0;

/* Register: TX_ARB_LOST_COUNT */
static const uint32_t TX_ARB_LOST_COUNT_OFFSET = 0x44;
static const uint32_t TX_ARB_LOST_COUNT_RESET = 0x0;

/* Register: TX_ERROR_COUNT */
static const uint32_t TX_ERROR_COUNT_OFFSET = 0x48;
static const uint32_t TX_ERROR_COUNT_RESET = 0x0;

/* Register: RX_MSG_RECV_COUNT */
static const uint32_t RX_MSG_RECV_COUNT_OFFSET = 0x4c;
static const uint32_t RX_MSG_RECV_COUNT_RESET = 0x0;

/* Register: RX_CRC_ERROR_COUNT */
static const uint32_t RX_CRC_ERROR_COUNT_OFFSET = 0x50;
static const uint32_t RX_CRC_ERROR_COUNT_RESET = 0x0;

/* Register: RX_FORM_ERROR_COUNT */
static const uint32_t RX_FORM_ERROR_COUNT_OFFSET = 0x54;
static const uint32_t RX_FORM_ERROR_COUNT_RESET = 0x0;

/* Register: RX_STUFF_ERROR_COUNT */
static const uint32_t RX_STUFF_ERROR_COUNT_OFFSET = 0x58;
static const uint32_t RX_STUFF_ERROR_COUNT_RESET = 0x0;

/* Register: TX_MSG_ID */
static const uint32_t TX_MSG_ID_OFFSET = 0x5c;
static const uint32_t TX_MSG_ID_RESET = 0x0;

/* Field: EXT_ID_EN */
static const uint32_t TX_MSG_ID_EXT_ID_EN_OFFSET = 0;
static const uint32_t TX_MSG_ID_EXT_ID_EN_WIDTH = 1;
static const uint32_t TX_MSG_ID_EXT_ID_EN_RESET = 0x0;
static const uint32_t TX_MSG_ID_EXT_ID_EN_MASK = 0x1;

/* Field: RTR_EN */
static const uint32_t TX_MSG_ID_RTR_EN_OFFSET = 1;
static const uint32_t TX_MSG_ID_RTR_EN_WIDTH = 1;
static const uint32_t TX_MSG_ID_RTR_EN_RESET = 0x0;
static const uint32_t TX_MSG_ID_RTR_EN_MASK = 0x2;

/* Field: ARB_ID_B */
static const uint32_t TX_MSG_ID_ARB_ID_B_OFFSET = 2;
static const uint32_t TX_MSG_ID_ARB_ID_B_WIDTH = 18;
static const uint32_t TX_MSG_ID_ARB_ID_B_RESET = 0x0;
static const uint32_t TX_MSG_ID_ARB_ID_B_MASK = 0xffffc;

/* Field: ARB_ID_A */
static const uint32_t TX_MSG_ID_ARB_ID_A_OFFSET = 20;
static const uint32_t TX_MSG_ID_ARB_ID_A_WIDTH = 11;
static const uint32_t TX_MSG_ID_ARB_ID_A_RESET = 0x0;
static const uint32_t TX_MSG_ID_ARB_ID_A_MASK = 0x7ff00000;

/* Register: TX_PAYLOAD_LENGTH */
static const uint32_t TX_PAYLOAD_LENGTH_OFFSET = 0x60;
static const uint32_t TX_PAYLOAD_LENGTH_RESET = 0x0;

/* Register: TX_PAYLOAD_0 */
static const uint32_t TX_PAYLOAD_0_OFFSET = 0x64;
static const uint32_t TX_PAYLOAD_0_RESET = 0x0;

/* Field: PAYLOAD_BYTE_0 */
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_0_OFFSET = 0;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_0_WIDTH = 8;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_0_RESET = 0x0;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_0_MASK = 0xff;

/* Field: PAYLOAD_BYTE_1 */
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_1_OFFSET = 8;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_1_WIDTH = 8;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_1_RESET = 0x0;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_1_MASK = 0xff00;

/* Field: PAYLOAD_BYTE_2 */
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_2_OFFSET = 16;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_2_WIDTH = 8;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_2_RESET = 0x0;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_2_MASK = 0xff0000;

/* Field: PAYLOAD_BYTE_3 */
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_3_OFFSET = 24;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_3_WIDTH = 8;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_3_RESET = 0x0;
static const uint32_t TX_PAYLOAD_0_PAYLOAD_BYTE_3_MASK = 0xff000000;

/* Register: TX_PAYLOAD_1 */
static const uint32_t TX_PAYLOAD_1_OFFSET = 0x68;
static const uint32_t TX_PAYLOAD_1_RESET = 0x0;

/* Field: PAYLOAD_BYTE_4 */
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_4_OFFSET = 0;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_4_WIDTH = 8;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_4_RESET = 0x0;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_4_MASK = 0xff;

/* Field: PAYLOAD_BYTE_5 */
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_5_OFFSET = 8;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_5_WIDTH = 8;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_5_RESET = 0x0;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_5_MASK = 0xff00;

/* Field: PAYLOAD_BYTE_6 */
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_6_OFFSET = 16;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_6_WIDTH = 8;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_6_RESET = 0x0;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_6_MASK = 0xff0000;

/* Field: PAYLOAD_BYTE_7 */
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_7_OFFSET = 24;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_7_WIDTH = 8;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_7_RESET = 0x0;
static const uint32_t TX_PAYLOAD_1_PAYLOAD_BYTE_7_MASK = 0xff000000;

/* Register: RX_MSG_ID */
static const uint32_t RX_MSG_ID_OFFSET = 0x6c;
static const uint32_t RX_MSG_ID_RESET = 0x0;

/* Field: EXT_ID_EN */
static const uint32_t RX_MSG_ID_EXT_ID_EN_OFFSET = 0;
static const uint32_t RX_MSG_ID_EXT_ID_EN_WIDTH = 1;
static const uint32_t RX_MSG_ID_EXT_ID_EN_RESET = 0x0;
static const uint32_t RX_MSG_ID_EXT_ID_EN_MASK = 0x1;

/* Field: RTR_EN */
static const uint32_t RX_MSG_ID_RTR_EN_OFFSET = 1;
static const uint32_t RX_MSG_ID_RTR_EN_WIDTH = 1;
static const uint32_t RX_MSG_ID_RTR_EN_RESET = 0x0;
static const uint32_t RX_MSG_ID_RTR_EN_MASK = 0x2;

/* Field: ARB_ID_B */
static const uint32_t RX_MSG_ID_ARB_ID_B_OFFSET = 2;
static const uint32_t RX_MSG_ID_ARB_ID_B_WIDTH = 18;
static const uint32_t RX_MSG_ID_ARB_ID_B_RESET = 0x0;
static const uint32_t RX_MSG_ID_ARB_ID_B_MASK = 0xffffc;

/* Field: ARB_ID_A */
static const uint32_t RX_MSG_ID_ARB_ID_A_OFFSET = 20;
static const uint32_t RX_MSG_ID_ARB_ID_A_WIDTH = 11;
static const uint32_t RX_MSG_ID_ARB_ID_A_RESET = 0x0;
static const uint32_t RX_MSG_ID_ARB_ID_A_MASK = 0x7ff00000;

/* Register: RX_PAYLOAD_LENGTH */
static const uint32_t RX_PAYLOAD_LENGTH_OFFSET = 0x70;
static const uint32_t RX_PAYLOAD_LENGTH_RESET = 0x0;

/* Register: RX_PAYLOAD_0 */
static const uint32_t RX_PAYLOAD_0_OFFSET = 0x74;
static const uint32_t RX_PAYLOAD_0_RESET = 0x0;

/* Field: PAYLOAD_BYTE_0 */
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_0_OFFSET = 0;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_0_WIDTH = 8;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_0_RESET = 0x0;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_0_MASK = 0xff;

/* Field: PAYLOAD_BYTE_1 */
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_1_OFFSET = 8;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_1_WIDTH = 8;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_1_RESET = 0x0;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_1_MASK = 0xff00;

/* Field: PAYLOAD_BYTE_2 */
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_2_OFFSET = 16;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_2_WIDTH = 8;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_2_RESET = 0x0;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_2_MASK = 0xff0000;

/* Field: PAYLOAD_BYTE_3 */
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_3_OFFSET = 24;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_3_WIDTH = 8;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_3_RESET = 0x0;
static const uint32_t RX_PAYLOAD_0_PAYLOAD_BYTE_3_MASK = 0xff000000;

/* Register: RX_PAYLOAD_1 */
static const uint32_t RX_PAYLOAD_1_OFFSET = 0x78;
static const uint32_t RX_PAYLOAD_1_RESET = 0x0;

/* Field: PAYLOAD_BYTE_4 */
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_4_OFFSET = 0;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_4_WIDTH = 8;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_4_RESET = 0x0;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_4_MASK = 0xff;

/* Field: PAYLOAD_BYTE_5 */
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_5_OFFSET = 8;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_5_WIDTH = 8;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_5_RESET = 0x0;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_5_MASK = 0xff00;

/* Field: PAYLOAD_BYTE_6 */
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_6_OFFSET = 16;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_6_WIDTH = 8;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_6_RESET = 0x0;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_6_MASK = 0xff0000;

/* Field: PAYLOAD_BYTE_7 */
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_7_OFFSET = 24;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_7_WIDTH = 8;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_7_RESET = 0x0;
static const uint32_t RX_PAYLOAD_1_PAYLOAD_BYTE_7_MASK = 0xff000000;

};

#endif