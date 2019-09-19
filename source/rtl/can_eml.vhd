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
    -- Transmit and receive counter variables are 1 bit larger
    -- than corresponding signals to check for overflow
    -- Counter for sequences of 11 recessive bits should never overflow
    variable v_transmit_error_count            : unsigned(C_ERROR_COUNT_LENGTH downto 0);
    variable v_receive_error_count             : unsigned(C_ERROR_COUNT_LENGTH downto 0);
    variable v_receive_11_recessive_bits_count : unsigned(C_ERROR_COUNT_LENGTH-1 downto 0);
    variable v_exit_bus_off                    : std_logic;
  begin
    if rising_edge(CLK) then
      -- Synchronous reset
      if RESET = '1' then
        s_transmit_error_count            <= (others => '0');
        s_receive_error_count             <= (others => '0');
        s_receive_11_recessive_bits_count <= (others => '0');
      else
        v_receive_error_count                                := (others => '0');
        v_receive_error_count(s_receive_error_count'range)   := s_receive_error_count;
        v_transmit_error_count                               := (others => '0');
        v_transmit_error_count(s_transmit_error_count'range) := s_transmit_error_count;
        v_exit_bus_off                                       := '0';

        ------------------------------------------------------------------------
        -- Transmit error counter logic
        ------------------------------------------------------------------------
        if TX_BIT_ERROR = '1' then
          v_transmit_error_count(s_transmit_error_count'range) := s_transmit_error_count;
          v_transmit_error_count                               := v_transmit_error_count + 8;

        elsif TX_ACK_ERROR = '1' then
          v_transmit_error_count(s_transmit_error_count'range) := s_transmit_error_count;
          v_transmit_error_count                               := v_transmit_error_count + 8;

        elsif TX_ACK_PASSIVE_ERROR = '1' then
          v_transmit_error_count(s_transmit_error_count'range) := s_transmit_error_count;
          v_transmit_error_count                               := v_transmit_error_count + 8;
        -- Todo: Just rename TX_ERROR_FLAG_BIT_ERROR and let EML do checking if
          -- we are ERROR ACTIVE or ERROR PASSIVE

        elsif TX_ACTIVE_ERROR_FLAG_BIT_ERROR = '1' then
          v_transmit_error_count(s_transmit_error_count'range) := s_transmit_error_count;
          v_transmit_error_count                               := v_transmit_error_count + 8;

        elsif TRANSMIT_SUCCESS = '1' then
          if s_transmit_error_count > 0 then
            v_transmit_error_count(s_transmit_error_count'range) := s_transmit_error_count;
            v_transmit_error_count                               := v_transmit_error_count - 1;
          end if;
        end if;



        ------------------------------------------------------------------------
        -- Receive error counter logic
        ------------------------------------------------------------------------
        if RX_STUFF_ERROR = '1' then
          v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
          v_receive_error_count                              := v_receive_error_count + 1;

        elsif RX_CRC_ERROR = '1' then
          v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
          v_receive_error_count                              := v_receive_error_count + 1;

        elsif RX_FORM_ERROR = '1' then
          v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
          v_receive_error_count                              := v_receive_error_count + 1;

        elsif RX_ACTIVE_ERROR_FLAG_BIT_ERROR = '1' then
          v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
          v_receive_error_count                              := v_receive_error_count + 8;

        elsif RX_OVERLOAD_FLAG_BIT_ERROR = '1' then
          v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
          v_receive_error_count                              := v_receive_error_count + 8;

        elsif RX_DOMINANT_BIT_AFTER_ERROR_FLAG = '1' then
          v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
          v_receive_error_count                              := v_receive_error_count + 8;

        elsif RECEIVE_SUCCESS = '1' then
          if s_receive_error_count >= C_ERROR_PASSIVE_THRESHOLD then
            v_receive_error_count := to_unsigned(C_RECV_ERROR_COUNTER_SUCCES_JUMP_VALUE,
                                                 v_receive_error_count'length);
          elsif s_receive_error_count > 0 then
            v_receive_error_count(s_receive_error_count'range) := s_receive_error_count;
            v_receive_error_count                              := v_receive_error_count + 1;
          end if;
        end if;

        ------------------------------------------------------------------------
        -- 11 successive recessive bit counter logic
        ------------------------------------------------------------------------
        if ERROR_STATE = BUS_OFF then
          if RECV_11_RECESSIVE_BITS = '1' then
            v_receive_11_recessive_bits_count := s_receive_11_recessive_bits_count + 1;

            if v_receive_11_recessive_bits_count = C_11_RECESSIVE_EXIT_BUS_OFF_THRESHOLD then
              v_exit_bus_off := '1';
            end if;
          end if;
        else
          -- Don't start counts of 11 recessive bit sequences
          -- before we are in bus off
          v_receive_11_recessive_bits_count := (others => '0');
        end if;

        ------------------------------------------------------------------------
        -- Update counter registers
        ------------------------------------------------------------------------
        s_receive_11_recessive_bits_count <= v_receive_11_recessive_bits_count;

        if v_exit_bus_off = '1' then
          s_transmit_error_count            <= (others => '0');
          s_receive_error_count             <= (others => '0');
        else
          s_transmit_error_count            <= v_transmit_error_count(s_transmit_error_count'range);
          s_receive_error_count             <= v_receive_error_count(s_receive_error_count'range);
        end if;

      end if; -- reset
    end if; -- rising_edge(clk)
  end process proc_error_counters;

  ------------------------------------------------------------------------
  -- Update error state based on error counter values
  ------------------------------------------------------------------------
  proc_error_state : process(s_transmit_error_count, s_receive_error_count) is
  begin
    if s_transmit_error_count >= C_BUS_OFF_THRESHOLD then
      ERROR_STATE <= BUS_OFF;

    elsif s_transmit_error_count >= C_ERROR_PASSIVE_THRESHOLD then
      ERROR_STATE <= ERROR_PASSIVE;

    elsif s_receive_error_count >= C_ERROR_PASSIVE_THRESHOLD then
      ERROR_STATE <= ERROR_PASSIVE;

    else
      ERROR_STATE <= ERROR_ACTIVE;
    end if;
  end process proc_error_state;

end architecture rtl;
