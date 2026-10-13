# INT8 Dot-Product Unit (SystemVerilog)

This project is a small digital circuit design for computing dot products of signed 8-bit integers. Dot products are used frequently in neural-network calculations. I wanted to see how these operations could be implemented using digital logic.

## How it works

A dot product multiplies corresponding numbers from two vectors and adds the products together. For example, `[2, 3]` and `[4, 5]` produce `(2 × 4) + (3 × 5) = 23`. The module can also add a bias to the resulting sum. The design uses parallel multiply-accumulate (MAC) units. The `PE_COUNT` parameter determines how many pairs of numbers are processed per clock cycle. For an eight-element dot product, one processing lane takes eight computation cycles, while four lanes take two. The products are accumulated into a signed 32-bit integer to preserve the intermediate result. After completing the dot product, the module can shift the accumulated result and convert it to a signed 8-bit output. It supports ReLU, which replaces negative outputs with zero, and saturation to prevent results from exceeding the signed 8-bit range. The `done` signal indicates when the calculation has finished. The design is intended as a basic arithmetic component for neural network hardware rather than a complete neural network accelerator.

## Testing

`int8_dot_accel.sv` contains the RTL implementation, while `tb_int8_dot.sv` contains the testbench. I tested the design in EDA Playground using Icarus Verilog. The testbench runs three cases with 1, 2, and 4 processing lanes. These include a regular dot product, positive saturation, and a negative result processed through ReLU. All tests passed for each lane configuration. To reproduce the tests, select SystemVerilog and Icarus Verilog in EDA Playground. Paste the corresponding files into the design and testbench editors and run the simulation.

Alternatively, with Icarus Verilog installed locally:

```bash
iverilog -g2012 -s tb_int8_dot -o sim.vvp int8_dot_accel.sv tb_int8_dot.sv
vvp sim.vvp
```

A successful run ends with:

```text
All RTL testbench checks passed.
```

## Limitations to the project

The design has only been tested through RTL simulation. I have not synthesized it for an FPGA or assessed its hardware resource usage and timing performance. The testbench covers selected input cases rather than every possible configuration. The module also handles only dot-product arithmetic. It does not include the memory architecture or data movement needed for a complete neural network.
