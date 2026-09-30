# int8 Systolic Array Accelerator Tile (sky130)

A 16×16 int8 systolic-array matmul tile in SystemVerilog, verified against a Python golden model and implemented RTL-to-GDSII in SkyWater 130 nm with LibreLane.

## Results (post-route, sky130A)

| Metric | Value |
|---|---|
| MACs | 256 (int8, 32-bit accumulate) |
| Fmax (typical corner) | ~41 MHz |
| Peak throughput | ~21 GOPS |
| MAC utilization | 94% at K=768, 99% at K=4096 |
| Die area | 8.78 mm² |
| DRC / LVS | Clean / clean |
| Power (vectorless est.) | ~0.53 W at 41 MHz |

## Design

- **Output-stationary 16×16 PE array** with skew registers to align operands
- **Stall-aware controller** (IDLE → ACC → WAIT → DRAIN) using ring-buffer pointers
- **Banked scratchpads**: 512-bit fill port, 128-bit reads into the array
- **2-stage pipelined requantization**: bias add, fixed-point scale, rounding shift, saturation, fused ReLU

## Verification

Python golden model (`tb/tb.py`) generates vectors for two ModelSim testbenches: `tb.sv` checks all 256 accumulators and int8 outputs across ReLU, scaling, and saturation cases; `tb_requant.sv` covers 12 edge cases including rounding boundaries and negative-value shifts. All pass.

## Build

```bash
python3 tb/tb.py                      # generate test vectors
sv2v rtl/*.sv > src/tile_top.v        # SV -> Verilog for Yosys
librelane config.json                 # RTL -> GDSII
```

## Status

- Hold timing not yet closed at typical/slow corners
- Next: AXI4 DMA, AXI4-Lite CSRs, timing closure, multi-tile
