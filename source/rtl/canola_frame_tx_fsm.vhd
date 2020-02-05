-------------------------------------------------------------------------------
-- Title      : Transmit FSM for CAN frames
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_frame_tx_fsm.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-06-26
-- Last update: 2020-02-05
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
use work.canola_pkg.all;

entity canola_frame_tx_fsm is
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
    TX_DONE                        : out std_logic;  -- Transmit done, ack received
    TX_ARB_LOST                    : out std_logic;  -- Arbitration was lost
    TX_ARB_WON                     : out std_logic;  -- Arbitration was won (pulsed)
    TX_FAILED                      : out std_logic;  -- (Re)transmit failed (arb lost or error)
    TX_RETRANSMITTING              : out std_logic;  -- Attempting retransmit

    -- Signals to/from BSP
    BSP_TX_DATA                     : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_TX_DATA_COUNT               : out natural range 0 to C_BSP_DATA_LENGTH;
    BSP_TX_WRITE_EN                 : out std_logic;
    BSP_TX_BIT_STUFF_EN             : out std_logic;
    BSP_TX_RX_MISMATCH              : in  std_logic;
    BSP_TX_RX_STUFF_MISMATCH        : in  std_logic;
    BSP_TX_DONE                     : in  std_logic;
    BSP_TX_CRC_CALC                 : in  std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_TX_ACTIVE                   : out std_logic;
    BSP_RX_ACTIVE                   : in  std_logic;
    BSP_SEND_ERROR_FLAG             : out std_logic;
    BSP_ERROR_FLAG_DONE             : in  std_logic;
    BSP_ACTIVE_ERROR_FLAG_BIT_ERROR : in  std_logic;

    -- Signals to/from EML
    EML_TX_BIT_ERROR                   : out std_logic;  -- Mismatch transmitted vs. monitored bit
    EML_TX_ACK_ERROR                   : out std_logic;  -- No ack received
    EML_TX_ARB_STUFF_ERROR             : out std_logic;  -- Stuff error during arbitration field
    EML_TX_ACTIVE_ERROR_FLAG_BIT_ERROR : out std_logic;
    EML_ERROR_STATE                    : in  std_logic_vector(C_CAN_ERROR_STATE_BITSIZE-1 downto 0);

    -- FSM state register output/input - for triplication and voting of state
    FSM_STATE_O       : out std_logic_vector(C_FRAME_TX_FSM_STATE_BITSIZE-1 downto 0);
    FSM_STATE_VOTED_I : in  std_logic_vector(C_FRAME_TX_FSM_STATE_BITSIZE-1 downto 0)
    );

end entity canola_frame_tx_fsm;

