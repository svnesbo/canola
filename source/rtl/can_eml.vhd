-------------------------------------------------------------------------------
-- Title      : Error Management Logic (EML) for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_eml.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-10
-- Last update: 2019-09-19
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Error Management Logic (EML) for the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-10  1.0      svn     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.can_pkg.all;

entity can_eml is
  port (
    CLK   : in std_logic;
    RESET : in std_logic;

    -- Error and success inputs should all be pulsed
    RX_STUFF_ERROR                   : in std_logic;
    RX_CRC_ERROR                     : in std_logic;
    RX_FORM_ERROR                    : in std_logic;
    RX_ACTIVE_ERROR_FLAG_BIT_ERROR   : in std_logic;
    RX_OVERLOAD_FLAG_BIT_ERROR       : in std_logic;
    RX_DOMINANT_BIT_AFTER_ERROR_FLAG : in std_logic;
    TX_BIT_ERROR                     : in std_logic;
    TX_ACK_ERROR                     : in std_logic;
    TX_ACK_PASSIVE_ERROR             : in std_logic;
    TX_ACTIVE_ERROR_FLAG_BIT_ERROR   : in std_logic;
    TRANSMIT_SUCCESS                 : in std_logic;
    RECEIVE_SUCCESS                  : in std_logic;
    RECV_11_RECESSIVE_BITS           : in std_logic;  -- Received/detected a sequence of
                                                      -- 11 recessive bits.

    ERROR_STATE          : out can_error_state_t;
    TRANSMIT_ERROR_COUNT : out unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
    RECEIVE_ERROR_COUNT  : out unsigned(C_ERROR_COUNT_LENGTH-1 downto 0)
    );

end entity can_eml;

architecture rtl of can_eml is
  signal s_transmit_error_count            : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
  signal s_receive_error_count             : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
  signal s_receive_11_recessive_bits_count : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);

begin  -- architecture rtl

  TRANSMIT_ERROR_COUNT <= s_transmit_error_count;
  RECEIVE_ERROR_COUNT  <= s_receive_error_count;

  proc_error_counters : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      -- Synchronous reset
      if RESET = '1' then
        s_transmit_error_count            <= (others => '0');
        s_receive_error_count             <= (others => '0');
        s_receive_11_recessive_bits_count <= (others => '0');
      else
        if TRANSMIT_SUCCESS = '1' then
          if s_transmit_error_count >= C_ERROR_PASSIVE_THRESHOLD then
            s_transmit_error_count <= to_unsigned(119, C_ERROR_COUNT_LENGTH); -- Todo: add constant
          elsif s_transmit_error_count > 0 then
            s_transmit_error_count <= s_transmit_error_count - 1;
          end if;
        end if;

        --if XMIT_FAIL = '1' then
        --  if s_transmit_error_count < (2**C_ERROR_COUNT_LENGTH)-1 then
        --    s_transmit_error_count <= s_transmit_error_count + 1;
        --  end if;
        --end if;

        if RECEIVE_SUCCESS = '1' then
          if s_receive_error_count >= C_ERROR_PASSIVE_THRESHOLD then
            s_receive_error_count <= to_unsigned(119, C_ERROR_COUNT_LENGTH); -- Todo: add constant
          elsif s_receive_error_count > 0 then
            s_receive_error_count <= s_receive_error_count - 1;
          end if;
        end if;

        --if RECV_FAIL = '1' then
        --  if s_receive_error_count < (2**C_ERROR_COUNT_LENGTH)-1 then
        --    s_receive_error_count <= s_receive_error_count + 1;
        --  end if;
        --end if;

        if RECV_11_RECESSIVE_BITS = '1' then
          if s_receive_11_recessive_bits_count < (2**C_ERROR_COUNT_LENGTH)-1 then
            s_receive_11_recessive_bits_count <= s_receive_11_recessive_bits_count + 1;
          end if;
        end if;
      end if;

      -- TODO:
      -- 12. An node which is ’bus off’ is permitted to become ’error active’ (no longer ’bus off’)
      -- with its error counters both set to 0 after 128 occurrence of 11 consecutive
      --  ’recessive’ bits have been monitored on the bus.
      if s_transmit_error_count >= C_BUS_OFF_THRESHOLD then
        ERROR_STATE <= BUS_OFF;
      elsif ERROR_STATE /= BUS_OFF then
        if s_transmit_error_count > C_ERROR_PASSIVE_THRESHOLD then
          ERROR_STATE <= ERROR_PASSIVE;
        else
          ERROR_STATE <= ERROR_ACTIVE;
        end if;
      end if;


      -- TODO:
      -- An error count value greater than about 96 indicates a heavily disturbed bus. It may be
      -- of advantage to provide means to test for this condition.
    end if;
  end process proc_error_counters;


  proc_error_status : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      -- Synchronous reset
      if RESET = '1' then

      else
      end if;
    end if;
  end process proc_error_status;

end architecture rtl;
