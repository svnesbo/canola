-------------------------------------------------------------------------------
-- Title      : Receive FSM for CAN bus
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_rx_fsm.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-07-06
-- Last update: 2019-08-14
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

entity can_rx_fsm is
  generic (
    G_BUS_REG_WIDTH : natural;
    G_ENABLE_EXT_ID : boolean);
  port (
    CLK              : in  std_logic;
    RESET            : in  std_logic;
    RX_MSG_OUT       : out can_msg_t;
    RX_MSG_VALID     : out std_logic;

    -- Signals to/from BSP
    BSP_RX_ACTIVE         : in  std_logic;
    BSP_RX_DATA           : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
    BSP_RX_DATA_COUNT     : in  natural range 0 to C_BSP_DATA_LENGTH;
    BSP_RX_DATA_CLEAR     : out std_logic;
    BSP_RX_DATA_OVERFLOW  : in  std_logic;
    BSP_RX_BIT_DESTUFF_EN : out std_logic;  -- Enable bit destuffing on data
                                            -- that is currently being received
    BSP_RX_CRC_CALC       : in  std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
    BSP_RX_SEND_ACK       : out std_logic;

    BSP_SEND_ERROR_FRAME  : out std_logic;  -- When pulsed, BSP cancels
                                            -- whatever it is doing, and sends
                                            -- an error frame of 6 dominant bits

    -- Counter registers for FSM
    REG_MSG_RECV_COUNT   : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_CRC_ERROR_COUNT  : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0);
    REG_FORM_ERROR_COUNT : out std_logic_vector(G_BUS_REG_WIDTH-1 downto 0)
    );

end entity can_rx_fsm;

architecture rtl of can_rx_fsm is

  type can_rx_fsm_t is (ST_IDLE,
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
                        ST_FORM_ERROR,
                        ST_DONE);

  signal s_fsm_state    : can_rx_fsm_t;
  signal s_reg_rx_msg   : can_msg_t;
  signal s_srr_rtr_bit  : std_logic;
  signal s_crc_mismatch : std_logic;
  signal s_crc_calc     : std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);

  signal s_reg_msg_recv_counter   : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_crc_error_counter  : unsigned(G_BUS_REG_WIDTH-1 downto 0);
  signal s_reg_form_error_counter : unsigned(G_BUS_REG_WIDTH-1 downto 0);



