-------------------------------------------------------------------------------
-- Title      : Status counters for Canola CAN controller
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : canola_counters_tmr.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-02-12
-- Last update: 2020-10-11
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Status counters for Canola CAN controller
--              Uses the TMR wrappers for the up_counter instances,
--              which allows for triplication.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-02-12  1.0      svn     Created
-- 2020-10-10  1.1      svn     Modified to use updated voters
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.canola_pkg.all;
use work.tmr_voter_pkg.all;
use work.tmr_wrapper_pkg.all;

entity canola_counters_tmr is
  generic (
    G_SEE_MITIGATION_EN      : integer := 1;  -- Enable TMR
    G_MISMATCH_OUTPUT_EN     : integer := 0;  -- Enable TMR voter mismatch output
    G_MISMATCH_OUTPUT_2ND_EN : integer := 0;  -- Enable additional mismatch output
    G_MISMATCH_OUTPUT_REG    : integer := 0;  -- Use register on mismatch output
    G_COUNTER_WIDTH          : natural;
    G_SATURATING_COUNTERS    : boolean  -- True  :   saturate,   False  :   Wrap-around
    );
  port (
    CLK   : in std_logic;
    RESET : in std_logic;

    -- Clear counters
    CLEAR_TX_MSG_SENT_COUNT    : in std_logic;
    CLEAR_TX_FAILED_COUNT      : in std_logic;
    CLEAR_TX_ACK_ERROR_COUNT   : in std_logic;
    CLEAR_TX_ARB_LOST_COUNT    : in std_logic;
    CLEAR_TX_BIT_ERROR_COUNT   : in std_logic;
    CLEAR_TX_RETRANSMIT_COUNT  : in std_logic;
    CLEAR_RX_MSG_RECV_COUNT    : in std_logic;
    CLEAR_RX_CRC_ERROR_COUNT   : in std_logic;
    CLEAR_RX_FORM_ERROR_COUNT  : in std_logic;
    CLEAR_RX_STUFF_ERROR_COUNT : in std_logic;

    -- Signals to count up counters
    TX_MSG_SENT_COUNT_UP    : in std_logic;
    TX_FAILED_COUNT_UP      : in std_logic;
    TX_ACK_ERROR_COUNT_UP   : in std_logic;
    TX_ARB_LOST_COUNT_UP    : in std_logic;
    TX_BIT_ERROR_COUNT_UP   : in std_logic;
    TX_RETRANSMIT_COUNT_UP  : in std_logic;
    RX_MSG_RECV_COUNT_UP    : in std_logic;
    RX_CRC_ERROR_COUNT_UP   : in std_logic;
    RX_FORM_ERROR_COUNT_UP  : in std_logic;
    RX_STUFF_ERROR_COUNT_UP : in std_logic;

    -- Counter values
    TX_MSG_SENT_COUNT_VALUE    : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_FAILED_COUNT_VALUE      : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_ACK_ERROR_COUNT_VALUE   : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_ARB_LOST_COUNT_VALUE    : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_BIT_ERROR_COUNT_VALUE   : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_RETRANSMIT_COUNT_VALUE  : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_MSG_RECV_COUNT_VALUE    : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_CRC_ERROR_COUNT_VALUE   : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_FORM_ERROR_COUNT_VALUE  : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_STUFF_ERROR_COUNT_VALUE : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);

    MISMATCH     : out std_logic;
    MISMATCH_2ND : out std_logic
    );

end entity canola_counters_tmr;

architecture struct of canola_counters_tmr is

  for all : up_counter_tmr_wrapper
    use configuration work.up_counter_tmr_wrapper_cfg;

  -- Voter mismatch for status counters
  constant C_mismatch_tx_msg_sent_count    : integer := 0;
  constant C_mismatch_tx_failed_count      : integer := 1;
  constant C_mismatch_tx_ack_error_count   : integer := 2;
  constant C_mismatch_tx_arb_lost_count    : integer := 3;
  constant C_mismatch_tx_bit_error_count   : integer := 4;
  constant C_mismatch_tx_retransmit_count  : integer := 5;
  constant C_mismatch_rx_msg_recv_count    : integer := 6;
  constant C_mismatch_rx_crc_error_count   : integer := 7;
  constant C_mismatch_rx_form_error_count  : integer := 8;
  constant C_mismatch_rx_stuff_error_count : integer := 9;
  constant C_MISMATCH_WIDTH                : integer := 10;
  signal s_mismatch_array                  : std_logic_vector(C_MISMATCH_WIDTH-1 downto 0);
  signal s_mismatch_2nd_array              : std_logic_vector(C_MISMATCH_WIDTH-1 downto 0);

