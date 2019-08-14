-------------------------------------------------------------------------------
-- Title      : Transmit FSM for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_tx_fsm.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-06-26
-- Last update: 2019-08-14
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
    CLK              : in  std_logic;
    RESET            : in  std_logic;
    TX_MSG_IN        : in  can_msg_t;
    TX_START         : in  std_logic;  -- Start sending TX_MSG
    TX_BUSY          : out std_logic;  -- FSM busy
    TX_DONE          : out std_logic;  -- Transmit complete
    TX_ACK_RECV      : out std_logic;  -- Acknowledge was received
    TX_ARB_LOST      : out std_logic;  -- Arbitration was lost
    TX_ERROR         : out std_logic;  -- Error while transmitting frame
    TX_FAILED        : out std_logic;  -- (Re)transmit failed (arb lost or error)

    -- Signals to/from BSP
    BSP_TX_DATA                : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_TX_DATA_COUNT          : out natural range 0 to C_BSP_DATA_LENGTH;
    BSP_TX_WRITE_EN            : out std_logic;
    BSP_TX_BIT_STUFF_EN        : out std_logic;
    BSP_TX_RX_MISMATCH         : in  std_logic;
    BSP_TX_DONE                : out std_logic;
    BSP_TX_CRC_CALC            : out std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_TX_RESET               : in  std_logic;
    BSP_RX_ACTIVE              : in  std_logic;
    BSP_SEND_ERROR_FRAME       : out std_logic;

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
                        ST_SETUP_ACK_SLOT,
                        ST_SETUP_ACK_DELIM,
                        ST_SETUP_EOF,
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
                        ST_SEND_RECV_ACK_SLOT,
                        ST_SEND_ACK_DELIM,
                        ST_SEND_EOF,
                        ST_ARB_LOST,
                        ST_FORM_ERROR,
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
        s_tx_ack_recv          <= '0';
        s_reg_msg_sent_counter <= (others => '0');
        s_reg_ack_recv_counter <= (others => '0');
        s_reg_arb_lost_counter <= (others => '0');
        s_reg_error_counter    <= (others => '0');
        s_retransmit_attempts  <= 0;
      else
        BSP_SEND_ERROR_FRAME <= '0';
        BSP_TX_WRITE_EN      <= '0';

        case s_fsm_state is
          when ST_IDLE =>
            TX_BUSY               <= '0';
            s_tx_ack_recv         <= '0';
            s_retransmit_attempts <= 0;

            if TX_START = '1' then
              TX_BUSY      <= '1';
              TX_ACK_RECV  <= '0';
              TX_ARB_LOST  <= '0';
              s_reg_tx_msg <= TX_MSG_IN;
              s_fsm_state  <= ST_WAIT_FOR_BUS_IDLE;
            end if;

          when ST_WAIT_FOR_BUS_IDLE =>
            -- TODO:
            -- Should there be a timeout here?
            -- Can we wait forever?
            if BSP_RX_ACTIVE = '0' then
              s_fsm_state <= ST_SEND_SOF;
            end if;

          when ST_SETUP_SOF =>
            BSP_TX_DATA(0)    <= C_SOF_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_SOF;

          when ST_SEND_SOF =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_FORM_ERROR;
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
            if BSP_TX_RX_MISMATCH = '1' then
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
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_IDE;
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
                s_fsm_state <= ST_FORM_ERROR;
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
              s_fsm_state <= ST_SETUP_RTR;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_RTR =>
            BSP_TX_DATA(0)    <= s_reg_tx_msg.remote_request;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_RTR;

          when ST_SEND_RTR =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_FORM_ERROR;
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
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_R0;
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
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_DLC;
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
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_DATA;
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
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_CRC;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_CRC =>
            -- CRC and CRC delimiter
            BSP_TX_DATA(0 to C_CAN_CRC_WIDTH-1) <= BSP_TX_CRC_CALC;
            BSP_TX_DATA(C_CAN_CRC_WIDTH)        <= C_CRC_DELIM_VALUE;
            BSP_TX_WRITE_EN                     <= '1';
            s_fsm_state                         <= ST_SEND_CRC;

          when ST_SEND_CRC =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SETUP_ACK_SLOT;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ACK_SLOT =>
            BSP_TX_DATA(0)    <= C_ACK_TRANSMIT_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_RECV_ACK_SLOT;

          when ST_SEND_RECV_ACK_SLOT =>
            if BSP_TX_RX_MISMATCH = '1' then
              -- In this case for the ACK we actually want to receive
              -- the opposite value of what we sent
              s_tx_ack_recv <= '1';
            end if;

            if BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SEND_ACK_DELIM;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_ACK_DELIM =>
            BSP_TX_DATA(0)    <= C_ACK_DELIM_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            BSP_TX_WRITE_EN   <= '1';
            s_fsm_state       <= ST_SEND_ACK_DELIM;

          when ST_SEND_ACK_DELIM =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_SEND_EOF;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_SETUP_EOF =>
            BSP_TX_DATA(0 to C_EOF_LENGTH-1) <= C_EOF;
            BSP_TX_DATA_COUNT                <= C_EOF_LENGTH;
            BSP_TX_WRITE_EN                  <= '1';
            s_fsm_state                      <= ST_SEND_EOF;

          when ST_SEND_EOF =>
            if BSP_TX_RX_MISMATCH = '1' then
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state <= ST_DONE;
            else
              BSP_TX_WRITE_EN <= '1';
            end if;

          when ST_ARB_LOST =>
            TX_ARB_LOST            <= '1';
            s_reg_arb_lost_counter <= s_reg_arb_lost_counter + 1;
            s_fsm_state            <= ST_RETRANSMIT;

          when ST_FORM_ERROR =>
            BSP_SEND_ERROR_FRAME <= '1';
            s_reg_error_counter  <= s_reg_error_counter + 1;
            s_fsm_state          <= ST_RETRANSMIT;

          when ST_RETRANSMIT =>
            -- Retry transmission until retransmit count is reached
            if s_retransmit_attempts = C_RETRANSMIT_COUNT_MAX then
              TX_FAILED   <= '1';
              s_fsm_state <= ST_IDLE;
            else
              s_reg_retransmit_counter  <= s_reg_retransmit_counter + 1;
              s_retransmit_attempts     <= s_retransmit_attempts + 1;
              s_fsm_state               <= ST_WAIT_FOR_BUS_IDLE;
            end if;

          when ST_DONE =>
            -- Increase counters, set status outputs, etc...
            s_reg_msg_sent_counter <= s_reg_msg_sent_counter + 1;

            if s_tx_ack_recv = '1' then
              s_reg_ack_recv_counter <= s_reg_ack_recv_counter + 1;
              TX_ACK_RECV            <= '1';
              TX_DONE                <= '1';
              s_fsm_state            <= ST_IDLE;
            else
              -- Did not receive ACK
              s_fsm_state <= ST_RETRANSMIT;
            end if;

        end case;
      end if;
    end if;
  end process proc_fsm;

end architecture rtl;
