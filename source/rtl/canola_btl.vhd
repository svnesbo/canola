-------------------------------------------------------------------------------
-- Title      : Bit Timing Logic (BTL) for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : canola_btl.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-01
-- Last update: 2020-01-10
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Bit Timing Logic (BTL) for the Canola CAN controller.
--              Receives and outputs bits that are received.
--              Responsible for hard synchronization on start of frame (dominant
--              bit received after bus idle), and soft resynchronization per
--              dominant bit while receiving.
--              Does not perform bit destuffing, that is done by BSP.
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-01  1.0      svn     Created
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.ceil;
use ieee.math_real.log2;

library work;
use work.canola_pkg.all;

entity canola_btl is
  port (
    CLK                     : in  std_logic;
    RESET                   : in  std_logic;
    CAN_TX                  : out std_logic;
    CAN_RX                  : in  std_logic;

    BTL_TX_BIT_VALUE        : in  std_logic;  -- Value of bit to transmit
    BTL_TX_BIT_VALID        : in  std_logic;  -- BTL should transmit this bit
    BTL_TX_RDY              : out std_logic;  -- BTL is ready to transmit next bit
    BTL_TX_DONE             : out std_logic;  -- BTL has outputted the bit on the bus
    BTL_TX_ACTIVE           : in  std_logic;  -- We want to transmit on the
                                              -- bus, avoid Rx syncing

    BTL_RX_BIT_VALUE        : out std_logic;  -- Received bit value
    BTL_RX_BIT_VALID        : out std_logic;  -- Received bit value is valid
    BTL_RX_SYNCED           : out std_logic;  -- BTL has sync to a frame and is receiving
    BTL_RX_STOP             : in  std_logic;  -- Receiving frame is done, BTL
                                              -- can go out of sync

    TRIPLE_SAMPLING         : in  std_logic;  -- Enable triple sampling

    PROP_SEG                : in  std_logic_vector(C_PROP_SEG_WIDTH-1 downto 0);
    PHASE_SEG1              : in  std_logic_vector(C_PHASE_SEG1_WIDTH-1 downto 0);
    PHASE_SEG2              : in  std_logic_vector(C_PHASE_SEG2_WIDTH-1 downto 0);
    SYNC_JUMP_WIDTH         : in  natural range 1 to C_SYNC_JUMP_WIDTH_MAX;

    TIME_QUANTA_CLOCK_SCALE : in  unsigned(C_TIME_QUANTA_WIDTH-1 downto 0)
    );

end entity canola_btl;