begin  -- architecture struct

  -----------------------------------------------------------------------------
  -- Status counters (messages sent/received, error counts)
  -----------------------------------------------------------------------------
  INST_tx_msg_sent_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_TX_MSG_SENT_COUNT,
      COUNT_UP     => TX_MSG_SENT_COUNT_UP,
      COUNT_OUT    => TX_MSG_SENT_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_tx_msg_sent_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_tx_msg_sent_count));

  INST_tx_failed_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_TX_FAILED_COUNT,
      COUNT_UP     => TX_FAILED_COUNT_UP,
      COUNT_OUT    => TX_FAILED_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_tx_failed_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_tx_failed_count));

  INST_tx_ack_error_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_TX_ACK_ERROR_COUNT,
      COUNT_UP     => TX_ACK_ERROR_COUNT_UP,
      COUNT_OUT    => TX_ACK_ERROR_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_tx_ack_error_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_tx_ack_error_count));

  INST_tx_arb_lost_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_TX_ARB_LOST_COUNT,
      COUNT_UP     => TX_ARB_LOST_COUNT_UP,
      COUNT_OUT    => TX_ARB_LOST_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_tx_arb_lost_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_tx_arb_lost_count));

  INST_tx_bit_error_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_TX_BIT_ERROR_COUNT,
      COUNT_UP     => TX_BIT_ERROR_COUNT_UP,
      COUNT_OUT    => TX_BIT_ERROR_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_tx_bit_error_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_tx_bit_error_count));

  INST_tx_retransmit_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_TX_RETRANSMIT_COUNT,
      COUNT_UP     => TX_RETRANSMIT_COUNT_UP,
      COUNT_OUT    => TX_RETRANSMIT_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_tx_retransmit_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_tx_retransmit_count));

  INST_rx_msg_recv_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_RX_MSG_RECV_COUNT,
      COUNT_UP     => RX_MSG_RECV_COUNT_UP,
      COUNT_OUT    => RX_MSG_RECV_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_rx_msg_recv_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_rx_msg_recv_count));

  INST_rx_crc_error_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_RX_CRC_ERROR_COUNT,
      COUNT_UP     => RX_CRC_ERROR_COUNT_UP,
      COUNT_OUT    => RX_CRC_ERROR_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_rx_crc_error_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_rx_crc_error_count));

  INST_rx_form_error_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_RX_FORM_ERROR_COUNT,
      COUNT_UP     => RX_FORM_ERROR_COUNT_UP,
      COUNT_OUT    => RX_FORM_ERROR_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_rx_form_error_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_rx_form_error_count));

  INST_rx_stuff_error_counter : up_counter_tmr_wrapper
    generic map (
      BIT_WIDTH                => G_COUNTER_WIDTH,
      IS_SATURATING            => G_SATURATING_COUNTERS,
      VERBOSE                  => false,
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
    port map (
      CLK          => CLK,
      RESET        => RESET,
      CLEAR        => CLEAR_RX_STUFF_ERROR_COUNT,
      COUNT_UP     => RX_STUFF_ERROR_COUNT_UP,
      COUNT_OUT    => RX_STUFF_ERROR_COUNT_VALUE,
      MISMATCH     => s_mismatch_array(C_mismatch_rx_stuff_error_count),
      MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_rx_stuff_error_count));


  -------------------------------------------------------------------------
  -- Mismatch in voted signals
  -------------------------------------------------------------------------
  INST_mismatch : entity work.mismatch
    generic map(
      G_SEE_MITIGATION_TECHNIQUE => G_SEE_MITIGATION_EN,
      G_MISMATCH_EN              => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_REGISTERED      => G_MISMATCH_OUTPUT_REG,
      G_ADDITIONAL_MISMATCH      => G_MISMATCH_OUTPUT_2ND_EN)
    port map(
      CLK                  => CLK,
      RST                  => RESET,
      mismatch_array_i     => s_mismatch_array,
      mismatch_2nd_array_i => s_mismatch_2nd_array,
      MISMATCH_O           => MISMATCH,
      MISMATCH_2ND_O       => MISMATCH_2ND);

end architecture struct;
