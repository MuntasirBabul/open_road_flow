# EDA Tools Setup on Ubuntu / WSL

This repository provides guidance for setting up **open-source EDA tools** such as **Yosys, OpenROAD, KLayout, cocotb, verilator, ngspice, xschem and OpenVAF** on Ubuntu or WSL. It focuses on creating a **reproducible environment**, configuring tools with the **module system**, and ensuring smooth workflow for digital and analog ASIC design and physical design verification.



## Overview

The setup allows users to install EDA tools in a centralized location, typically `/opt/tools`, and manage multiple versions through modules. By using tagged releases and modulefiles, designers can maintain a stable environment while experimenting with new tool versions without disrupting existing workflows.



## Prerequisites

Before installing tools, ensure your system has **basic development libraries** and dependencies installed. A working Ubuntu or WSL environment is required, with sufficient CPU, memory, and optional GPU support for GUI-enabled tools. Python3 and standard development packages are also recommended for scripting and flow automation.

Before proceeding, run the following script to install all required Ubuntu dependencies:

```bash
bash install_dependencies.sh
```


## Installing Tools

Tools such as **Yosys, OpenROAD, KLayout, cocotb, verilator, ngspice, xschem and OpenVAF** should be installed from their official repositories, preferably using the **latest stable tagged release**. Installing in `/opt/tools` helps maintain a consistent location and prevents conflicts with system-installed versions. After installation, each tool should be tested to ensure the binaries are functional and accessible.

Run the following script to install all tools (run it with `bash`, do not `source` it):

```bash
bash install_all_tools.sh
```

Optional settings, passed as environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `ROOT_INSTALLATION` | `yes` | `yes` installs to `/opt/tools` and `/opt/modulefiles` with sudo; `no` installs to `~/tools` and `~/modulefiles` |
| `SRC_DIR` | `$HOME` | Where the tool sources are cloned and built |
| `JOBS` | `nproc` | Parallel build jobs; lower it if the build runs out of memory (common for OpenROAD on WSL) |
| `INSTALL_YOSYS`, `INSTALL_OPENROAD`, `INSTALL_KLAYOUT`, `INSTALL_VERILATOR`, `INSTALL_COCOTB`, `INSTALL_NGSPICE`, `INSTALL_XSCHEM`, `INSTALL_OPENVAF` | `yes` | Set any of them to `no` to skip that tool |

For example, to install into your home directory with 4 build jobs:

```bash
ROOT_INSTALLATION=no JOBS=4 bash install_all_tools.sh
```

To install only the analog tools (ngspice, xschem, OpenVAF):

```bash
INSTALL_YOSYS=no INSTALL_OPENROAD=no INSTALL_KLAYOUT=no INSTALL_VERILATOR=no INSTALL_COCOTB=no bash install_all_tools.sh
```

Notes on the analog tools:

- **ngspice** is built with X11 plotting, CIDER, XSPICE, OpenMP and OSDI, so it can load Verilog-A models compiled by OpenVAF.
- **OpenVAF** is built from the maintained [OpenVAF-Reloaded](https://github.com/OpenVAF-Reloaded/OpenVAF) fork. It needs LLVM 18 or newer: `install_dependencies.sh` installs LLVM 18 where Ubuntu provides it (24.04 and later); on older releases install it from [apt.llvm.org](https://apt.llvm.org). Rust is installed for your user with rustup if `cargo` is not found. The binary is called `openvaf-r`; an `openvaf` link is also created.

The script is safe to re-run: it updates existing clones, overwrites modulefiles instead of appending to them, and builds as your user (only the install step uses sudo).

After installation, open a new shell and load every installed tool with:

```bash
source /opt/tools/env.sh
```

(use `~/tools/env.sh` when `ROOT_INSTALLATION=no`).


## Module System Setup

A **module system** allows users to load and unload tool environments easily, supporting multiple versions simultaneously. Each installed tool should have a corresponding modulefile in `/opt/modulefiles`. The modulefile sets environment variables, updates `PATH` and `LD_LIBRARY_PATH`, and ensures the correct version is active when loaded. This provides a clean, reproducible workflow across different projects or users.



## Avoiding Sudo Prompts

To streamline installations and scripting, users can configure **passwordless sudo** by updating the sudoers file safely with `visudo`. While convenient, this reduces system security and should only be applied on trusted personal or isolated machines. Multi-user or production systems should retain password prompts for safety.


 To avoid being prompted for a sudo password during installation       
 1. Open the sudoers file safely:                                      
```bash
 sudo visudo                                                      
```
 2. Locate the line for the sudo group:                                
```bash
 %sudo   ALL=(ALL:ALL) ALL                                        
```
 3. Modify it to:                                                      
```bash
 %sudo   ALL=(ALL:ALL) NOPASSWD:ALL                               
```

This allows all users in the 'sudo' group to execute sudo commands without entering a password.                                       
                                                                       
## WARNING:     
                                                         
 - Disabling the sudo password reduces security. Only do this on       
   trusted personal systems or isolated environments.                  
 - Avoid using this on multi-user or production machines.              
 - Always use 'visudo' to edit sudoers to prevent syntax errors        
   that can lock you out of sudo.                                      



## Notes and Tips

- Always use **tagged releases** for stability and reproducibility.  
- Ensure **WSL2 or Ubuntu** environment is properly configured for GUI and hardware acceleration if needed.  
- Keep **modulefiles updated** for all installed tools to avoid conflicts between versions.  
- Automate repetitive setup steps using scripts to save time and maintain consistency.


## Common Issues & Fixes

Some common challenges include version mismatches, modulepath misconfigurations, and GUI-related errors in WSL. Ensuring correct environment variables, modulefiles, and proper system dependencies typically resolves these issues. Users should check logs and tool outputs to identify and fix configuration problems.


## References

- [Yosys GitHub Repository](https://github.com/YosysHQ/yosys)  
- [OpenROAD GitHub Repository](https://github.com/The-OpenROAD-Project/OpenROAD)  
- [KLayout GitHub Repository](https://github.com/KLayout/klayout)  
- [SkyWater PDK](https://github.com/google/skywater-pdk)
- [Cocotb GitHub Repository](https://github.com/cocotb/cocotb)  
- [Verilator Official Website](https://www.veripool.org/verilator)
- [ngspice Website](https://ngspice.sourceforge.io/)
- [xschem GitHub Repository](https://github.com/StefanSchippers/xschem)
- [OpenVAF-Reloaded GitHub Repository](https://github.com/OpenVAF-Reloaded/OpenVAF)


