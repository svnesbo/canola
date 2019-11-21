-------------------------------------------------------------------------------
-- Title      : Receive FSM for CAN frames
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_frame_rx_fsm.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-06
-- Last update: 2019-11-21
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Rx FSM for the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-07-06  1.0      svn     Created
-------------------------------------------------------------------------------

-- TODO: Indicate in some way from tx_fsm that a message originated from us and
--       not an different node on the bus
-- TODO: Error handling
--       * Active Error Flag
--       * Passive Error Flag
--       * Error delimiter?
--       When are they used? Who issues them?
--       What happens when received CRC does not match calculated CRC in receiver?
--         - Besides not issuing ACK, what does the receiver do?
--       See 7.1 in Bosch CAN specification
-- TODO: RX_ACTIVE check..
--       Technically the BSP should not just detect that Rx is not active anymore,
--       I should get a bit stuff error if I receive too many bits of same value.
--       Maybe look for bit stuff error instead of RX_ACTIVE?

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.can_pkg.all;

entity can_frame_rx_fsm is
  generic (
    G_BUS_REG_WIDTH : natural;
    G_ENABLE_EXT_ID : boolean);
  port (
    CLK               : in  std_logic;
    RESET             : in  std_logic;
    RX_MSG_OUT        : out can_msg_t;
    RX_MSG_VALID      : out std_logic;
    TX_ARB_WON        : in  std_logic;  -- Tx FSM signal that we are transmitting and won arbitration
    INTER_FRAME_SPACE : out std_logic;  -- Indicates that we are in inter frame
                                        -- space, should not transmit
                                        -- Todo: Rx FSM follows Tx FSM, so Rx
                                        -- FSM could easily monitor IFS after
                                        -- Tx and Rx.
                                        -- Rx FSM can also be made to monitor
                                        -- incoming error flags, and give out
                                        -- IFS after error flags.

    -- Signals to/from BSP
    BSP_RX_ACTIVE             : in  std_logic;
    BSP_RX_DATA               : in  std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_RX_DATA_COUNT         : in  natural range 0 to C_BSP_DATA_LENGTH;
    BSP_RX_DATA_CLEAR         : out std_logic;
    BSP_RX_DATA_OVERFLOW      : in  std_logic;
    BSP_RX_BIT_DESTUFF_EN     : out std_logic;  -- Enable bit destuffing on data
                                                -- that is currently being received
    BSP_RX_STOP               : out std_logic;  -- Tell BSP to stop we've got EOF
    BSP_RX_CRC_CALC           : in  std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_RX_SEND_ACK           : out std_logic;

    BSP_RX_ACTIVE_ERROR_FLAG  : out std_logic;  -- Active error flag received
    BSP_RX_PASSIVE_ERROR_FLAG : out std_logic;  -- Passive error flag received
    BSP_SEND_ERROR_FLAG       : out std_logic;  -- When pulsed, BSP cancels
                                                -- whatever it is doing, and sends
                                                -- an error flag of 6 bits

    -- Counter registers for FSM
    REG_MSG_RECV_COUNT    : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_CRC_ERROR_COUNT   : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_FORM_ERROR_COUNT  : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_STUFF_ERROR_COUNT : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0)
    );

end entity can_frame_rx_fsm;

architecture rtl of can_frame_rx_fsm is

  type can_frame_rx_fsm_t is (ST_IDLE,
                              ST_RECV_SOF,
                              ST_RECV_ID_A,
                              ST_RECV_SRR_RTR,
                              ST_RECV_IDE,
                              ST_RECV_ID_B,
                              ST_RECV_EXT_FRAME_RTR,
                              ST_RECV_R1,
                              ST_RECV_R0,
                              ST_RECV_DLC,
                              ST_RECV_DATA,
                              ST_RECV_CRC,
                              ST_RECV_CRC_DELIM,
                              ST_SEND_RECV_ACK,
                              ST_RECV_ACK_DELIM,
                              ST_RECV_EOF,
                              ST_CRC_ERROR,
                              ST_STUFF_ERROR,
                              ST_FORM_ERROR,
                              ST_DONE,
                              ST_WAIT_BUS_IDLE);

  signal s_fsm_state        : can_frame_rx_fsm_t;
  signal s_reg_rx_msg       : can_msg_t;
  signal s_srr_rtr_bit      : std_logic;
  signal s_crc_mismatch     : std_logic;
  signal s_crc_calc         : std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
  signal s_bsp_data_cleared : std_logic;
  signal s_reg_tx_arb_won   : std_logic;

  signal s_reg_msg_recv_counter   : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_crc_error_counter  : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_form_error_counter : unsigned(G_BUS_REG_WIDTH-1 downto 0);



