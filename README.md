
# Asynchronous FIFO — CDC, Gray-Code Pointers & Static Timing Analysis

## Overview

This project implements and verifies an Asynchronous FIFO (First-In, First-Out) in Verilog, with independent write and read clock domains.

The main purpose of this project was to develop a practical understanding of:

* Clock Domain Crossing (CDC)
* Metastability and 2-flip-flop synchronizers
* Binary-to-Gray code conversion
* Asynchronous FIFO pointer architecture
* Full and empty detection
* Dual-clock memory inference
* Quartus FPGA synthesis and resource utilization
* Static Timing Analysis (STA)
* SDC clock constraints
* Unconstrained paths and I/O timing analysis
* Synchronizer identification in FPGA timing analysis

The design was developed and simulated using "ModelSim Intel FPGA Starter Edition" and synthesized/analysed using "Intel Quartus Prime 20.1.1".

---

## Project Objectives

The project was developed progressively rather than treating the FIFO as a black-box IP.

The implementation started with individual concepts and was then combined into a complete asynchronous FIFO:

Single-Bit CDC
      ↓
2-Flip-Flop Synchronizer
      ↓
Binary-to-Gray Conversion
      ↓
Multi-Bit Gray-Code CDC
      ↓
Write/Read Pointers
      ↓
Full/Empty Detection
      ↓
Dual-Clock FIFO Memory
      ↓
Static Timing Analysis


This approach allowed each part of the architecture to be simulated and understood independently before integration.

---

# 1. Asynchronous FIFO Architecture

The FIFO contains two independent clock domains:
                 WRITE DOMAIN
                wr_clk = 10 ns
                     │
                     ▼
                Write Pointer
                     │
                  Binary
                     │
                     ▼
                  Gray Code
                     │
                     ▼
              2-FF Synchronizer
                     │
                     │
                     ▼
              READ CLOCK DOMAIN
              READ CLOCK DOMAIN
                rd_clk = 14 ns
                     │
                     ▼
                 Read Pointer
                     │
                  Binary
                     │
                     ▼
                  Gray Code
                     │
                     ▼
              2-FF Synchronizer
                     │
                     │
                     ▼
             WRITE CLOCK DOMAIN


The write and read clocks are intentionally asynchronous.

For this implementation:

* Write clock period: 10 ns
* Write clock frequency: 100 MHz
* Read clock period: 14 ns
* Read clock frequency: approximately 71.43 MHz

The two clocks are therefore not assumed to have a fixed phase relationship.

---

# 2. Why Clock Domain Crossing Matters

A signal generated in one clock domain cannot safely be sampled directly by unrelated clock-domain logic.

For example:


Clock Domain A                 Clock Domain B

   clk_A                          clk_B
     │                              │
     ▼                              ▼

   Signal A ────────────────────► Logic B


If Signal A changes close to an active edge of clk_B, the receiving flip-flop can enter a metastable state.

A basic single-bit synchronizer was first implemented:

verilog
always @(posedge clk_B) begin
    sync1 <= signal_A;
    sync2 <= sync1;
end


The first flip-flop samples the asynchronous signal.

The second flip-flop provides an additional clock period for the first flip-flop's metastable condition to resolve.
             Clock Domain B

signal_A ──► FF1 ──► FF2 ──► synchronized signal
              │
              │
         possible
       metastability


A synchronizer does not mathematically eliminate metastability. Instead, it makes the probability of metastability propagating into subsequent logic extremely small.

---

# 3. Why Binary Counters Cannot Simply Be Synchronized

A multi-bit binary counter can change several bits simultaneously.

For example:

Binary:

0111
 ↓
1000

Four bits change during this transition.

If each bit is independently synchronized into another clock domain, the receiving domain could temporarily observe an invalid combination.

For example:

0111 → 1000

Possible sampled combination:
0100


The receiving domain could therefore observe a value that never actually existed in the source domain.

---

# 4. Gray Code

To reduce this problem, the FIFO uses **Gray-coded pointers** for clock-domain crossing.

Gray code has the important property that adjacent values differ by only one bit.

Example:

| Decimal | Binary | Gray |
| ------: | :----: | :--: |
|       0 |  0000  | 0000 |
|       1 |  0001  | 0001 |
|       2 |  0010  | 0011 |
|       3 |  0011  | 0010 |
|       4 |  0100  | 0110 |
|       5 |  0101  | 0111 |
|       6 |  0110  | 0101 |
|       7 |  0111  | 0100 |

