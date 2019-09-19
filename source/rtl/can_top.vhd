-------------------------------------------------------------------------------
-- Title      : Top level entity for Canola CAN controller
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_top.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-10
-- Last update: 2019-09-19
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Top level module for the Canola CAN controller
--              Provides a direct signal for interfacing and configuration
--              of the module.
--              To interact with the module via a bus interface, use one of the
--              other top level entities for the desired bus interface.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-10  1.0      svn     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.can_pkg.all;

entity can_top is
  generic (
    G_BUS_REG_WIDTH : natural;
    G_ENABLE_EXT_ID : boolean);
  port (
    CLK   : in std_logic;
    RESET : in std_logic;

    -- CANbus interface signals
    CAN_TX : out std_logic;
    CAN_RX : in  std_logic;

    -- Rx interface
    RX_MSG       : out can_msg_t;
    RX_MSG_VALID : out std_logic;

    -- Tx interface
    TX_MSG    : in  can_msg_t;
    TX_START  : in  std_logic;
    TX_BUSY   : out std_logic;
    TX_DONE   : out std_logic;
    TX_FAILED : out std_logic;

    -- BTL configuration
    BTL_TRIPLE_SAMPLING         : in std_logic;
    BTL_PROP_SEG                : in std_logic_vector(C_PROP_SEG_WIDTH-1 downto 0);
    BTL_PHASE_SEG1              : in std_logic_vector(C_PHASE_SEG1_WIDTH-1 downto 0);
    BTL_PHASE_SEG2              : in std_logic_vector(C_PHASE_SEG2_WIDTH-1 downto 0);
    BTL_SYNC_JUMP_WIDTH         : in natural range 1 to C_SYNC_JUMP_WIDTH_MAX;
    BTL_TIME_QUANTA_CLOCK_SCALE : in unsigned(C_TIME_QUANTA_WIDTH-1 downto 0)
    );

end entity can_top;