begin  -- architecture rtl

  REG_MSG_RECV_COUNT   <= std_logic_vector(s_reg_msg_recv_counter);
  REG_CRC_ERROR_COUNT  <= std_logic_vector(s_reg_crc_error_counter);
  REG_FORM_ERROR_COUNT <= std_logic_vector(s_reg_form_error_counter);

  RX_MSG_OUT           <= s_reg_rx_msg;

  proc_fsm : process(CLK) is
    variable v_bsp_rx_data_empty : std_logic;
  begin  -- process proc_fsm
    if rising_edge(CLK) then
      if RESET = '1' then
        s_fsm_state              <= ST_IDLE;
        s_crc_mismatch           <= '0';
        s_reg_msg_recv_counter   <= (others => '0');
        s_reg_crc_error_counter  <= (others => '0');
        s_reg_form_error_counter <= (others => '0');
        BSP_RX_BIT_DESTUFF_EN    <= '1';
        RX_MSG_VALID             <= '0';
      else
        RX_MSG_VALID          <= '0';
        BSP_RX_SEND_ACK       <= '0';
        BSP_RX_DATA_CLEAR     <= '0';
        BSP_SEND_ERROR_FRAME  <= '0';
        BSP_RX_BIT_DESTUFF_EN <= '1';

        v_bsp_rx_data_empty := '1' when BSP_RX_DATA_COUNT = 0 else '0';

        case s_fsm_state is
          when ST_IDLE =>
            s_crc_mismatch <= '0';

            if BSP_RX_ACTIVE = '1' then
              BSP_RX_DATA_CLEAR <= '1';
              s_fsm_state       <= ST_RECV_SOF;
            end if;

          when ST_RECV_SOF =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
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
            elsif BSP_RX_DATA_COUNT = C_ID_A_LENGTH then
              BSP_RX_DATA_CLEAR                             <= '1';
              s_reg_rx_msg.arb_id(C_ID_A_LENGTH-1 downto 0) <= BSP_RX_DATA(0 to C_ID_A_LENGTH-1);
              s_fsm_state                                   <= ST_RECV_SRR_RTR;
            end if;

          when ST_RECV_SRR_RTR =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
              BSP_RX_DATA_CLEAR <= '1';
              s_srr_rtr_bit     <= BSP_RX_DATA(0);
              s_fsm_state       <= ST_RECV_IDE;
            end if;

          when ST_RECV_IDE =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
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
            elsif BSP_RX_DATA_COUNT = C_ID_B_LENGTH then
              BSP_RX_DATA_CLEAR <= '1';

              s_reg_rx_msg.arb_id(C_ID_B_LENGTH+C_ID_A_LENGTH-1 downto C_ID_A_LENGTH) <=
                BSP_RX_DATA(0 to C_ID_B_LENGTH-1);

              s_fsm_state <= ST_RECV_EXT_FRAME_RTR;
            end if;

          when ST_RECV_EXT_FRAME_RTR =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
              BSP_RX_DATA_CLEAR           <= '1';
              s_reg_rx_msg.remote_request <= BSP_RX_DATA(0);
              s_fsm_state                 <= ST_RECV_R1;
            end if;

          when ST_RECV_R1 =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
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
            elsif BSP_RX_DATA_COUNT = 1 then
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
            elsif BSP_RX_DATA_COUNT = C_DLC_LENGTH then
              BSP_RX_DATA_CLEAR <= '1';

              if unsigned(BSP_RX_DATA(0 to C_DLC_LENGTH-1)) > C_DLC_MAX_VALUE then
                -- The DLC field is 4 bits and can technically represent values
                -- up to 15, but 8 is the maximum according to CAN bus specification
                s_fsm_state <= ST_FORM_ERROR;
              else
                s_reg_rx_msg.data_length <= BSP_RX_DATA(0 to C_DLC_LENGTH-1);
                s_fsm_state <= ST_RECV_DATA;
              end if;
            end if;

          when ST_RECV_DATA =>
            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = unsigned(s_reg_rx_msg.data_length) then
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

              -- 15-bit CRC + delimiter
            elsif BSP_RX_DATA_COUNT = C_CAN_CRC_WIDTH then
              if BSP_RX_DATA(0 to C_CAN_CRC_WIDTH-1) /= s_crc_calc then
                s_crc_mismatch <= '1';
              else
                s_crc_mismatch <= '0';
              end if;

              s_fsm_state    <= ST_RECV_CRC_DELIM;
            end if;

          when ST_RECV_CRC_DELIM =>
            -- No bit stuffing for CRC delimiter
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0) /= C_CRC_DELIM_VALUE then
                s_fsm_state <= ST_FORM_ERROR;
              else
                -- Send ACK only if CRC was ok
                if s_crc_mismatch <= '0' then
                  -- Pulsing this signal makes the BSP send an ack pulse
                  BSP_RX_SEND_ACK <= '1';
                end if;

                s_fsm_state     <= ST_SEND_RECV_ACK;
              end if;
            end if;

          when ST_SEND_RECV_ACK =>
            -- No bit stuffing for ACK slot
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = 1 then
              BSP_RX_DATA_CLEAR <= '1';

              if s_crc_mismatch = '0' and BSP_RX_DATA(0) /= C_ACK_VALUE then
                -- Did we try to send ACK, but did not read ACK value back?
                -- What kind of error is that? Form error?
                s_fsm_state <= ST_FORM_ERROR;
              else
                -- TODO: What if there was a CRC mismatch?
                --       Do I send active/passive error flag?
                --       And when do I send it? Immediately after CRC?
                --       At CRC delimiter, or ACK slot?
                s_fsm_state <= ST_RECV_EOF;
              end if;
            end if;

          when ST_RECV_EOF =>
            -- No bit stuffing for EOF (End of Frame)
            BSP_RX_BIT_DESTUFF_EN <= '0';

            if BSP_RX_ACTIVE = '0' then
              -- Did frame end unexpectedly?
              s_fsm_state <= ST_FORM_ERROR;
            elsif BSP_RX_DATA_COUNT = C_EOF_LENGTH then
              BSP_RX_DATA_CLEAR <= '1';

              if BSP_RX_DATA(0 to C_EOF_LENGTH-1) /= C_EOF then
                -- Is this a form error?
                s_fsm_state <= ST_FORM_ERROR;
              else
                s_fsm_state <= ST_DONE;
              end if;
            end if;

          when ST_FORM_ERROR =>
            -- Form Error applies to bit errors in any fixed field from SOF to
            -- CRC delimiter.

          when ST_DONE =>
            -- Pulsed one cycle
            RX_MSG_VALID <= '1';

          when others =>
            s_fsm_state <= ST_IDLE;

        end case;
      end if;
    end if;
  end process proc_fsm;

end architecture rtl;