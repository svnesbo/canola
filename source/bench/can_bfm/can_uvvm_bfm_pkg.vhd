-------------------------------------------------------------------------------
-- Title      : CAN Bus UVVM BFM
-- Project    :
-------------------------------------------------------------------------------
-- File       : can_uvvm_bfm_pkg.vhd
-- Author     : Simon Voigt Nesbø  <simon@simon-ThinkPad-T450s>
-- Company    :
-- Created    : 2018-06-20
-- Last update: 2018-08-11
-- Platform   :
-- Standard   : VHDL'93/02
-------------------------------------------------------------------------------
-- Description: Bus Functional Model (BFM) for CAN Bus for use with
--              Bitvis UVVM test benches
-------------------------------------------------------------------------------
-- Copyright (c) 2018
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2018-06-20  1.0      simon	Created
-------------------------------------------------------------------------------
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library uvvm_util;
context uvvm_util.uvvm_util_context;

library work;
use work.can_bfm_pkg.all;


package can_uvvm_bfm_pkg is
  constant C_SCOPE           : string  := "CAN HLP BFM";

-- Configuration record to be assigned in the test harness.
  type t_can_uvvm_bfm_config is record
    max_wait_cycles          : integer;
    max_wait_cycles_severity : t_alert_level;
    arb_lost_severity        : t_alert_level;
    ack_missing_severity     : t_alert_level;
    crc_error_severity       : t_alert_level;
    sync_quanta              : natural;
    prop_quanta              : natural;
    phase1_quanta            : natural;
    phase2_quanta            : natural;
    bit_rate                 : natural;
    clock_period             : time;
    id_for_bfm               : t_msg_id;
    id_for_bfm_wait          : t_msg_id;
    id_for_bfm_poll          : t_msg_id;
  end record;

  constant C_CAN_UVVM_BFM_CONFIG_DEFAULT : t_can_uvvm_bfm_config := (
    max_wait_cycles          => 1000,
    max_wait_cycles_severity => failure,
    arb_lost_severity        => warning,
    ack_missing_severity     => warning,
    crc_error_severity       => failure,
    sync_quanta              => 1,
    prop_quanta              => 3,
    phase1_quanta            => 3,
    phase2_quanta            => 3,
    bit_rate                 => 1000000,
    clock_period             => 25 ns,
    id_for_bfm               => ID_BFM,
    id_for_bfm_wait          => ID_BFM_WAIT,
    id_for_bfm_poll          => ID_BFM_POLL
    );


  -- Transmit a CAN frame
  -- The upper 18 bits of arbitration ID are ignored if extended_id is not set
  -- in the config.
  -- If remote_request is set high, a remote request frame will be sent,
  -- and any specified data is ignored.
  procedure can_uvvm_write (
    constant arb_id         : in  std_logic_vector(28 downto 0);
    constant extended_id    : in  std_logic;
    constant remote_request : in  std_logic;
    constant data           : in  can_payload_t;
    constant data_length    : in  natural;
    constant msg            : in  string;
    signal   clk            : in  std_logic;
    signal   can_tx         : out std_logic;
    signal   can_rx         : in  std_logic;
    constant scope          : in  string                := C_SCOPE;
    constant msg_id_panel   : in  t_msg_id_panel        := shared_msg_id_panel;
    constant config         : in  t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT;
    constant proc_name      : in  string                := "can_uvvm_write"
    );


  -- Wait for an incoming CAN frame
  -- The upper 18 bits of arbitration ID are ignored if extended_id is not set
  -- in the config.
  -- The remote_frame output will be set high if the incoming frame
  -- was a remote frame request.
  -- Data is only valid if the remote_frame output is low
  procedure can_uvvm_read (
    variable arb_id         : out std_logic_vector(28 downto 0);
    variable extended_id    : out std_logic;
    variable remote_frame   : out std_logic;
    variable data           : out can_payload_t;
    variable data_length    : out natural;
    constant msg            : in  string;
    signal clk              : in  std_logic;
    signal can_tx           : out std_logic;
    signal can_rx           : in  std_logic;
    variable timeout        : out std_logic;
    constant scope          : in  string                := C_SCOPE;
    constant msg_id_panel   : in  t_msg_id_panel        := shared_msg_id_panel;
    constant config         : in  t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT;
    constant proc_name      : in  string                := "can_uvvm_read"
    );


  -- Wait for an incoming CAN frame, and compare incoming data to data_exp
  -- The upper 18 bits of arbitration ID are ignored if extended_id is not set
  -- in the config.
  -- If remote_expect is set high, the procedure will expect to receive a
  -- remote frame request
  -- If remote_request is set high, this procedure will first send a
  -- remote frame request and then wait for any incoming CAN message
  -- Setting both remote_expect and remote_request high is illlegal
  procedure can_uvvm_check (
    constant arb_id_exp      : in  std_logic_vector(28 downto 0);
    constant extended_id     : in  std_logic;
    constant remote_expect   : in  std_logic;
    constant remote_request  : in  std_logic;
    constant data_exp        : in  can_payload_t;
    constant data_length_exp : in  natural;
    constant msg             : in  string;
    signal clk               : in  std_logic;
    signal can_tx            : out std_logic;
    signal can_rx            : in  std_logic;
    constant alert_level     : in  t_alert_level         := error;
    constant scope           : in  string                := C_SCOPE;
    constant msg_id_panel    : in  t_msg_id_panel        := shared_msg_id_panel;
    constant config          : in  t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT
    );