architecture struct of can_top is

  -- Signals for Tx FSM
  signal s_tx_fsm_ack_recv                    : std_logic;  -- Acknowledge was received
  signal s_tx_fsm_arb_lost                    : std_logic;  -- Arbitration was lost
  signal s_tx_fsm_active                      : std_logic;  -- Tx FSM wants to transmit
  signal s_tx_fsm_failed                      : std_logic;
  signal s_tx_fsm_reg_msg_sent_count          : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
  signal s_tx_fsm_reg_ack_recv_count          : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
  signal s_tx_fsm_reg_arb_lost_count          : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
  signal s_tx_fsm_reg_error_count             : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);

  -- Signals for Rx FSM
  signal s_rx_fsm_msg_recv_count   : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
  signal s_rx_fsm_crc_error_count  : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
  signal s_rx_fsm_form_error_count : std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);

  -- BSP interface to Tx FSM
  signal s_bsp_tx_data              : std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
  signal s_bsp_tx_data_count        : natural range 0 to C_BSP_DATA_LENGTH;
  signal s_bsp_tx_write_en          : std_logic;
  signal s_bsp_tx_bit_stuff_en      : std_logic;  -- Enable bit stuffing on current data
  signal s_bsp_tx_rx_mismatch       : std_logic;  -- Mismatch Tx and Rx
  signal s_bsp_tx_rx_stuff_mismatch : std_logic;  -- Mismatch Tx/Rx (stuff bit)
  signal s_bsp_tx_done              : std_logic;
  signal s_bsp_tx_crc_calc          : std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
  signal s_bsp_tx_active            : std_logic;  -- Resets bit stuff counter and CRC

  -- BSP interface to Rx FSM
  signal s_bsp_rx_active               : std_logic;
  signal s_bsp_rx_data                 : std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
  signal s_bsp_rx_data_count           : natural range 0 to C_BSP_DATA_LENGTH;
  signal s_bsp_rx_data_clear           : std_logic;
  signal s_bsp_rx_data_overflow        : std_logic;
  signal s_bsp_rx_bit_destuff_en       : std_logic;
  signal s_bsp_rx_bit_stuff_error      : std_logic;
  signal s_bsp_rx_crc_calc             : std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
  signal s_bsp_rx_send_ack             : std_logic;
  signal s_bsp_send_error_flag         : std_logic;
  signal s_bsp_send_error_flag_tx_fsm  : std_logic;
  signal s_bsp_send_error_flag_rx_fsm  : std_logic;
  signal s_bsp_error_flag_done         : std_logic;
  signal s_bsp_error_flag_bit_error    : std_logic;
  signal s_bsp_error_state             : can_error_state_t;

  -- BTL signals
  signal s_btl_tx_bit_value    : std_logic;
  signal s_btl_tx_bit_valid    : std_logic;
  signal s_btl_tx_rdy          : std_logic;
  signal s_btl_tx_done         : std_logic;
  signal s_btl_rx_bit_value    : std_logic;
  signal s_btl_rx_bit_valid    : std_logic;
  signal s_btl_rx_synced       : std_logic;

  -- BRG signals
  --signal s_brg_baud_pulse : std_logic;
  --signal s_brg_restart    : std_logic;
  --signal s_brg_count_val  : unsigned(C_TIME_QUANTA_WIDTH-1 downto 0);

  -- EML signals
  signal s_eml_rx_stuff_error                   : std_logic;
  signal s_eml_rx_crc_error                     : std_logic;
  signal s_eml_rx_form_error                    : std_logic;
  signal s_eml_rx_active_error_flag_bit_error   : std_logic;
  signal s_eml_rx_overload_flag_bit_error       : std_logic;
  signal s_eml_rx_dominant_bit_after_error_flag : std_logic;
  signal s_eml_tx_bit_error                     : std_logic;
  signal s_eml_tx_ack_error                     : std_logic;
  signal s_eml_tx_arb_stuff_error               : std_logic;
  signal s_eml_tx_active_error_flag_bit_error   : std_logic;
  signal s_eml_transmit_success                 : std_logic;
  signal s_eml_receive_success                  : std_logic;
  signal s_eml_recv_11_recessive_bits           : std_logic;
  signal s_eml_error_state                      : can_error_state_t;
  signal s_eml_transmit_error_count             : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
  signal s_eml_receive_error_count              : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);

