-------------------------------------------------------------------------------
-- Title      : Triplicated majority voter
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : majority_voter_triplicated.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-01-24
-- Last update: 2020-01-24
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
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_misc.all;


entity majority_voter_triplicated is
  generic (
    G_MISMATCH_OUTPUT_EN  : boolean := false;
    G_MISMATCH_OUTPUT_REG : boolean := false);
  port (
    CLK         : in  std_logic;
    INPUT_A     : in  std_logic;
    INPUT_B     : in  std_logic;
    INPUT_C     : in  std_logic;
    VOTER_OUT_A : out std_logic;
    VOTER_OUT_B : out std_logic;
    VOTER_OUT_C : out std_logic;
    MISMATCH    : out std_logic
    );

  attribute DONT_TOUCH             : string;
  attribute DONT_TOUCH of INPUT_A  : signal is "TRUE";
  attribute DONT_TOUCH of INPUT_B  : signal is "TRUE";
  attribute DONT_TOUCH of INPUT_C  : signal is "TRUE";
  attribute DONT_TOUCH of OUTPUT_A : signal is "TRUE";
  attribute DONT_TOUCH of OUTPUT_B : signal is "TRUE";
  attribute DONT_TOUCH of OUTPUT_C : signal is "TRUE";
end entity majority_voter_triplicated;


architecture rtl of majority_voter_triplicated is
  signal s_mismatch : std_logic_vector(2 downto 0);
begin  -- architecture rtl

  -- Majority vote of the inputs
  proc_voter : process (INPUT_A, INPUT_B, INPUT_C) is
  begin
    if INPUT_A = '1' and INPUT_B = '1' then
      VOTER_OUT <= '1';
    elsif INPUT_A = '1' and INPUT_C = '1' then
      VOTER_OUT <= '1';
    elsif INPUT_B = '1' and INPUT_C = '1' then
      VOTER_OUT <= '1';
    else
      VOTER_OUT <= '0';
    end if;
  end process proc_voter;

  INST_majority_voter_A : entity work.majority_voter
    generic map (
      G_MISMATCH_OUTPUT_EN  => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_REG => false)   -- It will be registered below
    port map (
      CLK       => CLK,
      INPUT_A   => INPUT_A,
      INPUT_B   => INPUT_B,
      INPUT_C   => INPUT_C,
      VOTER_OUT => VOTER_OUT_A,
      MISMATCH  => s_mismatch(0));

  INST_majority_voter_B : entity work.majority_voter
    generic map (
      G_MISMATCH_OUTPUT_EN  => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_REG => false)   -- It will be registered below
    port map (
      CLK       => CLK,
      INPUT_A   => INPUT_A,
      INPUT_B   => INPUT_B,
      INPUT_C   => INPUT_C,
      VOTER_OUT => VOTER_OUT_B,
      MISMATCH  => s_mismatch(1));

  INST_majority_voter_C : entity work.majority_voter
    generic map (
      G_MISMATCH_OUTPUT_EN  => G_MISMATCH_OUTPUT_EN,
      G_MISMATCH_OUTPUT_REG => false)   -- It will be registered below
    port map (
      CLK       => CLK,
      INPUT_A   => INPUT_A,
      INPUT_B   => INPUT_B,
      INPUT_C   => INPUT_C,
      VOTER_OUT => VOTER_OUT_C,
      MISMATCH  => s_mismatch(2));


  GEN_no_mismatch: if not G_MISMATCH_OUTPUT_EN generate
    MISMATCH <= '0';
  end generate GEN_mismatch;

  GEN_unreg_mismatch: if G_MISMATCH_OUTPUT_EN and not G_MISMATCH_OUTPUT_REG generate
    -- Mismatch output - not registered
    MISMATCH <= or_reduce(s_mismatch);
  end generate GEN_mismatch;

  GEN_unreg_mismatch: if G_MISMATCH_OUTPUT_EN and G_MISMATCH_OUTPUT_REG generate
    -- Mismatch output - registered
    proc_reg_mismatch: process (CLK) is
    begin
      if rising_edge(clk) then
        MISMATCH <= or_reduce(s_mismatch);
      end if;
    end process proc_unreg_mismatch;
  end generate GEN_mismatch;

end architecture rtl;
