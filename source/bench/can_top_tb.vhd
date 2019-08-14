-------------------------------------------------------------------------------
-- Title      : Top-level UVVM Testbench for Canola CAN Controller
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_top_tb.vhd
-- Author     : Simon Voigt Nesbo (svn@hvl.no)
-- Company    : Western Norway University of Applied Sciences
-- Created    : 2019-08-05
-- Last update: 2019-08-14
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

-- test bench entity
entity can_top_tb is
end can_top_tb;

architecture tb of can_top_tb is

  constant C_CLK_PERIOD : time       := 100 ns; -- 10 Mhz
  constant C_CLK_FREQ   : integer    := 1e9 ns / C_CLK_PERIOD;

  constant C_CAN_BAUD_PERIOD  : time    := 10000 ns;  -- 100 kHz
  constant C_CAN_BAUD_FREQ    : integer := 1e9 ns / C_CLK_PERIOD;

  -- Indicates where in a bit the Rx sample point should be
  -- Real value from 0.0 to 1.0.
  constant C_CAN_SAMPLE_POINT : real    := 0.7;

  constant C_TIME_QUANTA_CLOCK_SCALE_VAL : natural := 9;

  constant C_DATA_LENGTH_MAX : natural := 1000;
  constant C_NUM_ITERATIONS  : natural := 10;


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
  signal s_can_tx, s_can_rx : std_logic;

  signal s_can_rx_msg       : can_msg_t;
  signal s_can_tx_msg       : can_msg_t;
  signal s_can_rx_msg_valid : std_logic;
  signal s_can_tx_start     : std_logic;
  signal s_can_tx_busy      : std_logic;
  signal s_can_tx_done      : std_logic;
  signal s_can_tx_error     : std_logic;

  signal s_can_prop_seg        : std_logic_vector(C_PROP_SEG_WIDTH-1 downto 0)   := "0111";
  signal s_can_phase_seg1      : std_logic_vector(C_PHASE_SEG1_WIDTH-1 downto 0) := "0111";
  signal s_can_phase_seg2      : std_logic_vector(C_PHASE_SEG2_WIDTH-1 downto 0) := "0111";
  signal s_can_sync_jump_width : natural range 0 to C_SYNC_JUMP_WIDTH_MAX        := 2;

  signal can_bus_signal    : std_logic;

begin

  -- Set up clock generators
  clock_gen(s_clk, s_clock_ena, C_CLK_PERIOD);
  clock_gen(s_can_baud_clk, s_clock_ena, C_CAN_BAUD_PERIOD);

  can_bus_signal <= 'H';
  can_bus_signal <= '0' when s_can_tx = '0' else 'Z';
  s_can_rx       <= '1' ?= can_bus_signal;



  INST_can_top : entity work.can_top
    generic map (
      G_BUS_REG_WIDTH => 16,
      G_ENABLE_EXT_ID => true)
    port map (
      CLK                         => s_clk,
      RESET                       => s_reset,
      CAN_TX                      => s_can_tx,
      CAN_RX                      => s_can_rx,
      RX_MSG                      => s_can_rx_msg,
      RX_MSG_VALID                => s_can_rx_msg_valid,
      TX_MSG                      => s_can_tx_msg,
      TX_START                    => s_can_tx_start,
      TX_BUSY                     => s_can_tx_busy,
      TX_DONE                     => s_can_tx_done,
      TX_ERROR                    => s_can_tx_error,
      BTL_TRIPLE_SAMPLING         => '0',
      BTL_PROP_SEG                => s_can_prop_seg,
      BTL_PHASE_SEG1              => s_can_phase_seg1,
      BTL_PHASE_SEG2              => s_can_phase_seg2,
      BTL_SYNC_JUMP_WIDTH         => s_can_sync_jump_width,
      BTL_TIME_QUANTA_CLOCK_SCALE => to_unsigned(10, C_TIME_QUANTA_WIDTH)
      );


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
    log(ID_LOG_HDR, "Blabla", C_SCOPE);
    -----------------------------------------------------------------------------------------------
    --v_test_num := 0;

    --while v_test_num < C_NUM_ITERATIONS loop

    --  wait until rising_edge(s_can_baud_clk);
    --  wait until rising_edge(s_can_baud_clk);
    --end loop;

    -----------------------------------------------------------------------------------------------
    log(ID_LOG_HDR, "Blabla", C_SCOPE);
    -----------------------------------------------------------------------------------------------



    wait for 10000 ns;            -- to allow some time for completion
    report_alert_counters(FINAL); -- Report final counters and print conclusion for simulation (Success/Fail)
    log(ID_LOG_HDR, "SIMULATION COMPLETED", C_SCOPE);

    -- Finish the simulation
    std.env.stop;
    wait;  -- to stop completely

  end process p_main;

end tb;