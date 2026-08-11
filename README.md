# FPGA Trading Engine

A low-latency electronic trading engine implemented in SystemVerilog and targeted to a Xilinx Artix-7 FPGA.

The project explores the hardware architecture behind FPGA-based electronic trading systems. It implements order parsing, order-book management, price-time-priority matching, order cancellation, partial fills, and trade generation entirely in synthesizable RTL.

The design was functionally verified using Verilator and synthesized, placed, and routed in AMD Vivado. Post-implementation timing analysis was used to identify critical paths and iteratively optimize the design until timing closure was achieved at a 100 MHz target clock.

---

## Architecture

The trading engine consists of three main RTL components:

### Message Parser

Decodes incoming order messages and converts them into internal control and data signals used by the order book.

### Order Book

Maintains active BUY and SELL orders and implements the core trading logic:

- Order insertion
- Order cancellation
- BUY/SELL matching
- Price priority
- Time priority
- Partial fills
- Best bid tracking
- Best ask tracking

### Trading Engine

Integrates the message parser and order book into the complete processing pipeline.

```text
                Incoming Order Message
                         │
                         ▼
                ┌────────────────┐
                │ Message Parser │
                └───────┬────────┘
                        │
                        ▼
                ┌────────────────┐
                │   Order Book   │
                │                │
                │ Price / Time   │
                │   Priority     │
                └───────┬────────┘
                        │
             ┌──────────┴──────────┐
             ▼                     ▼
       Market State            Trade Event
     Best Bid / Ask        Price / Qty / IDs
```

---

## Order Matching

Orders are matched using **price-time priority**.

For BUY orders, higher prices have priority.

For SELL orders, lower prices have priority.

When multiple orders exist at the same price, the oldest order is selected first.

A BUY order can execute when:

```text
BUY price >= best SELL price
```

A SELL order can execute when:

```text
SELL price <= best BUY price
```

When the quantities of the two orders differ, the engine performs a partial fill and preserves the remaining quantity of the unfilled order.

---

## Verification

A SystemVerilog testbench was developed to verify the complete trading engine.

The verification suite covers:

1. BUY order insertion
2. SELL order insertion without a match
3. Crossing BUY order and trade generation
4. Order cancellation
5. Price-time priority
6. Partial fills
7. End-to-end processing latency

All functional tests pass under Verilator simulation.

![Simulation Results](docs/simulation-results.png)


The measured end-to-end processing latency in the testbench is:

**20 clock cycles**

---

## Timing Optimization

After functional verification, the design was synthesized and implemented in AMD Vivado with a **100 MHz target clock**.

The initial implementation did not meet the 10 ns timing requirement. Timing analysis showed that the critical paths were concentrated in the order-book selection logic, where order comparison and priority logic created long combinational paths and high-fanout signals.

The design was then iteratively optimized using post-implementation timing reports.

The optimization process included:

- Identifying the worst setup paths in Vivado
- Examining combinational depth and high-fanout paths
- Restructuring order-selection logic to shorten critical paths
- Reducing combinational work between sequential elements
- Re-running synthesis and implementation after RTL changes
- Evaluating Vivado implementation strategies for improved placement and routing
- Repeating timing analysis until the 100 MHz constraint was satisfied

During optimization, the worst negative slack was reduced from several nanoseconds of timing violation to **0.000 ns**, with no remaining failing endpoints.


---

## FPGA Implementation

The final design was synthesized, placed, and routed in AMD Vivado targeting a Xilinx Artix-7 FPGA.

### Timing Closure

The final implementation meets the specified **10 ns clock period**, corresponding to a **100 MHz target clock frequency**.

Final timing results:

![Timing Closure](docs/timing-closure.png)

---

## Resource Utilization

Post-implementation resource utilization on the target Artix-7 device:

![FPGA Utilization](docs/utilization.png)

The core logic occupies approximately **13% of the available LUTs** and **4% of the available flip-flops** on the target device.

---

## Tools and Technologies

- **SystemVerilog** — RTL design and verification
- **Verilator** — Functional simulation
- **AMD Vivado** — Synthesis, implementation, timing analysis, and utilization analysis
- **GTKWave** — Waveform inspection
  
---

## Key Results

- Designed a synthesizable electronic trading engine in SystemVerilog
- Implemented hardware order-book management
- Implemented price-time-priority order matching
- Supported order insertion, cancellation, matching, and partial fills
- Developed a SystemVerilog testbench covering core trading behavior
- Passed all functional verification tests
- Measured **20-cycle end-to-end processing latency** in simulation
- Performed post-implementation critical-path analysis in Vivado
- Iteratively optimized RTL and implementation for timing
- Achieved timing closure at a **100 MHz target clock**
- Achieved final **WNS = 0.000 ns** with **0 failing timing endpoints**
- Final implementation uses **2615 LUTs (12.57%)**
- Final implementation uses **1834 flip-flops (4.41%)**

---


