-------------------------------------------------------------------------------
-- Title      : Bit Stream Processor (BSP) for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_bsp.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-01
-- Last update: 2019-11-15
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Bit Stream Processor (BSP) for the Canola CAN controller
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

library work;
use work.can_pkg.all;

-- TODO: Rename all ports that are pulses so they have _PULSE extension?
--       .. do I want this?
--       Suggestion:
--       - Top level CANbus entity has _PULSE extensions
--       - Other entities in the hierarchy does not use them
-- TODO: Implement BSP_SEND_ERROR_FRAME and BSP_ERROR_STATE
--       * Actually, I could have two inputs:
--         - BSP_SEND_PASSIVE_ERROR_FLAG (six recessive bits)
--         - BSP_SEND_ACTIVE_ERROR_FLAG (six dominant bits)
--       * Or, alternatively, two inputs like this:
--         - BSP_SEND_ERROR_FLAG
--         - BSP_ERROR_STATE (active or passive error state)
--         Error state is then defined globally (both rx and tx firmware
--         knows about it), and BSP sends recessive or dominant when it
--         gets BSP_SEND_ERROR_FLAG based on BSP_ERROR_STATE input.
--       I think I like the second approach better..
--       Then the Rx FSM can just say I want to send an Error Flag when
--       there is a CRC mismatch (I think it should send error flag then?),
--       and it is controlled "globally" (or by some error module) if this
--       should be an active or passive error flag.
-- TODO: BSP should output and look for bit stuff errors?
-- TODO: BSP should detect Error Flags?

-- To send some data on the Tx interface:
--  * Hold BSP_TX_WRITE_EN low.
--  * Setup BSP_TX_DATA with a stream of data, starting at index 0.
--  * Setup BSP_TX_DATA_COUNT with number of bits in BSP_TX_DATA to send
--  * Set BSP_TX_WRITE_EN high, and hold it high until the BSP indicates that all
--    bits have been sent with the BSP_TX_DONE output.
-- If a received bit does not match the bit to be transmitted, the BSP_TX_MISMATCH
-- output goes high. Transmission can then be aborted by setting BSP_TX_WRITE_EN low immediately.
--
-- To receive data on the Rx interface:
--  * BSP_RX_ACTIVE goes high when the BTL has synced to an incoming CAN
--    message and is receiving
--  * For the BSP to search for and discard stuff bits, BSP_RX_BIT_DESTUFF_EN
--    must be set high
--  * The BSP shifts in data bit by bit, and makes them available at BSP_RX_DATA (LSB first)
--    BSP_RX_DATA_COUNT reflects the number of bits available in BSP_RX_DATA.
--  * The data received in BSP_RX_DATA can be cleared by pulsing
--    BSP_RX_DATA_CLEAR high for one clock cycle
--  * BSP_RX_CRC_CALC outputs the CRC that is calculated for the frame, and is
--    updated for each incoming bit. The CRC value is automatically reset at
--    the beginning of each received frame.
--  * To acknowledge an incoming message, BSP_RX_SEND_ACK_PULSE should be
--    pulsed high for a clock cycle immediately after the bit before the ACK
--    slot has been received

