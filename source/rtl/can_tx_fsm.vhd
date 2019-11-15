-------------------------------------------------------------------------------
-- Title      : Transmit FSM for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_tx_fsm.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-06-26
-- Last update: 2019-11-15
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Tx FSM for the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-06-26  1.0      svn     Created
-------------------------------------------------------------------------------

-- TODO: I think it should be Bit Error (not Form Error) when the monitored bit
--       does not match the transmitted bit in the node that is transmitting.
--       See section 7 Error Handling in Bosch CAN specification.
-- TODO: Acknowledgement Error: When no ACK is detected, we should attempt to
--       retransmit for a certain number of times. After too many failed
--       I think the transmitter has to be silent for a while (it assumes
--       that it is faulty and does not want to be holding the bus)
-- TODO: Error Active vs. Error Passive:
--       There should be two states, error active and error passive. Initially
--       a node is in error active state, when it detects an error it sends
--       an active error flag (six consecutive dominant bits). If it continues
--       detecting errors (reaches some count of errors), it should
--       flag/interrupt the application and give it some error warning, and
--       assume that it is faulty. At this point it goes into Error Passive
--       state, and now transmits Passive Error flag (six consecutive
--       recessive bits) on error instead.
-- TODO: I think it makes more sense that the Tx FSM sends the error flags,
--       and the BSP is very simple and just transmits whatever it is told

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.can_pkg.all;

entity can_tx_fsm is
  generic (
    G_BUS_REG_WIDTH : natural;
    G_ENABLE_EXT_ID : boolean);
  port (
    CLK                            : in  std_logic;
    RESET                          : in  std_logic;
    TX_MSG_IN                      : in  can_msg_t;
    TX_START                       : in  std_logic;  -- Start sending TX_MSG
    TX_RETRANSMIT_EN               : in  std_logic;
    TX_BUSY                        : out std_logic;  -- FSM busy
    TX_DONE                        : out std_logic;  -- Transmit complete
    TX_ACK_RECV                    : out std_logic;  -- Acknowledge was received
    TX_ARB_LOST                    : out std_logic;  -- Arbitration was lost
    TX_ARB_WON                     : out std_logic;  -- Arbitration was won (pulsed)
    TX_BIT_ERROR                   : out std_logic;  -- Mismatch transmitted vs. monitored bit
    TX_ACK_ERROR                   : out std_logic;  -- No ack received
    TX_ARB_STUFF_ERROR             : out std_logic;  -- Stuff error during arbitration field
    TX_ACTIVE_ERROR_FLAG_BIT_ERROR : out std_logic;
    TX_FAILED                      : out std_logic;  -- (Re)transmit failed (arb lost or error)
    ERROR_STATE                    : in  can_error_state_t;

    -- Signals to/from BSP
    BSP_TX_DATA                : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_TX_DATA_COUNT          : out natural range 0 to C_BSP_DATA_LENGTH;
    BSP_TX_WRITE_EN            : out std_logic;
    BSP_TX_BIT_STUFF_EN        : out std_logic;
    BSP_TX_RX_MISMATCH         : in  std_logic;
    BSP_TX_RX_STUFF_MISMATCH   : in  std_logic;
    BSP_TX_DONE                : in  std_logic;
    BSP_TX_CRC_CALC            : in  std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_TX_ACTIVE              : out std_logic;
    BSP_RX_ACTIVE              : in  std_logic;
    BSP_SEND_ERROR_FLAG        : out std_logic;
    BSP_ERROR_FLAG_DONE        : in  std_logic;
    BSP_ERROR_FLAG_BIT_ERROR   : in  std_logic;

    -- Counter registers for FSM
    REG_MSG_SENT_COUNT   : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_ACK_RECV_COUNT   : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_ARB_LOST_COUNT   : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_ERROR_COUNT      : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_RETRANSMIT_COUNT : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0)
    );

end entity can_tx_fsm;

