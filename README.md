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

Once the logic worked, I moved into Vivado with a 100 MHz target (10 ns period), but the first pass didn't meet timing. The reports pointed to the order-book selection logic as the bottleneck — the comparison and priority chains formed long combinational paths with heavy loaded signals which was the main thing holding the design back.

From there it was a lot of back-and-forth:

- Pulling the worst setup paths out of Vivado's timing reports
- Tracing through combinational depth and high-fanout nets
- Reworking the order-selection logic to break up those long paths
- Pushing more of the logic behind registers to shorten combinational stretches
- Re-synthesizing and re-implementing after every RTL change
- Trying different Vivado implementation strategies to see what placement/routing helped
- Repeating all of the above until the numbers actually closed

Worst negative slack went from 90 ns in the red to a clean 0.000 ns, with nothing left failing.

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
