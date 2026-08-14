# FPGA Trading Engine

A low-latency trading engine built in SystemVerilog, targeting a Xilinx Artix-7 FPGA. I wanted to understand what actually happens inside the hardware that HFT firms use to match orders in nanoseconds — so I built one myself, from message parsing all the way down to timing closure.

Everything runs entirely in synthesizable RTL: order parsing, order-book management, price-time-priority matching, cancellations, partial fills, and trade generation.

I verified the design functionally with Verilator, then took it through synthesis, place, and route in AMD Vivado. Getting it to actually meet timing was its own project. My first try missed the 100 MHz target by a good margin, and closing that gap meant digging into critical paths and restructuring the order-selection logic more than once.

---

## Architecture

Three main pieces of RTL:

### Message Parser
Takes incoming order messages and decodes them into the control/data signals the order book actually needs.

### Order Book
This is where the real logic lives — insertion, cancellation, matching, price priority, time priority, partial fills, and tracking the best bid/ask.

### Trading Engine
Wires the parser and order book together into one processing pipeline.

---

## Order Matching

Matching follows standard price-time priority: better prices go first, and if two orders sit at the same price, whichever arrived first wins.

A BUY fills when:
```text
BUY price >= best SELL price
```

A SELL fills when:
```text
SELL price <= best BUY price
```

If the two matched orders don't have equal size, the engine fills what it can and keeps the leftover quantity live on the book.

---

## Verification

I wrote a SystemVerilog testbench to exercise the engine end to end. It covers:

1. BUY order insertion
2. SELL order insertion with no match
3. A crossing BUY that generates a trade
4. Order cancellation
5. Price-time priority
6. Partial fills
7. End-to-end processing latency

Everything passes under Verilator.

![Simulation Results](docs/simulation-results.png)

End-to-end latency measured in the testbench: **20 clock cycles**.

---

## Timing Optimization

Once the logic worked, I moved into Vivado with a 100 MHz target (10 ns period), but the first constrained implementation came back with **−79.331 ns WNS**. The worst path ran through the order-selection logic, where the original linear search created a long chain of dependent comparisons.

The biggest change was replacing that linear search with a balanced **16 → 8 → 4 → 2 → 1 comparator tree**. That helped a lot, but it still wasn't enough to close timing, so I kept working through the critical paths and adding pipeline boundaries where the combinational logic was still too deep.

I also ended up registering both the selected order index and the order itself between stages. This kept later matching logic from going back through the live order book and helped break up some of the remaining paths.

After each change, I re-ran synthesis and implementation and checked the new worst paths. Near the end I also used Vivado's `Performance_Explore` strategy and physical optimization to squeeze out the remaining timing violations.

The progression looked like this:

**−79.331 ns → −65.617 ns → −17.883 ns → −5.170 ns → −0.586 ns → −0.446 ns → 0.000 ns**

The final implementation meets the original **100 MHz** target with **0 failing setup endpoints**.

End-to-end latency after pipelining: **20 clock cycles (200 ns)**.


---

## FPGA Implementation

Final design synthesized, placed, and routed for a Xilinx Artix-7.

### Timing Closure

Meets the 10 ns period / 100 MHz target with zero failing endpoints.

![Timing Closure](docs/timing-closure.png)

---

## Resource Utilization

![FPGA Utilization](docs/utilization.png)

The core logic comes in at roughly 13% of the device's LUTs and 4% of its flip-flops.

---

## Tools

- SystemVerilog — RTL design and verification
- Verilator — Functional simulation
- AMD Vivado — Synthesis, implementation, timing analysis, utilization
- GTKWave — Waveform debugging

---

## Key Results

- Built a synthesizable electronic trading engine in SystemVerilog, from scratch
- Implemented a hardware order book with price-time-priority matching
- Supports insertion, cancellation, matching, and partial fills
- Wrote a full SystemVerilog testbench covering core trading behavior — all tests passing
- Measured 20-cycle end-to-end latency in simulation
- Chased down and closed timing in Vivado through several rounds of critical-path analysis
- Closed timing at 100 MHz: **WNS = 0.000 ns**, 0 failing endpoints
- Final footprint: **2,615 LUTs (12.57%)**, **1,834 flip-flops (4.41%)**
