-------------------------------------------------------------------------------
-- Title      : UVVM Testbench for Canola CAN Controller AXI-lite slave
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_axi_slave_tb.vhd
-- Author     : Simon Voigt Nesbo (svn@hvl.no)
-- Company    : Western Norway University of Applied Sciences
-- Created    : 2019-08-05
-- Last update: 2019-12-17
-- Platform   :
-- Target     :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: UVVM testbench for AXI-lite slave version
--              of the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 2019-12-17  1.0      svn                     Created
-------------------------------------------------------------------------------

use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library bitvis_vip_axilite;
use bitvis_vip_axilite.axilite_bfm_pkg.all;

library work;
use work.axi_pkg.all;
use work.canola_axi_slave_pif_pkg.all;
use work.can_pkg.all;
use work.can_tb_pkg.all;
use work.can_bfm_pkg.all;
use work.can_uvvm_bfm_pkg.all;

-- test bench entity
entity can_axi_slave_tb is
end can_axi_slave_tb;

architecture tb of can_axi_slave_tb is

  constant C_CLK_PERIOD : time       := 6.25 ns; -- 160 Mhz
  constant C_CLK_FREQ   : integer    := 1e9 ns / C_CLK_PERIOD;

  constant C_CAN_BAUD_PERIOD  : time    := 1000 ns;  -- 1 MHz
  constant C_CAN_BAUD_FREQ    : integer := 1e9 ns / C_CAN_BAUD_PERIOD;

  -- Indicates where in a bit the Rx sample point should be
  -- Real value from 0.0 to 1.0.
  constant C_CAN_SAMPLE_POINT : real    := 0.7;

  constant C_TIME_QUANTA_CLOCK_SCALE_VAL : natural := 3;

  constant C_DATA_LENGTH_MAX : natural := 1000;
  constant C_NUM_ITERATIONS  : natural := 100;

  constant C_BUS_REG_WIDTH : natural := 32;

  -- Generate a clock with a given period,
  -- based on clock_gen from Bitvis IRQC testbench
  procedure clock_gen(
    signal clock_signal          : inout std_logic;
    signal clock_ena             : in    boolean;
    constant clock_period        : in    time
    ) is
    variable v_first_half_clk_period : time;
  begin
    loop
      if not clock_ena then
        wait until clock_ena;
      end if;

      v_first_half_clk_period := clock_period / 2;

      wait for v_first_half_clk_period;
      clock_signal <= not clock_signal;
      wait for (clock_period - v_first_half_clk_period);
      clock_signal <= not clock_signal;
    end loop;
  end;

  signal s_clock_ena      : boolean   := false;
  signal s_can_baud_clk   : std_logic := '0';

  signal s_reset            : std_logic := '0';
  signal s_clk              : std_logic := '0';

  -- Signals for CAN controller
  signal s_can_ctrl_tx       : std_logic;
  signal s_can_ctrl_rx       : std_logic;
  signal s_can_rx_valid_irq  : std_logic;
  signal s_can_tx_done_irq   : std_logic;
  signal s_can_tx_failed_irq : std_logic;
  signal s_can_axi_clk       : std_logic;
  signal s_can_axi_areset_n  : std_logic;
  signal s_can_axi_in        : t_axi_interconnect_to_slave;
  signal s_can_axi_out       : t_axi_slave_to_interconnect;

  -- CAN signals used by BFM
  signal s_can_bfm_tx        : std_logic                      := '1';
  signal s_can_bfm_rx        : std_logic                      := '1';

  -- Shared CAN bus signal
  signal s_can_bus_signal    : std_logic;

  -- Used by p_can_ctrl_rx_msg which monitors
  -- when the CAN controller receives a message
  signal s_msg_received : std_logic := '0';
  signal s_msg_reset    : std_logic := '0';
  signal s_msg          : can_msg_t;


  -- Signals for AXI bus
  --signal axi_master_araddr  : std_logic_vector (31 downto 0);
  --signal axi_master_arprot  : std_logic_vector (2 downto 0);
  --signal axi_master_arready : std_logic_vector (0 to 0);
  --signal axi_master_arvalid : std_logic_vector (0 to 0);
  --signal axi_master_awaddr  : std_logic_vector (31 downto 0);
  --signal axi_master_awprot  : std_logic_vector (2 downto 0);
  --signal axi_master_awready : std_logic_vector (0 to 0);
  --signal axi_master_awvalid : std_logic_vector (0 to 0);
  --signal axi_master_bready  : std_logic_vector (0 to 0);
  --signal axi_master_bresp   : std_logic_vector (1 downto 0);
  --signal axi_master_bvalid  : std_logic_vector (0 to 0);
  --signal axi_master_rdata   : std_logic_vector (31 downto 0);
  --signal axi_master_rready  : std_logic_vector (0 to 0);
  --signal axi_master_rresp   : std_logic_vector (1 downto 0);
  --signal axi_master_rvalid  : std_logic_vector (0 to 0);
  --signal axi_master_wdata   : std_logic_vector (31 downto 0);
  --signal axi_master_wready  : std_logic_vector (0 to 0);
  --signal axi_master_wstrb   : std_logic_vector (3 downto 0);
  --signal axi_master_wvalid  : std_logic_vector (0 to 0);

  constant C_AXI_BUS_ADDR_WIDTH : natural := 32;
  constant C_AXI_BUS_DATA_WIDTH : natural := 32;

  signal s_axi_bfm_if : t_axilite_if(write_address_channel(awaddr(C_AXI_BUS_ADDR_WIDTH-1 downto 0)),
                                     write_data_channel(wdata(C_AXI_BUS_DATA_WIDTH-1 downto 0),
                                                        wstrb((C_AXI_BUS_DATA_WIDTH/8)-1 downto 0)),
                                     read_address_channel(araddr(C_AXI_BUS_ADDR_WIDTH-1 downto 0)),
                                     read_data_channel(rdata(C_AXI_BUS_DATA_WIDTH-1 downto 0)))
    := init_axilite_if_signals(C_AXI_BUS_DATA_WIDTH, C_AXI_BUS_ADDR_WIDTH);

  constant C_AXILITE_BFM_CONFIG : t_axilite_bfm_config := (
    max_wait_cycles            => 100,
    max_wait_cycles_severity   => TB_FAILURE,
    clock_period               => C_CLK_PERIOD,
    clock_period_margin        => 10 ps,
    clock_margin_severity      => NO_ALERT,
    setup_time                 => 1.5 ns,
    hold_time                  => 1.5 ns,
    expected_response          => OKAY,
    expected_response_severity => TB_FAILURE,
    protection_setting         => UNPRIVILIGED_UNSECURE_DATA,
    num_aw_pipe_stages         => 1,
    num_w_pipe_stages          => 1,
    num_ar_pipe_stages         => 1,
    num_r_pipe_stages          => 1,
    num_b_pipe_stages          => 1,
    id_for_bfm                 => ID_BFM,
    id_for_bfm_wait            => ID_BFM_WAIT,
    id_for_bfm_poll            => ID_BFM_POLL
    );

