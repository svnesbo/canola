-------------------------------------------------------------------------------
-- Title      : Package for Canola CAN controller testbenches
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_tb_pkg.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-06-26
-- Last update: 2019-08-14
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Package with common functions etc. used in the testbenches for
--              the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-22  1.0      svn     Created
-------------------------------------------------------------------------------


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library work;
use work.can_pkg.all;

package can_tb_pkg is

  procedure generate_random_frame_size (
    variable rand_frame_size : out   natural;
    constant max_size        : in    natural;
    variable seed1           : inout positive;
    variable seed2           : inout positive);

  -- Fill a std_logic_vector with random data for testing BTL
  -- The desired length must be large enough to hold the EOF and SOF
  -- fields of a CAN frame, and the vector will begin with a SOF bit and end
  -- with the EOF bits. The bits in between will be random.
  procedure generate_random_data_for_btl (
    signal   data        : out   std_logic_vector;
    constant data_length : in    natural;
    variable seed1       : inout positive;
    variable seed2       : inout positive);

  -- Random sequence used when testing for ACK
  constant C_ACK_TEST_SEQUENCE              : std_logic_vector := "01100101111111";
  constant C_ACK_TEST_SEQUENCE_EXP          : std_logic_vector := "01100001111111";
  constant C_ACK_TEST_SEQUENCE_ACK_SLOT_IDX : natural          := 5;

end can_tb_pkg;


package body can_tb_pkg is

  procedure generate_random_frame_size (
    variable rand_frame_size : out   natural;
    constant max_size        : in    natural;
    variable seed1           : inout positive;
    variable seed2           : inout positive)
  is
    variable rand_real    : real;
  begin
    uniform(seed1, seed2, rand_real);

    rand_frame_size := integer(round(rand_real*real(max_size)));

    -- Make sure frame is at least large enough for SOF, EOF bits and a data bit
    if rand_frame_size < C_EOF_LENGTH+2 then
      rand_frame_size := rand_frame_size + C_EOF_LENGTH + 2;
    end if;

    if rand_frame_size > max_size then
      rand_frame_size := max_size;
    end if;
  end procedure generate_random_frame_size;

  -- Fill a std_logic_vector with random data for testing BTL
  -- The desired length must be large enough to hold the EOF and SOF
  -- fields of a CAN frame, and the vector will begin with a SOF bit and end
  -- with the EOF bits. The bits in between will be random.
  procedure generate_random_data_for_btl (
    signal   data        : out   std_logic_vector;
    constant data_length : in    natural;
    variable seed1       : inout positive;
    variable seed2       : inout positive)
  is
    variable rand_real           : real;
    variable rand_sl             : std_logic;
    variable rand_data           : std_logic_vector(0 to data'length-1)     := (others => '0');
    variable count               : natural                                  := 0;
    variable recessive_bit_count : natural                                  := 0;
    variable dominant_bit_count  : natural                                  := 0;
  begin

    assert data_length >= 2 + C_EOF_LENGTH
      report "Data length must at least include SOF, EOF and a data bit"
      severity error;

    assert data_length <= data'length
      report "Desired data length larger than data vector size"
      severity error;

    -- Fill first bit with C_SOF_VALUE
    rand_data(0)       := C_SOF_VALUE;  -- '0' - dominant
    count              := 1;
    dominant_bit_count := 1;

    while count < data_length loop
      if data_length - count > C_EOF_LENGTH + 1 then
        ---------------------------------------------------------------------
        -- Fill bits in between SOF and EOF with random data
        ---------------------------------------------------------------------
        uniform(seed1, seed2, rand_real);
        if rand_real >= 0.5 then
          if recessive_bit_count < 5 then
            rand_data(count) := '1';
          else
            -- Don't allow more than 5 consecutive bits of same value
            rand_data(count) := '0';
          end if;
        else
          if dominant_bit_count < 5 then
            rand_data(count) := '0';
          else
            -- Don't allow more than 5 consecutive bits of same value
            rand_data(count) := '1';
          end if;
        end if;

        if rand_data(count) /= rand_data(count-1) then
          recessive_bit_count := 0;
          dominant_bit_count  := 0;
        end if;

        if rand_data(count) = '1' then
          recessive_bit_count := recessive_bit_count + 1;
        else
          dominant_bit_count := dominant_bit_count + 1;
        end if;
      elsif data_length - count = C_EOF_LENGTH + 1 then
        ---------------------------------------------------------------------
        -- Make sure last bit before EOF is dominant,
        -- so that BTL does not think frame ended before it did
        ---------------------------------------------------------------------
        rand_data(count) := '0';

        if dominant_bit_count = 5 then
          -- If there was a sequence of 5 dominant bits before this bit,
          -- Just flip the previous bit
          rand_data(count-1) := '1';
        end if;
      else
        ---------------------------------------------------------------------
        -- Fill last C_EOF_SIZE bits with C_EOF_VALUE
        ---------------------------------------------------------------------
        rand_data(count) := C_EOF_VALUE;
      end if;

      count := count + 1;
    end loop;

    data <= rand_data;

    -- Update data next delta cycle
    wait for 0 ns;
  end procedure generate_random_data_for_btl;

end package body can_tb_pkg;