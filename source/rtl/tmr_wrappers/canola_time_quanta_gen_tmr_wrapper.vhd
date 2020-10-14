-------------------------------------------------------------------------------
-- Title      : Time quanta generator for CAN bus - TMR Wrapper
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_time_quanta_gen_tmr_wrapper.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-08-26
-- Last update: 2020-10-14
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Wrapper for Triple Modular Redundancy (TMR) for the
--              Time Quanta Generator (TQG) for the Canola CAN controller.
--              The wrapper creates three instances of the TQG entity,
--              and votes current counter value and outputs.
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-08-26  1.0      svn     Created
-- 2020-10-09  1.1      svn     Modified to use updated voters
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;
use ieee.numeric_std.all;

library work;
use work.canola_pkg.all;
use work.tmr_pkg.all;
use work.tmr_voter_pkg.all;

entity canola_time_quanta_gen_tmr_wrapper is
  generic (
    G_SEE_MITIGATION_EN       : integer := 1;  -- Enable TMR
    G_MISMATCH_OUTPUT_EN      : integer;
    G_MISMATCH_OUTPUT_2ND_EN  : integer;
    G_MISMATCH_OUTPUT_REG     : integer;
    G_TIME_QUANTA_SCALE_WIDTH : natural := C_TIME_QUANTA_SCALE_WIDTH_DEFAULT
    );
  port (
    CLK               : in  std_logic;
    RESET             : in  std_logic;
    RESTART           : in  std_logic;
    CLK_SCALE         : in  unsigned(G_TIME_QUANTA_SCALE_WIDTH-1 downto 0);
    TIME_QUANTA_PULSE : out std_logic;

    -- Indicates mismatch in any of the TMR voters
    MISMATCH     : out std_logic;
    MISMATCH_2ND : out std_logic
    );
end entity canola_time_quanta_gen_tmr_wrapper;

architecture structural of canola_time_quanta_gen_tmr_wrapper is

begin  -- architecture structural

  -- -----------------------------------------------------------------------
  -- Generate single instance of TQG when TMR is disabled
  -- -----------------------------------------------------------------------
  if_NOMITIGATION_generate : if G_SEE_MITIGATION_EN = 0 generate
    signal s_count_no_tmr : std_logic_vector(G_TIME_QUANTA_SCALE_WIDTH-1 downto 0);
  begin

    MISMATCH     <= '0';
    MISMATCH_2ND <= '0';

    -- Create instance of TQG which connects directly to the wrapper's outputs
    -- The counter value output from the TQG is routed directly back to its
    -- counter value input without voting.
    INST_canola_time_quanta_gen : entity work.canola_time_quanta_gen
      generic map (
        G_TIME_QUANTA_SCALE_WIDTH => G_TIME_QUANTA_SCALE_WIDTH)
      port map (
        CLK               => CLK,
        RESET             => RESET,
        RESTART           => RESTART,
        CLK_SCALE         => CLK_SCALE,
        TIME_QUANTA_PULSE => TIME_QUANTA_PULSE,
        COUNT_OUT         => s_count_no_tmr,
        COUNT_IN          => s_count_no_tmr);
  end generate if_NOMITIGATION_generate;


  -- -----------------------------------------------------------------------
  -- Generate three instances of TQG when TMR is enabled
  -- -----------------------------------------------------------------------
  if_TMR_generate : if G_SEE_MITIGATION_EN = 1 generate
    type t_count_tmr is array (0 to C_K_TMR-1) of std_logic_vector(G_TIME_QUANTA_SCALE_WIDTH-1 downto 0);
    signal s_count_out, s_count_voted : t_count_tmr;
    signal s_time_quanta_pulse_tmr    : std_logic_vector(0 to C_K_TMR-1);

    attribute DONT_TOUCH                            : string;
    attribute DONT_TOUCH of s_count_out             : signal is "TRUE";
    attribute DONT_TOUCH of s_count_voted           : signal is "TRUE";
    attribute DONT_TOUCH of s_time_quanta_pulse_tmr : signal is "TRUE";

    constant C_mismatch_count             : integer := 0;
    constant C_mismatch_time_quanta_pulse : integer := 1;
    constant C_MISMATCH_WIDTH             : integer := 2;

    signal s_mismatch_array     : std_ulogic_vector(C_MISMATCH_WIDTH-1 downto 0);
    signal s_mismatch_2nd_array : std_ulogic_vector(C_MISMATCH_WIDTH-1 downto 0);

  begin

    for_TMR_generate : for i in 0 to C_K_TMR-1 generate
      INST_canola_time_quanta_gen : entity work.canola_time_quanta_gen
        generic map (
          G_TIME_QUANTA_SCALE_WIDTH => G_TIME_QUANTA_SCALE_WIDTH)
        port map (
          CLK               => CLK,
          RESET             => RESET,
          RESTART           => RESTART,
          CLK_SCALE         => CLK_SCALE,
          TIME_QUANTA_PULSE => s_time_quanta_pulse_tmr(i),
          COUNT_OUT         => s_count_out(i),
          COUNT_IN          => s_count_voted(i));
    end generate for_TMR_generate;

    -- -----------------------------------------------------------------------
    -- TMR voters
    -- -----------------------------------------------------------------------
    INST_count_voter : tmr_voter_triplicated_array
      generic map (
        G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
        G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
        G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG,
        G_WIDTH                  => G_TIME_QUANTA_SCALE_WIDTH)
      port map (
        CLK          => CLK,
        RST          => RESET,
        INPUT_A      => s_count_out(0),
        INPUT_B      => s_count_out(1),
        INPUT_C      => s_count_out(2),
        VOTER_OUT_A  => s_count_voted(0),
        VOTER_OUT_B  => s_count_voted(1),
        VOTER_OUT_C  => s_count_voted(2),
        MISMATCH     => s_mismatch_array(C_mismatch_count),
        MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_count));

    INST_time_quanta_pulse_voter : tmr_voter
      generic map (
        G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
        G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG,
        G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN)
      port map (
        CLK          => CLK,
        RST          => RESET,
        INPUT        => s_time_quanta_pulse_tmr,
        VOTER_OUT    => TIME_QUANTA_PULSE,
        MISMATCH     => s_mismatch_array(C_mismatch_time_quanta_pulse),
        MISMATCH_2ND => s_mismatch_2nd_array(C_mismatch_time_quanta_pulse));

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

  end generate if_TMR_generate;

end architecture structural;
