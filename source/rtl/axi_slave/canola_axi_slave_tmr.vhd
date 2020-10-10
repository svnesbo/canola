-------------------------------------------------------------------------------
-- Title      : AXI Bus slave for Canola CAN controller (with TMR)
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : canola_axi_slave_tmr.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-02-06
-- Last update: 2020-10-10
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: AXI Bus slave for the Canola CAN controller.
--              The Canola CAN controller can be protected using Triple Modular
--              Redundancy (TMR) with this version of the AXI slave.
--              Note: Only the CAN controller will be triplicated when TMR
--                    is enabled. The AXI register interface will not be.
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-02-06  1.0      svn     Created
-- 2020-10-09  1.1      svn     Modified to use updated voters
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- User Libraries Start

-- User Libraries End

use work.axi_pkg.all;
use work.canola_axi_slave_pif_pkg.all;
use work.canola_pkg.all;

entity canola_axi_slave_tmr is
  generic (
    -- User Generics Start
    G_SEE_MITIGATION_EN      : integer := 1;  -- Enable TMR
    G_MISMATCH_OUTPUT_EN     : integer := 1;  -- Enable TMR voter mismatch output
    G_MISMATCH_OUTPUT_2ND_EN : integer := 0;  -- Enable additional mismatch output
    G_MISMATCH_OUTPUT_REG    : integer := 0;  -- Use register on mismatch output
    -- User Generics End

    -- AXI Bus Interface Generics
    G_AXI_BASEADDR : std_logic_vector(31 downto 0) := X"00000000"
    );
  port (
    -- User Ports Start
    CAN_RX       : in  std_logic;
    CAN_TX       : out std_logic;

    CAN_RX_VALID_IRQ  : out std_logic;
    CAN_TX_DONE_IRQ   : out std_logic;
    CAN_TX_FAILED_IRQ : out std_logic;

    MISMATCH_LOGIC        : out std_logic;  -- Mismatch in main logic
    MISMATCH_LOGIC_2ND    : out std_logic;  -- Additional mismatch output (logic)
    MISMATCH_COUNTERS     : out std_logic;  -- Mismatch in status counters
    MISMATCH_COUNTERS_2ND : out std_logic;  -- Additional mistmach output (counters)

    -- User Ports End
    -- AXI Bus Interface Ports
    AXI_CLK      : in  std_logic;
    AXI_RESET    : in  std_logic;
    AXI_ARESETN  : in  std_logic;
    AXI_AWADDR   : in  std_logic_vector(C_CANOLA_AXI_SLAVE_ADDR_WIDTH-1 downto 0);
    AXI_AWVALID  : in  std_logic;
    AXI_AWREADY  : out std_logic;
    AXI_WDATA    : in  std_logic_vector(C_CANOLA_AXI_SLAVE_DATA_WIDTH-1 downto 0);
    AXI_WVALID   : in  std_logic;
    AXI_WREADY   : out std_logic;
    AXI_BRESP    : out std_logic_vector(1 downto 0);
    AXI_BVALID   : out std_logic;
    AXI_BREADY   : in  std_logic;
    AXI_ARADDR   : in  std_logic_vector(C_CANOLA_AXI_SLAVE_ADDR_WIDTH-1 downto 0);
    AXI_ARVALID  : in  std_logic;
    AXI_ARREADY  : out std_logic;
    AXI_RDATA    : out std_logic_vector(C_CANOLA_AXI_SLAVE_DATA_WIDTH-1 downto 0);
    AXI_RRESP    : out std_logic_vector(1 downto 0);
    AXI_RVALID   : out std_logic;
    AXI_RREADY   : in  std_logic
    );

end entity canola_axi_slave_tmr;

architecture behavior of canola_axi_slave_tmr is

  -- User Architecture Start
  signal s_can_rx_msg      : can_msg_t;
  signal s_can_tx_msg      : can_msg_t;
  signal s_can_error_state : can_error_state_t;

  constant C_COUNTER_REG_WIDTH : natural := 32;

  signal s_tx_msg_sent_count_up    : std_logic;
  signal s_tx_failed_count_up      : std_logic;
  signal s_tx_ack_error_count_up   : std_logic;
  signal s_tx_arb_lost_count_up    : std_logic;
  signal s_tx_bit_error_count_up   : std_logic;
  signal s_tx_retransmit_count_up  : std_logic;
  signal s_rx_msg_recv_count_up    : std_logic;
  signal s_rx_crc_error_count_up   : std_logic;
  signal s_rx_form_error_count_up  : std_logic;
  signal s_rx_stuff_error_count_up : std_logic;

  -- User Architecture End

  -- Register Signals
  signal axi_rw_regs    : t_canola_axi_slave_rw_regs    := c_canola_axi_slave_rw_regs;
  signal axi_ro_regs    : t_canola_axi_slave_ro_regs    := c_canola_axi_slave_ro_regs;
  signal axi_pulse_regs : t_canola_axi_slave_pulse_regs := c_canola_axi_slave_pulse_regs;

