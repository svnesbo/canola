-------------------------------------------------------------------------------
-- Title      : Top-level UVVM Testbench for Canola CAN Controller
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_top_tb.vhd
-- Author     : Simon Voigt Nesbo (svn@hvl.no)
-- Company    : Western Norway University of Applied Sciences
-- Created    : 2019-08-05
-- Last update: 2019-09-19
-- Platform   :
-- Target     :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Top-level UVVM testbench for the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author                  Description
-- 2019-08-05  1.0      svn                     Created
-------------------------------------------------------------------------------

use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use work.can_pkg.all;
use work.can_tb_pkg.all;
use work.can_bfm_pkg.all;
use work.can_uvvm_bfm_pkg.all;

-- test bench entity
entity can_top_tb is
end can_top_tb;

architecture tb of can_top_tb is

  constant C_CLK_PERIOD : time       := 25 ns; -- 10 Mhz
  constant C_CLK_FREQ   : integer    := 1e9 ns / C_CLK_PERIOD;

  constant C_CAN_BAUD_PERIOD  : time    := 10000 ns;  -- 100 kHz
  constant C_CAN_BAUD_FREQ    : integer := 1e9 ns / C_CAN_BAUD_PERIOD;

  -- Indicates where in a bit the Rx sample point should be
  -- Real value from 0.0 to 1.0.
  constant C_CAN_SAMPLE_POINT : real    := 0.7;

  constant C_TIME_QUANTA_CLOCK_SCALE_VAL : natural := 3;

  constant C_DATA_LENGTH_MAX : natural := 1000;
  constant C_NUM_ITERATIONS  : natural := 100;

  constant C_BUS_REG_WIDTH : natural := 16;

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
  signal s_can_ctrl_tx           : std_logic;
  signal s_can_ctrl_rx           : std_logic;
  signal s_can_ctrl_rx_msg       : can_msg_t;
  signal s_can_ctrl_tx_msg       : can_msg_t;
  signal s_can_ctrl_rx_msg_valid : std_logic;
  signal s_can_ctrl_tx_start     : std_logic := '0';
  signal s_can_ctrl_tx_busy      : std_logic;
  signal s_can_ctrl_tx_done      : std_logic;

  signal s_can_ctrl_prop_seg        : std_logic_vector(C_PROP_SEG_WIDTH-1 downto 0)   := "0111";
  signal s_can_ctrl_phase_seg1      : std_logic_vector(C_PHASE_SEG1_WIDTH-1 downto 0) := "0111";
  signal s_can_ctrl_phase_seg2      : std_logic_vector(C_PHASE_SEG2_WIDTH-1 downto 0) := "0111";
  signal s_can_ctrl_sync_jump_width : natural range 0 to C_SYNC_JUMP_WIDTH_MAX        := 2;

  signal s_can_ctrl_transmit_error_count : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
  signal s_can_ctrl_receive_error_count  : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
  signal s_can_ctrl_error_state          : can_error_state_t;

  -- Registers/counters
  signal s_can_ctrl_reg_tx_msg_sent_count    : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_tx_ack_recv_count    : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_tx_arb_lost_count    : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_tx_error_count       : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_rx_msg_recv_count    : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_rx_crc_error_count   : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_rx_form_error_count  : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);
  signal s_can_ctrl_reg_rx_stuff_error_count : std_logic_vector(C_BUS_REG_WIDTH-1 downto 0);

  -- CAN signals used by BFM
  signal s_can_bfm_tx        : std_logic                      := '1';
  signal s_can_bfm_rx        : std_logic                      := '1';
  signal s_xmit_arb_id       : std_logic_vector(28 downto 0);
  constant s_xmit_ext_id     : std_logic                      := '0';
  signal s_xmit_data         : work.can_bfm_pkg.can_payload_t := (others => x"00");
  signal s_xmit_data_length  : natural;
  signal s_xmit_remote_frame : std_logic;
  signal s_recv_arb_id       : std_logic_vector(28 downto 0);
  signal s_recv_ext_id       : std_logic                      := '0';
  signal s_recv_data         : work.can_bfm_pkg.can_payload_t := (others => x"00");
  signal s_recv_data_length  : natural;
  signal s_recv_remote_frame : std_logic;

  -- Shared CAN bus signal
  signal s_can_bus_signal    : std_logic;

  -- Used by p_can_ctrl_rx_msg which monitors
  -- when the CAN controller receives a message
  signal s_msg_received : std_logic := '0';
  signal s_msg_reset    : std_logic := '0';
  signal s_msg          : can_msg_t;


