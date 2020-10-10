-------------------------------------------------------------------------------
-- Title      : Triplicated majority voter for TMR
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : tmr_voter_triplicated.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-01-24
-- Last update: 2020-10-10
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Majority voter with 3x single inputs, and 3x voted outputs for
--              Triple Modular Redundancy (TMR).
--              Inspired by code for majority voters written in SystemVerilog
--              for the ALICE ITS upgrade by Matteo Lupi
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-24  1.0      svn     Created
-- 2020-02-13  1.1      svn     Renamed tmr_voter_triplicated
-- 2020-10-09  1.2      svn     Update to have similar interface to voters in
--                              ALICE ITS Upgrade Readout Unit firmware
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;


entity tmr_voter_triplicated is
  generic (
    G_MISMATCH_OUTPUT_EN     : integer := 0;  -- Enable MISMATCH output
    G_MISMATCH_OUTPUT_2ND_EN : integer := 0;  -- Enable MISMATCH_2ND output
    G_MISMATCH_OUTPUT_REG    : integer := 0   -- Register on MISMATCH outputs
    );
  port (
    CLK          : in  std_logic;
    INPUT_A      : in  std_logic;
    INPUT_B      : in  std_logic;
    INPUT_C      : in  std_logic;
    VOTER_OUT_A  : out std_logic;
    VOTER_OUT_B  : out std_logic;
    VOTER_OUT_C  : out std_logic;
    MISMATCH     : out std_logic;
    MISMATCH_2ND : out std_logic
    );

  attribute DONT_TOUCH                : string;
  attribute DONT_TOUCH of INPUT_A     : signal is "TRUE";
  attribute DONT_TOUCH of INPUT_B     : signal is "TRUE";
  attribute DONT_TOUCH of INPUT_C     : signal is "TRUE";
  attribute DONT_TOUCH of VOTER_OUT_A : signal is "TRUE";
  attribute DONT_TOUCH of VOTER_OUT_B : signal is "TRUE";
  attribute DONT_TOUCH of VOTER_OUT_C : signal is "TRUE";
end entity tmr_voter_triplicated;


architecture rtl of tmr_voter_triplicated is
  signal s_mismatch     : std_logic_vector(2 downto 0);
  signal s_mismatch_2nd : std_logic_vector(2 downto 0);
begin  -- architecture rtl

  INST_tmr_voter_A : entity work.tmr_voter
    generic map (
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => 0)  -- It will be registered below
    port map (
      CLK          => CLK,
      INPUT_A      => INPUT_A,
      INPUT_B      => INPUT_B,
      INPUT_C      => INPUT_C,
      VOTER_OUT    => VOTER_OUT_A,
      MISMATCH     => s_mismatch(0),
      MISMATCH_2ND => s_mismatch_2nd(0));

  INST_tmr_voter_B : entity work.tmr_voter
    generic map (
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => 0)  -- It will be registered below
    port map (
      CLK          => CLK,
      INPUT_A      => INPUT_A,
      INPUT_B      => INPUT_B,
      INPUT_C      => INPUT_C,
      VOTER_OUT    => VOTER_OUT_B,
      MISMATCH     => s_mismatch(1),
      MISMATCH_2ND => s_mismatch_2nd(1));

  INST_tmr_voter_C : entity work.tmr_voter
    generic map (
      G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
      G_MISMATCH_OUTPUT_REG    => 0)  -- It will be registered below
    port map (
      CLK          => CLK,
      INPUT_A      => INPUT_A,
      INPUT_B      => INPUT_B,
      INPUT_C      => INPUT_C,
      VOTER_OUT    => VOTER_OUT_C,
      MISMATCH     => s_mismatch(2),
      MISMATCH_2ND => s_mismatch_2nd(2));


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
