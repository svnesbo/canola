-------------------------------------------------------------------------------
-- Title      : Package with component declarations for TMR wrappers
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : tmr_wrapper_pkg.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-10-10
-- Last update: 2020-10-11
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Component declarations for the TMR wrappers for use with
--              the configurations in tmr_wrapper_cfg.vhd.
--              Vivado doesn't allow instances of the configurations to be
--              created directly, it expects components to be instantiated and
--              these components must be bound to the configurations.
--              https://www.xilinx.com/support/answers/67946.html
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-10-11  1.0      svn     Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.canola_pkg.all;

package tmr_wrapper_pkg is

  component canola_btl_tmr_wrapper is
    generic (
      G_SEE_MITIGATION_EN       : integer;
      G_MISMATCH_OUTPUT_EN      : integer;
      G_MISMATCH_OUTPUT_2ND_EN  : integer;
      G_MISMATCH_OUTPUT_REG     : integer;
      G_TIME_QUANTA_SCALE_WIDTH : natural);
    port (
      CLK                 : in  std_logic;
      RESET               : in  std_logic;
      CAN_TX              : out std_logic;
      CAN_RX              : in  std_logic;
      BTL_TX_BIT_VALUE    : in  std_logic;
      BTL_TX_BIT_VALID    : in  std_logic;
      BTL_TX_RDY          : out std_logic;
      BTL_TX_DONE         : out std_logic;
      BTL_TX_ACTIVE       : in  std_logic;
      BTL_RX_BIT_VALUE    : out std_logic;
      BTL_RX_BIT_VALID    : out std_logic;
      BTL_RX_SYNCED       : out std_logic;
      BTL_RX_STOP         : in  std_logic;
      TRIPLE_SAMPLING     : in  std_logic;
      PROP_SEG            : in  std_logic_vector(C_PROP_SEG_WIDTH-1 downto 0);
      PHASE_SEG1          : in  std_logic_vector(C_PHASE_SEG1_WIDTH-1 downto 0);
      PHASE_SEG2          : in  std_logic_vector(C_PHASE_SEG2_WIDTH-1 downto 0);
      SYNC_JUMP_WIDTH     : in  unsigned(C_SYNC_JUMP_WIDTH_BITSIZE-1 downto 0);
      TIME_QUANTA_PULSE   : in  std_logic;
      TIME_QUANTA_RESTART : out std_logic;
      MISMATCH            : out std_logic;
      MISMATCH_2ND        : out std_logic);
  end component canola_btl_tmr_wrapper;


  component canola_bsp_tmr_wrapper is
    generic (
      G_SEE_MITIGATION_EN      : integer;
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK                             : in  std_logic;
      RESET                           : in  std_logic;
      BSP_TX_DATA                     : in  std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
      BSP_TX_DATA_COUNT               : in  std_logic_vector(C_BSP_DATA_LEN_BITSIZE-1 downto 0);
      BSP_TX_WRITE_EN                 : in  std_logic;
      BSP_TX_BIT_STUFF_EN             : in  std_logic;
      BSP_TX_RX_MISMATCH              : out std_logic;
      BSP_TX_RX_STUFF_MISMATCH        : out std_logic;
      BSP_TX_DONE                     : out std_logic;
      BSP_TX_CRC_CALC                 : out std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
      BSP_TX_ACTIVE                   : in  std_logic;
      BSP_RX_ACTIVE                   : out std_logic;
      BSP_RX_IFS                      : out std_logic;
      BSP_RX_DATA                     : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
      BSP_RX_DATA_COUNT               : out std_logic_vector(C_BSP_DATA_LEN_BITSIZE-1 downto 0);
      BSP_RX_DATA_CLEAR               : in  std_logic;
      BSP_RX_DATA_OVERFLOW            : out std_logic;
      BSP_RX_BIT_DESTUFF_EN           : in  std_logic;
      BSP_RX_STOP                     : in  std_logic;
      BSP_RX_CRC_CALC                 : out std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
      BSP_RX_SEND_ACK                 : in  std_logic;
      BSP_RX_ACTIVE_ERROR_FLAG        : out std_logic;
      BSP_RX_PASSIVE_ERROR_FLAG       : out std_logic;
      BSP_SEND_ERROR_FLAG             : in  std_logic;
      BSP_ERROR_FLAG_DONE             : out std_logic;
      BSP_ACTIVE_ERROR_FLAG_BIT_ERROR : out std_logic;
      EML_RECV_11_RECESSIVE_BITS      : out std_logic;
      EML_ERROR_STATE                 : in  std_logic_vector(C_CAN_ERROR_STATE_BITSIZE-1 downto 0);
      BTL_TX_BIT_VALUE                : out std_logic;
      BTL_TX_BIT_VALID                : out std_logic;
      BTL_TX_RDY                      : in  std_logic;
      BTL_TX_DONE                     : in  std_logic;
      BTL_RX_BIT_VALUE                : in  std_logic;
      BTL_RX_BIT_VALID                : in  std_logic;
      BTL_RX_SYNCED                   : in  std_logic;
      BTL_RX_STOP                     : out std_logic;
      MISMATCH                        : out std_logic;
      MISMATCH_2ND                    : out std_logic);
  end component canola_bsp_tmr_wrapper;


  component canola_eml_tmr_wrapper is
    generic (
      G_SEE_MITIGATION_EN      : integer;
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK                              : in  std_logic;
      RESET                            : in  std_logic;
      RX_STUFF_ERROR                   : in  std_logic;
      RX_CRC_ERROR                     : in  std_logic;
      RX_FORM_ERROR                    : in  std_logic;
      RX_ACTIVE_ERROR_FLAG_BIT_ERROR   : in  std_logic;
      RX_OVERLOAD_FLAG_BIT_ERROR       : in  std_logic;
      RX_DOMINANT_BIT_AFTER_ERROR_FLAG : in  std_logic;
      TX_BIT_ERROR                     : in  std_logic;
      TX_ACK_ERROR                     : in  std_logic;
      TX_ACTIVE_ERROR_FLAG_BIT_ERROR   : in  std_logic;
      TRANSMIT_SUCCESS                 : in  std_logic;
      RECEIVE_SUCCESS                  : in  std_logic;
      RECV_11_RECESSIVE_BITS           : in  std_logic;
      TEC_COUNT_VALUE                  : in  t_eml_counter_tmr;
      TEC_COUNT_INCR                   : out std_logic_vector(C_ERROR_COUNT_INCR_LENGTH-1 downto 0);
      TEC_COUNT_UP                     : out std_logic;
      TEC_COUNT_DOWN                   : out std_logic;
      TEC_CLEAR                        : out std_logic;
      TEC_SET                          : out std_logic;
      TEC_SET_VALUE                    : out std_logic_vector(C_ERROR_COUNT_LENGTH-1 downto 0);
      REC_COUNT_VALUE                  : in  t_eml_counter_tmr;
      REC_COUNT_INCR                   : out std_logic_vector(C_ERROR_COUNT_INCR_LENGTH-1 downto 0);
      REC_COUNT_UP                     : out std_logic;
      REC_COUNT_DOWN                   : out std_logic;
      REC_CLEAR                        : out std_logic;
      REC_SET                          : out std_logic;
      REC_SET_VALUE                    : out std_logic_vector(C_ERROR_COUNT_LENGTH-1 downto 0);
      RECESSIVE_BIT_COUNT_VALUE        : in  std_logic_vector(C_ERROR_COUNT_LENGTH-1 downto 0);
      RECESSIVE_BIT_COUNT_UP           : out std_logic;
      RECESSIVE_BIT_COUNT_CLEAR        : out std_logic;
      ERROR_STATE                      : out std_logic_vector(C_CAN_ERROR_STATE_BITSIZE-1 downto 0);
      MISMATCH                         : out std_logic;
      MISMATCH_2ND                     : out std_logic);
  end component canola_eml_tmr_wrapper;


  component canola_frame_rx_fsm_tmr_wrapper is
    generic (
      G_SEE_MITIGATION_EN      : integer;
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK                                : in  std_logic;
      RESET                              : in  std_logic;
      RX_MSG_OUT                         : out can_msg_t;
      RX_MSG_VALID                       : out std_logic;
      TX_ARB_WON                         : in  std_logic;
      BSP_RX_ACTIVE                      : in  std_logic;
      BSP_RX_IFS                         : in  std_logic;
      BSP_RX_DATA                        : in  std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
      BSP_RX_DATA_COUNT                  : in  std_logic_vector(C_BSP_DATA_LEN_BITSIZE-1 downto 0);
      BSP_RX_DATA_CLEAR                  : out std_logic;
      BSP_RX_DATA_OVERFLOW               : in  std_logic;
      BSP_RX_BIT_DESTUFF_EN              : out std_logic;
      BSP_RX_STOP                        : out std_logic;
      BSP_RX_CRC_CALC                    : in  std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
      BSP_RX_SEND_ACK                    : out std_logic;
      BSP_RX_ACTIVE_ERROR_FLAG           : in  std_logic;
      BSP_RX_PASSIVE_ERROR_FLAG          : in  std_logic;
      BSP_SEND_ERROR_FLAG                : out std_logic;
      BSP_ERROR_FLAG_DONE                : in  std_logic;
      BSP_ACTIVE_ERROR_FLAG_BIT_ERROR    : in  std_logic;
      BTL_RX_BIT_VALID                   : in  std_logic;
      BTL_RX_BIT_VALUE                   : in  std_logic;
      EML_TX_BIT_ERROR                   : out std_logic;
      EML_RX_STUFF_ERROR                 : out std_logic;
      EML_RX_CRC_ERROR                   : out std_logic;
      EML_RX_FORM_ERROR                  : out std_logic;
      EML_RX_ACTIVE_ERROR_FLAG_BIT_ERROR : out std_logic;
      EML_ERROR_STATE                    : in  std_logic_vector(C_CAN_ERROR_STATE_BITSIZE-1 downto 0);
      MISMATCH                           : out std_logic;
      MISMATCH_2ND                       : out std_logic);
  end component canola_frame_rx_fsm_tmr_wrapper;


  component canola_frame_tx_fsm_tmr_wrapper is
    generic (
      G_SEE_MITIGATION_EN      : integer;
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer;
      G_RETRANSMIT_COUNT_MAX   : natural);
    port (
      CLK                                : in  std_logic;
      RESET                              : in  std_logic;
      TX_MSG_IN                          : in  can_msg_t;
      TX_START                           : in  std_logic;
      TX_RETRANSMIT_EN                   : in  std_logic;
      TX_BUSY                            : out std_logic;
      TX_DONE                            : out std_logic;
      TX_ARB_LOST                        : out std_logic;
      TX_ARB_WON                         : out std_logic;
      TX_FAILED                          : out std_logic;
      TX_RETRANSMITTING                  : out std_logic;
      BSP_TX_DATA                        : out std_logic_vector(0 to C_BSP_DATA_LENGTH-1);
      BSP_TX_DATA_COUNT                  : out std_logic_vector(C_BSP_DATA_LEN_BITSIZE-1 downto 0);
      BSP_TX_WRITE_EN                    : out std_logic;
      BSP_TX_BIT_STUFF_EN                : out std_logic;
      BSP_TX_RX_MISMATCH                 : in  std_logic;
      BSP_TX_RX_STUFF_MISMATCH           : in  std_logic;
      BSP_TX_DONE                        : in  std_logic;
      BSP_TX_CRC_CALC                    : in  std_logic_vector(C_CAN_CRC_WIDTH-1 downto 0);
      BSP_TX_ACTIVE                      : out std_logic;
      BSP_RX_ACTIVE                      : in  std_logic;
      BSP_RX_IFS                         : in  std_logic;
      BSP_SEND_ERROR_FLAG                : out std_logic;
      BSP_ERROR_FLAG_DONE                : in  std_logic;
      BSP_ACTIVE_ERROR_FLAG_BIT_ERROR    : in  std_logic;
      EML_TX_BIT_ERROR                   : out std_logic;
      EML_TX_ACK_ERROR                   : out std_logic;
      EML_TX_ARB_STUFF_ERROR             : out std_logic;
      EML_TX_ACTIVE_ERROR_FLAG_BIT_ERROR : out std_logic;
      EML_ERROR_STATE                    : in  std_logic_vector(C_CAN_ERROR_STATE_BITSIZE-1 downto 0);
      MISMATCH                           : out std_logic;
      MISMATCH_2ND                       : out std_logic);
  end component canola_frame_tx_fsm_tmr_wrapper;


  component canola_time_quanta_gen_tmr_wrapper is
    generic (
      G_SEE_MITIGATION_EN       : integer;
      G_MISMATCH_OUTPUT_EN      : integer;
      G_MISMATCH_OUTPUT_2ND_EN  : integer;
      G_MISMATCH_OUTPUT_REG     : integer;
      G_TIME_QUANTA_SCALE_WIDTH : natural);
    port (
      CLK               : in  std_logic;
      RESET             : in  std_logic;
      RESTART           : in  std_logic;
      CLK_SCALE         : in  unsigned(G_TIME_QUANTA_SCALE_WIDTH-1 downto 0);
      TIME_QUANTA_PULSE : out std_logic;
      MISMATCH          : out std_logic;
      MISMATCH_2ND      : out std_logic);
  end component canola_time_quanta_gen_tmr_wrapper;


  component counter_saturating_tmr_wrapper_triplicated is
    generic (
      BIT_WIDTH                : integer;
      INCR_WIDTH               : natural;
      VERBOSE                  : boolean;
      G_SEE_MITIGATION_EN      : integer;
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK          : in  std_logic;
      RESET        : in  std_logic;
      CLEAR        : in  std_logic;
      SET          : in  std_logic;
      SET_VALUE    : in  std_logic_vector(BIT_WIDTH-1 downto 0);
      COUNT_UP     : in  std_logic;
      COUNT_DOWN   : in  std_logic;
      COUNT_INCR   : in  std_logic_vector(INCR_WIDTH-1 downto 0);
      COUNT_OUT_A  : out std_logic_vector(BIT_WIDTH-1 downto 0);
      COUNT_OUT_B  : out std_logic_vector(BIT_WIDTH-1 downto 0);
      COUNT_OUT_C  : out std_logic_vector(BIT_WIDTH-1 downto 0);
      MISMATCH     : out std_logic;
      MISMATCH_2ND : out std_logic);
  end component counter_saturating_tmr_wrapper_triplicated;


  component up_counter_tmr_wrapper is
    generic (
      BIT_WIDTH                : integer;
      IS_SATURATING            : boolean;
      VERBOSE                  : boolean;
      G_SEE_MITIGATION_EN      : integer;
      G_MISMATCH_OUTPUT_EN     : integer;
      G_MISMATCH_OUTPUT_2ND_EN : integer;
      G_MISMATCH_OUTPUT_REG    : integer);
    port (
      CLK          : in  std_logic;
      RESET        : in  std_logic;
      CLEAR        : in  std_logic;
      COUNT_UP     : in  std_logic;
      COUNT_OUT    : out std_logic_vector(BIT_WIDTH-1 downto 0);
      MISMATCH     : out std_logic;
      MISMATCH_2ND : out std_logic);
  end component up_counter_tmr_wrapper;

end package tmr_wrapper_pkg;
