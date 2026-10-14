# FIR Filters: Theory and Trade-offs

## What is an FIR filter?

A **Finite Impulse Response (FIR)** filter processes sampled data by taking a weighted sum of the current input and a finite number of previous input samples:

$$
y[n] = \sum_{k=0}^{N-1} h[k]x[n-k]
$$

Here, \(x[n]\) is the input, \(h[k]\) are the filter coefficients (taps), and \(N\) is the number of taps. By choosing the coefficients, a designer can suppress noise, keep a desired frequency band, or shape a signal.

## Why choose FIR over IIR or analog filtering?

No filter type is best for every application. The choice depends on phase accuracy, computation, latency, and where filtering happens in the signal chain.

| Type | Main strengths | Main trade-offs |
|---|---|---|
| **FIR** | Inherently stable; can provide exact linear phase; predictable feed-forward structure; well suited to pipelined FPGA/ASIC designs. | Sharp responses may need many taps, increasing hardware cost and delay. |
| **IIR** | Often achieves a sharp frequency response with fewer operations and less memory. | Usually has nonlinear phase; feedback and finite-precision effects require careful design. |
| **Analog** | Filters continuously and can remove unwanted frequencies before an ADC. | Component tolerances affect behavior; changing the response is less flexible; complex responses may need more circuitry. |

### Where FIR is often a good fit

- **Audio and communications:** linear phase can help preserve waveform shape; coefficients can shape or select frequency bands.
- **Image and video:** finite convolution kernels support predictable, parallel processing of pixels.
- **Sensors and instrumentation:** repeatable filtering can reduce noise while preserving waveform timing.
- **FPGA/ASIC pipelines:** multiply-and-add operations map well to DSP resources and can be pipelined for high throughput.

These are common use cases, not rules: IIR or analog filtering may be better when low cost, low delay, or pre-ADC filtering matters more.

## The key FIR trade-off

FIR filters offer **predictable behavior, inherent stability, and the option of linear phase**, but that control can cost more multipliers, registers, and processing delay—especially for long filters. IIR can be more efficient for some frequency-response targets, while analog filters are essential when filtering must occur before sampling. Real systems often combine analog and digital filtering.

## How this relates to this IP

This project implements a **16-tap programmable-coefficient FIR**. Its feed-forward datapath calculates a weighted sum of delayed input samples, while active and shadow coefficient banks are intended to let software prepare a new coefficient set before applying it. This makes the filter configurable without rebuilding the RTL. The design's value is its reusable digital implementation—not that FIR is always superior to IIR or analog alternatives.