For a binary value:

B[N:0]


the Gray code is generated using:

verilog
gray = binary ^ (binary >> 1);


For example:


Binary = 0011

0011
0011 >> 1 = 0001

0011 XOR 0001 = 0010

Gray = 0010


The Gray-coded pointer is then transferred through the synchronizer.

---

# 5. FIFO Pointer Architecture

For an 8-entry FIFO:


Depth = 8


Three bits are required to address the memory:


2^3 = 8


Therefore:


Memory address = pointer[2:0]


However, the FIFO pointer itself uses 4 bits.

\
P3 P2 P1 P0
│  └──────┘
│     memory address
│
└── wrap-around information

The additional MSB allows the FIFO to distinguish between:


EMPTY


and


FULL


when the lower address bits are identical.

Example:

### Empty


Write pointer = 0000
Read pointer  = 0000


The pointers are equal.

Therefore:


EMPTY = 1


### After eight writes

Write pointer = 1000
Read pointer  = 0000


The lower three bits are both:

000


but the extra wrap bit is different.

Therefore the FIFO is:


FULL = 1


This extra pointer bit is essential for correctly detecting FIFO wrap-around.

---

# 6. Pointer Synchronization

The write pointer is converted to Gray code and transferred into the read clock domain.

verilog
always @(posedge rd_clk or posedge reset) begin
    if (reset) begin
        wr_gray_sync1 <= 4'b0000;
        wr_gray_sync_rd <= 4'b0000;
    end
    else begin
        wr_gray_sync1 <= wr_gray;
        wr_gray_sync_rd <= wr_gray_sync1;
    end
end


This creates a two-stage synchronizer:


wr_gray
   │
   ▼
sync1
   │
   ▼
sync2
   │
   ▼
read clock domain


The important detail is that the synchronizer registers are clocked by **`rd_clk`**.

The reverse direction uses the write clock:


rd_gray
   │
   ▼
sync1
   │
   ▼
sync2
   │
   ▼
write clock domain


This allows each clock domain to safely receive the other domain's pointer information.

---

# 7. Full and Empty Detection

## Empty Detection

In the read domain:

verilog
assign empty = (rd_gray == wr_gray_sync_rd);


The FIFO is empty when the read pointer has caught up with the synchronized write pointer.

text
read pointer
     │
     ▼
     ●───────────────●
                     ▲
                     │
              synchronized
              write pointer
\

---

## Full Detection

For the 4-bit Gray-coded pointer used by this 8-entry FIFO:

\verilog
assign full = (wr_gray ==
              {~rd_gray_sync_wr[3:2],
               rd_gray_sync_wr[1:0]});
\

The upper two bits of the synchronized read Gray pointer are inverted for the full comparison.

This corresponds to the pointer being one complete FIFO depth ahead of the read pointer.

---

# 8. FIFO Memory

The FIFO stores:

* 8 entries
* 8 bits per entry

The memory is declared as:

verilog
reg [7:0] memory [0:7];


Therefore:

text
Depth  = 8
Width  = 8 bits
Storage = 64 bits


Write access occurs in the write clock domain:

verilog
always @(posedge wr_clk) begin
    if (wr_en && !full)
        memory[wr_ptr[2:0]] <= data_in;
end


Read access occurs in the read clock domain:

verilog
always @(posedge rd_clk or posedge reset) begin
    if (reset)
        data_out <= 8'b00000000;
    else if (rd_en && !empty)
        data_out <= memory[rd_ptr[2:0]];
end


The current implementation is intended as a learning implementation. Dual-clock RAM inference is device-specific, so the generated hardware mapping was checked using Quartus synthesis rather than assuming a particular RAM primitive.

--

# 9. Data Path vs Control Path

One of the key architectural concepts demonstrated by this project is the separation between the data path and the control/CDC path.

### Data path


data_in
   │
   ▼
FIFO memory
   │
   ▼
data_out


### Control path


Write Pointer
     │
     ▼
Gray Conversion
     │
     ▼
CDC Synchronizer
     │
     ▼
Read Domain
     │
     ▼
EMPTY detection


and:


Read Pointer
     │
     ▼
Gray Conversion
     │
     ▼