architecture rtl of canola_frame_tx_fsm is
  signal s_fsm_state_out   : can_frame_tx_fsm_state_t;
  signal s_fsm_state_voted : can_frame_tx_fsm_state_t;
  signal s_eml_error_state : can_error_state_t;

  attribute fsm_encoding                      : string;
  attribute fsm_encoding of s_fsm_state_out   : signal is "sequential";
  attribute fsm_encoding of s_fsm_state_voted : signal is "sequential";
  attribute fsm_encoding of s_eml_error_state : signal is "sequential";

  signal s_reg_tx_msg          : can_msg_t;
  signal s_tx_ack_recv         : std_logic;
  signal s_retransmit_attempts : natural range 0 to C_RETRANSMIT_COUNT_MAX;

  signal s_bsp_tx_write_en                : std_logic;
  signal s_tx_active_error_flag_bit_error : std_logic;

  alias a_tx_msg_id_a : std_logic_vector(C_ID_A_LENGTH-1 downto 0) is s_reg_tx_msg.arb_id_a;
  alias a_tx_msg_id_b : std_logic_vector(C_ID_B_LENGTH-1 downto 0) is s_reg_tx_msg.arb_id_b;

  alias a_tx_msg_id_a_reversed : std_logic_vector(a_tx_msg_id_a'reverse_range) is a_tx_msg_id_a;
  alias a_tx_msg_id_b_reversed : std_logic_vector(a_tx_msg_id_b'reverse_range) is a_tx_msg_id_b;

begin  -- architecture rtl

  -- We have to hold BSP_TX_WRITE_EN while sending data,
  -- but want it to go low immediately when BSP is done.
  -- There's only a few cycles to set up next data,
  -- kind of had to be this way..
  BSP_TX_WRITE_EN <= s_bsp_tx_write_en and not BSP_TX_DONE;

  -- Convert FSM state register output to std_logic_vector
  FSM_STATE_O <= std_logic_vector(to_unsigned(can_frame_tx_fsm_state_t'pos(s_fsm_state_out),
                                              C_FRAME_TX_FSM_STATE_BITSIZE));

  -- Convert voted FSM state register input from std_logic_vector to frame_tx_fsm_state_t
  s_fsm_state_voted <= can_frame_tx_fsm_state_t'val(to_integer(unsigned(FSM_STATE_VOTED_I)));


  proc_fsm : process(CLK) is
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      TX_ARB_WON                         <= '0';
      TX_ARB_LOST                        <= '0';
      TX_DONE                            <= '0';
      EML_TX_BIT_ERROR                   <= '0';
      EML_TX_ACK_ERROR                   <= '0';
      EML_TX_ARB_STUFF_ERROR             <= '0';
      EML_TX_ACTIVE_ERROR_FLAG_BIT_ERROR <= '0';
      BSP_SEND_ERROR_FLAG                <= '0';
      s_bsp_tx_write_en                  <= '0';
      BSP_TX_BIT_STUFF_EN                <= '1';

      if RESET = '1' then
        s_fsm_state_out                    <= ST_IDLE;
        TX_BUSY                            <= '0';
        BSP_TX_DATA                        <= (others => '0');
        BSP_TX_ACTIVE                      <= '0';
        s_tx_ack_recv                      <= '0';
        s_retransmit_attempts              <= 0;
        s_tx_active_error_flag_bit_error   <= '0';
      else
        case s_fsm_state_voted is
          when ST_IDLE =>
            BSP_TX_ACTIVE                    <= '0';
            TX_BUSY                          <= '0';
            s_tx_ack_recv                    <= '0';
            s_retransmit_attempts            <= 0;
            s_tx_active_error_flag_bit_error <= '0';

            -- EML_ERROR_STATE may change after transmission of error flag has started.
            -- Keep a registered version since we need to know its value while transmitting error flag
            s_eml_error_state <= can_error_state_t'val(to_integer(unsigned(EML_ERROR_STATE)));

            if TX_START = '1' and s_eml_error_state /= BUS_OFF then
              TX_BUSY         <= '1';
              s_reg_tx_msg    <= TX_MSG_IN;
              s_fsm_state_out <= ST_WAIT_FOR_BUS_IDLE;
            end if;

          when ST_WAIT_FOR_BUS_IDLE =>
            -- TODO:
            -- Should there be a timeout here?
            -- Can we wait forever?
            if BSP_RX_ACTIVE = '0' then
              BSP_TX_ACTIVE   <= '1';
              s_fsm_state_out <= ST_SETUP_SOF;
            end if;

          when ST_SETUP_SOF =>
            BSP_TX_DATA(0)    <= C_SOF_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            s_fsm_state_out   <= ST_SEND_SOF;

          when ST_SEND_SOF =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_ID_A;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_ID_A =>
            BSP_TX_DATA(0 to C_ID_A_LENGTH-1) <= a_tx_msg_id_a_reversed;
            BSP_TX_DATA_COUNT                 <= C_ID_A_LENGTH;
            s_fsm_state_out                   <= ST_SEND_ID_A;

          when ST_SEND_ID_A =>
            if BSP_TX_RX_STUFF_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_SEND_ERROR_FLAG;
            elsif BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_ARB_LOST;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state_out <= ST_SETUP_SRR;
              else
                s_fsm_state_out <= ST_SETUP_RTR;
              end if;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_SRR =>
            BSP_TX_DATA(0)    <= C_SRR_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            s_fsm_state_out   <= ST_SEND_SRR;

          when ST_SEND_SRR =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_IDE;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_IDE =>
            if s_reg_tx_msg.ext_id = '1' then
              BSP_TX_DATA(0)    <= C_IDE_EXT_VALUE;
              BSP_TX_DATA_COUNT <= 1;
            else
              BSP_TX_DATA(0)    <= C_IDE_STD_VALUE;
              BSP_TX_DATA_COUNT <= 1;
            end if;

            s_fsm_state_out <= ST_SEND_IDE;

          when ST_SEND_IDE =>
            if BSP_TX_RX_MISMATCH = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                BSP_TX_ACTIVE   <= '0';
                s_fsm_state_out <= ST_ARB_LOST;
              else
                BSP_TX_ACTIVE   <= '0';
                s_fsm_state_out <= ST_BIT_ERROR;
              end if;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state_out <= ST_SETUP_ID_B;
              else
                s_fsm_state_out <= ST_SETUP_R0;
              end if;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_ID_B =>
            BSP_TX_DATA(0 to C_ID_B_LENGTH-1) <= a_tx_msg_id_b_reversed;
            BSP_TX_DATA_COUNT                 <= C_ID_B_LENGTH;
            s_fsm_state_out                   <= ST_SEND_ID_B;

          when ST_SEND_ID_B =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_ARB_LOST;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_RTR;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_RTR =>
            -- At this point we have just won the arbitration,
            -- both for extended and basic ID messages
            TX_ARB_WON        <= '1';
            BSP_TX_DATA(0)    <= s_reg_tx_msg.remote_request;
            BSP_TX_DATA_COUNT <= 1;
            s_fsm_state_out   <= ST_SEND_RTR;

          when ST_SEND_RTR =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.ext_id = '1' then
                s_fsm_state_out <= ST_SETUP_R1;
              else
                s_fsm_state_out <= ST_SETUP_IDE;
              end if;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_R1 =>
            BSP_TX_DATA(0)    <= C_R1_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            s_fsm_state_out   <= ST_SEND_R1;

          when ST_SEND_R1 =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_R0;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_R0 =>
            BSP_TX_DATA(0)    <= C_R0_VALUE;
            BSP_TX_DATA_COUNT <= 1;
            s_fsm_state_out   <= ST_SEND_R0;

          when ST_SEND_R0 =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_DLC;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_DLC =>
            BSP_TX_DATA(0 to C_DLC_LENGTH-1) <= s_reg_tx_msg.data_length;
            BSP_TX_DATA_COUNT                <= C_DLC_LENGTH;
            s_fsm_state_out                  <= ST_SEND_DLC;

          when ST_SEND_DLC =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              if s_reg_tx_msg.remote_request = '1' then
                s_fsm_state_out <= ST_SETUP_CRC;
              elsif unsigned(s_reg_tx_msg.data_length) = 0 then
                s_fsm_state_out <= ST_SETUP_CRC;
              else
                s_fsm_state_out <= ST_SETUP_DATA;
              end if;
            else
              s_bsp_tx_write_en <= '1';
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
            s_fsm_state_out       <= ST_SEND_DATA;

          when ST_SEND_DATA =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE <= '0';
              s_fsm_state_out   <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out   <= ST_SETUP_CRC;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_CRC =>
            -- CRC and CRC delimiter
            BSP_TX_DATA(0 to C_CAN_CRC_WIDTH-1) <= BSP_TX_CRC_CALC;
            BSP_TX_DATA_COUNT                   <= C_CAN_CRC_WIDTH;
            s_fsm_state_out                     <= ST_SEND_CRC;

          when ST_SEND_CRC =>
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE <= '0';
              s_fsm_state_out   <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out   <= ST_SETUP_CRC_DELIM;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_CRC_DELIM =>
            -- CRC and CRC delimiter
            BSP_TX_BIT_STUFF_EN <= '0';
            BSP_TX_DATA(0)      <= C_CRC_DELIM_VALUE;
            BSP_TX_DATA_COUNT   <= 1;
            s_fsm_state_out     <= ST_SEND_CRC_DELIM;

          when ST_SEND_CRC_DELIM =>
            -- Note:
            -- CRC delimiter is not stuffed
            -- But since BSP_TX_BIT_STUFF_EN enables stuffing based on the previous bit,
            -- we leave it enabled also for the CRC delimiter, and disable it in the ACK
            -- slot state, to make sure that the last bit of the CRC is stuffed.
            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_ACK_SLOT;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_ACK_SLOT =>
            BSP_TX_BIT_STUFF_EN <= '0';
            BSP_TX_DATA(0)      <= C_ACK_TRANSMIT_VALUE;
            BSP_TX_DATA_COUNT   <= 1;
            s_fsm_state_out     <= ST_SEND_RECV_ACK_SLOT;

          when ST_SEND_RECV_ACK_SLOT =>
            BSP_TX_BIT_STUFF_EN <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              -- In this case for the ACK we actually want to receive
              -- the opposite value of what we sent
              s_tx_ack_recv <= '1';
            end if;

            if BSP_TX_DONE = '1' then
              if s_tx_ack_recv = '1' or BSP_TX_RX_MISMATCH = '1' then
                s_fsm_state_out <= ST_SETUP_ACK_DELIM;
              else
                -- I believe the error flag for ACK should be sent immediately,
                -- and not after the ACK delimiter.
                -- CAN spec 2.0B, 7.2 Error Signalling:
                -- "Whenever a BIT ERROR, a STUFF ERROR, a FORM ERROR or an
                --  ACKNOWLEDGMENT ERROR is detected by any station, transmission
                --  of an ERROR FLAG is started at the respective station at the next bit."
                s_fsm_state_out <= ST_ACK_ERROR;
              end if;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_ACK_DELIM =>
            BSP_TX_BIT_STUFF_EN <= '0';
            BSP_TX_DATA(0)      <= C_ACK_DELIM_VALUE;
            BSP_TX_DATA_COUNT   <= 1;
            s_fsm_state_out     <= ST_SEND_ACK_DELIM;

          when ST_SEND_ACK_DELIM =>
            BSP_TX_BIT_STUFF_EN <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_SETUP_EOF;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_EOF =>
            BSP_TX_BIT_STUFF_EN              <= '0';
            BSP_TX_DATA(0 to C_EOF_LENGTH-1) <= C_EOF;
            BSP_TX_DATA_COUNT                <= C_EOF_LENGTH;
            s_fsm_state_out                  <= ST_SEND_EOF;

          when ST_SEND_EOF =>
            BSP_TX_BIT_STUFF_EN <= '0';

            if BSP_TX_RX_MISMATCH = '1' then
              BSP_TX_ACTIVE   <= '0';
              s_fsm_state_out <= ST_BIT_ERROR;
            elsif BSP_TX_DONE = '1' then
              s_fsm_state_out <= ST_DONE;
            else
              s_bsp_tx_write_en <= '1';
            end if;

          when ST_SETUP_ERROR_FLAG =>
            -- Pulse send error flag output to BSP here
            -- UNLESS we are in BUS_OFF state
            BSP_SEND_ERROR_FLAG <= '1';
            s_fsm_state_out     <= ST_SEND_ERROR_FLAG;

          when ST_SEND_ERROR_FLAG =>
            if s_eml_error_state = ERROR_ACTIVE and BSP_ACTIVE_ERROR_FLAG_BIT_ERROR = '1' then
              -- CAN specification 7.1:
              -- Bit errors while sending active error flag should be detected,
              -- and leads to an increase in transmit error count by 8 in the EML
              EML_TX_ACTIVE_ERROR_FLAG_BIT_ERROR <= not s_tx_active_error_flag_bit_error;

              -- Send only one pulse on EML_RX_ACTIVE_ERROR_FLAG_BIT_ERROR per
              -- error flag, even if there are more than 1 bit errors
              s_tx_active_error_flag_bit_error   <= '1';
            elsif BSP_ERROR_FLAG_DONE = '1' then
              s_fsm_state_out <= ST_RETRANSMIT;
            end if;

          when ST_ARB_LOST =>
            TX_ARB_LOST            <= '1';
            s_fsm_state_out        <= ST_RETRANSMIT;

          when ST_BIT_ERROR =>
            BSP_SEND_ERROR_FLAG   <= '1';
            EML_TX_BIT_ERROR      <= '1';
            s_fsm_state_out       <= ST_RETRANSMIT;

          when ST_ACK_ERROR =>
            BSP_SEND_ERROR_FLAG       <= '1';
            EML_TX_ACK_ERROR          <= '1';
            s_fsm_state_out           <= ST_RETRANSMIT;

          when ST_RETRANSMIT =>
            -- TODO:
            -- Find out WHEN we are allowed to retransmit.....
            -- Check CAN specification

            -- Retry transmission until retransmit count is reached
            -- TODO: Need to respect IFS etc. before retransmitting....
            if TX_RETRANSMIT_EN = '0' or s_retransmit_attempts = C_RETRANSMIT_COUNT_MAX then
              TX_FAILED       <= '1';
              s_fsm_state_out <= ST_IDLE;
            else
              TX_RETRANSMITTING      <= '1';
              s_retransmit_attempts  <= s_retransmit_attempts + 1;
              s_fsm_state_out        <= ST_WAIT_FOR_BUS_IDLE;
            end if;

          when ST_DONE =>
            BSP_TX_ACTIVE   <= '0';
            TX_DONE         <= '1';
            s_fsm_state_out <= ST_IDLE;

        end case;
      end if;
    end if;
  end process proc_fsm;

end architecture rtl;
