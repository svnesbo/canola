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



# Test project for Zynq ZYBO board

The repository includes a test project on the Digilent ZYBO Zynq board is available for the controller. It is a Zynq processor block design with four instances of the Canola controller, and software for testing is also included in the repository. The software configures the controllers for a bitrate of 1 Mbit.
The project is for the [original ZYBO board](https://store.digilentinc.com/zybo-zynq-7000-arm-fpga-soc-trainer-board/), but could probably be adapted for newer versions of the board without too much difficulty.


## Setup Vivado project

The canola_test.tcl script in the vivado/ directory allows the project to be created. It was made using Vivado version 2018.3, but may work for other version.

To create the project (on linux), source the Vivado settings file (change the path to where ever your Vivado installation resides):

```console
$ . /opt/Xilinx/Vivado/2018.3/settings64.sh
```

Then from the top directory of the Canola repository, run Vivado with the following parameters:

```console
$ vivado -mode gui -source "vivado/canola_test.tcl"
```

And finally run implementation and generate bitstream.


## Setup Xilinx SDK firmware project

The firmware/software project for the Zynq is written in C and resides in software/canola_zynq_test/.

Before the firmware can be compiled you will have to generate the projects for the Zynq CPU and BSP (Board Support Package) for the canola_test Zynq design.

### Step 1 - Export hardware from Vivado

From the Vivado GUI, choose File -> Export Hardware. Choose "Export to: Local to Project". If you want to be able to program the FPGA from the Xilinx SDK, check the "Include bitstream" box (can be left unchecked if you want to program the FPGA from Vivado).


### Step 2 - Launch Xilinx SDK

From the Vivado GUI, choose File -> Launch SDK. Leave both "Exported location" and "Workspace" to "Local to Project".


### Step 3 - Create BSP project in Xilinx SDK

From Xilinx SDK, choose File -> New -> Board Support Package to create a new BSP project for the design.

![New Board Support Package Project](doc/zynq/xilinx_sdk_create_bsp.png "New Board Support Package Project")

The settings should be as in the image shown above. Choose to have the project created in the default location, and give the project the name "canola_test_bsp", because this is what the project for the actual Zynq firmware expects. 

Click Finish, and in then OK in the next window for the Board Support Package Settings (shown in the image below). The test project does not use any of the additional support libraries.

![Board Support Package Settings](doc/zynq/xilinx_sdk_create_bsp.png "Board Support Package Settings")


### Step 4 - Import Canola test project in Xilinx SDK

Finally, choose File -> Import in Xilinx SDK, and choose General -> Existing Projects into Workspace, as shown in the image below. The path to the project is software/canola_zynq_test/.

![Import Project](doc/zynq/xilinx_sdk_import_project1.png "Import Project")

Set the root directory to the project in software/canola_zynq_test/. The import window should look something like in the image below then. Then click Finish.

![Import Project](doc/zynq/xilinx_sdk_import_project2.png "Import Project")


### Step 5 - Build and launch project

You should now be able to build the firmware. Right click the canola_zynq_test project in the Project Explorer, and select Build Project. It should compile without any problems.

After compiling, right click the project again and select Debug As -> "Launch on Hardware (System Debugger)". Allow the debug perspective to be opened, and remember to click the resume button (play/pause icon, or Run->Resume) to start the debugger.

Obviously you can also run the project without the debugger if you don't need or want it.


## Using the test firmware

### UART status messages

The test firmware outputs some status messages and register values for the Canola controllers when it starts up on the JTAG UART. It should look something like below:

```
Starting...
-------------------
Initializing interrupts...
Initializing GPIO...
SW: 0
BTN: 0

Initializing Canola CAN controllers...
--------------------------------------
CONTROL: 0000000000
CONFIG: 0000000000
STATUS: 0000000000
BTL_PROP_SEG: 0x00000007
BTL_PHASE_SEG1: 0x00000007
BTL_PHASE_SEG2: 0x00000007
BTL_SYNC_JUMP_WIDTH: 0x00000001
BTL_TIME_QUANTA_CLOCK_SCALE: 0x00000009

Device 0:
-------------
STATUS: 0000000000
TRANSMIT_ERROR_COUNT: 0
RECEIVE_ERROR_COUNT: 0
TX_MSG_SENT_COUNT: 0
TX_ACK_RECV_COUNT: 0
TX_ARB_LOST_COUNT: 0
TX_ERROR_COUNT: 0
RX_MSG_RECV_COUNT: 0
RX_CRC_ERROR_COUNT: 0
RX_FORM_ERROR_COUNT: 0
RX_STUFF_ERROR_COUNT: 0
CONTROL: 0000000000
CONFIG: 0000000000
STATUS: 0000000000
BTL_PROP_SEG: 0x00000007
BTL_PHASE_SEG1: 0x00000007
BTL_PHASE_SEG2: 0x00000007
BTL_SYNC_JUMP_WIDTH: 0x00000001
BTL_TIME_QUANTA_CLOCK_SCALE: 0x00000009

...

```

When a test mode is active, status messages are displayed periodically (see below).

The UART for the ZYBO board typically appears as /dev/ttyUSB1 in Linux (unless you had other USB UART/serial devices connected already). The baud rate is 115200.


### Observing CAN messages

With a CAN adapter for your PC you can observe the messages transmitted by the Canola CAN controllers. It has been tested with [PEAK System's PCAN-USB](https://www.peak-system.com/PCAN-USB.199.0.html?&L=1)

SocketCAN must be setup in Linux before you can use the CAN adapter. The setup_socketcan.sh script takes care of loading the necessary kernel modules for CAN and SocketCAN, and sets up the can0 interface with a bitrate of 1 Mbit:

```console
$ sudo software/setup_socketcan.sh
```

When the can0 interface is up, you can view incoming CAN messages using candump:

```console
$ candump -L -x can0
```

Or if you want more information about the messages, cansniffer can be used instead:

```console
$ cansniffer can0
```

### Starting transmission from Canola controllers on Zynq board

The current version of the test firmware has 3 test modes:

* Manual mode
* Continuous mode
* Sequence mode


#### Manual mode

Turn SW0 on and leave the other switches off to enter the manual test mode.

While in the manual test mode, messages are sent when the push buttons are pressed. Button BTN0 sends messages from Canola instance 0, BTN1 from instance 1, and so on.

Turn SW0 off again to leave the manual test mode.


#### Continuous mode

Turn SW1 on and leave the other switches off to enter the continuous test mode.

In this mode transmissions of random data are continuously started from the controllers when they are not busy. Transmissions will be started from several controllers at the same time, and allows the loss of arbitration to be tested.

Status counters are printed after every 10000 message.

Turn SW1 off again to leave the continuous test mode.


#### Sequential mode

Turn SW2 on and leave the other switches off to enter the continuous test mode.

In this test mode transmissions of random data are started from one controller at a time. The test waits for 2 milliseconds after each transmission has been started, which should be sufficient for a CAN message of any length at 1 Mbit. After waiting it verifies that it received the Tx done interrupt from the transmitting controller, and that it got Rx message interrupt from the receiving controllers. The firmware has counters for success, failure, and number of messages sent and received. The counter values are printed when the test is stopped. Counter registers in the controllers are printed for every 10000 message that is sent.

Turn SW2 off again to leave the continuous test mode.
