-------------------------------------------------------------------------------
-- Title      : Triplicated majority voter array
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : majority_voter_triplicated_array.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-01-24
-- Last update: 2020-01-24
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Majority voter with 3x input arrays, and 3x voted outputs
--              arrays for Triple Modular Redundancy (TMR).
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


entity majority_voter_triplicated_array is
  generic (
    G_MISMATCH_OUTPUT_EN  : boolean := false;
    G_MISMATCH_OUTPUT_REG : boolean := false);
  port (
    CLK         : in  std_logic;
    INPUT_A     : in  std_logic_vector;
    INPUT_B     : in  std_logic_vector;
    INPUT_C     : in  std_logic_vector;
    VOTER_OUT_A : out std_logic_vector;
    VOTER_OUT_B : out std_logic_vector;
    VOTER_OUT_C : out std_logic_vector;
    MISMATCH    : out std_logic
    );

  attribute DONT_TOUCH             : string;
  attribute DONT_TOUCH of INPUT_A  : signal is "TRUE";
  attribute DONT_TOUCH of INPUT_B  : signal is "TRUE";
  attribute DONT_TOUCH of INPUT_C  : signal is "TRUE";
  attribute DONT_TOUCH of OUTPUT_A : signal is "TRUE";
  attribute DONT_TOUCH of OUTPUT_B : signal is "TRUE";
  attribute DONT_TOUCH of OUTPUT_C : signal is "TRUE";
end entity majority_voter_triplicated_array;


architecture rtl of majority_voter_triplicated_array is
  signal s_mismatch : std_logic_vector(INPUT_A'range);
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
    INST_majority_voter_triplicated: entity work.majority_voter_triplicated
      generic map (
        G_MISMATCH_OUTPUT_EN  => G_MISMATCH_OUTPUT_EN,
        G_MISMATCH_OUTPUT_REG => false) -- It will be registered below
      port map (
        CLK         => CLK,
        INPUT_A     => INPUT_A(i),
        INPUT_B     => INPUT_B(i),
        INPUT_C     => INPUT_C(i),
        VOTER_OUT_A => VOTER_OUT(i),
        VOTER_OUT_B => VOTER_OUT(i),
        VOTER_OUT_C => VOTER_OUT(i),
        MISMATCH    => s_mismatch(i));
  end generate GEN_tmr_voters;


  GEN_no_mismatch: if not G_MISMATCH_OUTPUT_EN generate
    MISMATCH <= '0';
  end generate GEN_no_mismatch;

  GEN_unreg_mismatch: if G_MISMATCH_OUTPUT_EN and not G_MISMATCH_OUTPUT_REG generate
    -- Mismatch output - not registered
    MISMATCH <= or_reduce(s_mismatch);
  end generate GEN_unreg_mismatch;

  GEN_reg_mismatch: if G_MISMATCH_OUTPUT_EN and G_MISMATCH_OUTPUT_REG generate
    -- Mismatch output - registered
    proc_reg_mismatch: process (CLK) is
    begin
      if rising_edge(clk) then
        MISMATCH <= or_reduce(s_mismatch);
      end if;
    end process proc_reg_mismatch;
  end generate GEN_reg_mismatch;

end architecture rtl;