architecture rtl of can_tx_fsm is

  type can_tx_fsm_t is (ST_IDLE,
                        ST_WAIT_FOR_BUS_IDLE,
                        ST_SETUP_SOF,
                        ST_SETUP_ID_A,
                        ST_SETUP_SRR,
                        ST_SETUP_IDE,
                        ST_SETUP_ID_B,
                        ST_SETUP_RTR,
                        ST_SETUP_R1,
                        ST_SETUP_R0,
                        ST_SETUP_DLC,
                        ST_SETUP_DATA,
                        ST_SETUP_CRC,
                        ST_SETUP_CRC_DELIM,
                        ST_SETUP_ACK_SLOT,
                        ST_SETUP_ACK_DELIM,
                        ST_SETUP_EOF,
                        ST_SETUP_ERROR_FLAG,
                        ST_SEND_SOF,
                        ST_SEND_ID_A,
                        ST_SEND_SRR,
                        ST_SEND_IDE,
                        ST_SEND_ID_B,
                        ST_SEND_RTR,
                        ST_SEND_R1,
                        ST_SEND_R0,
                        ST_SEND_DLC,
                        ST_SEND_DATA,
                        ST_SEND_CRC,
                        ST_SEND_CRC_DELIM,
                        ST_SEND_RECV_ACK_SLOT,
                        ST_SEND_ACK_DELIM,
                        ST_SEND_EOF,
                        ST_SEND_ERROR_FLAG,
                        ST_ARB_LOST,
                        ST_BIT_ERROR,
                        ST_ACK_ERROR,
                        ST_RETRANSMIT,
                        ST_DONE);

  signal s_fsm_state           : can_tx_fsm_t;
  signal s_reg_tx_msg          : can_msg_t;
  signal s_tx_ack_recv         : std_logic;
  signal s_retransmit_attempts : natural range 0 to C_RETRANSMIT_COUNT_MAX;

  signal s_reg_msg_sent_counter   : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_ack_recv_counter   : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_arb_lost_counter   : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_error_counter      : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_retransmit_counter : unsigned(G_BUS_REG_WIDTH-1 downto 0);

  alias a_tx_msg_id_a : std_logic_vector(C_ID_A_LENGTH-1 downto 0) is
    s_reg_tx_msg.arb_id(C_ID_A_LENGTH-1 downto 0);

  alias a_tx_msg_id_b : std_logic_vector(C_ID_A_LENGTH+C_ID_B_LENGTH-1 downto C_ID_A_LENGTH) is
    s_reg_tx_msg.arb_id(C_ID_A_LENGTH+C_ID_B_LENGTH-1 downto C_ID_A_LENGTH);

  alias a_tx_msg_id_a_reversed : std_logic_vector(a_tx_msg_id_a'reverse_range) is a_tx_msg_id_a;
  alias a_tx_msg_id_b_reversed : std_logic_vector(a_tx_msg_id_b'reverse_range) is a_tx_msg_id_b;

begin  -- architecture rtl

  REG_MSG_SENT_COUNT <= std_logic_vector(s_reg_msg_sent_counter);
  REG_ACK_RECV_COUNT <= std_logic_vector(s_reg_ack_recv_counter);
  REG_ARB_LOST_COUNT <= std_logic_vector(s_reg_arb_lost_counter);
  REG_ERROR_COUNT    <= std_logic_vector(s_reg_error_counter);

  proc_fsm : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      if RESET = '1' then
        s_fsm_state            <= ST_IDLE;
        TX_BUSY                <= '0';
        BSP_TX_DATA            <= (others => '0');
        BSP_TX_ACTIVE          <= '0';
        s_tx_ack_recv          <= '0';
        s_reg_msg_sent_counter <= (others => '0');
        s_reg_ack_recv_counter <= (others => '0');
        s_reg_arb_lost_counter <= (others => '0');
        s_reg_error_counter    <= (others => '0');
        s_retransmit_attempts  <= 0;
      else
        BSP_SEND_ERROR_FLAG  <= '0';
        BSP_TX_WRITE_EN      <= '0';
        BSP_TX_BIT_STUFF_EN  <= '1';
        TX_ARB_WON           <= '0';

        case s_fsm_state is
          when ST_IDLE =>
            BSP_TX_ACTIVE         <= '0';
            TX_BUSY               <= '0';
            s_tx_ack_recv         <= '0';
            s_retransmit_attempts <= 0;

            if TX_START = '1' then
              TX_BUSY       <= '1';
              TX_ACK_RECV   <= '0';
              TX_ARB_LOST   <= '0';
              s_reg_tx_msg  <= TX_MSG_IN;
              s_fsm_state   <= ST_WAIT_FOR_BUS_IDLE;
            end if;

          when ST_WAIT_FOR_BUS_IDLE =>
            -- TODO:
            -- Should there be a timeout here?
            -- Can we wait forever?
            if BSP_RX_ACTIVE = '0' then
              BSP_TX_ACTIVE <= '1';
              s_fsm_state   <= ST_SETUP_SOF;
            end if;

          when ST_SETUP_SOF =>
            BSP_TX_DATA(0)    <= C_SOF_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_SOF;

          when ST_SEND_SOF =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_ID_A;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ID_A =>
            BSP_TX_DATA(0 to C_ID_A_LENGTH-1) <= a_tx_msg_id_a_reversed;
            BSP_TX_DATA_COUNT                 <= C_ID_A_LENGTH;
            BSP_TX_WRITE_EN                   <= '1';
            s_fsm_state                       <= ST_SEND_ID_A;

          when ST_SEND_ID_A =>
            -- TODO: Check for stuff errors
            --       If
            if BSP_TX_RX_STUFF_MISMATCH = '1' then
              s_fsm_state <= ST_SEND_ERROR_FLAG;
            elsif BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_ARB_LOST;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state <= ST_SETUP_SRR;
              else
                s_fsm_state <= ST_SETUP_RTR;
              end if;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_SRR =>
            BSP_TX_DATA(0)    <= C_SRR_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_SRR;

          when ST_SEND_SRR =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_IDE;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_IDE =>
            if s_reg_tx_msg.ext_id = '1' then
              BSP_TX_DATA(0)    <= C_IDE_EXT_VALUE;
              BSP_TX_DATA_COUNT <= 1;
            else
              BSP_TX_DATA(0)    <= C_IDE_STD_VALUE;
              BSP_TX_DATA_COUNT <= 1;
            end if;

            BSP_TX_WRITE_EN <= '1';
            s_fsm_state     <= ST_SEND_IDE;

          when ST_SEND_IDE =>
            if BSP_TX_RX_MISMATCH = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state <= ST_ARB_LOST;
              else
                s_fsm_state <= ST_BIT_ERROR;
              end if;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state <= ST_SETUP_ID_B;
              else
                s_fsm_state <= ST_SETUP_R0;
              end if;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ID_B =>
            BSP_TX_DATA(0 to C_ID_B_LENGTH-1) <= a_tx_msg_id_b_reversed;
            BSP_TX_DATA_COUNT                 <= C_ID_B_LENGTH;
            BSP_TX_WRITE_EN                   <= '1';
            s_fsm_state                       <= ST_SEND_ID_B;

          when ST_SEND_ID_B =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_ARB_LOST;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_RTR;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_RTR =>
            -- At this point we have just won the arbitration,
            -- both for extended and basic ID messages
            TX_ARB_WON        <= '1';
            BSP_TX_DATA(0)    <= s_reg_tx_msg.remote_request;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_RTR;

          when ST_SEND_RTR =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state <= ST_SETUP_R1;
              else
                s_fsm_state <= ST_SETUP_IDE;
              end if;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_R1 =>
            BSP_TX_DATA(0)    <= C_R1_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_R1;

          when ST_SEND_R1 =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_R0;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_R0 =>
            BSP_TX_DATA(0)    <= C_R0_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_R0;

          when ST_SEND_R0 =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_DLC;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_DLC =>
            BSP_TX_DATA(0 to C_DLC_LENGTH-1) <= s_reg_tx_msg.data_length;
            BSP_TX_DATA_COUNT                <= C_DLC_LENGTH;
            BSP_TX_WRITE_EN                  <= '1';
            s_fsm_state                      <= ST_SEND_DLC;

          when ST_SEND_DLC =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.remote_request = '1' then
                s_fsm_state <= ST_SETUP_CRC;
              else
                s_fsm_state <= ST_SETUP_DATA;
              end if;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_DATA =>
            BSP_TX_DATA(0 to 7)   <= s_reg_tx_msg.data(0);
            BSP_TX_DATA(8 to 15)  <= s_reg_tx_msg.data(1);
            BSP_TX_DATA(16 to 23) <= s_reg_tx_msg.data(2);
            BSP_TX_DATA(24 to 31) <= s_reg_tx_msg.data(3);
            BSP_TX_DATA(32 to 39) <= s_reg_tx_msg.data(4);
            BSP_TX_DATA(40 to 47) <= s_reg_tx_msg.data(5);
            BSP_TX_DATA(48 to 55) <= s_reg_tx_msg.data(6);
            BSP_TX_DATA(56 to 63) <= s_reg_tx_msg.data(7);
            BSP_TX_DATA_COUNT     <= to_integer(unsigned(s_reg_tx_msg.data_length))*8;
            BSP_TX_WRITE_EN       <= '1';
            s_fsm_state           <= ST_SEND_DATA;

          when ST_SEND_DATA =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_CRC;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_CRC =>
            -- CRC and CRC delimiter
            BSP_TX_DATA(0 to C_CAN_CRC_WIDTH-1) <= BSP_TX_CRC_CALC;
            BSP_TX_DATA_COUNT                   <= C_CAN_CRC_WIDTH;
            BSP_TX_WRITE_EN                     <= '1';
            s_fsm_state                         <= ST_SEND_CRC;

          when ST_SEND_CRC =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_CRC_DELIM;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_CRC_DELIM =>
            -- CRC and CRC delimiter
            BSP_TX_BIT_STUFF_EN   <= '0';
            BSP_TX_DATA(0)        <= C_CRC_DELIM_VALUE;
            BSP_TX_DATA_COUNT     <= 1;
            BSP_TX_WRITE_EN       <= '1';
            s_fsm_state           <= ST_SEND_CRC_DELIM;

          when ST_SEND_CRC_DELIM =>
            BSP_TX_BIT_STUFF_EN   <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_ACK_SLOT;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ACK_SLOT =>
            BSP_TX_BIT_STUFF_EN <= '0';
            BSP_TX_DATA(0)      <= C_ACK_TRANSMIT_VALUE;
            BSP_TX_DATA_COUNT   <= 1;
            BSP_TX_WRITE_EN     <= '1';
            s_fsm_state         <= ST_SEND_RECV_ACK_SLOT;

          when ST_SEND_RECV_ACK_SLOT =>
            BSP_TX_BIT_STUFF_EN <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              -- In this case for the ACK we actually want to receive
              -- the opposite value of what we sent
              s_tx_ack_recv <= '1';
            end if;

            if BSP_TX_DONE = '1' then
              s_fsm_state     <= ST_SETUP_ACK_DELIM;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ACK_DELIM =>
            BSP_TX_BIT_STUFF_EN <= '0';
            BSP_TX_DATA(0)      <= C_ACK_DELIM_VALUE;
            BSP_TX_DATA_COUNT   <= 1;
            BSP_TX_WRITE_EN     <= '1';
            s_fsm_state         <= ST_SEND_ACK_DELIM;

          when ST_SEND_ACK_DELIM =>
            BSP_TX_BIT_STUFF_EN <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_EOF;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_EOF =>
            BSP_TX_BIT_STUFF_EN              <= '0';
            BSP_TX_DATA(0 to C_EOF_LENGTH-1) <= C_EOF;
            BSP_TX_DATA_COUNT                <= C_EOF_LENGTH;
            BSP_TX_WRITE_EN                  <= '1';
            s_fsm_state                      <= ST_SEND_EOF;

          when ST_SEND_EOF =>
            BSP_TX_BIT_STUFF_EN <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_DONE;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ERROR_FLAG =>
            -- Pulse send error flag output to BSP here
            -- UNLESS we are in BUS_OFF state
            BSP_SEND_ERROR_FLAG <= '1';
            s_fsm_state         <= ST_SEND_ERROR_FLAG;

          when ST_SEND_ERROR_FLAG =>
            if ERROR_STATE = ERROR_ACTIVE and BSP_ERROR_FLAG_BIT_ERROR = '1' then
              -- CAN specification 7.1:
              -- Bit errors while sending active error flag should be detected,
              -- and leads to an increase in transmit error count by 8 in the EML
              TX_ACTIVE_ERROR_FLAG_BIT_ERROR <= '1';
              s_fsm_state                    <= ST_RETRANSMIT;
            elsif BSP_ERROR_FLAG_DONE = '1' then
              s_fsm_state <= ST_RETRANSMIT;
            end if;

          when ST_ARB_LOST =>
            TX_ARB_LOST            <= '1';
            BSP_TX_ACTIVE          <= '0';
            s_reg_arb_lost_counter <= s_reg_arb_lost_counter + 1;
            s_fsm_state            <= ST_RETRANSMIT;

          when ST_BIT_ERROR =>
            BSP_SEND_ERROR_FLAG  <= '1';
            s_reg_error_counter  <= s_reg_error_counter + 1;
            s_fsm_state          <= ST_RETRANSMIT;

          when ST_ACK_ERROR =>
            -- Page 50: https://www.nxp.com/docs/en/reference-manual/BCANPSV2.pdf
            --"An Acknowledgement error must be detected by a transmitter whenever it does not monitor a
            -- dominant bit during ACK Slot"
            --
            -- "A node detecting an error condition signals this by transmitting an Error flag. An error-active node
            --  will transmit an ACTIVE Error flag; an error-passive node will transmit a PASSIVE Error flag.
            --  Whenever a Bit error, a Stuff error, a Form error or an Acknowledgement error is detected by any
            --  node, that node will start transmission of an Error flag at the next bit time.
            --  Whenever a CRC error is detected, transmission of an Error flag will start at the bit following the
            --  ACK Delimiter, unless an Error flag for another error condition has already been started."

            --when ST_BIT_ERROR =>
            -- Page 49: https://www.nxp.com/docs/en/reference-manual/BCANPSV2.pdf
            -- "A node which is sending a bit on the bus also monitors the bus. The node must detect, and interpret
            --  as a Bit error, the situation where the bit value monitored is different from the bit value being sent.
            --  An exception to this is the sending of a recessive bit during the stuffed bit-stream of the Arbitration
            --  field or during the ACK Slot; in this case no Bit error occurs when a dominant bit is monitored.
            --  A transmitter sending a PASSIVE Error flag and detecting a dominant bit does not interpret this
            --  as a Bit error"

          when ST_RETRANSMIT =>
            -- TODO:
            -- Find out WHEN we are allowed to retransmit.....
            -- Check CAN specification

            -- Retry transmission until retransmit count is reached
            -- TODO: Need to respect IFS etc. before retransmitting....
            if TX_RETRANSMIT_EN = '0' or s_retransmit_attempts = C_RETRANSMIT_COUNT_MAX then
              TX_FAILED   <= '1';
              s_fsm_state <= ST_IDLE;
            else
              s_reg_retransmit_counter  <= s_reg_retransmit_counter + 1;
              s_retransmit_attempts     <= s_retransmit_attempts + 1;
              s_fsm_state               <= ST_WAIT_FOR_BUS_IDLE;
            end if;

          when ST_DONE =>
            -- Increase counters, set status outputs, etc...
            -- Should I increase this when no ACK was received?
            s_reg_msg_sent_counter <= s_reg_msg_sent_counter + 1;

            BSP_TX_ACTIVE <= '0';

            if s_tx_ack_recv = '1' then
              s_reg_ack_recv_counter <= s_reg_ack_recv_counter + 1;
              TX_ACK_RECV            <= '1';
              TX_DONE                <= '1';
              s_fsm_state            <= ST_IDLE;
            else
              -- Did not receive ACK..
              -- Pulsing TX_ACTIVE allows BSP to reset CRC etc.,
              -- and prevents BTL from syncing
              s_fsm_state   <= ST_RETRANSMIT;
            end if;

        end case;
      end if;
    end if;
  end process proc_fsm;

end architecture rtl;
