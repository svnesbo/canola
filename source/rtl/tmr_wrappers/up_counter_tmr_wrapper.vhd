-------------------------------------------------------------------------------
-- Title      : Up counter tmr wrapper
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : up_counter_tmr_wrapper.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-01-30
-- Last update: 2020-10-10
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: TMR wrapper for up_counter.
--              Creates three instances of the up_counter,
--              and has one voted output of the counter value.
--              Heavily based on upcounter_tmr_wrapper written for the
--              ALICE ITS upgrade by Matteo Lupi.
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-30  1.0      svn     Created
-- 2020-10-09  1.1      svn     Modified to use updated voters
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.tmr_pkg.all;
use work.tmr_voter_pkg.all;

entity up_counter_tmr_wrapper is
  generic (
    BIT_WIDTH                : integer := 16;
    IS_SATURATING            : boolean := false;
    VERBOSE                  : boolean := false;
    G_SEE_MITIGATION_EN      : integer := 1;  -- Enable TMR
    G_MISMATCH_OUTPUT_EN     : integer;
    G_MISMATCH_OUTPUT_2ND_EN : integer;
    G_MISMATCH_OUTPUT_REG    : integer);
  port (
    CLK          : in  std_logic;
    RESET        : in  std_logic;
    CLEAR        : in  std_logic;
    COUNT_UP     : in  std_logic;
    COUNT_OUT    : out std_logic_vector(BIT_WIDTH-1 downto 0);
    MISMATCH     : out std_logic;
    MISMATCH_2ND : out std_logic);
  attribute DONT_TOUCH                                : string;
  attribute DONT_TOUCH of up_counter_tmr_wrapper : entity is "true";
end entity up_counter_tmr_wrapper;

-------------------------------------------------------------------------------
-- Architecture
-------------------------------------------------------------------------------
architecture structural of up_counter_tmr_wrapper is
begin

  if_NOMITIGATION_generate : if G_SEE_MITIGATION_EN = 0 generate
    signal s_counter_nonvoted : std_logic_vector(BIT_WIDTH-1 downto 0);
  begin

    INST_up_counter : entity work.up_counter
      generic map (
        BIT_WIDTH     => BIT_WIDTH,
        IS_SATURATING => IS_SATURATING,
        VERBOSE       => VERBOSE)
      port map (
        CLK            => CLK,
        RESET          => RESET,
        CLEAR          => CLEAR,
        COUNT_UP       => COUNT_UP,
        COUNT_OUT      => s_counter_nonvoted,
        COUNT_VOTED_IN => s_counter_nonvoted);

    COUNT_OUT    <= s_counter_nonvoted;
    MISMATCH     <= '0';
    MISMATCH_2ND <= '0';

  end generate if_NOMITIGATION_generate;


  if_TMR_generate : if G_SEE_MITIGATION_EN = 1 generate
    type t_count_value_tmr is array (0 to C_K_TMR-1) of std_logic_vector(BIT_WIDTH-1 downto 0);

    signal s_counter_out   : t_count_value_tmr;
    signal s_counter_voted : t_count_value_tmr;

    attribute DONT_TOUCH                    : string;
    attribute DONT_TOUCH of s_counter_out   : signal is "TRUE";
    attribute DONT_TOUCH of s_counter_voted : signal is "TRUE";
  begin

    for_TMR_generate : for i in 0 to C_K_TMR-1 generate
      INST_up_counter : entity work.up_counter
        generic map (
          BIT_WIDTH     => BIT_WIDTH,
          IS_SATURATING => IS_SATURATING,
          VERBOSE       => VERBOSE)
        port map (
          CLK            => CLK,
          RESET          => RESET,
          CLEAR          => CLEAR,
          COUNT_UP       => COUNT_UP,
          COUNT_OUT      => s_counter_out(i),
          COUNT_VOTED_IN => s_counter_voted(i));
    end generate for_TMR_generate;

    INST_upcount_voter : tmr_voter_triplicated_array
      generic map (
        G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
        G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
        G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG,
        G_WIDTH                  => BIT_WIDTH)
      port map (
        CLK          => CLK,
        RST          => RESET,
        INPUT_A      => s_counter_out(0),
        INPUT_B      => s_counter_out(1),
        INPUT_C      => s_counter_out(2),
        VOTER_OUT_A  => s_counter_voted(0),
        VOTER_OUT_B  => s_counter_voted(1),
        VOTER_OUT_C  => s_counter_voted(2),
        MISMATCH     => MISMATCH,
        MISMATCH_2ND => MISMATCH_2ND);

    COUNT_OUT <= s_counter_voted(0);

  end generate if_TMR_generate;

end architecture structural;
