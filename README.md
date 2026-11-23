# NB64
Northbound is a RISC-V SoC capable of booting Linux, intended for those who wish to learn SoC design from first principles. It can be synthesized as a 64- or 32-bit design and is mainly tested on the Nexys A7-100T FPGA board. This repository also includes files for hardening the design on the Sky130 130 nm process node.

## Repository Structure
| Directory    | Description                                              |
| :---         | :---                                                     |
| **`asic/`**  | ASIC hardening and physical implementation               |
| **`build/`** | Build and runtime artifacts including waveforms and logs |
| **`core/`**  | CPU core design and verification                         |
| **`docs/`**  | Architectural documentation and reference specifications |
| **`fpga/`**  | FPGA board support and prototyping                       |
| **`ip/`**    | External IP blocks such as SRAM and SoC peripherals      |
| **`sim/`**   | Simulation scripts and source files                      |
| **`soc/`**   | Top-level SoC design and verification                    |
| **`sw/`**    | Boot code and demo programs                              |

## Dependencies
You only need two tools to get started:

* **GNU Make**
* **Verilator** (v5.050 or newer)

## Support the Project
If you found this project helpful or interesting, please consider leaving a star and checking out [my other projects](https://github.com/alan-pedersen)! I mostly work on CPU cores and SoC components :-)