begin  -- architecture rtl

  REG_MSG_RECV_COUNT   <= std_logic_vector(s_reg_msg_recv_counter);
  REG_CRC_ERROR_COUNT  <= std_logic_vector(s_reg_crc_error_counter);
  REG_FORM_ERROR_COUNT <= std_logic_vector(s_reg_form_error_counter);

  RX_MSG_OUT           <= s_reg_rx_msg;

  proc_fsm : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      if RESET = '1' then
        s_reg_rx_msg.arb_id         <= (others => '0');
        s_reg_rx_msg.remote_request <= '0';
        s_reg_rx_msg.ext_id         <= '0';
        s_reg_rx_msg.data_length    <= (others => '0');

        for i in 0 to 7 loop
          s_reg_rx_msg.data(0) <= (others => '0');
        end loop;

        s_fsm_state                <= ST_IDLE;
        s_crc_mismatch             <= '0';
        s_reg_msg_recv_counter     <= (others => '0');
        s_reg_crc_error_counter    <= (others => '0');
        s_reg_form_error_counter   <= (others => '0');
        BSP_RX_BIT_DESTUFF_EN      <= '1';
        BSP_RX_STOP                <= '0';
        RX_MSG_VALID               <= '0';
      else
        RX_MSG_VALID          <= '0';
        BSP_RX_SEND_ACK       <= '0';
        BSP_RX_DATA_CLEAR     <= '0';
        BSP_SEND_ERROR_FLAG   <= '0';
        BSP_RX_BIT_DESTUFF_EN <= '1';
        BSP_RX_STOP           <= '0';

        -- Tx FSM is transmitting message, and won arbitration
        if TX_ARB_WON = '1' then
          s_reg_tx_arb_won <= '1';
        end if;

        case s_fsm_state is
          when ST_IDLE =>
            s_crc_mismatch <= '0';

            -- Clear flag from Tx FSM
            s_reg_tx_arb_won <= '0';

            if BSP_RX_ACTIVE = '1' then
              BSP_RX_DATA_CLEAR <= '1';
              s_fsm_state       <= ST_RECV_SOF;
            end if;

          when ST_RECV_SOF =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0) = C_SOF_VALUE then
                s_fsm_state <= ST_RECV_ID_A;
              else
                s_fsm_state <= ST_FORM_ERROR;
              end if;
            end if;

          when ST_RECV_ID_A =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = C_ID_A_LENGTH and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR                             <= '1';
              s_reg_rx_msg.arb_id(C_ID_A_LENGTH-1 downto 0) <= BSP_RX_DATA(0 to C_ID_A_LENGTH-1);
              s_fsm_state                                   <= ST_RECV_SRR_RTR;
            end if;

          when ST_RECV_SRR_RTR =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';
              s_srr_rtr_bit     <= BSP_RX_DATA(0);
              s_fsm_state       <= ST_RECV_IDE;
            end if;

          when ST_RECV_IDE =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0) = C_IDE_EXT_VALUE then
                s_reg_rx_msg.ext_id <= '1';

                -- The previous bit is RTR for standard frame,
                -- and SRR for extended frame. SRR must have value 1 (recessive)
                if s_srr_rtr_bit /= C_SRR_VALUE then
                  s_fsm_state <= ST_FORM_ERROR;
                else
                  s_fsm_state <= ST_RECV_ID_B;
                end if;
              else
                -- Standard frame
                s_reg_rx_msg.ext_id         <= '0';
                s_reg_rx_msg.remote_request <= s_srr_rtr_bit;
                s_fsm_state                 <= ST_RECV_R0;
              end if;
            end if;

          when ST_RECV_ID_B =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = C_ID_B_LENGTH and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              s_reg_rx_msg.arb_id(C_ID_B_LENGTH+C_ID_A_LENGTH-1 downto C_ID_A_LENGTH) <=
                BSP_RX_DATA(0 to C_ID_B_LENGTH-1);

              s_fsm_state <= ST_RECV_EXT_FRAME_RTR;
            end if;

          when ST_RECV_EXT_FRAME_RTR =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR           <= '1';
              s_reg_rx_msg.remote_request <= BSP_RX_DATA(0);
              s_fsm_state                 <= ST_RECV_R1;
            end if;

          when ST_RECV_R1 =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0) /= C_R1_VALUE then
                s_fsm_state <= ST_FORM_ERROR;
              else
                s_fsm_state <= ST_RECV_R0;
              end if;
            end if;

          when ST_RECV_R0 =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0) /= C_R0_VALUE then
                s_fsm_state <= ST_FORM_ERROR;
              else
                s_fsm_state <= ST_RECV_DLC;
              end if;
            end if;

          when ST_RECV_DLC =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;

            elsif BSP_RX_DATA_COUNT = C_DLC_LENGTH and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if unsigned(BSP_RX_DATA(0 to C_DLC_LENGTH-1)) > C_DLC_MAX_VALUE then
                -- The DLC field is 4 bits and can technically represent values
                -- up to 15, but 8 is the maximum according to CAN bus specification
                s_fsm_state <= ST_FORM_ERROR;
              else
                s_reg_rx_msg.data_length <= BSP_RX_DATA(0 to C_DLC_LENGTH-1);

                if s_reg_rx_msg.remote_request = '1' then
                  s_crc_calc  <= BSP_RX_CRC_CALC;
                  s_fsm_state <= ST_RECV_CRC;
                else
                  s_fsm_state <= ST_RECV_DATA;
                end if;
              end if;
            end if;

          when ST_RECV_DATA =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = unsigned(s_reg_rx_msg.data_length)*8 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              s_reg_rx_msg.data(0) <= BSP_RX_DATA(0 to 7);
              s_reg_rx_msg.data(1) <= BSP_RX_DATA(8 to 15);
              s_reg_rx_msg.data(2) <= BSP_RX_DATA(16 to 23);
              s_reg_rx_msg.data(3) <= BSP_RX_DATA(24 to 31);
              s_reg_rx_msg.data(4) <= BSP_RX_DATA(32 to 39);
              s_reg_rx_msg.data(5) <= BSP_RX_DATA(40 to 47);
              s_reg_rx_msg.data(6) <= BSP_RX_DATA(48 to 55);
              s_reg_rx_msg.data(7) <= BSP_RX_DATA(56 to 63);

              s_crc_calc  <= BSP_RX_CRC_CALC;
              s_fsm_state <= ST_RECV_CRC;
            end if;

          when ST_RECV_CRC =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;

              -- 15-bit CRC
            elsif BSP_RX_DATA_COUNT = C_CAN_CRC_WIDTH and BSP_RX_DATA_CLEAR = '0' then
              if BSP_RX_DATA(0 to C_CAN_CRC_WIDTH-1) /= s_crc_calc then
                s_crc_mismatch <= '1';
              else
                s_crc_mismatch <= '0';
              end if;

              BSP_RX_DATA_CLEAR <= '1';
              s_fsm_state       <= ST_RECV_CRC_DELIM;
            end if;

          when ST_RECV_CRC_DELIM =>
            -- No bit stuffing for CRC delimiter
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0) /= C_CRC_DELIM_VALUE then
                s_fsm_state <= ST_FORM_ERROR;
              else
                -- Send ACK only if CRC was ok
                if s_crc_mismatch = '0' then
                  if s_reg_tx_arb_won = '0' then
                    -- If arbitration was not won, we are receiving this message
                    -- from a different node, and should always acknowledge
                    -- However, if arbitration was won then we are transmitting
                    -- this message ourselves, and should not acknowledge our
                    -- own message.

                    -- Pulsing this signal makes the BSP send an ack pulse
                    BSP_RX_SEND_ACK <= '1';
                  end if;
                end if;

                -- CAN specification part B - 7.2 Error Signaling
                -- Send error flag following ACK delimiter on CRC error,
                -- so we have to wait for the ack and ack delimiters
                -- regardless of CRC status
                s_fsm_state     <= ST_SEND_RECV_ACK;
              end if;
            end if;

          when ST_SEND_RECV_ACK =>
            -- No bit stuffing for ACK slot
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if s_crc_mismatch = '0' and BSP_RX_DATA(0) /= C_ACK_VALUE then
                if s_reg_tx_arb_won = '0' then
                  -- Did we try to send ACK, but did not read ACK value back?
                  -- Todo: What kind of error is that? Form error?
                  s_fsm_state <= ST_FORM_ERROR;
                else
                  -- In this case we were transmitting this message ourselves,
                  -- and did not send out ACK, so we proceed as normal and let
                  -- the Tx FSM handle ACK error.
                  s_fsm_state <= ST_RECV_ACK_DELIM;
                end if;
              else
                s_fsm_state <= ST_RECV_ACK_DELIM;
              end if;
            end if;

          when ST_RECV_ACK_DELIM =>
            -- No bit stuffing for EOF (End of Frame)
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              if s_crc_mismatch = '1' then
                -- CAN specification part B - 7.2 Error Signaling
                -- Send error flag following ACK delimiter on CRC error,
                s_fsm_state <= ST_CRC_ERROR;
              elsif BSP_RX_DATA(0) /= C_ACK_DELIM_VALUE then
                if s_reg_tx_arb_won = '0' then
                  -- Did we try to send ACK, but did not read ACK value back?
                  -- Todo: What kind of error is that? Form error?
                  s_fsm_state <= ST_FORM_ERROR;
                else
                  -- In this case we were transmitting this message ourselves,
                  -- and did not send out ACK, so we proceed as normal and let
                  -- the Tx FSM handle ACK error.
                  s_fsm_state <= ST_RECV_EOF;
                end if;
              else
                s_fsm_state <= ST_RECV_EOF;
              end if;
            end if;

          when ST_RECV_EOF =>
            -- No bit stuffing for EOF (End of Frame)
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = C_EOF_LENGTH and BSP_RX_DATA_CLEAR = '0' then
              BSP_RX_DATA_CLEAR <= '1';

              -- Note: Last bit of EOF is don't care for the receiver
              -- See CAN specification 2.0B: 5 Message Validation
              if BSP_RX_DATA(0 to C_EOF_LENGTH-2) /= C_EOF(0 to C_EOF_LENGTH-2) then
                -- Is this a form error?
                s_fsm_state <= ST_FORM_ERROR;
              else
                s_fsm_state <= ST_DONE;
              end if;
            end if;

          when ST_CRC_ERROR =>
            -- Todo:
            -- Increase CRC error count
            -- Increase receive error count
            -- Send error flag
            BSP_RX_STOP <= '1';
            s_fsm_state <= ST_IDLE;

          -- Error handling summary:
          --
          -- Page 50: https://www.nxp.com/docs/en/reference-manual/BCANPSV2.pdf
          -- "A node detecting an error condition signals this by transmitting an Error flag. An error-active node
          --  will transmit an ACTIVE Error flag; an error-passive node will transmit a PASSIVE Error flag.
          --  Whenever a Bit error, a Stuff error, a Form error or an Acknowledgement error is detected by any
          --  node, that node will start transmission of an Error flag at the next bit time.
          --  Whenever a CRC error is detected, transmission of an Error flag will start at the bit following the
          --  ACK Delimiter, unless an Error flag for another error condition has already been started."

          when ST_FORM_ERROR =>
            if s_reg_tx_arb_won = '0' then
              -- We are receiving this message from a different node
              -- Increase receive error counters
              null;
            else
              -- We are transmitting this message ourselves
              -- Don't increase receive error counters
              null;
            end if;

            BSP_RX_STOP <= '1';
            s_fsm_state <= ST_IDLE;

            -- Form Error applies to bit errors in any fixed field from SOF to
            -- CRC delimiter.

            -- TODO:
            -- Signal error here...
            -- Increase counters...

          --when ST_CRC_ERROR =>

          when ST_STUFF_ERROR =>
            -- TODO:
            -- Handle this error
            BSP_RX_STOP <= '1';
            s_fsm_state <= ST_IDLE;

          when ST_DONE =>
            -- Don't output messages we were transmitting ourselves
            -- (ie. when arbitration was won)
            if s_reg_tx_arb_won = '0' then
              -- Pulsed one cycle
              RX_MSG_VALID           <= '1';
              s_reg_msg_recv_counter <= s_reg_msg_recv_counter + 1;
            end if;

            s_fsm_state            <= ST_WAIT_BUS_IDLE;

          when ST_WAIT_BUS_IDLE =>
            -- TODO:
            -- Handle this differently..
            -- I have a state in BSP that handles IFS now, and a signal for it
            if BSP_RX_ACTIVE = '0' then
              s_fsm_state <= ST_IDLE;
            end if;

          when others =>
            s_fsm_state <= ST_IDLE;

        end case;

        -- Special handling of error flags and stuff errors
        if s_fsm_state /= ST_IDLE then
          -- Stuff errors are detected by looking for error flags while we
          -- are receiving parts of a frame that should be bit stuffed
          if BSP_RX_BIT_DESTUFF_EN = '1' and
            (BSP_RX_ACTIVE_ERROR_FLAG = '1' or BSP_RX_PASSIVE_ERROR_FLAG = '1')
          then
            s_fsm_state <= ST_STUFF_ERROR;
          end if;
        end if;

      end if;
    end if;
  end process proc_fsm;

end architecture rtl;
