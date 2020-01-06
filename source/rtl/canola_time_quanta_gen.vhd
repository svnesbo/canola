-------------------------------------------------------------------------------
-- Title      : Time quanta generator for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_time_quanta_gen.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-03
-- Last update: 2020-01-06
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Time quanta generator for the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-03  1.0      svn     Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

library work;
use work.canola_pkg.all;

-- Generates a pulse (1 CLK cycle long) on the TIME_QUANTA_PULSE output every
-- COUNT_VAL+1 clock cycles.
-- Note: A pulse is outputted immediately following reset.
entity canola_time_quanta_gen is
  port (
    CLK               : in  std_logic;
    RESET             : in  std_logic;
    RESTART           : in  std_logic;
    COUNT_VAL         : in  unsigned(C_TIME_QUANTA_WIDTH-1 downto 0);
    TIME_QUANTA_PULSE : out std_logic
    );
end entity canola_time_quanta_gen;

architecture rtl of canola_time_quanta_gen is
  signal s_counter : unsigned(C_TIME_QUANTA_WIDTH-1 downto 0);
begin  -- architecture rtl

  proc_time_quanta_gen : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      TIME_QUANTA_PULSE <= '0';

      -- Synchronous reset
      if RESET = '1' or RESTART = '1' then
        TIME_QUANTA_PULSE <= '0';
        s_counter         <= (others => '0');
      else
        if s_counter = COUNT_VAL then
          TIME_QUANTA_PULSE <= '1';
          s_counter         <= (others => '0');
        else
          s_counter <= s_counter + 1;
        end if;
      end if;
    end if;
  end process proc_time_quanta_gen;

end architecture rtl;