begin

  -- Set up clock generators
  clock_gen(s_clk, s_clock_ena, C_CLK_PERIOD);
  clock_gen(s_can_baud_clk, s_clock_ena, C_CAN_BAUD_PERIOD);

  s_can_bus_signal <= 'H';
  s_can_bus_signal <= '0' when s_can_ctrl_tx = '0' else 'Z';
  s_can_bus_signal <= '0' when s_can_bfm_tx  = '0' else 'Z';
  s_can_ctrl_rx    <= '1' ?= s_can_bus_signal;
  s_can_bfm_rx     <= '1' ?= s_can_bus_signal;



  INST_can_top : entity work.can_top
    generic map (
      G_BUS_REG_WIDTH => C_BUS_REG_WIDTH,
      G_ENABLE_EXT_ID => true)
    port map (
      CLK   => s_clk,
      RESET => s_reset,

      -- CAN bus interface signals
      CAN_TX => s_can_ctrl_tx,
      CAN_RX => s_can_ctrl_rx,

      -- Rx interface
      RX_MSG       => s_can_ctrl_rx_msg,
      RX_MSG_VALID => s_can_ctrl_rx_msg_valid,

      -- Tx interface
      TX_MSG   => s_can_ctrl_tx_msg,
      TX_START => s_can_ctrl_tx_start,
      TX_BUSY  => s_can_ctrl_tx_busy,
      TX_DONE  => s_can_ctrl_tx_done,

      BTL_TRIPLE_SAMPLING         => '0',
      BTL_PROP_SEG                => s_can_ctrl_prop_seg,
      BTL_PHASE_SEG1              => s_can_ctrl_phase_seg1,
      BTL_PHASE_SEG2              => s_can_ctrl_phase_seg2,
      BTL_SYNC_JUMP_WIDTH         => s_can_ctrl_sync_jump_width,
      BTL_TIME_QUANTA_CLOCK_SCALE => to_unsigned(C_TIME_QUANTA_CLOCK_SCALE_VAL,
                                                 C_TIME_QUANTA_WIDTH),

      -- Error state and counters
      TRANSMIT_ERROR_COUNT => s_can_ctrl_transmit_error_count,
      RECEIVE_ERROR_COUNT  => s_can_ctrl_receive_error_count,
      ERROR_STATE          => s_can_ctrl_error_state,

      -- Registers/counters
      REG_TX_MSG_SENT_COUNT    => s_can_ctrl_reg_tx_msg_sent_count,
      REG_TX_ACK_RECV_COUNT    => s_can_ctrl_reg_tx_ack_recv_count,
      REG_TX_ARB_LOST_COUNT    => s_can_ctrl_reg_tx_arb_lost_count,
      REG_TX_ERROR_COUNT       => s_can_ctrl_reg_tx_error_count,
      REG_RX_MSG_RECV_COUNT    => s_can_ctrl_reg_rx_msg_recv_count,
      REG_RX_CRC_ERROR_COUNT   => s_can_ctrl_reg_rx_crc_error_count,
      REG_RX_FORM_ERROR_COUNT  => s_can_ctrl_reg_rx_form_error_count,
      REG_RX_STUFF_ERROR_COUNT => s_can_ctrl_reg_rx_stuff_error_count
      );

  -- Monitor CAN controller and indicate when it has received a message (rx_msg_valid is pulsed)
  p_can_ctrl_rx_msg: process (s_can_ctrl_rx_msg_valid, s_msg_reset) is
  begin
    if s_msg_reset = '1' then
      s_msg_received <= '0';
    elsif s_can_ctrl_rx_msg_valid = '1' then
      s_msg_received <= '1';
      s_msg          <= s_can_ctrl_rx_msg;
    end if;
  end process p_can_ctrl_rx_msg;


  p_main: process
    constant C_SCOPE     : string  := C_TB_SCOPE_DEFAULT;

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

    -- Todo 1: Put this in a package file?
    -- Todo 2: Define one message type for use both with BFM and RTL code,
    --         and define can_payload_t in one place..
    procedure generate_random_can_message (
      variable arb_id       : out std_logic_vector(28 downto 0);
      variable data         : out work.can_bfm_pkg.can_payload_t;
      variable data_length  : out natural;
      variable remote_frame : out std_logic;
      constant extended_id  : in  std_logic := '0'
      ) is
      variable rand_real : real;
      variable rand_id   : natural;
      variable rand_byte : natural;
    begin
      uniform(seed1, seed2, rand_real);
      data_length := natural(round(rand_real * real(8)));

      uniform(seed1, seed2, rand_real);
      if rand_real > 0.5 then
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

    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test #1: Basic ID msg from BFM to Canola CAN controller", C_SCOPE);
    -----------------------------------------------------------------------------------------------
    v_test_num    := 0;
    v_xmit_ext_id := '0';

    while v_test_num < C_NUM_ITERATIONS loop
      s_msg_reset <= '1';
      wait until rising_edge(s_clk);
      s_msg_reset <= '0';
      wait until rising_edge(s_clk);



      generate_random_can_message (v_xmit_arb_id,
                                   v_xmit_data,
                                   v_xmit_data_length,
                                   v_xmit_remote_frame,
                                   v_xmit_ext_id);

      s_xmit_arb_id       <= v_xmit_arb_id;
      s_xmit_data         <= v_xmit_data;
      s_xmit_data_length  <= v_xmit_data_length;
      s_xmit_remote_frame <= v_xmit_remote_frame;

      wait until rising_edge(s_clk);

      can_uvvm_write(v_xmit_arb_id,
                     v_xmit_ext_id,
                     v_xmit_remote_frame,
                     v_xmit_data,
                     v_xmit_data_length,
                     "Send random message with CAN BFM",
                     s_clk,
                     s_can_bfm_tx,
                     s_can_bfm_rx);

      wait until s_msg_received = '1' for 10*C_CAN_BAUD_PERIOD;

      check_value(s_msg_received, '1', error, "Check that CAN controller received msg.");
      check_value(s_msg.ext_id, v_xmit_ext_id, error, "Check extended ID bit");

      -- Todo: Replace with variable and test both basic and extended ID
      if v_xmit_ext_id = '1' then
        check_value(s_msg.arb_id, v_xmit_arb_id, error, "Check received ID");
      else
        -- Only check the relevant ID bits for non-extended ID
        check_value(s_msg.arb_id(C_ID_A_LENGTH-1 downto 0),
                    v_xmit_arb_id(C_ID_A_LENGTH-1 downto 0),
                    error,
                    "Check received ID");
      end if;

      check_value(s_msg.remote_request, v_xmit_remote_frame, error, "Check received RTR bit");

      check_value(s_msg.data_length,
                  std_logic_vector(to_unsigned(v_xmit_data_length, C_DLC_LENGTH)),
                  error, "Check data length");

      -- Don't check data for remote frame requests
      if v_xmit_remote_frame = '0' then
        for idx in 0 to v_xmit_data_length-1 loop
          check_value(s_msg.data(idx), v_xmit_data(idx), error, "Check received data");
        end loop;
      end if;

      wait until rising_edge(s_can_baud_clk);
      wait until rising_edge(s_can_baud_clk);

      v_test_num := v_test_num + 1;
    end loop;

    check_value(to_integer(unsigned(s_can_ctrl_reg_rx_msg_recv_count)), C_NUM_ITERATIONS,
                error, "Check number of received messages in CAN controller.");


    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test #2: Basic ID msg from Canola CAN controller to BFM", C_SCOPE);
    -----------------------------------------------------------------------------------------------
    v_test_num    := 0;
    v_xmit_ext_id := '0';

    while v_test_num < C_NUM_ITERATIONS loop
      generate_random_can_message (v_xmit_arb_id,
                                   v_xmit_data,
                                   v_xmit_data_length,
                                   v_xmit_remote_frame,
                                   v_xmit_ext_id);

      s_can_ctrl_tx_msg.arb_id         <= v_xmit_arb_id;
      s_can_ctrl_tx_msg.ext_id         <= v_xmit_ext_id;
      s_can_ctrl_tx_msg.data_length    <= std_logic_vector(to_unsigned(v_xmit_data_length, C_DLC_LENGTH));
      s_can_ctrl_tx_msg.remote_request <= v_xmit_remote_frame;

      for i in 0 to 7 loop
        s_can_ctrl_tx_msg.data(i)      <= v_xmit_data(i);
      end loop;

      wait until falling_edge(s_clk);
      s_can_ctrl_tx_start <= '1';
      wait until falling_edge(s_clk);
      s_can_ctrl_tx_start <= transport '0' after C_CLK_PERIOD;

      can_uvvm_check(v_xmit_arb_id,
                     v_xmit_ext_id,
                     v_xmit_remote_frame,
                     '0', -- Don't send remote request and expect response
                     v_xmit_data,
                     v_xmit_data_length,
                     "Receive and check message with CAN BFM",
                     s_clk,
                     s_can_bfm_tx,
                     s_can_bfm_rx,
                     error);

      wait until rising_edge(s_can_baud_clk);
      wait until rising_edge(s_can_baud_clk);

      v_test_num := v_test_num + 1;
    end loop;

    check_value(to_integer(unsigned(s_can_ctrl_reg_tx_msg_sent_count)), C_NUM_ITERATIONS,
                error, "Check number of transmitted messages from CAN controller.");
    check_value(to_integer(unsigned(s_can_ctrl_reg_tx_ack_recv_count)), C_NUM_ITERATIONS,
                error, "Check number of acknowledged messages in CAN controller.");

    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test #3: Extended ID msg from BFM to Canola CAN controller", C_SCOPE);
    -----------------------------------------------------------------------------------------------
    v_test_num    := 0;
    v_xmit_ext_id := '1';

    while v_test_num < C_NUM_ITERATIONS loop
      s_msg_reset <= '1';
      wait until rising_edge(s_clk);
      s_msg_reset <= '0';
      wait until rising_edge(s_clk);

      generate_random_can_message (v_xmit_arb_id,
                                   v_xmit_data,
                                   v_xmit_data_length,
                                   v_xmit_remote_frame,
                                   v_xmit_ext_id);

      s_xmit_arb_id       <= v_xmit_arb_id;
      s_xmit_data         <= v_xmit_data;
      s_xmit_data_length  <= v_xmit_data_length;
      s_xmit_remote_frame <= v_xmit_remote_frame;

      wait until rising_edge(s_clk);

      can_uvvm_write(v_xmit_arb_id,
                     v_xmit_ext_id,
                     v_xmit_remote_frame,
                     v_xmit_data,
                     v_xmit_data_length,
                     "Send random message with CAN BFM",
                     s_clk,
                     s_can_bfm_tx,
                     s_can_bfm_rx);

      wait until s_msg_received = '1' for 10*C_CAN_BAUD_PERIOD;

      check_value(s_msg_received, '1', error, "Check that CAN controller received msg.");
      check_value(s_msg.ext_id, v_xmit_ext_id, error, "Check extended ID bit");

      -- Todo: Replace with variable and test both basic and extended ID
      if v_xmit_ext_id = '1' then
        check_value(s_msg.arb_id, v_xmit_arb_id, error, "Check received ID");
      else
        -- Only check the relevant ID bits for non-extended ID
        check_value(s_msg.arb_id(C_ID_A_LENGTH-1 downto 0),
                    v_xmit_arb_id(C_ID_A_LENGTH-1 downto 0),
                    error,
                    "Check received ID");
      end if;

      check_value(s_msg.remote_request, v_xmit_remote_frame, error, "Check received RTR bit");

      check_value(s_msg.data_length,
                  std_logic_vector(to_unsigned(v_xmit_data_length, C_DLC_LENGTH)),
                  error, "Check data length");

      -- Don't check data for remote frame requests
      if v_xmit_remote_frame = '0' then
        for idx in 0 to v_xmit_data_length-1 loop
          check_value(s_msg.data(idx), v_xmit_data(idx), error, "Check received data");
        end loop;
      end if;

      wait until rising_edge(s_can_baud_clk);
      wait until rising_edge(s_can_baud_clk);

      v_test_num := v_test_num + 1;
    end loop;

    check_value(to_integer(unsigned(s_can_ctrl_reg_rx_msg_recv_count)), C_NUM_ITERATIONS*2,
                error, "Check number of received messages in CAN controller.");

    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Test #4: Extended ID msg from Canola CAN controller to BFM", C_SCOPE);
    -----------------------------------------------------------------------------------------------
    v_test_num    := 0;
    v_xmit_ext_id := '1';

    while v_test_num < C_NUM_ITERATIONS loop
      generate_random_can_message (v_xmit_arb_id,
                                   v_xmit_data,
                                   v_xmit_data_length,
                                   v_xmit_remote_frame,
                                   v_xmit_ext_id);

      s_can_ctrl_tx_msg.arb_id         <= v_xmit_arb_id;
      s_can_ctrl_tx_msg.ext_id         <= v_xmit_ext_id;
      s_can_ctrl_tx_msg.data_length    <= std_logic_vector(to_unsigned(v_xmit_data_length, C_DLC_LENGTH));
      s_can_ctrl_tx_msg.remote_request <= v_xmit_remote_frame;

      for i in 0 to 7 loop
        s_can_ctrl_tx_msg.data(i)      <= v_xmit_data(i);
      end loop;

      wait until falling_edge(s_clk);
      s_can_ctrl_tx_start <= '1';
      wait until falling_edge(s_clk);
      s_can_ctrl_tx_start <= transport '0' after C_CLK_PERIOD;

      can_uvvm_check(v_xmit_arb_id,
                     v_xmit_ext_id,
                     v_xmit_remote_frame,
                     '0', -- Don't send remote request and expect response
                     v_xmit_data,
                     v_xmit_data_length,
                     "Receive and check message with CAN BFM",
                     s_clk,
                     s_can_bfm_tx,
                     s_can_bfm_rx,
                     error);

      wait until rising_edge(s_can_baud_clk);
      wait until rising_edge(s_can_baud_clk);

      v_test_num := v_test_num + 1;
    end loop;

    check_value(to_integer(unsigned(s_can_ctrl_reg_tx_msg_sent_count)), C_NUM_ITERATIONS*2,
                error, "Check number of transmitted messages from CAN controller.");
    check_value(to_integer(unsigned(s_can_ctrl_reg_tx_ack_recv_count)), C_NUM_ITERATIONS*2,
                error, "Check number of acknowledged messages in CAN controller.");


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
