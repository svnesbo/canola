-------------------------------------------------------------------------------
-- Title      : Package for Canola CAN Controller
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : can_pkg.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2019-06-26
-- Last update: 2019-08-15
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Package with definitions used in the Canola CAN controller
-------------------------------------------------------------------------------
-- Copyright (c) 2019
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2019-06-26  1.0      svn     Created
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

package can_pkg is
  -----------------------------------------------------------------------------
  -- Definitions specific for CAN protocol
  -----------------------------------------------------------------------------

  constant C_SOF_VALUE          : std_logic := '0';
  constant C_IDE_STD_VALUE      : std_logic := '0';
  constant C_IDE_EXT_VALUE      : std_logic := '1';
  constant C_SRR_VALUE          : std_logic := '1';
  constant C_R0_VALUE           : std_logic := '0';
  constant C_R1_VALUE           : std_logic := '0';
  constant C_CRC_DELIM_VALUE    : std_logic := '1';
  constant C_ACK_VALUE          : std_logic := '0'; -- Ack value sent by receiver
  constant C_ACK_TRANSMIT_VALUE : std_logic := '1'; -- Ack value sent by transmitter
  constant C_ACK_DELIM_VALUE    : std_logic := '1';
  constant C_EOF_VALUE          : std_logic := '1';

  constant C_ID_A_LENGTH : natural := 11;   -- Standard arbitration ID
  constant C_ID_B_LENGTH : natural := 18;   -- Extended arbitration ID
                                                -- (ID A + B)
  constant C_DLC_LENGTH    : natural := 4;
  constant C_DLC_MAX_VALUE : natural := 8;

  constant C_EOF_LENGTH      : natural := 7;  -- 7 End Of Frame bits (recessive 1)
  constant C_IFS_LENGTH      : natural := 3;  -- 3 Interframe Spacing bits (recessive 1)

  constant C_EOF : std_logic_vector(0 to C_EOF_LENGTH-1) := (others => C_EOF_VALUE);

  constant C_BASIC_ARB_ID_LENGTH : natural := 11;
  constant C_EXT_ARB_ID_LENGTH   : natural := 29;


  -----------------------------------------------------------------------------
  -- Definitions specific for the Canola CAN controller implementation
  -----------------------------------------------------------------------------
  constant C_TIME_QUANTA_WIDTH   : natural := 5;
  constant C_PROP_SEG_WIDTH      : natural := 4;
  constant C_PHASE_SEG1_WIDTH    : natural := 4;
  constant C_PHASE_SEG2_WIDTH    : natural := 4;
  constant C_SYNC_JUMP_WIDTH_MAX : natural := 2;
  constant C_SEGMENT_WIDTH_MAX   : natural := maximum(C_PROP_SEG_WIDTH, maximum(C_PHASE_SEG1_WIDTH,
                                                                                C_PHASE_SEG2_WIDTH));
  -- Longest field that BSP will be transmitting/receiving is the payload,
  -- which is 8 bytes
  constant C_BSP_DATA_LENGTH : natural := 8*8;

  constant C_STUFF_BIT_THRESHOLD : natural := 5;



  constant C_ACCEPTANCE_FILTERS_MAX : natural := 256;

  constant C_CAN_CRC_WIDTH : natural := 15;

  -- TODO: Set this to whatever value the CANbus standard specifies
  constant C_RETRANSMIT_COUNT_MAX : natural := 4;

  type can_payload_t is array (0 to 7) of std_logic_vector(7 downto 0);

  type can_msg_t is record
    arb_id         : std_logic_vector(C_EXT_ARB_ID_LENGTH-1 downto 0);
    remote_request : std_logic;
    ext_id         : std_logic;
    data           : can_payload_t;
    data_length    : std_logic_vector(C_DLC_LENGTH-1 downto 0);
  end record can_msg_t;


  -----------------------------------------------------------------------------
  -- Declarations for error handling
  -----------------------------------------------------------------------------
  constant C_ERROR_FLAG_LENGTH       : natural := 6;
  constant C_ERROR_DELIMITER_LENGTH  : natural := 8;

  constant C_ERROR_PASSIVE_THRESHOLD : natural := 128;
  constant C_BUS_OFF_THRESHOLD       : natural := 256;

  constant C_ERROR_COUNT_LENGTH      : natural := 10;

  constant C_ACTIVE_ERROR_FLAG_DATA  : std_logic_vector(0 to C_ERROR_FLAG_LENGTH-1) := "000000";
  constant C_PASSIVE_ERROR_FLAG_DATA : std_logic_vector(0 to C_ERROR_FLAG_LENGTH-1) := "111111";

  type can_error_state_t is (ERROR_ACTIVE, ERROR_PASSIVE, BUS_OFF);

  -----------------------------------------------------------------------------
  -- Declarations for acceptance filtering
  -----------------------------------------------------------------------------
  -- Acceptance filter type
  type can_acf_t is array (integer range <>) of std_logic_vector(C_EXT_ARB_ID_LENGTH-1 downto 0);

end can_pkg;
