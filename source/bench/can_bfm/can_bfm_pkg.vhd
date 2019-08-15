-------------------------------------------------------------------------------
-- Title      : CAN bus BFM
-- Project    :
-------------------------------------------------------------------------------
-- File       : can_bfm.vhd
-- Author     : Simon Voigt Nesbo  <svn@hvl.no>
-- Company    : Western Norway University of Applied Sciences
-- Created    : 2018-05-24
-- Last update: 2018-08-10
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: General purpose Bus Functional Model (BFM) for CAN bus
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-05-24  1.0      simon	Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


package can_bfm_pkg is

  type can_payload_t is array (0 to 7) of std_logic_vector(7 downto 0);

  procedure can_write (
    constant arb_id           : in  std_logic_vector(28 downto 0);
    constant remote_request   : in  std_logic;
    constant extended_id      : in  std_logic;
    constant data             : in  can_payload_t;
    constant data_length      : in  natural;
    signal clk                : in  std_logic;
    signal can_tx             : out std_logic;
    signal can_rx             : in  std_logic;
    variable bit_stuffing_dbg : out std_logic;
    variable sample_point_dbg : out std_logic;
    variable arb_lost         : out std_logic;
    variable ack_received     : out std_logic;
    constant bit_stuff_en     : in  std_logic;
    constant clock_period     : in  time;
    constant bit_rate         : in  natural := 1000000;
    constant sync_quanta      : in  natural := 1;
    constant prop_quanta      : in  natural := 3;
    constant phase1_quanta    : in  natural := 3;
    constant phase2_quanta    : in  natural := 3
    );

  procedure can_read (
    variable arb_id           : out std_logic_vector(28 downto 0);
    variable remote_frame     : out std_logic;
    variable extended_id      : out std_logic;
    variable data             : out can_payload_t;
    variable data_length      : out natural;
    constant timeout_cycles   : in  natural;
    signal clk                : in  std_logic;
    signal can_rx             : in  std_logic;
    signal can_tx             : out std_logic;
    variable bit_stuffing_dbg : out std_logic;
    variable sample_point_dbg : out std_logic;
    constant bit_stuff_en     : in  std_logic;
    variable timeout          : out std_logic;
    variable crc_error        : out std_logic;
    constant clock_period     : in  time;
    constant bit_rate         : in  natural := 1000000;
    constant sync_quanta      : in  natural := 1;
    constant prop_quanta      : in  natural := 3;
    constant phase1_quanta    : in  natural := 3;
    constant phase2_quanta    : in  natural := 3
    );

  function calc_can_crc15 (
    constant data : std_logic_vector
    ) return std_logic_vector;


  -- Bit positions/indexes of fields in standard CAN frame
  constant C_STD_SOF_INDEX    : natural := 0;   -- Start Of Frame
  constant C_STD_ARB_ID_INDEX : natural := 1;   -- Arbitration ID
  constant C_STD_RTR_INDEX    : natural := 12;  -- Remote Transmission Request
  constant C_STD_IDE_INDEX    : natural := 13;  -- Identifier Extension Bit
  constant C_STD_R0_INDEX     : natural := 14;  -- Reserved Bit 0 (dominant zero)
  constant C_STD_DLC_INDEX    : natural := 15;  -- Data Length Code
  constant C_STD_DATA_INDEX   : natural := 19;  -- Data

  -- Bit positions/indexes of fields in extended CAN frame
  constant C_EXT_SOF_INDEX      : natural := 0;   -- Start Of Frame
  constant C_EXT_ARB_ID_A_INDEX : natural := 1;   -- Arbitration ID A
  constant C_EXT_SRR_INDEX      : natural := 12;  -- Substitute Remote Request
  constant C_EXT_IDE_INDEX      : natural := 13;  -- Identifier Extension Bit
  constant C_EXT_ARB_ID_B_INDEX : natural := 14;  -- Arbitration ID A
  constant C_EXT_RTR_INDEX      : natural := 32;  -- Remote Transmission Request
  constant C_EXT_R0_INDEX       : natural := 33;  -- Reserved Bit 0 (dominant zero)
  constant C_EXT_R1_INDEX       : natural := 34;  -- Reserved Bit 1 (dominant zero)
  constant C_EXT_DLC_INDEX      : natural := 35;  -- Data Length Code
  constant C_EXT_DATA_INDEX     : natural := 39;  -- Data

  -- Bit positions of CRC, ACK, and EOF bits.
  --
  constant C_CRC_INDEX       : natural := 0;  -- Cyclic Redundancy Check
  constant C_CRC_DELIM_INDEX : natural := 15; -- CRC delimiter (recessive 1)
  constant C_ACK_SLOT_INDEX  : natural := 16; -- ACK slot (transmitter sends
                                              -- recessive 1, receiver can
                                              -- assert dominant 0)
  constant C_ACK_DELIM_INDEX : natural := 17; -- ACK delimiter (recessive 1)
  constant C_EOF_INDEX       : natural := 18; -- End Of Frame (recessive 1)

  constant C_EOF_SIZE        : natural := 7;  -- 7 End Of Frame bits (recessive 1)
  constant C_IFS_SIZE        : natural := 3;  -- 3 Interframe Spacing bits (recessive 1)