begin

  -- Set up clock generators
  clock_gen(s_clk, s_clock_ena, C_CLK_PERIOD);
  clock_gen(s_can_baud_clk, s_clock_ena, C_CAN_BAUD_PERIOD);

  s_can_axi_clk      <= s_clk;
  s_can_axi_areset_n <= not s_reset;

  s_can_bus_signal <= 'H';
  s_can_bus_signal <= '0' when s_can_ctrl_tx = '0' else 'Z';
  s_can_bus_signal <= '0' when s_can_bfm_tx  = '0' else 'Z';
  s_can_ctrl_rx    <= '1' ?= s_can_bus_signal;
  s_can_bfm_rx     <= '1' ?= s_can_bus_signal;

  -- Connect AXI BFM interface to AXI interfaces for Canola AXI slave
  s_can_axi_in.awaddr  <= s_axi_bfm_if.write_address_channel.awaddr;
  s_can_axi_in.awvalid <= s_axi_bfm_if.write_address_channel.awvalid;
  s_can_axi_in.wdata   <= s_axi_bfm_if.write_data_channel.wdata;
  s_can_axi_in.wvalid  <= s_axi_bfm_if.write_data_channel.wvalid;
  s_can_axi_in.bready  <= s_axi_bfm_if.write_response_channel.bready;
  s_can_axi_in.araddr  <= s_axi_bfm_if.read_address_channel.araddr;
  s_can_axi_in.arvalid <= s_axi_bfm_if.read_address_channel.arvalid;
  s_can_axi_in.rready  <= s_axi_bfm_if.read_data_channel.rready;


  s_axi_bfm_if.write_address_channel.awready <= s_can_axi_out.awready;
  s_axi_bfm_if.write_data_channel.wready     <= s_can_axi_out.wready;
  s_axi_bfm_if.read_address_channel.arready  <= s_can_axi_out.arready;
  s_axi_bfm_if.write_response_channel.bresp  <= s_can_axi_out.bresp;
  s_axi_bfm_if.write_response_channel.bvalid <= s_can_axi_out.bvalid;
  s_axi_bfm_if.read_data_channel.rdata       <= s_can_axi_out.rdata;
  s_axi_bfm_if.read_data_channel.rresp       <= s_can_axi_out.rresp;
  s_axi_bfm_if.read_data_channel.rvalid      <= s_can_axi_out.rvalid;

  s_axi_bfm_if.write_address_channel.awprot <= (others => '0');
  s_axi_bfm_if.write_data_channel.wstrb     <= (others => '0');



  INST_canola_axi_slave: entity work.canola_axi_slave
    port map (
      CAN_RX            => s_can_ctrl_rx,
      CAN_TX            => s_can_ctrl_tx,
      CAN_RX_VALID_IRQ  => s_can_rx_valid_irq,
      CAN_TX_DONE_IRQ   => s_can_tx_done_irq,
      CAN_TX_FAILED_IRQ => s_can_tx_failed_irq,
      axi_clk           => s_can_axi_clk,
      axi_areset_n      => s_can_axi_areset_n,
      axi_in            => s_can_axi_in,
      axi_out           => s_can_axi_out);


  p_main: process
    constant C_SCOPE          : string                := C_TB_SCOPE_DEFAULT;
    variable v_can_bfm_config : t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT;

    -- Pulse a signal for a number of clock cycles.
    -- Source: irqc_tb.vhd from Bitvis UVVM 1.4.0
    procedure pulse(
      signal   target          : inout std_logic;
      signal   clock_signal    : in    std_logic;
      constant num_periods     : in    natural;
      constant msg             : in    string
    ) is
    begin
      if num_periods > 0 then
        wait until falling_edge(clock_signal);
        target  <= '1';
        for i in 1 to num_periods loop
          wait until falling_edge(clock_signal);
        end loop;
      else
        target  <= '1';
        wait for 0 ns;  -- Delta cycle only
      end if;
      target  <= '0';
      log(ID_SEQUENCER_SUB, msg, C_SCOPE);
    end;

    -- Pulse a signal for a number of clock cycles.
    -- Source: irqc_tb.vhd from Bitvis UVVM 1.4.0
    procedure pulse(
      signal   target        : inout  std_logic_vector;
      constant pulse_value   : in     std_logic_vector;
      signal   clock_signal  : in     std_logic;
      constant num_periods   : in     natural;
      constant msg           : in     string) is
    begin
      if num_periods > 0 then
        wait until falling_edge(clock_signal);
        target <= pulse_value;
        for i in 1 to num_periods loop
          wait until falling_edge(clock_signal);
        end loop;
      else
        target <= pulse_value;
        wait for 0 ns;  -- Delta cycle only
      end if;
      target(target'range) <= (others => '0');
      log(ID_SEQUENCER_SUB, "Pulsed to " & to_string(pulse_value, HEX, AS_IS, INCL_RADIX) & ". " & msg, C_SCOPE);
    end;


    -- Log overloads for simplification
    procedure log(
      msg   : string) is
    begin
      log(ID_SEQUENCER, msg, C_SCOPE);
    end;

    variable seed1         : positive := 53267458;
    variable seed2         : positive := 90832486;
    variable v_count       : natural;
    variable v_test_num    : natural;
    variable v_data_length : natural;


    procedure axilite_write(
      constant addr_value         : in  t_canola_axi_slave_addr;
      constant data_value         : in  std_logic_vector;
      constant msg                : in  string) is
    begin
      axilite_write(unsigned(addr_value),
                    data_value,
                    msg,
                    s_can_axi_clk,
                    s_axi_bfm_if,
                    C_SCOPE,
                    shared_msg_id_panel,
                    C_AXILITE_BFM_CONFIG);
    end procedure axilite_write;


    procedure axilite_read(
      constant addr_value         : in  t_canola_axi_slave_addr;
      variable data_value         : out std_logic_vector;
      constant msg                : in  string) is
    begin
      axilite_read(unsigned(addr_value),
                   data_value,
                   msg,
                   s_can_axi_clk,
                   s_axi_bfm_if,
                   C_SCOPE,
                   shared_msg_id_panel,
                   C_AXILITE_BFM_CONFIG);
    end procedure axilite_read;


    procedure axilite_check(
      constant addr_value         : in  t_canola_axi_slave_addr;
      constant data_exp           : in  std_logic_vector;
      constant msg                : in  string) is
    begin
      axilite_check(unsigned(addr_value),
                    data_exp,
                    msg,
                    s_can_axi_clk,
                    s_axi_bfm_if,
                    error,
                    C_SCOPE,
                    shared_msg_id_panel,
                    C_AXILITE_BFM_CONFIG);
    end procedure axilite_check;


    -- Todo 1: Put this in a package file?
    -- Todo 2: Define one message type for use both with BFM and RTL code,
    --         and define can_payload_t in one place..
    procedure generate_random_can_message (
      variable arb_id             : out std_logic_vector(28 downto 0);
      variable data               : out work.can_bfm_pkg.can_payload_t;
      variable data_length        : out natural;
      variable remote_frame       : out std_logic;
      constant extended_id        : in  std_logic := '0';
      constant allow_remote_frame : in  std_logic := '1'
      ) is
      variable rand_real : real;
      variable rand_id   : natural;
      variable rand_byte : natural;
    begin
      uniform(seed1, seed2, rand_real);
      data_length := natural(round(rand_real * real(8)));

      uniform(seed1, seed2, rand_real);
      if rand_real > 0.5 and allow_remote_frame = '1' then
        remote_frame := '1';
      else
        remote_frame := '0';
      end if;

      uniform(seed1, seed2, rand_real);
      if extended_id = '1' then
        rand_id             := natural(round(rand_real * real(2**29-1)));
        arb_id(28 downto 0) := std_logic_vector(to_unsigned(rand_id, 29));
      else
        rand_id              := natural(round(rand_real * real(2**11-1)));
        arb_id(28 downto 11) := (others => '0');
        arb_id(10 downto 0)  := std_logic_vector(to_unsigned(rand_id, 11));
      end if;

      if remote_frame = '0' then
        for byte_num in 0 to 7 loop
          if byte_num < data_length then
            uniform(seed1, seed2, rand_real);
            rand_byte      := natural(round(rand_real * real(255)));
            data(byte_num) := std_logic_vector(to_unsigned(rand_byte, 8));
          else
            data(byte_num) := x"00";
          end if;
        end loop;  -- byte_num
      end if;

    end procedure generate_random_can_message;


    function resize_data (
      constant slv_in : std_logic_vector)
      return std_logic_vector is
    begin
      return std_logic_vector(resize(unsigned(slv_in), C_CANOLA_AXI_SLAVE_DATA_WIDTH));
    end function resize_data;



    variable v_can_bfm_tx        : std_logic                      := '1';
    variable v_can_bfm_rx        : std_logic                      := '1';
    variable v_xmit_arb_id       : std_logic_vector(28 downto 0);
    variable v_xmit_ext_id       : std_logic                      := '0';
    variable v_xmit_data         : work.can_bfm_pkg.can_payload_t := (others => x"00");
    variable v_xmit_data_length  : natural;
    variable v_xmit_remote_frame : std_logic;
    variable v_xmit_arb_lost     : std_logic     := '0';

    variable v_recv_arb_id       : std_logic_vector(28 downto 0);
    variable v_recv_data         : work.can_bfm_pkg.can_payload_t;
    variable v_recv_ext_id       : std_logic     := '0';
    variable v_recv_remote_frame : std_logic     := '0';
    variable v_recv_data_length  : natural       := 0;
    variable v_recv_timeout      : std_logic;

    variable v_can_tx_status    : can_tx_status_t;
    variable v_can_rx_error_gen : can_rx_error_gen_t := C_CAN_RX_NO_ERROR_GEN;

    variable v_arb_lost_count       : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_ack_recv_count       : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_tx_error_count       : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_rx_msg_count         : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_rx_crc_error_count   : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_rx_form_error_count  : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_rx_stuff_error_count : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
    variable v_receive_error_count  : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);

    variable v_rand_baud_delay : natural;
    variable v_rand_real       : real;
  begin
    -- Print the configuration to the log
    report_global_ctrl(VOID);
    report_msg_id_panel(VOID);

    enable_log_msg(ALL_MESSAGES);
    --disable_log_msg(ALL_MESSAGES);
    --enable_log_msg(ID_LOG_HDR);

    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Start simulation of CAN controller", C_SCOPE);
    -----------------------------------------------------------------------------------------------

    s_clock_ena <= true;                -- to start clock generator
    pulse(s_reset, s_clk, 10, "Pulsed reset-signal - active for 10 cycles");

    wait until rising_edge(s_clk);
    wait until rising_edge(s_clk);

    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Check default/reset values of registers", C_SCOPE);
    -----------------------------------------------------------------------------------------------
    axilite_check(C_ADDR_STATUS,
                  resize_data(c_canola_axi_slave_ro_regs.STATUS.ERROR_STATE &
                              c_canola_axi_slave_ro_regs.STATUS.TX_FAILED &
                              c_canola_axi_slave_ro_regs.STATUS.TX_DONE &
                              c_canola_axi_slave_ro_regs.STATUS.TX_BUSY &
                              c_canola_axi_slave_ro_regs.STATUS.RX_MSG_VALID),
                  "Check STATUS register");

    axilite_check(C_ADDR_CONTROL,
                  resize_data("" & c_canola_axi_slave_pulse_regs.CONTROL.TX_START),
                  "Check CONTROL register");

    axilite_check(C_ADDR_CONFIG,
                  resize_data(c_canola_axi_slave_rw_regs.CONFIG.TX_RETRANSMIT_EN &
                              c_canola_axi_slave_rw_regs.CONFIG.BTL_TRIPLE_SAMPLING_EN),
                  "Check CONFIG register");

    axilite_check(C_ADDR_BTL_PROP_SEG,
                  resize_data(c_canola_axi_slave_rw_regs.BTL_PROP_SEG),
                  "Check BTL_PROP_SEG register");

    axilite_check(C_ADDR_BTL_PHASE_SEG1,
                  resize_data(c_canola_axi_slave_rw_regs.BTL_PHASE_SEG1),
                  "Check BTL_PHASE_SEG1 register");

    axilite_check(C_ADDR_BTL_PHASE_SEG2,
                  resize_data(c_canola_axi_slave_rw_regs.BTL_PHASE_SEG2),
                  "Check BTL_PHASE_SEG2 register");

    axilite_check(C_ADDR_BTL_SYNC_JUMP_WIDTH,
                  resize_data(c_canola_axi_slave_rw_regs.BTL_SYNC_JUMP_WIDTH),
                  "Check BTL_SYNC_JUMP_WIDTH register");

    axilite_check(C_ADDR_BTL_TIME_QUANTA_CLOCK_SCALE,
                  resize_data(c_canola_axi_slave_rw_regs.BTL_TIME_QUANTA_CLOCK_SCALE),
                  "Check BTL_TIME_QUANTA_CLOCK_SCALE register");

    axilite_check(C_ADDR_TRANSMIT_ERROR_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.TRANSMIT_ERROR_COUNT),
                  "Check TRANSMIT_ERROR_COUNT register");

    axilite_check(C_ADDR_RECEIVE_ERROR_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.RECEIVE_ERROR_COUNT),
                  "Check RECEIVE_ERROR_COUNT register");

    axilite_check(C_ADDR_TX_MSG_SENT_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.TX_MSG_SENT_COUNT),
                  "Check TX_MSG_SENT_COUNT register");

    axilite_check(C_ADDR_TX_ACK_RECV_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.TX_ACK_RECV_COUNT),
                  "Check TX_ACK_RECV_COUNT register");

    axilite_check(C_ADDR_TX_ARB_LOST_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.TX_ARB_LOST_COUNT),
                  "Check TX_ARB_LOST_COUNT register");

    axilite_check(C_ADDR_TX_ERROR_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.TX_ERROR_COUNT),
                  "Check TX_ERROR_COUNT register");

    axilite_check(C_ADDR_RX_MSG_RECV_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.RX_MSG_RECV_COUNT),
                  "Check RX_MSG_RECV_COUNT register");

    axilite_check(C_ADDR_RX_CRC_ERROR_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.RX_CRC_ERROR_COUNT),
                  "Check RX_CRC_ERROR_COUNT register");

    axilite_check(C_ADDR_RX_FORM_ERROR_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.RX_FORM_ERROR_COUNT),
                  "Check RX_FORM_ERROR_COUNT register");

    axilite_check(C_ADDR_RX_STUFF_ERROR_COUNT,
                  resize_data(c_canola_axi_slave_ro_regs.RX_STUFF_ERROR_COUNT),
                  "Check RX_STUFF_ERROR_COUNT register");

    -----------------------------------------------------------------------------------------------
    -- Simulation complete
    -----------------------------------------------------------------------------------------------
    wait for 10000 ns;            -- to allow some time for completion
    report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

    -- Finish the simulation
    std.env.stop;
    wait;  -- to stop completely

end process p_main;

end tb;
