# Programmable 16-Tap FIR: Design Overview

## Overview

This project implements a **16-tap signed FIR filter** in SystemVerilog. It accepts a signed 4-bit input sample and produces a signed 16-bit output. Its 16 signed 8-bit coefficients can be programmed into a shadow bank and then activated together through a commit request.

The design is intended as a learning project toward a reusable FIR hardware IP block. It separates the sample-processing datapath from the coefficient-loading and commit-control logic.

## Main features

- 16 taps with signed, programmable 8-bit coefficients.
- Signed 4-bit sample input and signed 16-bit output.
- Transposed FIR datapath with registered internal state.
- Separate **active** and **shadow** coefficient banks.
- Per-coefficient write tracking through the `SREADY` bitmap.
- A stored commit request (`CREQ`) that waits until all shadow coefficients have been written.
- `DONE` pulse to indicate completion of a coefficient commit.
- Active-low asynchronous reset (`RSTn`).
- `FIREN` control to enable normal operation or halt it.

## Datapath

The active coefficients are named `h0` through `h15`. These are the coefficients used by the filter during normal operation. The shadow coefficients are named `s0` through `s15`; software or a controller writes new values into this bank.

The transposed datapath uses the current input sample and active coefficients to update the output and internal state registers `r0` through `r14`. In simplified form, the RTL follows this pattern:

\[
y[n] = x[n]h_0 + r_0
\]

\[
r_i \leftarrow x[n]h_{i+1} + r_{i+1}
\]

for the internal stages, with the final stage updated from the last coefficient product. The registers hold the partial sums between clock edges.

The exact arithmetic behavior also depends on the declared signal widths and SystemVerilog expression sizing. The 16-bit output and state declarations do not by themselves guarantee that every possible 16-tap sum is free from overflow; the input range, coefficient range, and expression widths should be verified.

## Coefficient programming and commit sequence

The coefficient interface consists of `CENWR`, `CADDR`, and `CDATA`:

1. Set `CADDR` to the desired tap index, from 0 to 15.
2. Present the signed coefficient value on `CDATA`.
3. Assert `CENWR` for the clock edge on which the coefficient should be written.
4. Repeat for each coefficient that needs to be programmed.

When a coefficient is written, the corresponding bit in `SREADY` is set. `SRSTATUS` is the reduction-AND of `SREADY`, so it becomes high when all 16 shadow coefficient positions have been written since the last clearing of the bitmap.

The CPU or controller requests activation by pulsing `COMMIT` while `FIREN` is high. The request is stored in `CREQ`. If the shadow bank is not ready yet, the request remains pending while additional coefficient writes are made. When both `CREQ` and `SRSTATUS` are high, the RTL copies the shadow coefficients into the active bank, clears the FIR state and output, clears `SREADY`, clears `CREQ`, and pulses `DONE`.

This is a **full-bank update protocol**: the current readiness logic requires all 16 coefficient positions to be written before a commit can complete. Since `SREADY` is cleared after a commit, a subsequent commit requires all 16 positions to be written again.

## Interface reference

| Signal | Direction | Description |
|---|---|---|
| `CLK` | Input | Main rising-edge clock |
| `RSTn` | Input | Active-low asynchronous reset |
| `FIREN` | Input | Enables filtering, coefficient writes, and commit handling |
| `x_in` | Input | Signed 4-bit input sample |
| `y_out` | Output | Signed 16-bit filtered output |
| `BUSY` | Output | High during normal filtering; low during reset, halt, and commit |
| `CENWR` | Input | Enables a shadow coefficient write |
| `CADDR` | Input | 4-bit coefficient address, 0–15 |
| `CDATA` | Input | Signed 8-bit coefficient value |
| `SREADY` | Output | 16-bit bitmap indicating which shadow coefficient positions have been written |
| `COMMIT` | Input | Requests activation of the shadow coefficient bank |
| `DONE` | Output | One-clock indication that a commit has completed |
| `CREQ` | Internal | Stores a commit request until it can be completed |
| `SRSTATUS` | Internal | High when every bit of `SREADY` is high |

## Reset and halt behavior

When `RSTn` is asserted low, the active and shadow coefficients, readiness bitmap, commit request, filter state, output, and control outputs are reset.

When `FIREN` is low, the sequential logic does not process samples, accept coefficient writes, or capture new commit requests. `BUSY` and `DONE` are driven low. The current coefficient contents, readiness bitmap, and any pending `CREQ` are retained, so re-enabling `FIREN` resumes from the retained control state.

`FIREN` is sampled by the clocked logic; it is a synchronous halt/enable control, not an asynchronous emergency-stop mechanism.

## Current design scope and verification notes

This version is a fixed 16-tap implementation. The coefficient values are programmable, but the number of taps and data widths are not parameterized.

Before treating the module as production-ready IP, verify at least:

- Signed arithmetic and output values against a software reference model.
- Reset and halt/resume behavior.
- Writes to every coefficient address.
- A commit request arriving before all coefficients are ready.
- `DONE` timing and clearing of `SREADY`.
- Back-to-back coefficient programming and commits.
- Simultaneous `COMMIT`, coefficient-write, and commit-completion events.
- Arithmetic sizing, truncation, and overflow for the supported input and coefficient ranges.

In particular, simultaneous events need a defined priority. In the current RTL, a `COMMIT` or coefficient write on the same clock edge as commit completion can interact with nonblocking assignments to `CREQ` or `SREADY`. These cases should be resolved explicitly and covered by a testbench.

## Project status

This repository is a work in progress. The current focus is on developing the RTL architecture and its coefficient configuration interface. Verification, documentation, and IP packaging can be expanded as the design matures.
