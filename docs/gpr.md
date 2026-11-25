# General-Purpose Register File (`nb64_gpr`)
`nb64_gpr` implements a typical 32 x `XLEN` (64-bit or 32-bit) general-purpose register file, with two combinational read ports (`rs1`, `rs2`) and one synchronous write port (`rd`).

## Implementation Details
* Only registers `x1`-`x31` are physically instantiated, as reading `x0` always returns `0` and writes to `x0` are ignored.
* No reset mechanism is implemented, as RISC-V does not require GPRs to hold defined values after a reset; software is responsible for initializing registers before reading them. Additionally, omitting the reset saves area and enables LUTRAM inference on FPGAs.
* Operands `rs1` and `rs2` are typically read in ID and first needed in EX. While data hazards from 1 and 2 cycles earlier are handled by EX-stage forwarding (`EX/MEM` and `MEM/WB`), an instruction 3 cycles earlier is in WB while the consumer is in ID and the register file is being read. As such, forwarding `rd_data_i` to the matching read port in the same cycle ensures no stall is needed.

## Read Priority
Each read port resolves its output combinationally in the following order:

1. `raddr == 0` returns `0`
2. `rd_we_i && (rd_addr_i == raddr)` returns `rd_data_i`
3. Otherwise returns `regs[addr]`

## Interface
| Signal       | Direction | Width  | Description                                               |
| :---         | :---      | :---   | :---                                                      |
| `clk_i`      | `input`   | `1`    | Rising-edge clock for synchronous register writes         |
| `rs1_addr_i` | `input`   | `5`    | Source register 1 index (`x0`–`x31`)                      |
| `rs2_addr_i` | `input`   | `5`    | Source register 2 index (`x0`–`x31`)                      |
| `rs1_data_o` | `output`  | `XLEN` | Combinational read data for `rs1_addr_i`                  |
| `rs2_data_o` | `output`  | `XLEN` | Combinational read data for `rs2_addr_i`                  |
| `rd_we_i`    | `input`   | `1`    | Active-high write enable for `rd_addr_i`                  |
| `rd_addr_i`  | `input`   | `5`    | Destination register index (`x0` writes are ignored)      |
| `rd_data_i`  | `input`   | `XLEN` | Data written to `rd_addr_i` on the next rising clock edge |

## Verification
`nb64_gpr` is formally verified using `core/sva/nb64_gpr_sva.sv` across the following properties:

* Reading `x0` into either `rs1` or `rs2` always returns `0`
* Reading a register that is simultaneously being written returns `rd_data_i`
* Reading a register not currently being written returns the value stored in `regs[addr]`
* When `rd_we_i` is asserted for a non-zero `rd_addr_i`, `regs[rd_addr_i]` updates to `rd_data_i` on the next clock edge
* Any register not targeted by an active write retains its value across clock edges
