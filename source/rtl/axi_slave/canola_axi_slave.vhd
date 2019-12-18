library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- User Libraries Start

-- User Libraries End

use work.axi_pkg.all;
use work.canola_axi_slave_pif_pkg.all;
use work.can_pkg.all;

entity canola_axi_slave is

  generic (
    -- User Generics Start

    -- User Generics End
    -- AXI Bus Interface Generics
    G_AXI_BASEADDR        : std_logic_vector(31 downto 0) := 32X"0");
  port (
    -- User Ports Start
    CAN_RX       : in  std_logic;
    CAN_TX       : out std_logic;

    CAN_RX_VALID_IRQ  : out std_logic;
    CAN_TX_DONE_IRQ   : out std_logic;
    CAN_TX_FAILED_IRQ : out std_logic;

    -- User Ports End
    -- AXI Bus Interface Ports
    AXI_CLK      : in  std_logic;
    AXI_ARESET_N : in  std_logic;
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

end entity canola_axi_slave;

architecture behavior of canola_axi_slave is

  -- User Architecture Start
  signal s_can_rx_msg      : can_msg_t;
  signal s_can_tx_msg      : can_msg_t;
  signal s_can_error_state : can_error_state_t;
  signal s_btl_sync_jump_width : natural range 1 to C_SYNC_JUMP_WIDTH_MAX-1;

  constant C_INTERNAL_REG_WIDTH : natural := 16;
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

  with axi_rw_regs.BTL_SYNC_JUMP_WIDTH select
    s_btl_sync_jump_width <=
    1 when "00",
    1 when "01",
    2 when "10",
    2 when others;

  INST_can_top : entity work.can_top
    generic map (
      G_BUS_REG_WIDTH => C_INTERNAL_REG_WIDTH,
      G_ENABLE_EXT_ID => true)
    port map (
      CLK   => axi_clk,
      RESET => not axi_areset_n,

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

      BTL_TRIPLE_SAMPLING         => axi_rw_regs.CONFIG.BTL_TRIPLE_SAMPLING_EN,
      BTL_PROP_SEG                => axi_rw_regs.BTL_PROP_SEG(C_PROP_SEG_WIDTH-1 downto 0),
      BTL_PHASE_SEG1              => axi_rw_regs.BTL_PHASE_SEG1(C_PHASE_SEG1_WIDTH-1 downto 0),
      BTL_PHASE_SEG2              => axi_rw_regs.BTL_PHASE_SEG2(C_PHASE_SEG2_WIDTH-1 downto 0),
      BTL_SYNC_JUMP_WIDTH         => s_btl_sync_jump_width,
      BTL_TIME_QUANTA_CLOCK_SCALE => unsigned(axi_rw_regs.BTL_TIME_QUANTA_CLOCK_SCALE(C_TIME_QUANTA_WIDTH-1 downto 0)),

      -- Error state and counters
      std_logic_vector(TRANSMIT_ERROR_COUNT) => axi_ro_regs.TRANSMIT_ERROR_COUNT(C_ERROR_COUNT_LENGTH-1 downto 0),
      std_logic_vector(RECEIVE_ERROR_COUNT)  => axi_ro_regs.RECEIVE_ERROR_COUNT(C_ERROR_COUNT_LENGTH-1 downto 0),
      ERROR_STATE                            => s_can_error_state,

      -- Registers/counters
      REG_TX_MSG_SENT_COUNT    => axi_ro_regs.TX_MSG_SENT_COUNT,
      REG_TX_ACK_RECV_COUNT    => axi_ro_regs.TX_ACK_RECV_COUNT,
      REG_TX_ARB_LOST_COUNT    => axi_ro_regs.TX_ARB_LOST_COUNT,
      REG_TX_ERROR_COUNT       => axi_ro_regs.TX_ERROR_COUNT,
      REG_RX_MSG_RECV_COUNT    => axi_ro_regs.RX_MSG_RECV_COUNT,
      REG_RX_CRC_ERROR_COUNT   => axi_ro_regs.RX_CRC_ERROR_COUNT,
      REG_RX_FORM_ERROR_COUNT  => axi_ro_regs.RX_FORM_ERROR_COUNT,
      REG_RX_STUFF_ERROR_COUNT => axi_ro_regs.RX_STUFF_ERROR_COUNT
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
      areset_n            => AXI_ARESET_N,
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