end package can_uvvm_bfm_pkg;


package body can_uvvm_bfm_pkg is

  procedure can_uvvm_write (
    constant arb_id         : in  std_logic_vector(28 downto 0);
    constant extended_id    : in  std_logic;
    constant remote_request : in  std_logic;
    constant data           : in  can_payload_t;
    constant data_length    : in  natural;
    constant msg            : in  string;
    signal   clk            : in  std_logic;
    signal   can_tx         : out std_logic;
    signal   can_rx         : in  std_logic;
    constant scope          : in  string                := C_SCOPE;
    constant msg_id_panel   : in  t_msg_id_panel        := shared_msg_id_panel;
    constant config         : in  t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT;
    constant proc_name      : in  string                := "can_uvvm_write"
    ) is
    variable v_proc_call      : line;
    variable bit_stuff_dbg    : std_logic := '0';
    variable sample_point_dbg : std_logic := '0';
    variable arb_lost         : std_logic := '0';
    variable ack_received     : std_logic := '0';
  begin
    -- Format procedure call string
    write(v_proc_call, to_string("can_uvvm_write(ID:"));

    if extended_id = '1' then
      write(v_proc_call,to_string(arb_id, HEX, AS_IS, INCL_RADIX));
    else
      write(v_proc_call,to_string(arb_id(10 downto 0), HEX, AS_IS, INCL_RADIX));
    end if;

    write(v_proc_call, to_string(", Length:"));
    write(v_proc_call, to_string(data_length, 1));

    if remote_request = '1' then
      write(v_proc_call, to_string(", RTR"));
    elsif data_length > 0 then
      write(v_proc_call, to_string(", Data:0x"));

      for byte_num in 0 to data_length-1 loop
        write(v_proc_call, to_string(data(byte_num), HEX));
      end loop;
    end if;
    write(v_proc_call, to_string(")"));

    can_write(arb_id,
              remote_request,
              extended_id,
              data,
              data_length,
              clk,
              can_tx,
              can_rx,
              bit_stuff_dbg,
              sample_point_dbg,
              arb_lost,
              ack_received,
              '1', -- bit stuffing enabled
              config.clock_period,
              config.bit_rate,
              config.sync_quanta,
              config.prop_quanta,
              config.phase1_quanta,
              config.phase2_quanta);

    if arb_lost = '1' then
      alert(config.arb_lost_severity, v_proc_call.all & "=> Failed. Arbitration lost.", scope);
    elsif ack_received = '0' then
      alert(config.ack_missing_severity, v_proc_call.all & "=> ACK missing.", scope);
    end if;

    if proc_name = "can_uvvm_write" then
      log(config.id_for_bfm, v_proc_call.all & " completed. " & msg, scope, msg_id_panel);
    end if;

  end procedure can_uvvm_write;


  procedure can_uvvm_read (
    variable arb_id         : out std_logic_vector(28 downto 0);
    variable extended_id    : out std_logic;
    variable remote_frame   : out std_logic;
    variable data           : out can_payload_t;
    variable data_length    : out natural;
    constant msg            : in  string;
    signal clk              : in  std_logic;
    signal can_tx           : out std_logic;
    signal can_rx           : in  std_logic;
    variable timeout        : out std_logic;
    constant scope          : in  string                := C_SCOPE;
    constant msg_id_panel   : in  t_msg_id_panel        := shared_msg_id_panel;
    constant config         : in  t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT;
    constant proc_name      : in  string                := "can_uvvm_read"
    )
  is
    variable v_proc_call      : line;
    variable crc_error        : std_logic := '0';
    variable bit_stuff_dbg    : std_logic := '0';
    variable sample_point_dbg : std_logic := '0';
  begin
    can_read(arb_id,
             remote_frame,
             extended_id,
             data,
             data_length,
             config.max_wait_cycles,
             clk,
             can_rx,
             can_tx,
             bit_stuff_dbg, -- bit stuffing debug output not used
             sample_point_dbg, -- sample point debug output not used
             '1',  -- bit stuffing enabled
             timeout,
             crc_error,
             config.clock_period,
             config.bit_rate,
             config.sync_quanta,
             config.prop_quanta,
             config.phase1_quanta,
             config.phase2_quanta);


    if timeout = '1' then
      alert(config.max_wait_cycles_severity, v_proc_call.all & "Failed, timeout.", scope);
    else
      write(v_proc_call, to_string("can_uvvm_read()=> ID:"));

      if extended_id = '1' then
        write(v_proc_call, to_string(arb_id, HEX, AS_IS, INCL_RADIX));
      else
        write(v_proc_call, to_string(arb_id(10 downto 0), HEX, AS_IS, INCL_RADIX));
      end if;


      if remote_frame = '1' then
        write(v_proc_call, to_string(" RTR"));
      end if;

      write(v_proc_call, to_string(" Length:"));
      write(v_proc_call, to_string(data_length, 1));

      if data_length > 0 and remote_frame = '0' then
        write(v_proc_call, to_string(" Data: 0x"));

        for byte_num in 0 to data_length-1 loop
          write(v_proc_call, to_string(data(byte_num), HEX));
        end loop;
      end if;

      write(v_proc_call, to_string(". "));

      if proc_name = "can_uvvm_read" then
        log(config.id_for_bfm, v_proc_call.all & msg, scope, msg_id_panel);
      end if;
    end if;


  end procedure can_uvvm_read;


  procedure can_uvvm_check (
    constant arb_id_exp      : in  std_logic_vector(28 downto 0);
    constant extended_id     : in  std_logic;
    constant remote_expect   : in  std_logic;
    constant remote_request  : in  std_logic;
    constant data_exp        : in  can_payload_t;
    constant data_length_exp : in  natural;
    constant msg             : in  string;
    signal clk               : in  std_logic;
    signal can_tx            : out std_logic;
    signal can_rx            : in  std_logic;
    constant alert_level     : in  t_alert_level         := error;
    constant scope           : in  string                := C_SCOPE;
    constant msg_id_panel    : in  t_msg_id_panel        := shared_msg_id_panel;
    constant config          : in  t_can_uvvm_bfm_config := C_CAN_UVVM_BFM_CONFIG_DEFAULT
    )
  is
    constant proc_name   : string := "can_uvvm_check";
    variable v_proc_call : line;
    variable v_error_msg : line;

    variable v_empty_data : can_payload_t;

    variable v_arb_id       : std_logic_vector(28 downto 0);
    variable v_remote_frame : std_logic;
    variable v_extended_id  : std_logic;
    variable v_data         : can_payload_t;
    variable v_data_length  : natural;
    variable v_timeout      : std_logic;
  begin
    if remote_expect = '1' and remote_request = '1' then
      write(v_error_msg, to_string(" => Failed. Can not request and expect remote frame"));
      alert(TB_ERROR, v_proc_call.all & v_error_msg.all & LF & msg, scope);
      return;
    end if;

    -- Format procedure call string
    write(v_proc_call, to_string("can_uvvm_check(ID:"));

    if extended_id = '1' then
      write(v_proc_call, to_string(arb_id_exp, HEX, AS_IS, INCL_RADIX));
    else
      write(v_proc_call, to_string(arb_id_exp(10 downto 0), HEX, AS_IS, INCL_RADIX));
    end if;

    write(v_proc_call, to_string(", Length:"));
    write(v_proc_call, to_string(data_length_exp, 1));

    if remote_request = '1' then
      write(v_proc_call, to_string(", send RTR"));
    elsif remote_expect = '1' then
      write(v_proc_call, to_string(", expect RTR"));
    elsif data_length_exp > 0 then
      write(v_proc_call, to_string(", Data:0x"));

      for byte_num in 0 to data_length_exp-1 loop
        write(v_proc_call, to_string(data_exp(byte_num), HEX));
      end loop;
    end if;
    write(v_proc_call, to_string(")"));

    -- Send a remote frame first if requested, and wait for response
    if remote_request = '1' then
      can_uvvm_write (arb_id_exp,
                      extended_id,
                      remote_request,
                      v_empty_data,
                      data_length_exp,
                      msg,
                      clk,
                      can_tx,
                      can_rx,
                      scope,
                      msg_id_panel,
                      config,
                      proc_name);
    end if;

    -- Read CAN message
    can_uvvm_read(v_arb_id,
                  v_extended_id,
                  v_remote_frame,
                  v_data,
                  v_data_length,
                  msg,
                  clk,
                  can_tx,
                  can_rx,
                  v_timeout,
                  scope,
                  msg_id_panel,
                  config,
                  proc_name);

    if v_timeout = '1' then
      log(config.id_for_bfm, v_proc_call.all & "=> Failed, timeout. " & msg, scope, msg_id_panel);
      return;
    end if;

    -- Check if we received basic/extended frame, and what was expected
    if v_extended_id /= extended_id then
      if extended_id = '1' then
        alert(alert_level, v_proc_call.all & "=> Failed. Got basic frame." & LF & msg);
      else
        alert(alert_level, v_proc_call.all & "=> Failed. Got extended frame." & LF & msg);
      end if;
      return;
    end if;

    -- Compare received ID with expected
    if v_extended_id = '1' then
      if v_arb_id /= arb_id_exp then
        alert(alert_level, v_proc_call.all & "=> Failed. Got ID:0x" &
              to_string(v_arb_id, HEX) & LF & msg);
        return;
      end if;
    else
      if v_arb_id(10 downto 0) /= arb_id_exp(10 downto 0) then
        alert(alert_level, v_proc_call.all & "=> Failed. Got ID:0x" &
              to_string(v_arb_id(10 downto 0), HEX) & LF & msg);
        return;
      end if;
    end if;

    -- Check if correct data or remote frame was received
    if v_remote_frame /= remote_expect then
      if remote_expect = '1' then
        alert(alert_level, v_proc_call.all & "=> Failed. Got data frame." & LF & msg);
      else
        alert(alert_level, v_proc_call.all & "=> Failed. Got remote frame." & LF & msg);
      end if;
      return;
    end if;

    -- Check data length
    if v_data_length /= data_length_exp then
      alert(alert_level, v_proc_call.all & "=> Failed. Received data length:" &
            to_string(v_data_length, 1));
      return;
    end if;

    -- Compare data if received and not remote frame
    if v_remote_frame = '0' and v_data_length > 0 then
      if v_data(0 to v_data_length-1) /= data_exp(0 to v_data_length-1) then
        write(v_error_msg, to_string("=> Failed. Received data:0x"));

        for byte_num in 0 to v_data_length-1 loop
          write(v_error_msg, to_string(v_data(byte_num), HEX));
        end loop;

        alert(alert_level, v_proc_call.all & v_error_msg.all & ". " & LF & msg);
        return;
      end if;
    end if;

    log(config.id_for_bfm, v_proc_call.all & "=> OK.");

  end procedure can_uvvm_check;

end package body can_uvvm_bfm_pkg;
