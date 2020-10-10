-------------------------------------------------------------------------------
-- Title      : General mismatch module
-- Project    : ITSWP10
-------------------------------------------------------------------------------
-- File       : mismatch.vhd
-- Author     : Arild Velure  <arild.velure@cern.ch>
-- Company    : CERN
-- Created    : 2020-03-19
-- Last update: 2020-04-21
-- Platform   : Xilinx Vivado 2018.3
-- Standard   : VHDL 2008
-------------------------------------------------------------------------------
-- Description: General module for generating mismatch signals
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity mismatch is
  generic(
    G_SEE_MITIGATION_TECHNIQUE : integer  := 1;
    G_MISMATCH_EN              : integer  := 1;
    G_MISMATCH_REGISTERED      : integer  := 0;
    G_ADDITIONAL_MISMATCH      : integer  := 1);
  port(
    CLK                  : in std_logic;
    RST                  : in std_logic;
    mismatch_array_i     : in std_ulogic_vector;
    mismatch_2nd_array_i : in std_ulogic_vector;
    MISMATCH_O           : out std_logic;
    MISMATCH_2ND_O       : out std_logic);
end entity mismatch;

architecture RTL of mismatch is
begin

  if_NOMITIGATION_generate : if G_SEE_MITIGATION_TECHNIQUE = 0 or G_MISMATCH_EN = 0 generate
    MISMATCH_O     <= '0';
    MISMATCH_2ND_O <= '0';
  end generate if_NOMITIGATION_generate;

  if_TMR_generate : if (G_SEE_MITIGATION_TECHNIQUE = 1 or  G_SEE_MITIGATION_TECHNIQUE = 3) and G_MISMATCH_EN = 1 generate
    signal mismatch_int     : std_logic;
    signal mismatch_2nd_int : std_logic;
  begin

    -- Generate Mismatch signals
    mismatch_int <= or_reduce(mismatch_array_i);
    mismatch_2nd_int <= or_reduce(mismatch_2nd_array_i) when G_ADDITIONAL_MISMATCH = 1
                        else '0';

    registered_mismatch : if G_MISMATCH_REGISTERED = 1 generate
      register_mismatch : process (CLK) is
      begin
        if rising_edge(CLK) then
          if RST = '1' then
            MISMATCH_O     <= '0';
          else
            MISMATCH_O     <= mismatch_int;
          end if;
        end if;
      end process register_mismatch;

      registered_2nd_mismatch : if G_ADDITIONAL_MISMATCH = 1 generate
        register_2nd_mismatch : process (CLK) is
        begin
          if rising_edge(CLK) then
            if RST = '1' then
              MISMATCH_2ND_O <= '0';
            else
              MISMATCH_2ND_O <= mismatch_2nd_int;
            end if;
          end if;
        end process register_2nd_mismatch;
      end generate registered_2nd_mismatch;

      no_registered_2nd_mismatch : if G_ADDITIONAL_MISMATCH = 0 generate
        MISMATCH_2ND_O <= '0';
      end generate no_registered_2nd_mismatch;
    end generate registered_mismatch;

    comb_mismatch : if G_MISMATCH_REGISTERED = 0 generate
      MISMATCH_O     <= mismatch_int;
      MISMATCH_2ND_O <= mismatch_2nd_int;
    end generate comb_mismatch;
  end generate if_TMR_generate;
end architecture RTL;