begin

  -- User Logic Start
  s_can_tx_msg.ext_id         <= axi_rw_regs.TX_MSG_ID.EXT_ID_EN;
  s_can_tx_msg.remote_request <= axi_rw_regs.TX_MSG_ID.RTR_EN;
  s_can_tx_msg.arb_id_a       <= axi_rw_regs.TX_MSG_ID.ARB_ID_A;
  s_can_tx_msg.arb_id_b       <= axi_rw_regs.TX_MSG_ID.ARB_ID_B;
  s_can_tx_msg.data_length    <= axi_rw_regs.TX_PAYLOAD_LENGTH;
  s_can_tx_msg.data(0)        <= axi_rw_regs.TX_PAYLOAD_0.PAYLOAD_BYTE_0;
  s_can_tx_msg.data(1)        <= axi_rw_regs.TX_PAYLOAD_0.PAYLOAD_BYTE_1;
  s_can_tx_msg.data(2)        <= axi_rw_regs.TX_PAYLOAD_0.PAYLOAD_BYTE_2;
  s_can_tx_msg.data(3)        <= axi_rw_regs.TX_PAYLOAD_0.PAYLOAD_BYTE_3;
  s_can_tx_msg.data(4)        <= axi_rw_regs.TX_PAYLOAD_1.PAYLOAD_BYTE_4;
  s_can_tx_msg.data(5)        <= axi_rw_regs.TX_PAYLOAD_1.PAYLOAD_BYTE_5;
  s_can_tx_msg.data(6)        <= axi_rw_regs.TX_PAYLOAD_1.PAYLOAD_BYTE_6;
  s_can_tx_msg.data(7)        <= axi_rw_regs.TX_PAYLOAD_1.PAYLOAD_BYTE_7;

  axi_ro_regs.RX_MSG_ID.EXT_ID_EN         <= s_can_rx_msg.ext_id;
  axi_ro_regs.RX_MSG_ID.RTR_EN            <= s_can_rx_msg.remote_request;
  axi_ro_regs.RX_MSG_ID.ARB_ID_A          <= s_can_rx_msg.arb_id_a;
  axi_ro_regs.RX_MSG_ID.ARB_ID_B          <= s_can_rx_msg.arb_id_b;
  axi_ro_regs.RX_PAYLOAD_LENGTH           <= s_can_rx_msg.data_length;
  axi_ro_regs.RX_PAYLOAD_0.PAYLOAD_BYTE_0 <= s_can_rx_msg.data(0);
  axi_ro_regs.RX_PAYLOAD_0.PAYLOAD_BYTE_1 <= s_can_rx_msg.data(1);
  axi_ro_regs.RX_PAYLOAD_0.PAYLOAD_BYTE_2 <= s_can_rx_msg.data(2);
  axi_ro_regs.RX_PAYLOAD_0.PAYLOAD_BYTE_3 <= s_can_rx_msg.data(3);
  axi_ro_regs.RX_PAYLOAD_1.PAYLOAD_BYTE_4 <= s_can_rx_msg.data(4);
  axi_ro_regs.RX_PAYLOAD_1.PAYLOAD_BYTE_5 <= s_can_rx_msg.data(5);
  axi_ro_regs.RX_PAYLOAD_1.PAYLOAD_BYTE_6 <= s_can_rx_msg.data(6);
  axi_ro_regs.RX_PAYLOAD_1.PAYLOAD_BYTE_7 <= s_can_rx_msg.data(7);

  with s_can_error_state select
    axi_ro_regs.STATUS.ERROR_STATE <=
    "00" when ERROR_ACTIVE,
    "01" when ERROR_PASSIVE,
    "10" when BUS_OFF;

  INST_canola_top_tmr : entity work.canola_top_tmr
    generic map (
      G_SEE_MITIGATION_EN       => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN      => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN  => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG     => G_MISMATCH_OUTPUT_REG,
      G_TIME_QUANTA_SCALE_WIDTH => C_TIME_QUANTA_SCALE_WIDTH_DEFAULT)
    port map (
      CLK   => AXI_CLK,
      RESET => AXI_RESET,

      -- CAN bus interface signals
      CAN_TX => CAN_TX,
      CAN_RX => CAN_RX,

      -- Rx interface
      RX_MSG       => s_can_rx_msg,
      RX_MSG_VALID => CAN_RX_VALID_IRQ,

      -- Tx interface
      TX_MSG           => s_can_tx_msg,
      TX_START         => axi_pulse_regs.CONTROL.TX_START,
      TX_RETRANSMIT_EN => axi_rw_regs.CONFIG.TX_RETRANSMIT_EN,
      TX_BUSY          => axi_ro_regs.STATUS.TX_BUSY,
      TX_DONE          => CAN_TX_DONE_IRQ,
      TX_FAILED        => CAN_TX_FAILED_IRQ,

      BTL_TRIPLE_SAMPLING     => axi_rw_regs.CONFIG.BTL_TRIPLE_SAMPLING_EN,
      BTL_PROP_SEG            => axi_rw_regs.BTL_PROP_SEG(C_PROP_SEG_WIDTH-1 downto 0),
      BTL_PHASE_SEG1          => axi_rw_regs.BTL_PHASE_SEG1(C_PHASE_SEG1_WIDTH-1 downto 0),
      BTL_PHASE_SEG2          => axi_rw_regs.BTL_PHASE_SEG2(C_PHASE_SEG2_WIDTH-1 downto 0),
      BTL_SYNC_JUMP_WIDTH     => unsigned(axi_rw_regs.BTL_SYNC_JUMP_WIDTH),
      TIME_QUANTA_CLOCK_SCALE => unsigned(axi_rw_regs.TIME_QUANTA_CLOCK_SCALE(C_TIME_QUANTA_SCALE_WIDTH_DEFAULT-1 downto 0)),

      -- Error state and counters
      std_logic_vector(TRANSMIT_ERROR_COUNT) => axi_ro_regs.TRANSMIT_ERROR_COUNT(C_ERROR_COUNT_LENGTH-1 downto 0),
      std_logic_vector(RECEIVE_ERROR_COUNT)  => axi_ro_regs.RECEIVE_ERROR_COUNT(C_ERROR_COUNT_LENGTH-1 downto 0),
      ERROR_STATE                            => s_can_error_state,

      -- Counter signals
      TX_MSG_SENT_COUNT_UP       => s_tx_msg_sent_count_up,
      TX_FAILED_COUNT_UP         => s_tx_failed_count_up,
      TX_ACK_ERROR_COUNT_UP      => s_tx_ack_error_count_up,
      TX_ARB_LOST_COUNT_UP       => s_tx_arb_lost_count_up,
      TX_BIT_ERROR_COUNT_UP      => s_tx_bit_error_count_up,
      TX_RETRANSMIT_COUNT_UP     => s_tx_retransmit_count_up,
      RX_MSG_RECV_COUNT_UP       => s_rx_msg_recv_count_up,
      RX_CRC_ERROR_COUNT_UP      => s_rx_crc_error_count_up,
      RX_FORM_ERROR_COUNT_UP     => s_rx_form_error_count_up,
      RX_STUFF_ERROR_COUNT_UP    => s_rx_stuff_error_count_up,

      MISMATCH     => MISMATCH_LOGIC,
      MISMATCH_2ND => MISMATCH_LOGIC_2ND
      );

  INST_canola_counters_tmr : entity work.canola_counters_tmr
    generic map (
      G_SEE_MITIGATION_EN      => G_SEE_MITIGATION_EN,
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG,
      G_COUNTER_WIDTH          => C_COUNTER_REG_WIDTH,
      G_SATURATING_COUNTERS    => true)
    port map (
      CLK   => AXI_CLK,
      RESET => AXI_RESET,

      CLEAR_TX_MSG_SENT_COUNT    => axi_pulse_regs.CONTROL.RESET_TX_MSG_SENT_COUNTER,
      CLEAR_TX_FAILED_COUNT      => axi_pulse_regs.CONTROL.RESET_TX_FAILED_COUNTER,
      CLEAR_TX_ACK_ERROR_COUNT   => axi_pulse_regs.CONTROL.RESET_TX_ACK_ERROR_COUNTER,
      CLEAR_TX_ARB_LOST_COUNT    => axi_pulse_regs.CONTROL.RESET_TX_ARB_LOST_COUNTER,
      CLEAR_TX_BIT_ERROR_COUNT   => axi_pulse_regs.CONTROL.RESET_TX_BIT_ERROR_COUNTER,
      CLEAR_TX_RETRANSMIT_COUNT  => axi_pulse_regs.CONTROL.RESET_TX_RETRANSMIT_COUNTER,
      CLEAR_RX_MSG_RECV_COUNT    => axi_pulse_regs.CONTROL.RESET_RX_MSG_RECV_COUNTER,
      CLEAR_RX_CRC_ERROR_COUNT   => axi_pulse_regs.CONTROL.RESET_RX_CRC_ERROR_COUNTER,
      CLEAR_RX_FORM_ERROR_COUNT  => axi_pulse_regs.CONTROL.RESET_RX_FORM_ERROR_COUNTER,
      CLEAR_RX_STUFF_ERROR_COUNT => axi_pulse_regs.CONTROL.RESET_RX_STUFF_ERROR_COUNTER,

      TX_MSG_SENT_COUNT_UP    => s_tx_msg_sent_count_up,
      TX_FAILED_COUNT_UP      => s_tx_failed_count_up,
      TX_ACK_ERROR_COUNT_UP   => s_tx_ack_error_count_up,
      TX_ARB_LOST_COUNT_UP    => s_tx_arb_lost_count_up,
      TX_BIT_ERROR_COUNT_UP   => s_tx_bit_error_count_up,
      TX_RETRANSMIT_COUNT_UP  => s_tx_retransmit_count_up,
      RX_MSG_RECV_COUNT_UP    => s_rx_msg_recv_count_up,
      RX_CRC_ERROR_COUNT_UP   => s_rx_crc_error_count_up,
      RX_FORM_ERROR_COUNT_UP  => s_rx_form_error_count_up,
      RX_STUFF_ERROR_COUNT_UP => s_rx_stuff_error_count_up,

      TX_MSG_SENT_COUNT_VALUE    => axi_ro_regs.TX_MSG_SENT_COUNT,
      TX_FAILED_COUNT_VALUE      => axi_ro_regs.TX_FAILED_COUNT,
      TX_ACK_ERROR_COUNT_VALUE   => axi_ro_regs.TX_ACK_ERROR_COUNT,
      TX_ARB_LOST_COUNT_VALUE    => axi_ro_regs.TX_ARB_LOST_COUNT,
      TX_BIT_ERROR_COUNT_VALUE   => axi_ro_regs.TX_BIT_ERROR_COUNT,
      TX_RETRANSMIT_COUNT_VALUE  => axi_ro_regs.TX_RETRANSMIT_COUNT,
      RX_MSG_RECV_COUNT_VALUE    => axi_ro_regs.RX_MSG_RECV_COUNT,
      RX_CRC_ERROR_COUNT_VALUE   => axi_ro_regs.RX_CRC_ERROR_COUNT,
      RX_FORM_ERROR_COUNT_VALUE  => axi_ro_regs.RX_FORM_ERROR_COUNT,
      RX_STUFF_ERROR_COUNT_VALUE => axi_ro_regs.RX_STUFF_ERROR_COUNT,

      MISMATCH     => MISMATCH_COUNTERS,
      MISMATCH_2ND => MISMATCH_COUNTERS_2ND
      );

  -- User Logic End

  i_canola_axi_slave_axi_pif : entity work.canola_axi_slave_axi_pif
    generic map (
      G_AXI_BASEADDR        => g_axi_baseaddr)
    port map (
      axi_rw_regs         => axi_rw_regs,
      axi_ro_regs         => axi_ro_regs,
      axi_pulse_regs      => axi_pulse_regs,
      clk                 => AXI_CLK,
      areset_n            => AXI_ARESETN,
      awaddr              => AXI_AWADDR,
      awvalid             => AXI_AWVALID,
      awready             => AXI_AWREADY,
      wdata               => AXI_WDATA(C_CANOLA_AXI_SLAVE_DATA_WIDTH-1 downto 0),
      wvalid              => AXI_WVALID,
      wready              => AXI_WREADY,
      bresp               => AXI_BRESP,
      bvalid              => AXI_BVALID,
      bready              => AXI_BREADY,
      araddr              => AXI_ARADDR(C_CANOLA_AXI_SLAVE_ADDR_WIDTH-1 downto 0),
      arvalid             => AXI_ARVALID,
      arready             => AXI_ARREADY,
      rdata               => AXI_RDATA(C_CANOLA_AXI_SLAVE_DATA_WIDTH-1 downto 0),
      rresp               => AXI_RRESP,
      rvalid              => AXI_RVALID,
      rready              => AXI_RREADY
      );

end architecture behavior;
