-------------------------------------------------------------------------------
-- Title      : Majority voters for Triple Modular Redundancy (TMR)
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : tmr_voter_pkg.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-10-06
-- Last update: 2020-10-14
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Package for majority voters for Triple Modular Redundancy (TMR)
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-10-06  1.0      svn     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.tmr_pkg.all;


package tmr_voter_pkg is

  component tmr_voter is
    generic (
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK          : in  std_logic;
      RST          : in  std_logic;
      INPUT        : in  std_logic_vector(C_K_TMR-1 downto 0);
      VOTER_OUT    : out std_logic;
      MISMATCH     : out std_logic;
      MISMATCH_2ND : out std_logic);
  end component tmr_voter;

  component tmr_voter_array is
    generic (
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer;
      G_WIDTH                  : integer);
    port (
      CLK          : in  std_logic;
      RST          : in  std_logic;
      INPUT_A      : in  std_logic_vector;
      INPUT_B      : in  std_logic_vector;
      INPUT_C      : in  std_logic_vector;
      VOTER_OUT    : out std_logic_vector;
      MISMATCH     : out std_logic;
      MISMATCH_2ND : out std_logic);
  end component tmr_voter_array;

  component tmr_voter_triplicated is
    generic (
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK          : in  std_logic;
      RST          : in  std_logic;
      INPUT_A      : in  std_logic;
      INPUT_B      : in  std_logic;
      INPUT_C      : in  std_logic;
      VOTER_OUT_A  : out std_logic;
      VOTER_OUT_B  : out std_logic;
      VOTER_OUT_C  : out std_logic;
      MISMATCH     : out std_logic;
      MISMATCH_2ND : out std_logic);
  end component tmr_voter_triplicated;

  component tmr_voter_triplicated_array is
    generic (
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer;
      G_WIDTH                  : integer);
    port (
      CLK          : in  std_logic;
      RST          : in  std_logic;
      INPUT_A      : in  std_logic_vector;
      INPUT_B      : in  std_logic_vector;
      INPUT_C      : in  std_logic_vector;
      VOTER_OUT_A  : out std_logic_vector;
      VOTER_OUT_B  : out std_logic_vector;
      VOTER_OUT_C  : out std_logic_vector;
      MISMATCH     : out std_logic;
      MISMATCH_2ND : out std_logic);
  end component tmr_voter_triplicated_array;

end package tmr_voter_pkg;
