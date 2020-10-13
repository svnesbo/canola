-------------------------------------------------------------------------------
-- Title      : Majority voter for TMR
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : tmr_voter.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-01-24
-- Last update: 2020-10-14
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Majority voter with 3x single inputs, and a single voted
--              output for Triple Modular Redundancy (TMR).
--              Inspired by code for majority voters written in SystemVerilog
--              for the ALICE ITS upgrade by Matteo Lupi
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-01-24  1.0      svn     Created
-- 2020-02-13  1.1      svn     Renamed tmr_voter
-- 2020-10-09  1.2      svn     Update to have similar interface to voters in
--                              ALICE ITS Upgrade Readout Unit firmware
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

library work;
use work.tmr_pkg.all;


entity tmr_voter is
  generic (
    G_MISMATCH_OUTPUT_EN     : integer := 0;  -- Enable MISMATCH output
    G_MISMATCH_OUTPUT_2ND_EN : integer := 0;  -- Enable MISMATCH_2ND output
    G_MISMATCH_OUTPUT_REG    : integer := 0   -- Register on MISMATCH outputs
    );
  port (
    CLK          : in  std_logic;
    INPUT        : in  std_logic_vector(C_K_TMR-1 downto 0);
    VOTER_OUT    : out std_logic;
    MISMATCH     : out std_logic;
    MISMATCH_2ND : out std_logic
    );

  attribute DONT_TOUCH          : string;
  attribute DONT_TOUCH of INPUT : signal is "TRUE";
end entity tmr_voter;

architecture rtl of tmr_voter is

begin  -- architecture rtl

  -- Majority vote of the inputs
  proc_voter : process (INPUT) is
  begin
    if INPUT(0) = '1' and INPUT(1) = '1' then
      VOTER_OUT <= '1';
    elsif INPUT(0) = '1' and INPUT(2) = '1' then
      VOTER_OUT <= '1';
    elsif INPUT(1) = '1' and INPUT(2) = '1' then
      VOTER_OUT <= '1';
    else
      VOTER_OUT <= '0';
    end if;
  end process proc_voter;


  GEN_no_mismatch: if G_MISMATCH_OUTPUT_EN = 0 generate
    MISMATCH <= '0';
  end generate GEN_no_mismatch;


  GEN_unregistered_mismatch: if G_MISMATCH_OUTPUT_EN = 1 and G_MISMATCH_OUTPUT_REG = 0 generate
    -- Mismatch output - unregistered
    proc_unreg_mismatch: process (INPUT) is
    begin
      if INPUT(0) = '1' and INPUT(1) = '1' and INPUT(2) = '1' then
        MISMATCH <= '0';
      elsif INPUT(0) = '0' and INPUT(1) = '0' and INPUT(2) = '0' then
        MISMATCH <= '0';
      else
        MISMATCH <= '1';
      end if;
    end process proc_unreg_mismatch;
  end generate GEN_unregistered_mismatch;


  GEN_registered_mismatch: if G_MISMATCH_OUTPUT_EN = 1 and G_MISMATCH_OUTPUT_REG = 1 generate
    -- Mismatch output - registered
    proc_reg_mismatch: process (CLK) is
    begin
      if rising_edge(clk) then
        if INPUT(0) = '1' and INPUT(1) = '1' and INPUT(2) = '1' then
          MISMATCH <= '0';
        elsif INPUT(0) = '0' and INPUT(1) = '0' and INPUT(2) = '0' then
          MISMATCH <= '0';
        else
          MISMATCH <= '1';
        end if;
      end if;
    end process proc_reg_mismatch;
  end generate GEN_registered_mismatch;


  GEN_no_mismatch_2nd: if G_MISMATCH_OUTPUT_2ND_EN = 0 generate
    MISMATCH_2ND <= '0';
  end generate GEN_no_mismatch_2nd;


  GEN_unregistered_mismatch_2nd: if G_MISMATCH_OUTPUT_2ND_EN = 1 and G_MISMATCH_OUTPUT_REG = 0 generate
    -- Additional mismatch output - unregistered
    proc_unreg_mismatch_2nd: process (INPUT) is
    begin
      if INPUT(0) = '1' and INPUT(1) = '1' and INPUT(2) = '1' then
        MISMATCH_2ND <= '0';
      elsif INPUT(0) = '0' and INPUT(1) = '0' and INPUT(2) = '0' then
        MISMATCH_2ND <= '0';
      else
        MISMATCH_2ND <= '1';
      end if;
    end process proc_unreg_mismatch_2nd;
  end generate GEN_unregistered_mismatch_2nd;


  GEN_registered_mismatch_2nd: if G_MISMATCH_OUTPUT_2ND_EN = 1 and G_MISMATCH_OUTPUT_REG = 1 generate
    -- Additional mismatch output - registered
    proc_reg_mismatch_2nd: process (CLK) is
    begin
      if rising_edge(clk) then
        if INPUT(0) = '1' and INPUT(1) = '1' and INPUT(2) = '1' then
          MISMATCH_2ND <= '0';
        elsif INPUT(0) = '0' and INPUT(1) = '0' and INPUT(2) = '0' then
          MISMATCH_2ND <= '0';
        else
          MISMATCH_2ND <= '1';
        end if;
      end if;
    end process proc_reg_mismatch_2nd;
  end generate GEN_registered_mismatch_2nd;

end architecture rtl;
