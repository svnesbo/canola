/**
 * @file   canola_tests.h
 * @author Simon Voigt Nesbo
 * @date   January 23, 2020
 * @brief  Test modes in Zynq tes firmware for Canola CAN controller
 */

#ifndef CANOLA_TESTS_H
#define CANOLA_TESTS_H

void canola_manual_test(void);
void canola_continuous_send_test(void);
void canola_sequence_send_test(void);

#endif