entity can_bsp is
  port (
    CLK   : in std_logic;
    RESET : in std_logic;

    -- Interface to Tx FSM
    BSP_TX_DATA              : in  std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_TX_DATA_COUNT        : in  natural range 0 to C_BSP_DATA_LENGTH;
    BSP_TX_WRITE_EN          : in  std_logic;
    BSP_TX_BIT_STUFF_EN      : in  std_logic;  -- Enable bit stuffing on current data
    BSP_TX_RX_MISMATCH       : out std_logic;  -- Mismatch Tx and Rx. Also used
                                               -- for ACK detection
    BSP_TX_RX_STUFF_MISMATCH : out std_logic;  -- Mismatch Tx and Rx for stuff bit
    BSP_TX_DONE              : out std_logic;
    BSP_TX_CRC_CALC          : out std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_TX_ACTIVE            : in  std_logic;  -- Resets bit stuff counter and CRC

    -- Interface to Rx FSM
    BSP_RX_ACTIVE          : out std_logic;
    BSP_RX_DATA            : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_RX_DATA_COUNT      : out natural range 0 to C_BSP_DATA_LENGTH;
    BSP_RX_DATA_CLEAR      : in  std_logic;
    BSP_RX_DATA_OVERFLOW   : out std_logic;
    BSP_RX_BIT_DESTUFF_EN  : in  std_logic;  -- Enable bit destuffing on data
                                             -- that is currently being received
    BSP_RX_BIT_STUFF_ERROR : out std_logic;  -- Pulsed on error
    BSP_RX_CRC_CALC        : out std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_RX_SEND_ACK        : in  std_logic;  -- Pulsed input

    BSP_SEND_ERROR_FLAG    : in  std_logic;  -- When pulsed, BSP cancels
                                             -- whatever it is doing, and sends
                                             -- an error flag. The type of flag
                                             -- depends on BSP_ERROR_STATE input
    BSP_ERROR_FLAG_DONE      : out std_logic; -- Pulsed
    BSP_ERROR_FLAG_BIT_ERROR : out std_logic; -- Bit error was detected while
                                              -- transmitting error flag
                                              -- Note: Only for ACTIVE error flag
    BSP_ERROR_STATE : in can_error_state_t;  -- Indicates if the CAN controller
                                             -- is in active or passive error
                                             -- state, or bus off state

    -- Interface to BTL
    BTL_TX_BIT_VALUE           : out std_logic;
    BTL_TX_BIT_VALID           : out std_logic;
    BTL_TX_RDY                 : in  std_logic;
    BTL_TX_DONE                : in  std_logic;
    BTL_RX_BIT_VALUE           : in  std_logic;
    BTL_RX_BIT_VALID           : in  std_logic;
    BTL_RX_SYNCED              : in  std_logic);

end entity can_bsp;

architecture rtl of can_bsp is
  -----------------------------------------------------------------------------
  -- Rx process signals
  -----------------------------------------------------------------------------
  signal s_rx_bit                : std_logic;
  signal s_rx_bit_valid_pulse    : std_logic;
  signal s_rx_restart_crc_pulse  : std_logic;
  signal s_rx_stuff_counter      : natural range 0 to C_STUFF_BIT_THRESHOLD+1;
  signal s_rx_data_counter       : natural range 0 to C_BSP_DATA_LENGTH;
  signal s_rx_previous_bit_val   : std_logic;

  -- Indicates that next bit should be a stuff bit
  signal s_rx_stuff_bit_expected : std_logic;


  -----------------------------------------------------------------------------
  -- Tx process signals
  -----------------------------------------------------------------------------
  signal s_tx_write_counter      : natural range 0 to C_BSP_DATA_LENGTH;
  signal s_tx_stuff_counter      : natural range 0 to C_STUFF_BIT_THRESHOLD+1;
  signal s_tx_restart_crc_pulse  : std_logic;
  signal s_tx_active_reg         : std_logic;
  signal s_tx_bit_sent           : std_logic;
  signal s_tx_bit_queued         : std_logic;
  signal s_tx_stuff_bit_sent     : std_logic;
  signal s_tx_stuff_bit_queued   : std_logic;
  signal s_tx_rx_mismatch_flag   : std_logic;

  -- Indicates that we are ready to send next bit.
  -- Initially high when setting up BSP for a chunk of data,
  -- and goes high every time a bit has been fully transmitted and read back
  signal s_tx_bit_rdy            : std_logic;

  signal s_send_ack              : std_logic;


