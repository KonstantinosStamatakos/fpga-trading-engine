# FPGA Low-Latency Trading Engine

A hardware-oriented trading engine implemented in SystemVerilog, designed to explore deterministic, low-latency order processing on FPGA architectures.

The system accepts encoded market messages, maintains a simplified limit order book, performs price-time-priority matching, supports order cancellation and partial fills, and produces trade execution outputs.

The complete design was verified through SystemVerilog simulation and synthesized/implemented in AMD Vivado with a 100 MHz clock target.

---

## Overview

Electronic trading systems require extremely low and predictable processing latency. FPGAs are well suited to these workloads because market-data processing, order-book operations, and matching logic can be implemented directly in hardware.

This project implements a simplified FPGA trading pipeline:

```text
                 Incoming Message
                       │
                       ▼
              ┌─────────────────┐
              │ Message Parser  │
              └────────┬────────┘
                       │
                ADD / CANCEL
                       │
                       ▼
              ┌─────────────────┐
              │   Order Book    │
              │                 │
              │   BUY │ SELL    │
              └────────┬────────┘
                       │
                       ▼
              ┌─────────────────┐
              │ Matching Logic  │
              └────────┬────────┘
                       │
                       ▼
                 Trade Output
```

The design focuses on hardware architecture, deterministic processing, pipelining, and timing optimization rather than implementing a full production exchange.

---

## Features

- SystemVerilog RTL implementation
- Encoded market-message parsing
- Limit order book
- BUY and SELL order handling
- Best bid / best ask tracking
- Price-time priority
- Crossing-order detection
- Order cancellation
- Partial fills
- Trade execution output
- Sequence-number based time priority
- Pipelined order-book search
- Self-checking SystemVerilog testbench
- End-to-end latency measurement
- FPGA synthesis and implementation in Vivado
- 100 MHz timing target achieved

---

## Architecture

### Message Parser

`message_parser.sv` converts incoming encoded messages into internal trading-engine commands.

The parser extracts information such as:

- message type
- order ID
- side
- price
- quantity

These signals are passed to the order-book logic for processing.

### Order Book

`order_book.sv` maintains active BUY and SELL orders.

Each order contains information including:

```text
valid
side
price
quantity
order_id
sequence_number
```

Sequence numbers preserve arrival ordering when multiple orders exist at the same price.

The book determines the highest-priority BUY and SELL orders according to:

1. Price priority
2. Time priority

For BUY orders, higher prices have priority.

For SELL orders, lower prices have priority.

Orders at the same price are prioritized by arrival sequence.

### Matching Engine

A trade occurs when an incoming order crosses an existing order on the opposite side of the book.

Example:

```text
Best Ask: 10010

Incoming BUY:
Price:     10020
Quantity:  20
```

Because:

```text
10020 >= 10010
```

the orders cross and a trade is generated.

The engine outputs information including:

```text
buy_order_id
sell_order_id
execution_price
execution_quantity
```

Partial fills are supported when the quantities of the two orders differ.

---

## Pipelined Order Search

Finding the best order requires comparing multiple active entries.

A large combinational comparison network creates a long FPGA critical path, so the search logic is pipelined across multiple comparison levels.

Conceptually:

```text
Orders
  │
  ▼
Pairwise comparisons
  │
  ▼
Intermediate winners
  │
  ▼
Higher-level comparisons
  │
  ▼
Best Bid / Best Ask
```

This reduces the amount of combinational logic between registers and improves achievable clock frequency.

---

## Verification

The design includes a self-checking SystemVerilog testbench:

```text
tb/trading_engine_tb.sv
```

The testbench verifies several important behaviors.

### Test 1 — Add BUY

Verifies that a BUY order is correctly inserted and becomes the best bid.

### Test 2 — Add SELL Without Match

Adds a SELL order above the current bid and verifies that no trade occurs.

### Test 3 — Crossing BUY

Sends a BUY order that crosses the best ask and verifies the generated trade.

### Test 4 — Cancel

Verifies removal of an existing order from the book.

### Test 5 — Price-Time Priority

Adds multiple orders at the same price and verifies that the earlier order receives execution priority.

### Test 6 — Partial Fill

Verifies correct quantity handling when only part of an order can be executed.

### Test 7 — End-to-End Latency

Measures the number of clock cycles between an input transaction and the resulting trade output.

Simulation result:

```text
TEST 1: ADD BUY
PASS TEST 1

TEST 2: ADD SELL without match
PASS TEST 2

TEST 3: Crossing BUY
PASS TEST 3

TEST 4: CANCEL
PASS TEST 4

TEST 5: Price-time priority
PASS TEST 5

TEST 6: Partial fill
PASS TEST 6

TEST 7: End-to-end latency
PASS TEST 7: End-to-end latency = 20 cycles

====================================
ALL TRADING ENGINE TESTS PASSED
====================================
```

---

## FPGA Timing

The design was synthesized and implemented in AMD Vivado targeting a 100 MHz clock:

```text
Clock period: 10 ns
Clock frequency: 100 MHz
```

After pipelining and timing optimization, the implemented design met the specified timing constraint.

The timing analysis reported no failing setup endpoints for the final implementation.

---

## Project Structure

```text
fpga-trading-engine/
│
├── rtl/
│   ├── trading_pkg.sv
│   ├── message_parser.sv
│   ├── order_book.sv
│   └── trading_engine.sv
│
├── tb/
│   └── trading_engine_tb.sv
│
└── README.md
```

### RTL Files

**`trading_pkg.sv`**  
Shared types and constants used throughout the trading engine.

**`message_parser.sv`**  
Decodes incoming market messages.

**`order_book.sv`**  
Stores orders, determines best bid/ask, performs matching, cancellation, and quantity updates.

**`trading_engine.sv`**  
Top-level module connecting the parser and order book.

### Verification

**`trading_engine_tb.sv`**  
Self-checking SystemVerilog testbench covering order insertion, cancellation, matching, price-time priority, partial fills, and latency.

---

## Tools

- SystemVerilog
- Verilator
- GTKWave
- AMD Vivado

---

## Design Goals

The main goals of the project were to explore:

- FPGA-based low-latency architectures
- deterministic hardware processing
- order-book implementation in RTL
- price-time-priority matching
- pipelined comparison networks
- RTL verification
- FPGA timing analysis and optimization

The project demonstrates the complete workflow from RTL architecture and functional verification through synthesis, implementation, and timing closure.
