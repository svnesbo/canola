-------------------------------------------------------------------------------
-- Title      : Majority voter array for TMR
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : tmr_voter_array.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-01-24
-- Last update: 2020-10-10
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Majority voter with 3x input arrays, and a voted output array
--              for Triple Modular Redundancy (TMR)
--              Inspired by code for majority voters written in SystemVerilog
--              for the ALICE ITS upgrade by Matteo Lupi
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-24  1.0      svn     Created
-- 2020-02-13  1.1      svn     Renamed tmr_voter_array
-- 2020-10-09  1.2      svn     Update to have similar interface to voters in
--                              ALICE ITS Upgrade Readout Unit firmware
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;


entity tmr_voter_array is
  generic (
    G_MISMATCH_OUTPUT_EN     : integer := 0;  -- Enable MISMATCH output
    G_MISMATCH_OUTPUT_2ND_EN : integer := 0;  -- Enable MISMATCH_2ND output
    G_MISMATCH_OUTPUT_REG    : integer := 0   -- Register on MISMATCH outputs
    );
  port (
    CLK          : in  std_logic;
    INPUT_A      : in  std_logic_vector;
    INPUT_B      : in  std_logic_vector;
    INPUT_C      : in  std_logic_vector;
    VOTER_OUT    : out std_logic_vector;
    MISMATCH     : out std_logic;
    MISMATCH_2ND : out std_logic
    );
end entity tmr_voter_array;


architecture rtl of tmr_voter_array is
  signal s_mismatch     : std_logic_vector(INPUT_A'range);
  signal s_mismatch_2nd : std_logic_vector(INPUT_A'range);
begin  -- architecture rtl

  assert INPUT_A'length = INPUT_B'length
    report "Lengths of input vectors A and B do not match"
    severity failure;

  assert INPUT_A'length = INPUT_C'length
    report "Lengths of input vectors A and C do not match"
    severity failure;

  assert INPUT_A'length = VOTER_OUT'length
    report "Lengths of input vectors A and output vector VOTER_OUT do not match"
    severity failure;

  GEN_tmr_voters: for i in INPUT_A'range generate
    INST_tmr_voter: entity work.tmr_voter
      generic map (
        G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
        G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
        G_MISMATCH_OUTPUT_REG    => 0)  -- It will be registered below
      port map (
        CLK          => CLK,
        INPUT_A      => INPUT_A(i),
        INPUT_B      => INPUT_B(i),
        INPUT_C      => INPUT_C(i),
        VOTER_OUT    => VOTER_OUT(i),
        MISMATCH     => s_mismatch(i),
        MISMATCH_2ND => s_mismatch_2nd(i));
  end generate GEN_tmr_voters;


  GEN_no_mismatch: if G_MISMATCH_OUTPUT_EN = 0 generate
    MISMATCH <= '0';
  end generate GEN_no_mismatch;

  GEN_unreg_mismatch: if G_MISMATCH_OUTPUT_EN = 1 and G_MISMATCH_OUTPUT_REG = 0 generate
    -- Mismatch output - not registered
    MISMATCH <= or_reduce(s_mismatch);
  end generate GEN_unreg_mismatch;

  GEN_reg_mismatch: if G_MISMATCH_OUTPUT_EN = 1 and G_MISMATCH_OUTPUT_REG = 1 generate
    -- Mismatch output - registered
    proc_reg_mismatch: process (CLK) is
    begin
      if rising_edge(clk) then
        MISMATCH <= or_reduce(s_mismatch);
      end if;
    end process proc_reg_mismatch;
  end generate GEN_reg_mismatch;


  GEN_no_mismatch_2nd: if G_MISMATCH_OUTPUT_2ND_EN = 0 generate
    MISMATCH_2ND <= '0';
  end generate GEN_no_mismatch_2nd;

  GEN_unreg_mismatch_2nd: if G_MISMATCH_OUTPUT_2ND_EN = 1 and G_MISMATCH_OUTPUT_REG = 0 generate
    -- Additional mismatch output - not registered
    MISMATCH_2ND <= or_reduce(s_mismatch_2nd);
  end generate GEN_unreg_mismatch_2nd;

  GEN_reg_mismatch_2nd: if G_MISMATCH_OUTPUT_2ND_EN = 1 and G_MISMATCH_OUTPUT_REG = 1 generate
    -- Additional mismatch output - registered
    proc_reg_mismatch_2nd: process (CLK) is
    begin
      if rising_edge(clk) then
        MISMATCH_2ND <= or_reduce(s_mismatch_2nd);
      end if;
    end process proc_reg_mismatch_2nd;
  end generate GEN_reg_mismatch_2nd;

end architecture rtl;
