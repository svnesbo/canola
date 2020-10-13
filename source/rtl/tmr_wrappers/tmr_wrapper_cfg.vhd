-------------------------------------------------------------------------------
-- Title      : Configurations for the TMR wrappers
-- Project    : Canola CAN Controller
-------------------------------------------------------------------------------
-- File       : tmr_wrapper_cfg.vhd
-- Author     : Simon Voigt Nesbø  <svn@hvl.no>
-- Company    :
-- Created    : 2020-10-10
-- Last update: 2020-10-14
-- Platform   :
-- Standard   : VHDL'08
-------------------------------------------------------------------------------
-- Description: Configuration declarations for the TMR wrappers in the design.
--              The configurations choose the TMR voter entities to be used
--              with the component declarations from tmr_voter_pkg.
--              If you want to use custom TMR voters, you can modify this file
--              to map to the existing voter components.
-------------------------------------------------------------------------------
-- Copyright (c) 2020
-------------------------------------------------------------------------------
-- Revisions  :
-- Date        Version  Author  Description
-- 2020-10-10  1.0      svn     Created
-------------------------------------------------------------------------------
library work;
use work.tmr_voter_pkg.all;


-------------------------------------------------------------------------------
-- BTL - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration canola_btl_tmr_wrapper_cfg of canola_btl_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter
        use entity work.tmr_voter(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT        => INPUT,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration canola_btl_tmr_wrapper_cfg;


-------------------------------------------------------------------------------
-- BSP - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration canola_bsp_tmr_wrapper_cfg of canola_bsp_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter
        use entity work.tmr_voter(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT        => INPUT,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_array
        use entity work.tmr_voter_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration canola_bsp_tmr_wrapper_cfg;


-------------------------------------------------------------------------------
-- EML - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration canola_eml_tmr_wrapper_cfg of canola_eml_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter
        use entity work.tmr_voter(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT        => INPUT,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_array
        use entity work.tmr_voter_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration canola_eml_tmr_wrapper_cfg;


-------------------------------------------------------------------------------
-- Frame Rx FSM - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration canola_frame_rx_fsm_tmr_wrapper_cfg of canola_frame_rx_fsm_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter
        use entity work.tmr_voter(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT        => INPUT,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_array
        use entity work.tmr_voter_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration canola_frame_rx_fsm_tmr_wrapper_cfg;


-------------------------------------------------------------------------------
-- Frame Tx FSM - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration canola_frame_tx_fsm_tmr_wrapper_cfg of canola_frame_tx_fsm_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter
        use entity work.tmr_voter(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT        => INPUT,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_array
        use entity work.tmr_voter_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration canola_frame_tx_fsm_tmr_wrapper_cfg;


-------------------------------------------------------------------------------
-- Time Quanta Generator - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration canola_time_quanta_gen_tmr_wrapper_cfg of canola_time_quanta_gen_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter
        use entity work.tmr_voter(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT        => INPUT,
                    VOTER_OUT    => VOTER_OUT,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration canola_time_quanta_gen_tmr_wrapper_cfg;


-------------------------------------------------------------------------------
-- Saturating counter - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration counter_saturating_tmr_wrapper_triplicated_cfg of counter_saturating_tmr_wrapper_triplicated is

  for structural
    for if_TMR_generate

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for;  -- if_TMR_generate
  end for;  -- structural

end configuration counter_saturating_tmr_wrapper_triplicated_cfg;


-------------------------------------------------------------------------------
-- Up counter - TMR Wrapper Configuration
-------------------------------------------------------------------------------
configuration up_counter_tmr_wrapper_cfg of up_counter_tmr_wrapper is

  for structural
    for if_TMR_generate

      for all : tmr_voter_triplicated_array
        use entity work.tmr_voter_triplicated_array(rtl)
          generic map (
            G_MISMATCH_OUTPUT_EN     => G_MISMATCH_OUTPUT_EN,
            G_MISMATCH_OUTPUT_2ND_EN => G_MISMATCH_OUTPUT_2ND_EN,
            G_MISMATCH_OUTPUT_REG    => G_MISMATCH_OUTPUT_REG)
          port map (CLK          => CLK,
                    INPUT_A      => INPUT_A,
                    INPUT_B      => INPUT_B,
                    INPUT_C      => INPUT_C,
                    VOTER_OUT_A  => VOTER_OUT_A,
                    VOTER_OUT_B  => VOTER_OUT_B,
                    VOTER_OUT_C  => VOTER_OUT_C,
                    MISMATCH     => MISMATCH,
                    MISMATCH_2ND => MISMATCH_2ND);
      end for;

    end for; -- if_TMR_generate
  end for;  -- structural

end configuration up_counter_tmr_wrapper_cfg;
