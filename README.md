# Canola

A CAN bus controller for FPGA's written in VHDL

![Canola CAN Controller Block Diagram](doc/canola_block_diagram.png)

## Bit Timing Logic (BTL)

### PROP_SEG

The length of the propagation segment is equal to PROP_SEG+1

TODO: Require an input sequence like 00011111

### PHASE_SEG1

The length of the phase segment 1 is equal to PHASE_SEG1+1

TODO: Require an input sequence like 00011111

### PHASE_SEG2

The length of the phase segment 1 is equal to PHASE_SEG2+1
PHASE_SEG2 should be not be longer than PHASE_SEG1

TODO: Require an input sequence like 00011111


# Note

The CAN controller should be as dumb as possible! It should not calculate stuff, it should be supplied with the correct register values from software in order to minimize the amount of logic, and reduce its radiation cross section.