CDC Synchronizer
     │
     ▼
Write Domain
     │
     ▼
FULL detection


The Gray-coded pointer information crosses clock domains.

The FIFO data itself is stored in the shared dual-clock memory.

---

# 10. Simulation and Verification

The FIFO was simulated using ModelSim.

The testbench exercised:

* Reset
* FIFO writes
* FIFO reads
* FIFO full condition
* FIFO empty condition
* FIFO wrap-around
* Independent write/read clocks
* CDC pointer synchronization
* FIFO ordering

Example test data included:


Data 1 = 10101010
Data 2 = 11001100


The values were written into the FIFO and subsequently read back in FIFO order.

Waveforms were inspected to observe:


wr_ptr
wr_gray
rd_ptr
rd_gray
wr_gray_sync_rd
rd_gray_sync_wr
full
empty
data_in
data_out


This provided visibility into both the data path and the CDC control path.

---

# 11. Quartus Synthesis

The design was synthesized using:

Intel Quartus Prime 20.1.1

Target FPGA:

Intel Cyclone V 5CSEMA5F31C6

Quartus successfully inferred dual-port RAM for the FIFO memory.

The synthesis report showed:

| Resource          | Usage |
| ----------------- | ----: |
| ALMs              |    20 |
| Registers         |    41 |
| Block memory bits |    64 |
| DSP blocks        |     0 |
| PLLs              |     0 |

The inferred memory was reported as:


Operation mode: DUAL_PORT
Width: 8 bits
Address width: 3 bits
Number of words: 8


This corresponds to the intended:


8 × 8-bit FIFO


---

# 12. Static Timing Analysis

An important part of this project was understanding how FPGA timing analysis behaves when clock constraints are missing.

Initially, the design did not have correct clock constraints.

Quartus therefore derived unrealistic 1 ns clocks.

This produced negative setup slack because the timing analyzer was effectively trying to meet a 1 GHz clock requirement rather than the intended clock periods.

The timing report initially showed negative setup slack.

---

# 13. SDC Clock Constraints

The intended clocks were then explicitly constrained using an SDC file:


create_clock -name wr_clk -period 10.000 [get_ports wr_clk]

create_clock -name rd_clk -period 14.000 [get_ports rd_clk]

set_clock_groups -asynchronous \
    -group [get_clocks wr_clk] \
    -group [get_clocks rd_clk]


These constraints tell Quartus:


wr_clk = 10 ns
rd_clk = 14 ns


and:


wr_clk and rd_clk are asynchronous


The asynchronous clock grouping is important because the two clock domains do not have a fixed phase relationship.

---

# 14. Timing Results After Clock Constraints

After applying the clock constraints, Quartus reported positive setup and hold slack.

Representative slow-corner results included:

| Clock    | Setup Slack | Hold Slack |
| -------- | ----------: | ---------: |
| `wr_clk` |   +6.631 ns |  +0.440 ns |
| `rd_clk` |  +10.406 ns |  +0.230 ns |

Minimum pulse-width checks were also positive.

This demonstrated the importance of providing correct clock definitions to STA.

A timing failure caused by incorrect or missing constraints is fundamentally different from a timing failure caused by insufficient physical performance.

---

# 15. CDC Timing Analysis

Quartus identified synchronizer chains in the design.

The timing report identified:


Synchronizer chains: 8
Shortest synchronizer chain: 2 registers


The two-register structure corresponds to the intended CDC architecture:


Asynchronous signal
        │
        ▼
   Synchronizer FF1
        │
        ▼
   Synchronizer FF2
        │
        ▼
Receiving domain


The report also provided available settling-time information for the synchronizer chains.

This was useful for understanding how FPGA timing tools analyse metastability-related structures.

---

# 16. Understanding "Design Is Not Fully Constrained"

After the clocks were correctly constrained, Quartus no longer reported unconstrained clocks.

However, the design still reported unconstrained I/O paths.

The report showed:


Illegal Clocks                 0
Unconstrained Clocks           0
Unconstrained Input Ports     11
Unconstrained Input Paths     76
Unconstrained Output Ports    34
Unconstrained Output Paths    54


The unconstrained input ports were:


data_in[7:0]
wr_en
rd_en
reset


The 34 unconstrained outputs corresponded to the exposed output signals in the learning version of the design.

---

# 17. Why the I/O Paths Were Unconstrained