begin  -- architecture struct

  s_bsp_send_error_flag <= s_bsp_send_error_flag_tx_fsm or s_bsp_send_error_flag_rx_fsm;

  INST_can_tx_fsm : entity work.can_tx_fsm
    generic map (
      G_BUS_REG_WIDTH => G_BUS_REG_WIDTH,
      G_ENABLE_EXT_ID => G_ENABLE_EXT_ID)
    port map (
      CLK                            => CLK,
      RESET                          => RESET,
      TX_MSG_IN                      => TX_MSG,
      TX_START                       => TX_START,
      TX_BUSY                        => TX_BUSY,
      TX_DONE                        => TX_DONE,
      TX_ACK_RECV                    => open,
      TX_ARB_LOST                    => open,
      TX_BIT_ERROR                   => s_eml_tx_bit_error,
      TX_ACK_ERROR                   => s_eml_tx_ack_error,
      TX_ARB_STUFF_ERROR             => s_eml_tx_arb_stuff_error,
      TX_ACTIVE_ERROR_FLAG_BIT_ERROR => s_eml_tx_active_error_flag_bit_error,
      TX_FAILED                      => s_tx_fsm_failed,
      TX_ACTIVE                      => s_tx_fsm_active,
      ERROR_STATE                    => s_eml_error_state,
      BSP_TX_DATA                    => s_bsp_tx_data,
      BSP_TX_DATA_COUNT              => s_bsp_tx_data_count,
      BSP_TX_WRITE_EN                => s_bsp_tx_write_en,
      BSP_TX_BIT_STUFF_EN            => s_bsp_tx_bit_stuff_en,
      BSP_TX_RX_MISMATCH             => s_bsp_tx_rx_mismatch,
      BSP_TX_RX_STUFF_MISMATCH       => s_bsp_tx_rx_stuff_mismatch,
      BSP_TX_DONE                    => s_bsp_tx_done,
      BSP_TX_CRC_CALC                => s_bsp_tx_crc_calc,
      BSP_RX_ACTIVE                  => s_bsp_rx_active,
      BSP_SEND_ERROR_FLAG            => s_bsp_send_error_flag_tx_fsm,
      BSP_ERROR_FLAG_DONE            => s_bsp_error_flag_done,
      BSP_ERROR_FLAG_BIT_ERROR       => s_bsp_error_flag_bit_error,
      REG_MSG_SENT_COUNT             => s_tx_fsm_reg_msg_sent_count,
      REG_ACK_RECV_COUNT             => s_tx_fsm_reg_ack_recv_count,
      REG_ARB_LOST_COUNT             => s_tx_fsm_reg_arb_lost_count,
      REG_ERROR_COUNT                => s_tx_fsm_reg_error_count);

  INST_can_rx_fsm : entity work.can_rx_fsm
    generic map (
      G_BUS_REG_WIDTH => G_BUS_REG_WIDTH,
      G_ENABLE_EXT_ID => G_ENABLE_EXT_ID)
    port map (
      CLK                    => CLK,
      RESET                  => RESET,
      RX_MSG_OUT             => RX_MSG,
      RX_MSG_VALID           => RX_MSG_VALID,
      BSP_RX_ACTIVE          => s_bsp_rx_active,
      BSP_RX_DATA            => s_bsp_rx_data,
      BSP_RX_DATA_COUNT      => s_bsp_rx_data_count,
      BSP_RX_DATA_CLEAR      => s_bsp_rx_data_clear,
      BSP_RX_DATA_OVERFLOW   => s_bsp_rx_data_overflow,
      BSP_RX_BIT_DESTUFF_EN  => s_bsp_rx_bit_destuff_en,
      BSP_RX_BIT_STUFF_ERROR => s_bsp_rx_bit_stuff_error,
      BSP_RX_CRC_CALC        => s_bsp_rx_crc_calc,
      BSP_RX_SEND_ACK        => s_bsp_rx_send_ack,
      BSP_SEND_ERROR_FLAG    => s_bsp_send_error_flag_rx_fsm,
      REG_MSG_RECV_COUNT     => s_rx_fsm_msg_recv_count,
      REG_CRC_ERROR_COUNT    => s_rx_fsm_crc_error_count,
      REG_FORM_ERROR_COUNT   => s_rx_fsm_form_error_count);


  INST_can_bsp : entity work.can_bsp
    port map (
      CLK                      => CLK,
      RESET                    => RESET,
      BSP_TX_DATA              => s_bsp_tx_data,
      BSP_TX_DATA_COUNT        => s_bsp_tx_data_count,
      BSP_TX_WRITE_EN          => s_bsp_tx_write_en,
      BSP_TX_BIT_STUFF_EN      => s_bsp_tx_bit_stuff_en,
      BSP_TX_RX_MISMATCH       => s_bsp_tx_rx_mismatch,
      BSP_TX_RX_STUFF_MISMATCH => s_bsp_tx_rx_stuff_mismatch,
      BSP_TX_DONE              => s_bsp_tx_done,
      BSP_TX_CRC_CALC          => s_bsp_tx_crc_calc,
      BSP_TX_ACTIVE            => s_tx_fsm_active,
      BSP_RX_ACTIVE            => s_bsp_rx_active,
      BSP_RX_DATA              => s_bsp_rx_data,
      BSP_RX_DATA_COUNT        => s_bsp_rx_data_count,
      BSP_RX_DATA_CLEAR        => s_bsp_rx_data_clear,
      BSP_RX_DATA_OVERFLOW     => s_bsp_rx_data_overflow,
      BSP_RX_BIT_DESTUFF_EN    => s_bsp_rx_bit_destuff_en,
      BSP_RX_BIT_STUFF_ERROR   => s_bsp_rx_bit_stuff_error,
      BSP_RX_CRC_CALC          => s_bsp_rx_crc_calc,
      BSP_RX_SEND_ACK          => s_bsp_rx_send_ack,
      BSP_SEND_ERROR_FLAG      => s_bsp_send_error_flag,
      BSP_ERROR_FLAG_DONE      => s_bsp_error_flag_done,
      BSP_ERROR_FLAG_BIT_ERROR => s_bsp_error_flag_bit_error,
      BSP_ERROR_STATE          => s_bsp_error_state,
      BTL_TX_BIT_VALUE         => s_btl_tx_bit_value,
      BTL_TX_BIT_VALID         => s_btl_tx_bit_valid,
      BTL_TX_RDY               => s_btl_tx_rdy,
      BTL_TX_DONE              => s_btl_tx_done,
      BTL_RX_BIT_VALUE         => s_btl_rx_bit_value,
      BTL_RX_BIT_VALID         => s_btl_rx_bit_valid,
      BTL_RX_SYNCED            => s_btl_rx_synced);

  INST_can_btl : entity work.can_btl
    port map (
      CLK                     => CLK,
      RESET                   => RESET,
      CAN_TX                  => CAN_TX,
      CAN_RX                  => CAN_RX,
      BTL_TX_BIT_VALUE        => s_btl_tx_bit_value,
      BTL_TX_BIT_VALID        => s_btl_tx_bit_valid,
      BTL_TX_RDY              => s_btl_tx_rdy,
      BTL_TX_DONE             => s_btl_tx_done,
      BTL_TX_ACTIVE           => s_tx_fsm_active,
      BTL_RX_BIT_VALUE        => s_btl_rx_bit_value,
      BTL_RX_BIT_VALID        => s_btl_rx_bit_valid,
      BTL_RX_SYNCED           => s_btl_rx_synced,
      TRIPLE_SAMPLING         => BTL_TRIPLE_SAMPLING,
      PROP_SEG                => BTL_PROP_SEG,
      PHASE_SEG1              => BTL_PHASE_SEG1,
      PHASE_SEG2              => BTL_PHASE_SEG2,
      SYNC_JUMP_WIDTH         => BTL_SYNC_JUMP_WIDTH,
      TIME_QUANTA_CLOCK_SCALE => BTL_TIME_QUANTA_CLOCK_SCALE);

  INST_can_eml: entity work.can_eml
    port map (
      CLK                              => CLK,
      RESET                            => RESET,
      RX_STUFF_ERROR                   => s_eml_rx_stuff_error,
      RX_CRC_ERROR                     => s_eml_rx_crc_error,
      RX_FORM_ERROR                    => s_eml_rx_form_error,
      RX_ACTIVE_ERROR_FLAG_BIT_ERROR   => s_eml_rx_active_error_flag_bit_error,
      RX_OVERLOAD_FLAG_BIT_ERROR       => s_eml_rx_overload_flag_bit_error,
      RX_DOMINANT_BIT_AFTER_ERROR_FLAG => s_eml_rx_dominant_bit_after_error_flag,
      TX_BIT_ERROR                     => s_eml_tx_bit_error,
      TX_ACK_ERROR                     => s_eml_tx_ack_error,
      TX_ACK_PASSIVE_ERROR             => '0',
      TX_ACTIVE_ERROR_FLAG_BIT_ERROR   => s_eml_tx_active_error_flag_bit_error,
      TRANSMIT_SUCCESS                 => TX_DONE,
      RECEIVE_SUCCESS                  => RX_MSG_VALID,
      RECV_11_RECESSIVE_BITS           => s_eml_recv_11_recessive_bits,
      ERROR_STATE                      => s_eml_error_state,
      TRANSMIT_ERROR_COUNT             => s_eml_transmit_error_count,
      RECEIVE_ERROR_COUNT              => s_eml_receive_error_count);

end architecture struct;
