# int8 Systolic Array Accelerator (sky130)

A 16×16 int8 systolic-array matmul accelerator in SystemVerilog, verified against a Python golden model and implemented RTL-to-GDSII in SkyWater 130 nm with LibreLane.

## Results (compute tile, post-route, sky130A)

| Metric | Value |
|---|---|
| MACs | 256 (int8, 32-bit accumulate) |
| Timing | Closed at 41.7 MHz (24 ns, TT corner), +2.8 ns slack |
| Peak throughput | 21.3 GOPS |
| MAC utilization | 95–99% for K ≥ 1024 |
| Die area | 8.41 mm² (57% utilization) |
| DRC / LVS | Clean / clean |
| Power (vectorless est.) | ~0.83 W |

## Design

- **Output-stationary 16×16 PE array** with skew registers to align operand wavefronts
- **Ring-buffered input scratchpads** with pointer-based flow control, so long-K operands stream through a 32-word buffer
- **Stall-aware controller** (IDLE → ACC → WAIT → DRAIN)
- **2-stage pipelined requantization**: per-channel bias, fixed-point scaling, rounding shift, saturation, fused ReLU
- **CSR register block**: job configuration, start/done, DRAM base addresses; rounding constant and clamp bound precomputed off the datapath

## Verification

Python golden model (`tb/tb.py`) generates vectors for ModelSim testbenches: `tb.sv` checks all 256 accumulators and int8 outputs across ReLU, scaling, and saturation cases; `tb_requant.sv` covers edge cases including rounding boundaries and negative-value shifts.

## Build

```bash
python3 tb/tb.py                      # generate test vectors
sv2v rtl/*.sv > src/tile_top.v        # SV -> Verilog for Yosys
librelane config.json                 # RTL -> GDSII
```

## Physical design notes

- Post-route STA traced the critical path to config inputs fanning out across the die (~8 ns of repeaters); pipelining requant plus delay-driven synthesis cut it from 24.2 to 21.2 ns.
- Slow corner (SS, 100 °C) closes at ~27 MHz; moving config into on-chip CSRs with per-lane register replication targets those paths.

## Status / next

- AXI4 burst DMA and AXI4-Lite CSR interface for DRAM-to-DRAM operation
- SDC constraints (AXI I/O delays, multicycle paths for static config)
- Antenna fixes, all-corner closure, multi-tile