Clock constraints tell Quartus when the FPGA clocks occur.

They do not automatically tell Quartus when external devices drive or consume FPGA I/O.

For example:


External device
      │
      │ data_in
      ▼
FPGA input
      │
      ▼
FPGA logic


Quartus needs additional information about when `data_in` becomes valid relative to a reference clock.

This is normally represented using an input-delay constraint such as:


set_input_delay


Similarly:

FPGA logic
    │
    ▼
FPGA output
    │
    ▼
External device


requires information about when the external device expects the signal.

This is normally represented using:


set_output_delay
`

No arbitrary input/output delays were added because this standalone educational FIFO does not have a defined external device timing specification.

This prevents the timing report from being artificially "fixed" using assumptions that do not represent a real system.

---

# 18. Important STA Lesson

The project demonstrated the difference between:

### Clock constraint

create_clock


Defines the clock period and timing waveform.

### Input delay

set_input_delay
`

Describes when an external input can arrive relative to a reference clock.

### Output delay


set_output_delay


Describes the timing requirement imposed by an external receiving device.

### Clock grouping

set_clock_groups -asynchronous


Defines unrelated clock domains so that ordinary inter-clock setup/hold analysis is not performed between them.

These constraints solve different timing-analysis problems and should not be used interchangeably.

---

# 19. Verification Strategy

The project followed a progressive verification strategy:

`
Concept
  ↓
Small standalone simulation
  ↓
Waveform inspection
  ↓
Integration
  ↓
FIFO simulation
  ↓
Synthesis
  ↓
RTL/resource inspection
  ↓
Static Timing Analysis
  ↓
CDC analysis


This allowed functional behaviour and implementation behaviour to be investigated separately.

---

# 20. Tools Used

### HDL

* Verilog

### Simulation

* ModelSim Intel FPGA Starter Edition 10.5b

### FPGA Design

* Intel Quartus Prime 20.1.1

### Hardware

* Intel Cyclone V DE1-SoC

### Analysis

* RTL simulation
* Quartus Analysis & Synthesis
* Fitter
* Timing Analyzer
* CDC/synchronizer analysis
* Resource utilization analysis

---

# 21. Project Structure

A possible repository structure is:

async-fifo/
│
├── rtl/
│   └── async_fifo.v
│
├── tb/
│   └── async_fifo_tb.v
│
├── constraints/
│   └── async_fifo_quartus.sdc
│
├── simulation/
│   └── waveforms/
│
├── reports/
│   ├── synthesis/
│   ├── fitter/
│   └── timing/
│
└── README.md


---

# 22. Key Learning Outcomes

Through this project, I developed practical understanding of:

* Clock Domain Crossing
* Metastability
* Multi-stage synchronizers
* Gray-code encoding
* Asynchronous FIFO architecture
* FIFO pointer wrap-around
* Full/empty detection
* Dual-clock RAM inference
* FPGA synthesis
* Resource utilization
* Static Timing Analysis
* SDC constraints
* Clock-domain relationships
* Unconstrained I/O timing
* Synchronizer analysis in Quartus

The project also provided practical experience interpreting FPGA tool reports rather than treating synthesis and timing reports as simple pass/fail outputs.

---

# 23. Future Improvements

Potential extensions include:

* Add a parameterized FIFO depth and data width
* Implement a cleaner production-style FIFO interface
* Add dedicated write/read status flags
* Add almost-full and almost-empty flags
* Add SystemVerilog assertions
* Add constrained-random verification
* Add functional coverage
* Compare RTL behaviour against a reference FIFO model
* Investigate Quartus RAM inference in greater detail
* Add appropriate I/O timing constraints for a defined external interface
* Investigate Quartus synchronizer/MTBF reporting and explicit synchronizer identification
* Implement the FIFO using vendor-supported FPGA FIFO primitives/IP for comparison
* Port the design to a different FPGA family such as Intel MAX 10

---

## Conclusion

This project demonstrates an asynchronous FIFO implemented from fundamental RTL building blocks, with particular emphasis on CDC correctness, Gray-coded pointer transfer, FIFO status generation, FPGA memory inference, and static timing analysis.

Rather than treating the FIFO as a black-box component, the project was developed incrementally to understand how the RTL maps to FPGA hardware and how Quartus analyses clock domains, synchronizer chains, memory resources, and timing constraints.
