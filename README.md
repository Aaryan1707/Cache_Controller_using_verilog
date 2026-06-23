# Direct-Mapped Cache Controller
> A synthesizable Verilog implementation of a direct-mapped cache controller with FSM-based hit/miss logic, simulated in Icarus Verilog on EDA Playground.

---

## Table of Contents
- [Project Overview](#project-overview)
- [Architecture](#architecture)
- [File Structure](#file-structure)
- [Address Breakdown](#address-breakdown)
- [FSM State Diagram](#fsm-state-diagram)
- [Storage Arrays](#storage-arrays)
- [I/O Port Reference](#io-port-reference)
- [How to Run](#how-to-run)
- [Simulation Scenarios](#simulation-scenarios)
- [Expected Output](#expected-output)
- [Waveform Guide](#waveform-guide)
- [Key Concepts](#key-concepts)

---

## Project Overview

A **cache controller** is hardware that sits between the processor and memory. It manages fast cache memory so the CPU gets data as quickly as possible — without waiting for slow main RAM on every access.

This project implements:
- A **direct-mapped cache** with 4 lines
- A **3-state FSM** (IDLE → COMPARE → ALLOCATE)
- **Valid bits** to distinguish filled vs empty cache lines
- A **fake DRAM** (256-byte memory array) to simulate realistic miss behaviour
- A **testbench** covering 3 scenarios: cold miss, cache hit, and different-address miss

---

## Architecture

```
          ┌─────────────────────────────────────────────┐
          │              cache_controller.v              │
          │                                             │
  CPU ───►│  cpu_req / cpu_addr                         │
          │         │                                   │
          │         ▼                                   │
          │   ┌───────────┐    HIT?  ┌───────────────┐  │
          │   │   FSM     │─────────►│  cache_data[] │  │
          │   │  3 states │          │  tag_array[]  │  │
          │   │           │    MISS? │  valid_array[]│  │
          │   └─────┬─────┘    ┌────►└───────────────┘  │
          │         │          │                         │
          │         ▼          │    ┌───────────────┐   │
          │   ALLOCATE state───┘───►│  memory[0:255]│   │
          │                         │  (fake DRAM)  │   │
          │                         └───────────────┘   │
          │                                             │
  CPU ◄───│  cpu_data / hit / miss / ready              │
          └─────────────────────────────────────────────┘
```

---

## File Structure

```
cache_controller_project/
│
├── cache_controller.v   # Main RTL module — cache logic + FSM + fake memory
└── cache_tb.v           # Testbench — 3 scenarios + waveform dump
```

> Only 2 files. ~200 lines total.

---

## Address Breakdown

The design uses **8-bit addresses** split as follows:

```
 Bit:   7   6   5   4   3   2   1   0
        ┌───────────────────┬─────────┐
        │      TAG (6 bits) │ IDX(2b) │
        │      [7:2]        │  [1:0]  │
        └───────────────────┴─────────┘
```

| Field  | Bits   | Width | Purpose                              |
|--------|--------|-------|--------------------------------------|
| TAG    | [7:2]  | 6 bits | Identifies which memory block is cached |
| INDEX  | [1:0]  | 2 bits | Selects which of the 4 cache lines to check |
| OFFSET | —      | 0 bits | Not needed (block size = 1 word)     |

**Example — address `0x0C` (00001100):**
```
TAG   = bits[7:2] = 000011 = 0x03
INDEX = bits[1:0] = 00     = line 0
→ Check cache line 0. If tag_array[0]==0x03 and valid_array[0]==1 → HIT
```

**Example — address `0x14` (00010100):**
```
TAG   = bits[7:2] = 000101 = 0x05
INDEX = bits[1:0] = 00     = line 0
→ Same line as 0x0C but different tag → CONFLICT (evicts 0x0C)
```

---

## FSM State Diagram

```
         cpu_req=1
  ┌────────────────────────────┐
  │                            ▼
  │              ┌─────────────────────┐
  │              │        IDLE         │◄──────────────────┐
  │              │  hit=0, miss=0      │                   │
  │              │  ready=0            │                   │
  │              └──────────┬──────────┘                   │
  │                         │ cpu_req=1                    │
  │                         ▼                              │
  │              ┌─────────────────────┐                   │
  │              │      COMPARE        │  valid=1           │
  │              │  Check valid bit    │  tag match ────────┤ HIT
  │              │  Check tag match    │  → set hit=1       │ (2 cycles)
  │              └──────────┬──────────┘  → ready=1        │
  │                         │ valid=0 OR                   │
  │                         │ tag mismatch                 │
  │                         │ → set miss=1                 │
  │                         ▼                              │
  │              ┌─────────────────────┐                   │
  └──────────────│      ALLOCATE       │───────────────────┘
    MISS+FILL    │  Fetch memory[]     │  → update cache
    (3 cycles)   │  Fill cache arrays  │  → ready=1
                 │  valid_array[i]=1   │  → miss=0
                 └─────────────────────┘
```

| State    | Code | What happens |
|----------|------|--------------|
| IDLE     | 2'd0 | Waits for cpu_req. Clears outputs. |
| COMPARE  | 2'd1 | Checks valid bit + tag. Decides hit or miss. |
| ALLOCATE | 2'd2 | Fetches from RAM. Fills cache. Sets ready. |

**Cycle cost:**
- HIT path:  `IDLE → COMPARE → IDLE` = **2 cycles**
- MISS path: `IDLE → COMPARE → ALLOCATE → IDLE` = **3 cycles**

---

## Storage Arrays

```verilog
reg [7:0] cache_data  [0:CACHE_LINES-1];  // Actual data bytes
reg [5:0] tag_array   [0:CACHE_LINES-1];  // Which address owns this line
reg       valid_array [0:CACHE_LINES-1];  // Is this line occupied?
reg [7:0] memory      [0:255];            // Fake DRAM (256 bytes)
```

### cache_data[ ]
Stores the actual data byte for each cache line. Written in ALLOCATE, read in COMPARE on a hit.

### tag_array[ ]
6 bits wide (matching the 6-bit tag field). Records which memory block currently occupies each cache line. Compared against the incoming address tag during COMPARE.

### valid_array[ ]
1 bit per line. Prevents stale garbage from being treated as a hit after reset. Only set to `1` in ALLOCATE after a confirmed RAM fetch.

### memory[ ]
Simulates main DRAM. Initialized as:
```verilog
memory[i] <= i + 8'hAA;
```
This means every address holds a predictable value you can verify by hand:
- `memory[0x0C]` = `0x0C + 0xAA` = `0xB6`
- `memory[0x14]` = `0x14 + 0xAA` = `0xBE`

---

## I/O Port Reference

| Port          | Direction | Width | Description |
|---------------|-----------|-------|-------------|
| `clk`         | input     | 1     | System clock. All logic on posedge. |
| `rst`         | input     | 1     | Async active-high reset. Clears all arrays and state. |
| `cpu_req`     | input     | 1     | CPU asserts for 1 cycle to request data. |
| `cpu_addr`    | input     | 8     | Memory address CPU wants to read. |
| `cpu_data`    | output    | 8     | Data returned to CPU (from cache or RAM). |
| `hit`         | output    | 1     | High when data was found in cache. |
| `miss`        | output    | 1     | Pulses high for 1 cycle when tag mismatch or valid=0. |
| `ready`       | output    | 1     | High when cpu_data is valid and stable for CPU to read. |

---

## How to Run

### On EDA Playground (Recommended)

1. Go to [edaplayground.com](https://edaplayground.com) and log in (free account)
2. Paste `cache_controller.v` into the **left pane**
3. Paste `cache_tb.v` into the **right pane**
4. Set **Languages & Libraries** → `Verilog/SystemVerilog`
5. Set **Simulator** → `Icarus Verilog 0.9.7`
6. Check ✅ **"Open EPWave after run"**
7. Click **Run**

### On Local Machine (Icarus Verilog)

```bash
# Compile
iverilog -o cache_sim cache_controller.v cache_tb.v

# Run
vvp cache_sim

# View waveform (requires GTKWave)
gtkwave cache_sim.vcd
```

---

## Simulation Scenarios

| Scenario | Address | Expected Result | Reason |
|----------|---------|-----------------|--------|
| 1 — Cold miss   | `0x0C` | MISS → fetch RAM → fill cache | First access, valid=0 |
| 2 — Cache hit   | `0x0C` | HIT → return from cache | Same address, valid=1, tag matches |
| 3 — New address | `0x14` | MISS → fetch RAM → fill cache | Different tag, same index (conflict) |
| Bonus — Hit     | `0x14` | HIT → return from cache | Now cached from scenario 3 |

---

## Expected Output

```
==============================================
  Direct-Mapped Cache Controller Simulation
==============================================

[Scenario 1] First access to 0x0C => expect MISS
  Addr=0x0C | hit=0 miss=0 | data=0xB6 | ready=1

[Scenario 2] Same address 0x0C again => expect HIT
  Addr=0x0C | hit=1 miss=0 | data=0xB6 | ready=1

[Scenario 3] New address 0x14 => expect MISS
  Addr=0x14 | hit=0 miss=0 | data=0xBE | ready=1

[Bonus]      Same address 0x14 again => expect HIT
  Addr=0x14 | hit=1 miss=0 | data=0xBE | ready=1

==============================================
  Simulation complete. Open cache_sim.vcd
  in EPWave to view waveforms.
==============================================
```

---

## Waveform Guide

Add these signals in EPWave to see the full picture:

```
clk          — clock edges
rst          — reset pulse at start
cpu_req      — request pulses
cpu_addr     — address value
hit          — goes high on scenario 2 and bonus
miss         — pulses on scenarios 1 and 3
ready        — asserts when data is valid
cpu_data     — 0xB6 after scenario 1, 0xBE after scenario 3
state[1:0]   — 0=IDLE, 1=COMPARE, 2=ALLOCATE
```

**Reading the state signal:**
- Miss path: `0 → 1 → 2 → 0` (3 transitions)
- Hit path:  `0 → 1 → 0` (2 transitions)

---

## Key Concepts

### Why direct-mapped?
Each address maps to exactly one cache line (index bits select it). Simple, fast, O(1) lookup. Tradeoff: conflict misses when two addresses share the same index.

### Why valid bits?
On reset, tag_array contains zeros which could accidentally match an incoming tag. Valid bits guarantee a slot is only considered "occupied" after it has been intentionally filled via ALLOCATE.

### Why does miss pulse for only 1 cycle?
`miss=1` is set in COMPARE (miss detected), then immediately cleared to `miss=0` in ALLOCATE (miss being resolved). It signals detection, not duration.

### What is asynchronous reset?
The `always @(posedge clk or posedge rst)` pattern means reset takes effect immediately when rst goes high — without waiting for the next clock edge. Used in real ASIC and FPGA designs.

### Conflict miss example
`0x0C` and `0x14` both have index bits `00` → both fight for cache line 0. Accessing `0x14` evicts `0x0C`. This is the fundamental weakness of direct-mapped caches, solved by set-associative designs.

---

## Parameters (easy to modify)

```verilog
parameter CACHE_LINES = 4;   // increase to 8, 16, 32...
// Address width = 8 bits    // increase for larger address space
// Block size    = 1 word    // add offset bits for multi-word blocks
```

To scale up: increase `CACHE_LINES` to a power of 2, adjust index bit width accordingly, and add offset bits if block size > 1 word.

---

*Designed for educational use — EDA Playground / Icarus Verilog*