end package can_bfm_pkg;


package body can_bfm_pkg is

  procedure can_write (
    constant arb_id           : in  std_logic_vector(28 downto 0);
    constant remote_request   : in  std_logic;
    constant extended_id      : in  std_logic;
    constant data             : in  can_payload_t;
    constant data_length      : in  natural;
    signal clk                : in  std_logic;
    signal can_tx             : out std_logic;
    signal can_rx             : in  std_logic;
    variable bit_stuffing_dbg : out std_logic;
    variable sample_point_dbg : out std_logic;
    variable arb_lost         : out std_logic;
    variable ack_received     : out std_logic;
    constant bit_stuff_en     : in  std_logic;
    constant clock_period     : in  time;
    constant bit_rate         : in  natural := 1000000;
    constant sync_quanta      : in  natural := 1;
    constant prop_quanta      : in  natural := 3;
    constant phase1_quanta    : in  natural := 3;
    constant phase2_quanta    : in  natural := 3
    ) is
    variable bit_buffer       : std_logic_vector(0 to 200);

    -- Bit start index in bit_buffer for byte
    variable byte_start_index : natural;

    -- Bit end index in bit_buffer for byte
    variable byte_end_index   : natural;

    -- Bit start index for crc in bit_buffer (depends on data size)
    variable crc_start_index  : natural;
    variable crc              : std_logic_vector(14 downto 0);

    variable frame_end_index : natural;

    -- Counter of how many consecutive bits of the same type has been sent
    -- If five consecutive bits have the same polarity, a "stuffed" bit with opposite
    -- polarity is sent to help with synchronization
    variable bit_stuffing_counter : natural   := 0;
    variable previous_bit_value   : std_logic := '0';

    constant bit_period        : time := 1 sec / bit_rate;
    constant bit_quanta        : time := bit_period / 10;
    constant bit_quanta_cycles : natural := bit_quanta / clock_period;

    constant sync_cycles   : natural := sync_quanta*bit_quanta_cycles;
    constant prop_cycles   : natural := prop_quanta*bit_quanta_cycles;
    constant phase1_cycles : natural := phase1_quanta*bit_quanta_cycles;
    constant phase2_cycles : natural := phase2_quanta*bit_quanta_cycles;

    constant sample_point_cycles : natural := sync_cycles+prop_cycles+phase1_cycles;

  begin
    arb_lost     := '0';
    ack_received := '0';

    assert (sync_quanta+prop_quanta+phase1_quanta+phase2_quanta) = 10
      report "can_write(): Error. Illegal bit timing setup." severity failure;


    -- -------------------------------------------------------------------------
    -- Initialize bit buffer for CAN frame
    -- -------------------------------------------------------------------------

    if extended_id = '0' then
      -- -----------------------------------------------------------------------
      -- Standard frame
      -- -----------------------------------------------------------------------
      bit_buffer(C_STD_SOF_INDEX) := '0';
      bit_buffer(C_STD_ARB_ID_INDEX to C_STD_ARB_ID_INDEX+10) := arb_id(10 downto 0);
      bit_buffer(C_STD_RTR_INDEX) := remote_request;
      bit_buffer(C_STD_IDE_INDEX) := extended_id;
      bit_buffer(C_STD_R0_INDEX) := '0';
      bit_buffer(C_STD_DLC_INDEX to C_STD_DLC_INDEX+3) := std_logic_vector(to_unsigned(data_length, 4));

      if remote_request = '0' then
        for byte_counter in 0 to data_length-1 loop
          byte_start_index := C_STD_DATA_INDEX+byte_counter*8;
          byte_end_index := byte_start_index+7;
          bit_buffer(byte_start_index to byte_end_index) := data(byte_counter);
        end loop;
        crc_start_index := C_STD_DATA_INDEX+(data_length*8);
      else
        crc_start_index := C_STD_DATA_INDEX;
      end if;

      crc := calc_can_crc15(bit_buffer(0 to crc_start_index-1));
      bit_buffer(crc_start_index to crc_start_index+14) := crc;

      bit_buffer(crc_start_index+C_CRC_DELIM_INDEX) := '1';
      bit_buffer(crc_start_index+C_ACK_SLOT_INDEX) := '1';
      bit_buffer(crc_start_index+C_ACK_DELIM_INDEX) := '1';

      frame_end_index := crc_start_index+C_EOF_INDEX+C_EOF_SIZE+C_IFS_SIZE-1;

      bit_buffer(crc_start_index+C_EOF_INDEX to frame_end_index) := (others => '1');
    else
      -- -----------------------------------------------------------------------
      -- Extended frame
      -- -----------------------------------------------------------------------
      bit_buffer(C_EXT_SOF_INDEX) := '0';
      bit_buffer(C_EXT_ARB_ID_A_INDEX to C_EXT_ARB_ID_A_INDEX+10) := arb_id(10 downto 0);

      -- RTR bit has a different position in extended frame.
      -- The SRR bit is placed in the same position as RTR a in standard frame.
      -- SRR should always be 1 (recessive) for extended frame, effectively
      -- giving an extended frame lower priority than a standard frame
      bit_buffer(C_EXT_SRR_INDEX) := '1';
      bit_buffer(C_EXT_IDE_INDEX) := extended_id;
      bit_buffer(C_EXT_ARB_ID_B_INDEX to C_EXT_ARB_ID_B_INDEX+17) := arb_id(28 downto 11);
      bit_buffer(C_EXT_RTR_INDEX) := remote_request;
      bit_buffer(C_EXT_R0_INDEX) := '0';
      bit_buffer(C_EXT_R1_INDEX) := '0';
      bit_buffer(C_EXT_DLC_INDEX to C_EXT_DLC_INDEX+3) := std_logic_vector(to_unsigned(data_length, 4));

      if remote_request = '0' then
        for byte_counter in 0 to data_length-1 loop
          byte_start_index := C_EXT_DATA_INDEX+byte_counter*8;
          byte_end_index := byte_start_index+7;
          bit_buffer(byte_start_index to byte_end_index) := data(byte_counter);
        end loop;
        crc_start_index := C_EXT_DATA_INDEX+(data_length*8);
      else
        crc_start_index := C_EXT_DATA_INDEX;
      end if;

      crc := calc_can_crc15(bit_buffer(0 to crc_start_index-1));
      bit_buffer(crc_start_index to crc_start_index+14) := crc;

      bit_buffer(crc_start_index+C_CRC_DELIM_INDEX) := '1';
      bit_buffer(crc_start_index+C_ACK_SLOT_INDEX) := '1';
      bit_buffer(crc_start_index+C_ACK_DELIM_INDEX) := '1';

      frame_end_index := crc_start_index+C_EOF_INDEX+C_EOF_SIZE+C_IFS_SIZE-1;

      bit_buffer(crc_start_index+C_EOF_INDEX to frame_end_index)
        := (others => '1');
    end if;


    -- -------------------------------------------------------------------------
    -- Transmit bit buffer (CAN frame), and do bit stuffing
    -- -------------------------------------------------------------------------

    wait until rising_edge(clk);

    for bit_counter in 0 to frame_end_index loop
      can_tx <= bit_buffer(bit_counter);

      -- Wait for sampling point before reading back CAN RX value
      for cycle_count in 0 to sample_point_cycles-1 loop
        wait until rising_edge(clk);
      end loop;

      sample_point_dbg := '1';

      -- Check for ACK and arbitration lost
      if bit_counter = crc_start_index+C_ACK_SLOT_INDEX then
        if can_rx = '0' then
          ack_received := '1';
        end if;
      elsif can_rx /= bit_buffer(bit_counter) then
        arb_lost := '1';
        exit;
      end if;

      -- Calculate number of consecutive bits of same value,
      -- used for bit stuffing below.
      if previous_bit_value = bit_buffer(bit_counter) then
        bit_stuffing_counter := bit_stuffing_counter+1;
      else
        previous_bit_value   := bit_buffer(bit_counter);
        bit_stuffing_counter := 1;
      end if;

      for cycle_count in 0 to phase2_cycles-1 loop
        wait until rising_edge(clk);
        sample_point_dbg := '0';
      end loop;  -- cycle_count

      -- Do bit stuffing if we sent 5 consecutive bits of same value
      -- Bit stuffing should end after CRC code (before delimiter)
      -- See page 45 here:
      -- https://www.nxp.com/docs/en/reference-manual/BCANPSV2.pdf
      if bit_stuffing_counter = 5 and
         bit_stuff_en = '1' and
         bit_counter < crc_start_index+C_CRC_DELIM_INDEX
      then
        bit_stuffing_dbg := '1';
        can_tx <= not bit_buffer(bit_counter);
        previous_bit_value := not bit_buffer(bit_counter);
        bit_stuffing_counter := 1;

        for cycle_count in 0 to sample_point_cycles-1 loop
          wait until rising_edge(clk);
        end loop;
        sample_point_dbg := '1';

        -- Check if arbitration was lost
        -- Should probably not be possible for a stuff bit
        if can_rx /= previous_bit_value then
          arb_lost := '1';
          exit;
        end if;

        for cycle_count in 0 to phase2_cycles-1 loop
          wait until rising_edge(clk);
          sample_point_dbg := '0';
        end loop;  -- cycle_count

        bit_stuffing_dbg := '0';
      end if;
    end loop;  -- bit_counter

    can_tx <= '1';
    wait until rising_edge(clk);

  end procedure can_write;


  procedure can_read (
    variable arb_id           : out std_logic_vector(28 downto 0);
    variable remote_frame     : out std_logic;
    variable extended_id      : out std_logic;
    variable data             : out can_payload_t;
    variable data_length      : out natural;
    constant timeout_cycles   : in  natural;
    signal clk                : in  std_logic;
    signal can_rx             : in  std_logic;
    signal can_tx             : out std_logic;
    variable bit_stuffing_dbg : out std_logic;
    variable sample_point_dbg : out std_logic;
    constant bit_stuff_en     : in  std_logic;
    variable timeout          : out std_logic;
    variable crc_error        : out std_logic;
    constant clock_period     : in  time;
    constant bit_rate         : in  natural := 1000000;
    constant sync_quanta      : in  natural := 1;
    constant prop_quanta      : in  natural := 3;
    constant phase1_quanta    : in  natural := 3;
    constant phase2_quanta    : in  natural := 3)
  is
    variable timeout_cycle_count : natural := 0;

    variable can_frame_rx_done : std_logic := '0';

    variable bit_buffer  : std_logic_vector(0 to 200);
    variable bit_counter : natural := 0;

    -- Expected size (in bits) of CAN frame
    -- (excluding CRC delim, ACK slot/delim and EOF)
    -- The size is calculated when the DLC field is received.
    variable can_frame_bit_size : natural := 0;

    variable data_length_bits : natural := 0;
    variable data_bits_index  : natural := 0;

    -- Counter of how many consecutive bits of the same type has been sent
    -- If five consecutive bits have the same polarity, a "stuffed" bit with opposite
    -- polarity is sent to help with synchronization
    variable bit_stuffing_counter : natural   := 0;
    variable previous_bit_value   : std_logic := '0';

    -- Bit start index for crc in bit_buffer (depends on data size)
    variable crc_start_index  : natural;
    variable crc_calc         : std_logic_vector(14 downto 0);
    variable crc_received     : std_logic_vector(14 downto 0);

    constant bit_period        : time    := 1 sec /bit_rate;
    constant bit_quanta        : time    := bit_period / 10;
    constant bit_quanta_cycles : natural := bit_quanta / clock_period;

    constant sync_cycles   : natural := sync_quanta*bit_quanta_cycles;
    constant prop_cycles   : natural := prop_quanta*bit_quanta_cycles;
    constant phase1_cycles : natural := phase1_quanta*bit_quanta_cycles;
    constant phase2_cycles : natural := phase2_quanta*bit_quanta_cycles;

    constant sample_point_cycles : natural := sync_cycles+prop_cycles+phase1_cycles;

  begin  -- procedure can_read
    bit_stuffing_dbg := '0';
    crc_error        := '0';
    timeout          := '0';
    extended_id      := '0';

    -- -------------------------------------------------------------------------
    -- Wait for activity on CAN RX signal
    -- -------------------------------------------------------------------------
    while can_rx = '1' loop
      wait until rising_edge(clk);

      -- Break out of procedure if timeout is reached
      if timeout_cycles /= 0 then
        timeout_cycle_count := timeout_cycle_count + 1;
        if timeout_cycle_count = timeout_cycles then
          timeout := '1';
          return;
        end if;
      end if;
    end loop;

    -- -------------------------------------------------------------------------
    -- Receive CAN msg
    -- -------------------------------------------------------------------------
    while can_frame_rx_done = '0' loop
      bit_stuffing_dbg := '0';

      -- Wait for sampling point before sampling CAN RX
      for cycle_count in 0 to sample_point_cycles-1 loop
        wait until rising_edge(clk);
      end loop;

      sample_point_dbg := '1';

      -- TODO: Check for bit stuffing errors...

      if bit_stuff_en = '1' then
        -- After 5 consecutive bits of same value, a stuffing bit is sent
        if bit_stuffing_counter = 5 then
          -- Discard stuff bits
          bit_stuffing_dbg     := '1';
          bit_stuffing_counter := 1;

          assert previous_bit_value /= can_rx report "Stuff bit with wrong polarity received" severity failure;

          previous_bit_value   := can_rx;
        else
          -- Data bits
          bit_buffer(bit_counter) := can_rx;
          bit_counter             := bit_counter + 1;

          if previous_bit_value /= can_rx or bit_counter = 0 then
            -- Reset bit stuffing counter when bit differs from previous bit
            bit_stuffing_counter := 1;
            previous_bit_value   := can_rx;
          else
            -- Increase bit stuffing counter for consecutive bits of same value
            bit_stuffing_counter := bit_stuffing_counter + 1;
          end if;
        end if;
      end if;

      -- Check if we've received data length,
      -- so we know how many bits we're receiving
      if bit_counter > C_STD_IDE_INDEX then
        if bit_buffer(C_STD_IDE_INDEX) = '0' and bit_counter = C_STD_DLC_INDEX+4 then
          data_length := to_integer(unsigned(bit_buffer(C_STD_DLC_INDEX to C_STD_DLC_INDEX+3)));

          -- Payload data is not sent for remote frames
          if bit_buffer(C_STD_RTR_INDEX) = '1' then
            data_length_bits := 0;
          else
            data_length_bits := 8 * to_integer(unsigned(bit_buffer(C_STD_DLC_INDEX to C_STD_DLC_INDEX+3)));
          end if;

          can_frame_bit_size := data_length_bits + C_STD_DATA_INDEX + C_CRC_DELIM_INDEX + 1;

        elsif bit_buffer(C_EXT_IDE_INDEX) = '1' and bit_counter = C_EXT_DLC_INDEX+4 then
          data_length := to_integer(unsigned(bit_buffer(C_EXT_DLC_INDEX to C_EXT_DLC_INDEX+3)));

          -- Payload data is not sent for remote frames
          if bit_buffer(C_EXT_RTR_INDEX) = '1' then
            data_length_bits := 0;
          else
            data_length_bits := 8 * to_integer(unsigned(bit_buffer(C_EXT_DLC_INDEX to C_EXT_DLC_INDEX+3)));
          end if;

          can_frame_bit_size := data_length_bits + C_EXT_DATA_INDEX + C_CRC_DELIM_INDEX + 1;
        end if;
      end if;

      -- Wait for the remaining time (phase 2) of this bit
      for cycle_count in 0 to phase2_cycles-1 loop
        wait until rising_edge(clk);
        sample_point_dbg := '0';
      end loop;  -- cycle_count

      -- End loop when last bit was received
      -- can_frame_bit_size is set to zero until the DLC field has been received
      if can_frame_bit_size /= 0 and can_frame_bit_size = bit_counter then
        can_frame_rx_done := '1';
      end if;
    end loop;

    -- -------------------------------------------------------------------------
    -- Verify CRC and CRC delimiter value
    -- -------------------------------------------------------------------------
    crc_start_index := can_frame_bit_size - (C_CRC_DELIM_INDEX+1);
    crc_calc := calc_can_crc15(bit_buffer(0 to crc_start_index-1));
    crc_received := bit_buffer(crc_start_index to crc_start_index+14);

    if crc_calc /= crc_received then
      crc_error := '1';
      wait until rising_edge(clk);
      crc_error := '0';
      wait until rising_edge(clk);
      return;
    end if;

    assert bit_buffer(crc_start_index + C_CRC_DELIM_INDEX) = '1'
      report "can_read(): CRC delimiter was 0, expected 1" severity error;

    -- -------------------------------------------------------------------------
    -- Send ACK signal
    -- -------------------------------------------------------------------------
    can_tx <= '0';
    wait for bit_period;
    can_tx <= '1';

    -- -------------------------------------------------------------------------
    -- Wait for ACK delimiter, End Of Frame (EOF), and Interframe Spacing (IFS)
    -- -------------------------------------------------------------------------
    for ack_delim_eof_ifs_bit_num in 0 to (1+C_EOF_SIZE+C_IFS_SIZE) loop
      -- Wait for sampling point before sampling CAN RX
      for cycle_count in 0 to sample_point_cycles-1 loop
        wait until rising_edge(clk);
      end loop;
      sample_point_dbg := '1';
      if ack_delim_eof_ifs_bit_num = 0 then
        assert can_rx = '1' report "can_read(): ACK delimiter was 0, expected 1" severity error;
      elsif ack_delim_eof_ifs_bit_num <= (1+C_EOF_SIZE) then
        assert can_rx = '1' report "can_read(): EOF bit was 0, expected 1" severity error;
      else
        assert can_rx = '1' report "can_read(): IFS bit was 0, expected 1" severity error;
      end if;

      -- Wait for the remaining time (phase 2) of this bit
      for cycle_count in 0 to phase2_cycles-1 loop
        wait until rising_edge(clk);
        sample_point_dbg := '0';
      end loop;  -- cycle_count
    end loop;  -- ack_delim_eof_ifs_bit_num

    -- -------------------------------------------------------------------------
    -- Parse CAN message
    -- -------------------------------------------------------------------------
    if bit_buffer(C_STD_IDE_INDEX) = '0' then
      -- Standard frame
      arb_id(10 downto 0)  := bit_buffer(C_STD_ARB_ID_INDEX to C_STD_ARB_ID_INDEX+10);
      arb_id(28 downto 11) := (others => '0');
      remote_frame         := bit_buffer(C_STD_RTR_INDEX);
      extended_id          := '0';
      data_bits_index      := C_STD_DATA_INDEX;
    else
      -- Extended frame
      arb_id(10 downto 0)  := bit_buffer(C_EXT_ARB_ID_A_INDEX to C_EXT_ARB_ID_A_INDEX+10);
      arb_id(28 downto 11) := bit_buffer(C_EXT_ARB_ID_B_INDEX to C_EXT_ARB_ID_B_INDEX+17);
      remote_frame         := bit_buffer(C_EXT_RTR_INDEX);
      extended_id          := '1';
      data_bits_index      := C_EXT_DATA_INDEX;
    end if;

    -- Copy data from bit buffer
    -- No copying takes place for remote frame requests,
    -- because data_length_bits is set to zero in that case
    for bit_num in 0 to 63 loop
      -- Bits are sent MSB first
      if bit_num < data_length_bits then
        data(bit_num/8)(7 - (bit_num mod 8)) := bit_buffer(data_bits_index+bit_num);
      else
        data(bit_num/8)(7 - (bit_num mod 8)) := '0';
      end if;
    end loop;

    wait until rising_edge(clk);

  end procedure can_read;


  -- CRC calculation as specified in BOSCH CAN Specification Version 2.0
  function calc_can_crc15 (
    constant data : std_logic_vector
    ) return std_logic_vector is
    variable crc_shift_reg : std_logic_vector(14 downto 0) := (others => '0');
    variable crc_next      : std_logic;

    -- Bit 15 is not used, it's just there to allow the assignment
    constant crc_poly      : std_logic_vector(15 downto 0) := x"4599";
  begin
    for bit_count in data'range loop
      crc_next := data(bit_count) xor crc_shift_reg(14);
      crc_shift_reg(14 downto 1) := crc_shift_reg(13 downto 0);
      crc_shift_reg(0) := '0';

      if crc_next = '1' then
        crc_shift_reg(14 downto 0) := crc_shift_reg(14 downto 0) xor crc_poly(14 downto 0);
      end if;
    end loop;  -- bit_count

    return crc_shift_reg;
  end function calc_can_crc15;


end package body can_bfm_pkg;
