# Digital FIR Filter IP

A SystemVerilog implementation of a programmable 16-tap Finite Impulse Response (FIR) filter. The project explores FIR filter fundamentals, a transposed hardware architecture, and a coefficient-loading interface with active and shadow banks.

## Project overview

- Fixed 16-tap transposed FIR datapath.
- Signed 4-bit input samples and signed 16-bit output.
- Programmable signed 8-bit coefficients.
- Shadow coefficient bank with per-tap write tracking.
- Commit request and completion signaling.

## Documentation

- [FIR Theory and Applications](docs/FIR_Theory.md) — FIR filter fundamentals, equation, properties, hardware mapping, and industry applications.
- [FIR Design Overview](docs/FIR_Design.md) — This implementation's architecture, interface, coefficient programming sequence, commit behavior, and verification considerations.

## Project status

This is a work in progress. The RTL architecture and configuration interface are being developed; verification and IP packaging remain part of the ongoing work.

## Repository structure

```text
Digital-FIR-Filter/
├── README.md
├── rtl/
│   └── FIR.sv
├── docs/
│   ├── FIR_Theory.md
│   └── FIR_Design.md
└── tb/
    └── FIR_tb.sv
```

The directory tree above is the suggested organization; files and folders can be added as the project develops.
