-------------------------------------------------------------------------------
-- Title      : Status counters for Canola CAN controller
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : canola_counters.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-02-12
-- Last update: 2020-02-14
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Status counters for Canola CAN controller
--              Uses up_counter instances directly without TMR wrapper
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-02-12  1.0      svn     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.canola_pkg.all;

entity canola_counters is
  generic (
    G_COUNTER_WIDTH       : natural;
    G_SATURATING_COUNTERS : boolean  -- True: saturate, False: Wrap-around
    );
  port (
    CLK   : in std_logic;
    RESET : in std_logic;

    -- Clear counters
    CLEAR_TX_MSG_SENT_COUNT    : in std_logic;
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
    TX_ACK_ERROR_COUNT_VALUE   : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_ARB_LOST_COUNT_VALUE    : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_BIT_ERROR_COUNT_VALUE   : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    TX_RETRANSMIT_COUNT_VALUE  : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_MSG_RECV_COUNT_VALUE    : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_CRC_ERROR_COUNT_VALUE   : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_FORM_ERROR_COUNT_VALUE  : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0);
    RX_STUFF_ERROR_COUNT_VALUE : out std_logic_vector(G_COUNTER_WIDTH-1 downto 0)
    );

end entity canola_counters;

architecture struct of canola_counters is

begin  -- architecture struct

  -----------------------------------------------------------------------------
  -- Status counters (messages sent/received, error counts)
  -----------------------------------------------------------------------------
  INST_tx_msg_sent_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_TX_MSG_SENT_COUNT,
      COUNT_UP       => TX_MSG_SENT_COUNT_UP,
      COUNT_OUT      => TX_MSG_SENT_COUNT_VALUE,
      COUNT_VOTED_IN => TX_MSG_SENT_COUNT_VALUE);

  INST_tx_ack_error_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_TX_ACK_ERROR_COUNT,
      COUNT_UP       => TX_ACK_ERROR_COUNT_UP,
      COUNT_OUT      => TX_ACK_ERROR_COUNT_VALUE,
      COUNT_VOTED_IN => TX_ACK_ERROR_COUNT_VALUE);

  INST_tx_arb_lost_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_TX_ARB_LOST_COUNT,
      COUNT_UP       => TX_ARB_LOST_COUNT_UP,
      COUNT_OUT      => TX_ARB_LOST_COUNT_VALUE,
      COUNT_VOTED_IN => TX_ARB_LOST_COUNT_VALUE);

  INST_tx_bit_error_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_TX_BIT_ERROR_COUNT,
      COUNT_UP       => TX_BIT_ERROR_COUNT_UP,
      COUNT_OUT      => TX_BIT_ERROR_COUNT_VALUE,
      COUNT_VOTED_IN => TX_BIT_ERROR_COUNT_VALUE);

  INST_tx_retransmit_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_TX_RETRANSMIT_COUNT,
      COUNT_UP       => TX_RETRANSMIT_COUNT_UP,
      COUNT_OUT      => TX_RETRANSMIT_COUNT_VALUE,
      COUNT_VOTED_IN => TX_RETRANSMIT_COUNT_VALUE);

  INST_rx_msg_recv_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_RX_MSG_RECV_COUNT,
      COUNT_UP       => RX_MSG_RECV_COUNT_UP,
      COUNT_OUT      => RX_MSG_RECV_COUNT_VALUE,
      COUNT_VOTED_IN => RX_MSG_RECV_COUNT_VALUE);

  INST_rx_crc_error_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_RX_CRC_ERROR_COUNT,
      COUNT_UP       => RX_CRC_ERROR_COUNT_UP,
      COUNT_OUT      => RX_CRC_ERROR_COUNT_VALUE,
      COUNT_VOTED_IN => RX_CRC_ERROR_COUNT_VALUE);

  INST_rx_form_error_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_RX_FORM_ERROR_COUNT,
      COUNT_UP       => RX_FORM_ERROR_COUNT_UP,
      COUNT_OUT      => RX_FORM_ERROR_COUNT_VALUE,
      COUNT_VOTED_IN => RX_FORM_ERROR_COUNT_VALUE);

  INST_rx_stuff_error_counter: entity work.up_counter
    generic map (
      BIT_WIDTH     => G_COUNTER_WIDTH,
      IS_SATURATING => G_SATURATING_COUNTERS,
      VERBOSE       => false)
    port map (
      CLK            => CLK,
      RESET          => RESET,
      CLEAR          => CLEAR_RX_STUFF_ERROR_COUNT,
      COUNT_UP       => RX_STUFF_ERROR_COUNT_UP,
      COUNT_OUT      => RX_STUFF_ERROR_COUNT_VALUE,
      COUNT_VOTED_IN => RX_STUFF_ERROR_COUNT_VALUE);

end architecture struct;