architecture rtl of canola_btl is

  -- Used to extend s_segment during PHASE_SEG1 if we detect a positive
  -- phase error.
  -- See RESYNCHRONIZATION, page 29, of BOSCH CAN Specification 2.0
  function shift_left_and_fill_with_one (
    constant vector_in    : std_logic_vector;
    constant shift_amount : integer range 0 to 4)
    return std_logic_vector
  is
    alias a_vector_in    : std_logic_vector(0 to vector_in'length-1) is vector_in;
    variable vector_out  : std_logic_vector(0 to vector_in'length-1);

    -- Range evaluates to null if shift_amount is zero
    variable fill_vector : std_logic_vector(0 to shift_amount-1) := (others => '1');
  begin
    if shift_amount > 0 then
      vector_out := a_vector_in(shift_amount to a_vector_in'right) & fill_vector;
    else
      vector_out := a_vector_in;
    end if;

    return vector_out;
  end function shift_left_and_fill_with_one;


  type sync_fsm_t is (ST_SYNC_SEG,
                      ST_PROP_SEG,
                      ST_PHASE_SEG1,
                      ST_PHASE_SEG2);

  signal s_sync_state : sync_fsm_t := ST_SYNC_SEG;

  -- Essentially a shift register that holds a sequence of 1s,
  -- where each 1 corresponds to a time quanta.
  -- It is initialized with a sequence of 1s corresponding to the length of
  -- either PROP_SEG, PHASE1_SEG or PHASE2_SEG, before entering the respective
  -- states: ST_PROP_SEG, ST_PHASE1_SEG, or ST_PHASE2_SEG.
  -- During those states it is right shifted 1 time per time quanta pulse
  -- until there are no 1s left, at which point we continue to the next segment.
  signal s_segment         : std_logic_vector(C_SEGMENT_WIDTH_MAX-1 downto 0);

  signal s_frame_hard_sync      : std_logic;
  signal s_resync_allowed       : std_logic;
  signal s_resync_done          : std_logic;
  signal s_phase_error          : natural range 0 to C_SYNC_JUMP_WIDTH_MAX;
  signal s_sample_point_rx      : std_logic;
  signal s_sample_point_tx      : std_logic;
  signal s_sample_point_rx_done : std_logic;
  signal s_sample_point_tx_done : std_logic;
  signal s_output_rx_bit_pulse  : std_logic;
  signal s_time_quanta_pulse    : std_logic;

  -- Indicates that we detected a falling edge transition on CAN_RX
  -- for the bit that is currently being processed
  signal s_got_rx_bit_falling_edge : std_logic;

  -- Actual bit sampled @ baud clock, will be processed as part of CANbus frame
  -- (In the case of triple sampling, this is the majority voted value of the
  -- 3 most recent CAN_RX samples)
  signal s_sampled_bit       : std_logic;

  -- Previous 2 bit values - used with triple sampling
  signal s_baud_sampled_bits : std_logic_vector(1 downto 0);

  -- Previous bit sampled @ system clock
  -- Used for edge detection when not in sync
  signal s_clk_sampled_bit   : std_logic_vector(1 downto 0);

  -- signal s_sync_jump_width : unsigned(C_SYNC_JUMP_WIDTH_MAX downto 0);

  -- Number of baud pulses that the bus has been "idle" (no transitions)
  signal s_bus_idle_count : integer range 0 to C_EOF_LENGTH;

  -- Number of bits in a row that has been dominant (0) or recessive (1)
  signal s_dominant_bit_count : unsigned(3 downto 0);
  signal s_recessive_bit_count : unsigned(3 downto 0);

  -- BTL_TX_BIT_VALUE registered when BTL_TX_BIT_VALID is high,
  -- to be transmitted on the Tx sample point
  signal s_btl_tx_bit : std_logic;

begin  -- architecture rtl

  -- Generates a 1 (system) clock cycle pulse for each baud
  INST_canola_time_quanta_gen : entity work.canola_time_quanta_gen
    port map (
      CLK               => CLK,
      RESET             => RESET,
      RESTART           => s_frame_hard_sync,
      COUNT_VAL         => TIME_QUANTA_CLOCK_SCALE,
      TIME_QUANTA_PULSE => s_time_quanta_pulse);

  proc_rx_sync_fsm : process(CLK) is
    variable v_phase_error             : natural range 0 to C_SYNC_JUMP_WIDTH_MAX;
    variable v_got_rx_bit_falling_edge : std_logic;
    variable v_segment                 : std_logic_vector(C_SEGMENT_WIDTH_MAX-1 downto 0);
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      -- Synchronous reset
      if RESET = '1' then
        BTL_RX_SYNCED               <= '0';
        s_frame_hard_sync         <= '0';
        s_resync_allowed          <= '0';
        s_resync_done             <= '0';
        s_got_rx_bit_falling_edge <= '0';
      else
        s_frame_hard_sync      <= '0';

        if s_clk_sampled_bit(1) = '1' and s_clk_sampled_bit(0) = '0' then
          v_got_rx_bit_falling_edge := '1';
        else
          v_got_rx_bit_falling_edge := '0';
        end if;

        if v_got_rx_bit_falling_edge = '1' then
          -- s_got_rx_bit_falling_edge is reset in
          -- ST_PHASE_SEG2 when transitioning to ST_SYNC_SEG
          s_got_rx_bit_falling_edge <= '1';
        end if;


        if BTL_RX_STOP = '1' then
          -- Go out of sync when instructed to (by BSP)
          BTL_RX_SYNCED <= '0';
        elsif BTL_RX_SYNCED = '0' and v_got_rx_bit_falling_edge = '1' then
          -- Enable Rx when falling edge is detected
          BTL_RX_SYNCED <= '1';
        end if;

        -----------------------------------------------------------------------
        -- Hard sync (ie. jump to SYNC_SEG, reset baud gen) to incoming frame
        -- when we are not already receiving a frame, and not transmitting
        -----------------------------------------------------------------------
        if BTL_RX_SYNCED = '0' and v_got_rx_bit_falling_edge = '1' and BTL_TX_ACTIVE = '0' then
          -- This will reset the time quanta generator, and next time quanta pulse
          -- should be in exactly one time quanta from now.
          -- BTL_RX_SYNCED and s_got_rx_bit_falling_edge should both be '1' by then,
          -- so that ST_SYNC_SEG knows that we are in sync with falling edge
          -- and a resync should not be performed for the current (SOF) bit
            s_frame_hard_sync <= '1';
            s_sync_state      <= ST_SYNC_SEG;

          -- Hard sync is not allowed when we are transmitting,
          -- however because of the fixed phase between rx and tx sample point,
                      -- we should already be in sync with what is being transmitted

        -----------------------------------------------------------------------
        -- FSM logic for bit synchronization within a CAN frame
        -- Note: FSM is processed only on baud pulses
        -----------------------------------------------------------------------
        elsif s_time_quanta_pulse = '1' then
          case s_sync_state is
            when ST_SYNC_SEG =>

              if BTL_RX_SYNCED = '1' and s_got_rx_bit_falling_edge = '0' then
                s_resync_allowed <= '1';
              else
                s_resync_allowed <= '0';
              end if;

              s_resync_done             <= '0';
              s_phase_error             <= 0;
              s_segment                 <= (others => '0');
              s_segment(PROP_SEG'range) <= PROP_SEG;
              s_sync_state              <= ST_PROP_SEG;

            when ST_PROP_SEG =>
              v_phase_error := s_phase_error;

              if s_got_rx_bit_falling_edge = '0' then
                -- Limit phase error to SJW, which is the
                -- largest jump in phase we are allowed to make
                if v_phase_error < C_SYNC_JUMP_WIDTH_MAX then
                  v_phase_error := v_phase_error + 1;
                end if;
              end if;

              v_segment := '0' & s_segment(s_segment'left downto 1);  -- Shift right by 1 bit

              -- Checking the LSB only saves logic.
              -- Shouldn't be necessary to compare the whole vector to zero,
              -- assuming that the user has setup the segment inputs correctly.
              if v_segment(0) = '0' then
                -- Last time quanta in PROP_SEG
                -- Setup segment for PHASE1_SEG
                v_segment                   := (others => '0');
                v_segment(PHASE_SEG1'range) := PHASE_SEG1;
                s_sync_state                <= ST_PHASE_SEG1;
              end if;

              s_phase_error <= v_phase_error;
              s_segment     <= v_segment;


            when ST_PHASE_SEG1 =>
              v_phase_error             := s_phase_error;
              v_segment                 := '0' & s_segment(s_segment'left downto 1);  -- Shift right by 1 bit

              if s_got_rx_bit_falling_edge = '0' then
                -- No falling edge detected yet for this bit.
                -- Limit phase error to SJW, which is the
                -- largest jump in phase we are allowed to make
                if v_phase_error < C_SYNC_JUMP_WIDTH_MAX then
                  v_phase_error := v_phase_error + 1;
                end if;
              elsif s_got_rx_bit_falling_edge = '1' and s_resync_allowed = '1' and s_resync_done = '0' then
                -- Detected Rx falling edge during PROP_SEG or PHASE_SEG,
                -- so we should extend PHASE_SEG with the phase error
                v_segment        := shift_left_and_fill_with_one(v_segment, v_phase_error);
                s_resync_done    <= '1';
                s_resync_allowed <= '0';
              end if;

              -- Checking the LSB only saves logic.
              -- Shouldn't be necessary to compare the whole vector to zero,
              -- assuming that the user has setup the segment inputs correctly.
              if v_segment(0) = '0' then
                -- Last time quanta in PHASE1_SEG, setup segment for PHASE2_SEG
                -- Also reset phase error and falling edge detection, as we start
                -- looking for transition for next bit in PHASE2_SEG
                v_segment                   := (others => '0');
                v_segment(PHASE_SEG2'range) := PHASE_SEG2;

                -- Phase error for PHASE_SEG2 becomes shorter the longer into PHASE_SEG2
                -- we are, so start with maximum value for v_phase_error and
                -- decrease it each time quanta in PHASE_SEG2
                v_phase_error               := C_SYNC_JUMP_WIDTH_MAX;

                s_resync_done               <= '0';
                s_sync_state                <= ST_PHASE_SEG2;
              end if;

              s_segment                 <= v_segment;
              s_phase_error             <= v_phase_error;

          when ST_PHASE_SEG2 =>
              v_phase_error             := s_phase_error;
              v_segment                 := '0' & s_segment(s_segment'left downto 1);  -- Shift right by 1 bit

              if s_got_rx_bit_falling_edge = '0' and v_phase_error > 0 then
                  v_phase_error := v_phase_error - 1;
              end if;

              -- Detected Rx falling edge during PHASE_SEG2, which is too early,
              -- we expect it during SYNC_SEG. Shorten by PHASE_SEG2 by phase error
              if s_got_rx_bit_falling_edge = '1' and s_resync_allowed = '1' and s_resync_done = '0' then
                v_segment     := v_segment srl v_phase_error;
                s_resync_done <= '1';
              end if;

              -- Checking the LSB only saves logic.
              -- Shouldn't be necessary to compare the whole vector to zero,
              -- assuming that the user has setup the segment inputs correctly.
              if v_segment(0) = '0' then
                -- Last time quanta in PHASE2_SEG
                v_segment                   := (others => '0');
                v_phase_error               := 0;
                s_got_rx_bit_falling_edge   <= '0';
                s_sync_state                <= ST_SYNC_SEG;
              end if;

              s_segment                 <= v_segment;
              s_phase_error             <= v_phase_error;

            when others =>
              s_sync_state      <= ST_SYNC_SEG;

          end case;

        end if; -- s_time_quanta_pulse = '1'
      end if; -- RESET = '0'
    end if; -- rising_edge(CLK)
  end process proc_rx_sync_fsm;


  proc_tx_sync : process(CLK) is
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        BTL_TX_RDY  <= '1';
        BTL_TX_DONE <= '0';

        -- Recessive bit value (1) is default
        CAN_TX       <= '1';
        s_btl_tx_bit <= '1';
      else
        BTL_TX_DONE <= '0';

        if BTL_TX_BIT_VALID = '1' then
          BTL_TX_RDY   <= '0';
          s_btl_tx_bit <= BTL_TX_BIT_VALUE;
        end if;

        -- Update CAN_TX only on tx sample point
        if s_sample_point_tx = '1' then
          if BTL_TX_RDY = '0' then
            CAN_TX      <= s_btl_tx_bit;
            BTL_TX_DONE <= '1';
            BTL_TX_RDY  <= '1';
          else
            -- Revert CAN_TX back to recessive bit value (1)
            -- if we were not requested to transmit a bit
            CAN_TX <= '1';
          end if;
        end if;
      end if;
    end if;
  end process proc_tx_sync;


  proc_sample_points : process(CLK) is
  begin
    if rising_edge(CLK) then

      s_sample_point_tx      <= '0';
      s_sample_point_tx_done <= '0';
      s_sample_point_rx      <= '0';
      s_sample_point_rx_done <= '0';

      if s_sync_state = ST_SYNC_SEG then
        if s_sample_point_tx_done = '0' then
          s_sample_point_tx <= '1';
        else
          s_sample_point_tx <= '0';
        end if;
        s_sample_point_tx_done <= '1';
      end if;

      if s_sync_state = ST_PHASE_SEG2 then
        if s_sample_point_rx_done = '0' then
          s_sample_point_rx <= '1';
        else
          s_sample_point_rx <= '0';
        end if;
        s_sample_point_rx_done <= '1';
      end if;
    end if;
  end process proc_sample_points;


  -- Detect if there are no transitions when we are receiving frame
  -- If we detect too many bits with no transitions in a row we end
  -- the frame
  proc_bus_idle_counter : process(CLK) is
  begin
    if rising_edge(CLK) then
      -- Synchronize to time quantas
      if s_time_quanta_pulse = '1' then
        if CAN_RX /= s_baud_sampled_bits(0) then
          s_bus_idle_count <= 0;
        elsif s_bus_idle_count < C_EOF_LENGTH then
          s_bus_idle_count <= s_bus_idle_count + 1;
        end if;
      end if;
    end if;
  end process proc_bus_idle_counter;


  -- purpose: Sample received bits
  -- type   : sequential
  -- inputs : CLK, RESET, CAN_RX
  -- outputs: s_baud_sampled_bits
  proc_sample_rx_bit : process (CLK, RESET) is
    variable v_sampled_bit : std_logic;
  begin  -- process proc_sample_rx_bit
    if rising_edge(CLK) then
      if RESET = '1' then
        s_baud_sampled_bits   <= (others => '0');
        s_dominant_bit_count  <= (others => '0');
        s_recessive_bit_count <= (others => '0');
        s_output_rx_bit_pulse <= '0';
      else
        s_output_rx_bit_pulse <= '0';
        -----------------------------------------------------------------------
        -- Sample bits @ system clock
        -- Used to detect falling edge transition when we are not in sync
        -----------------------------------------------------------------------
        s_clk_sampled_bit(1) <= s_clk_sampled_bit(0);
        s_clk_sampled_bit(0) <= CAN_RX;

        -----------------------------------------------------------------------
        -- Sample bits @ baud clock
        -- These bit values are stored and processed
        -----------------------------------------------------------------------
        if s_time_quanta_pulse = '1' then
          -- Sample and store 2 previous values of CAN_RX,
          -- used for triple sampling and for falling edge
          -- detection in proc_sync_fsm
          s_baud_sampled_bits(1) <= s_baud_sampled_bits(0);
          s_baud_sampled_bits(0) <= CAN_RX;
        end if;

        if s_sample_point_rx = '1' then
          if TRIPLE_SAMPLING = '1' then
            v_sampled_bit := (s_baud_sampled_bits(0) and s_baud_sampled_bits(1)) or
                             (s_baud_sampled_bits(0) and CAN_RX) or
                             (s_baud_sampled_bits(1) and CAN_RX);
          else
            v_sampled_bit := CAN_RX;
          end if;

          if v_sampled_bit /= s_sampled_bit then
            s_recessive_bit_count <= (others => '0');
            s_dominant_bit_count  <= (others => '0');
          end if;

          if v_sampled_bit = '1' then
            s_recessive_bit_count <= s_recessive_bit_count + 1;
          else
            s_dominant_bit_count <= s_dominant_bit_count + 1;
          end if;

          s_sampled_bit         <= v_sampled_bit;
          s_output_rx_bit_pulse <= '1';
        end if;
      end if;
    end if;
  end process proc_sample_rx_bit;


  -- purpose: Output received bit value output from BTL (this module)
  -- type   : sequential
  -- inputs : CLK, RESET, s_sampled_bit, s_output_rx_bit_pulse
  -- outputs: BTL_RX_BIT_VALUE, BTL_RX_BIT_VALID
  proc_rx_bit_output : process(CLK) is
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        BTL_RX_BIT_VALID <= '0';
        BTL_RX_BIT_VALUE <= '0';
      else
        BTL_RX_BIT_VALID <= '0';

        if s_output_rx_bit_pulse = '1' then
          BTL_RX_BIT_VALID <= '1';
          BTL_RX_BIT_VALUE <= s_sampled_bit;
        end if;
      end if;
    end if;
  end process proc_rx_bit_output;


end architecture rtl;