begin  -- architecture rtl

  proc_rx : process(CLK) is
    variable v_rx_stuff_counter        : natural range 0 to C_STUFF_BIT_THRESHOLD+1;
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      BSP_RX_BIT_STUFF_ERROR <= '0';
      s_rx_bit_valid_pulse   <= '0';
      s_rx_restart_crc_pulse <= '0';

      if RESET = '1' then
        BSP_RX_DATA             <= (others => '0');
        BSP_RX_DATA_COUNT       <= 0;
        s_rx_data_counter       <= 0;
        s_rx_stuff_bit_expected <= '0';
        BSP_RX_DATA_OVERFLOW    <= '0';
        BSP_RX_ACTIVE           <= '0';

        -- Start at zero when we haven't received any bits yet
        s_rx_stuff_counter <= 0;
      else
        if BSP_RX_DATA_CLEAR = '1' then
          BSP_RX_DATA_COUNT      <= 0;
          s_rx_data_counter      <= 0;
        else
          -- This delays data count output by one cycle,
          -- which allows data count output to be in sync with CRC output
          BSP_RX_DATA_COUNT      <= s_rx_data_counter;
        end if;
        -----------------------------------------------------------------------
        -- BTL synchronized to start of frame
        -----------------------------------------------------------------------
        if BTL_RX_SYNCED = '1' and BSP_RX_ACTIVE = '0' then
          BSP_RX_ACTIVE           <= '1';
          BSP_RX_DATA             <= (others => '0');
          BSP_RX_DATA_COUNT       <= 0;
          s_rx_data_counter       <= 0;
          s_rx_stuff_bit_expected <= '0';
          BSP_RX_DATA_OVERFLOW    <= '0';
          s_rx_restart_crc_pulse  <= '1';

          -- Start at zero when we haven't received any bits yet
          s_rx_stuff_counter <= 0;

        -----------------------------------------------------------------------
        -- Receiving data for frame
        -----------------------------------------------------------------------
        elsif BSP_RX_ACTIVE = '1' and BTL_RX_BIT_VALID = '1' then
          v_rx_stuff_counter     := s_rx_stuff_counter;

          ---------------------------------------------------------------------
          -- Consecutive bit count and stuff bit detection
          ---------------------------------------------------------------------
          --if BSP_RX_BIT_DESTUFF_EN = '1' then
          if s_rx_previous_bit_val = BTL_RX_BIT_VALUE then
            if s_rx_stuff_bit_expected = '1' then
              -- Bit stuffing error.
              -- Already got 5 consecutive bits of same value,
              -- was expecting a stuff bit of opposite polarity
              BSP_RX_BIT_STUFF_ERROR <= '1';
            elsif BSP_RX_BIT_DESTUFF_EN = '1' then
              v_rx_stuff_counter := v_rx_stuff_counter + 1;
            end if;
          else
            -- Got bit of opposite polarity, reset stuff counter.
            -- Start at one, because we have one bit already.
            v_rx_stuff_counter := 1;
          end if;

          if v_rx_stuff_counter = C_STUFF_BIT_THRESHOLD and BSP_RX_BIT_DESTUFF_EN = '1' then
            s_rx_stuff_bit_expected <= '1';
          end if;

          s_rx_stuff_counter    <= v_rx_stuff_counter;
          s_rx_previous_bit_val <= BTL_RX_BIT_VALUE;

          ---------------------------------------------------------------------
          -- Shift bits into shift register as they are received
          ---------------------------------------------------------------------
          if s_rx_stuff_bit_expected = '0' then
            if s_rx_data_counter < C_BSP_DATA_LENGTH then
              BSP_RX_DATA(s_rx_data_counter) <= BTL_RX_BIT_VALUE;
              s_rx_data_counter              <= s_rx_data_counter+1;

              -- Used for CRC calculation
              s_rx_bit             <= BTL_RX_BIT_VALUE;
              s_rx_bit_valid_pulse <= '1';
            else
              BSP_RX_DATA_OVERFLOW <= '1';
            end if;
          ---------------------------------------------------------------------
          -- Ignore stuff bits
          ---------------------------------------------------------------------
          elsif s_rx_stuff_bit_expected = '1' then
            s_rx_stuff_bit_expected <= '0';
          end if;

        -----------------------------------------------------------------------
        -- End of frame
        -----------------------------------------------------------------------
        elsif BTL_RX_SYNCED = '0' then
          BSP_RX_ACTIVE     <= '0';
        end if;
      end if; -- RESET = '0'
    end if; -- rising_edge(CLK)
  end process proc_rx;



  proc_tx : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      if RESET = '1' then
        s_tx_write_counter       <= 0;
        s_tx_stuff_counter       <= 0;
        s_tx_restart_crc_pulse   <= '1';
        s_tx_bit_sent            <= '0';
        s_tx_bit_queued          <= '0';
        s_tx_stuff_bit_sent      <= '0';
        s_tx_stuff_bit_queued    <= '0';
        s_tx_rx_mismatch_flag    <= '0';
        s_send_ack               <= '0';
        BTL_TX_BIT_VALUE         <= '1'; -- Recessive
        BTL_TX_BIT_VALID         <= '0';
        BSP_TX_RX_MISMATCH       <= '0';
        BSP_TX_RX_STUFF_MISMATCH <= '0';
        BSP_TX_DONE              <= '0';
      else
        BTL_TX_BIT_VALID         <= '0';
        BSP_TX_RX_MISMATCH       <= '0';
        BSP_TX_RX_STUFF_MISMATCH <= '0';
        BSP_TX_DONE              <= '0';
        s_tx_restart_crc_pulse   <= '0';

        if BSP_RX_SEND_ACK = '1' then
          -- Persistant signal, BSP_RX_SEND_ACK is pulsed
          -- and controlled by the Rx FSM
          s_send_ack <= '1';
        end if;

        s_tx_active_reg <= BSP_TX_ACTIVE;

        -- Reset stuff counter and CRC calculator at start of transmission
        if BSP_TX_ACTIVE = '1' and s_tx_active_reg = '0' then
          s_tx_stuff_counter     <= 0;
          s_tx_restart_crc_pulse <= '1';
        end if;

        -- Prepare for next chunk of data when BSP_TX_WRITE_EN goes low
        if BSP_TX_WRITE_EN = '0' then
          s_tx_write_counter    <= 0;
          s_tx_bit_rdy          <= '1';
          s_tx_bit_sent         <= '0';
          s_tx_bit_queued       <= '0';
          s_tx_stuff_bit_sent   <= '0';
          s_tx_stuff_bit_queued <= '0';
          s_tx_rx_mismatch_flag <= '0';
        end if;

        if s_send_ack = '1' then
          -- Acknowledge a received frame by asserting ACK
          if BTL_TX_RDY = '1' then
            BTL_TX_BIT_VALUE <= C_ACK_VALUE;
            BTL_TX_BIT_VALID <= '1';
            s_send_ack       <= '0';
          end if;
        elsif BSP_TX_WRITE_EN = '1' and s_tx_active_reg = '1' and s_tx_rx_mismatch_flag = '0' then
          -- Stop writing data when immediately when Tx/Rx mismatch is detected,
          -- as Tx FSM will not have sufficient time to signal to deassert
          -- TX_ACTIVE and TX_WRITE_EN before next bit is sent to BTL by BSP

          if s_tx_write_counter < BSP_TX_DATA_COUNT then
            if BTL_TX_RDY = '1' and s_tx_bit_rdy = '1' then
              if BSP_TX_BIT_STUFF_EN = '1' and s_tx_stuff_counter = C_STUFF_BIT_THRESHOLD then
                -- The CAN protocol requires a transition after 5 bits of same
                -- value, by inserting a "stuff bit" of opposite value, even if
                -- the next bit in the stream would have a transition,
                -- The stuff bits are also included in this 5-bit count
                -- of consecutive bits with same value
                -- The bit stuffing is not performed for the EOF etc. of the
                -- CAN frame, so the Tx FSM is responsible for setting
                -- BSP_TX_BIT_STUFF_EN low for these parts of the message.
                BTL_TX_BIT_VALUE      <= not BTL_TX_BIT_VALUE;
                BTL_TX_BIT_VALID      <= '1';
                s_tx_stuff_counter    <= 1;
                s_tx_stuff_bit_queued <= '1';
                s_tx_bit_rdy          <= '0';
              else
                -- BTL_TX_BIT_VALUE should still hold the previous bit value at this point..
                if BTL_TX_BIT_VALUE = BSP_TX_DATA(s_tx_write_counter) and BSP_TX_BIT_STUFF_EN = '1' then
                  -- Increase "stuff counter" when we transmit
                  -- consecutive bits of the same value
                  s_tx_stuff_counter <= s_tx_stuff_counter + 1;
                else
                  s_tx_stuff_counter <= 1;
                end if;

                BTL_TX_BIT_VALUE <= BSP_TX_DATA(s_tx_write_counter);
                BTL_TX_BIT_VALID <= '1';
                s_tx_bit_queued  <= '1';
                s_tx_bit_rdy     <= '0';
              end if;
            end if;

            if BTL_TX_DONE = '1' then
              if s_tx_bit_queued = '1' then
                s_tx_bit_queued <= '0';
                s_tx_bit_sent   <= '1';

              elsif s_tx_stuff_bit_queued = '1' then
                s_tx_stuff_bit_queued <= '0';
                s_tx_stuff_bit_sent   <= '1';
              end if;
            end if;


            if s_tx_bit_sent = '1' and BTL_RX_BIT_VALID = '1' then
              -- Did we receive the same bit we transmitted previously?
              if BTL_TX_BIT_VALUE /= BTL_RX_BIT_VALUE then
                BSP_TX_RX_MISMATCH    <= '1';
                BSP_TX_DONE           <= '1';
                s_tx_rx_mismatch_flag <= '1';
              end if;

              s_tx_bit_sent      <= '0';
              s_tx_bit_rdy       <= '1';
              s_tx_write_counter <= s_tx_write_counter + 1;

            elsif s_tx_stuff_bit_sent = '1' and BTL_RX_BIT_VALID = '1' then
              -- Did we receive the same bit we transmitted?
              if BTL_TX_BIT_VALUE /= BTL_RX_BIT_VALUE then
                BSP_TX_RX_STUFF_MISMATCH <= '1';
                BSP_TX_DONE              <= '1';
                s_tx_rx_mismatch_flag    <= '1';
              end if;

              s_tx_stuff_bit_sent <= '0';
              s_tx_bit_rdy        <= '1';
            end if;
          elsif s_tx_bit_rdy = '1' then
            -- s_tx_write_counter has reached BSP_TX_DATA_COUNT,
            -- and we are done transmitting and reading back the last bit
            BSP_TX_DONE       <= '1';
          end if;
        end if; -- BSP_TX_WRITE_EN = '1' and s_tx_active_reg = '1'
      end if; -- if/else RESET = '0'
    end if; -- rising_edge(CLK)
  end process proc_tx;


  INST_can_crc_rx: entity work.can_crc
    port map (
      CLK       => CLK,
      RESET     => RESET or s_rx_restart_crc_pulse,
      BIT_IN    => s_rx_bit,
      BIT_VALID => s_rx_bit_valid_pulse,
      CRC_OUT   => BSP_RX_CRC_CALC);

  INST_can_crc_tx: entity work.can_crc
    port map (
      CLK       => CLK,
      RESET     => RESET or s_tx_restart_crc_pulse,
      BIT_IN    => BTL_TX_BIT_VALUE,
      BIT_VALID => BTL_TX_BIT_VALID and s_tx_bit_queued,
      CRC_OUT   => BSP_TX_CRC_CALC);

end architecture rtl;
