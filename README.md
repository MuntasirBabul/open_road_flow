# EDA Tools Setup on Ubuntu / WSL

This repository provides guidance for setting up **open-source EDA tools** such as **Yosys, OpenROAD, KLayout, Verilator, Icarus Verilog, cocotb, ngspice, xschem, OpenVAF, Magic, Netgen and the sky130 PDK (through ciel)** on Ubuntu or WSL. It focuses on creating a **reproducible environment**, configuring tools with the **module system**, and ensuring smooth workflow for digital and analog ASIC design and physical design verification.



## Overview

The setup allows users to install EDA tools in a centralized location, typically `/opt/tools`, and manage multiple versions through modules. By using tagged releases and modulefiles, designers can maintain a stable environment while experimenting with new tool versions without disrupting existing workflows.



## Prerequisites

A working Ubuntu or WSL environment is required, with sufficient CPU, memory, and optional GPU support for GUI-enabled tools, and a user that can run `sudo`.

**The Ubuntu packages are installed by `install_all_tools.sh` itself**, as its first step: every tool lists the packages its build needs (`TOOL_PKGS` in the script), and the script installs the missing ones for the tools you chose, in one `sudo apt-get` call, before any build starts. A missing package therefore stops the run in the first minute, and sudo asks for its password once, at the start. There is no separate step to remember.

To check without installing anything (no sudo):

```bash
INSTALL_DEPS=check bash install_all_tools.sh
```

`install_dependencies.sh` is optional: it installs the packages of every tool (or of the tools left at `INSTALL_<TOOL>=yes`) without building anything, e.g. to prepare a machine in advance:

```bash
bash install_dependencies.sh
```


## Installing Tools

Tools such as **Yosys, OpenROAD, KLayout, Verilator, Icarus Verilog, cocotb, ngspice, xschem, OpenVAF, Magic, Netgen and the sky130 PDK (through ciel)** should be installed from their official repositories, preferably using the **latest stable tagged release**. Installing in `/opt/tools` helps maintain a consistent location and prevents conflicts with system-installed versions. After installation, each tool should be tested to ensure the binaries are functional and accessible.

Run the following script to install all tools (run it with `bash`, do not `source` it):

Run in a terminal, it first lists the tools and asks which to install (numbers separated by spaces, or `a` for all). To skip the question, choose tools with the `INSTALL_<TOOL>` variables below, or set `TOOL_MENU=no` to install everything.

```bash
bash install_all_tools.sh
```

Optional settings, passed as environment variables:

| Variable | Default | Meaning |
|---|---|---|
| `ROOT_INSTALLATION` | `yes` | `yes` installs to `/opt/tools` and `/opt/modulefiles` with sudo; `no` installs to `~/tools` and `~/modulefiles` |
| `SRC_DIR` | `$HOME` | Where the tool sources are cloned and built |
| `JOBS` | `nproc` | Parallel build jobs; lower it if the build runs out of memory (common for OpenROAD on WSL) |
| `INSTALL_YOSYS`, `INSTALL_OPENROAD`, `INSTALL_KLAYOUT`, `INSTALL_VERILATOR`, `INSTALL_IVERILOG`, `INSTALL_COCOTB`, `INSTALL_NGSPICE`, `INSTALL_XSCHEM`, `INSTALL_OPENVAF`, `INSTALL_MAGIC`, `INSTALL_NETGEN`, `INSTALL_PDK` | `yes` | Set any of them to `no` to skip that tool |
| `INSTALL_DEPS` | `yes` | `yes` installs the missing Ubuntu packages of the chosen tools first (sudo), then builds; `only` installs them and exits; `check` lists what is missing and exits (no sudo); `no` never calls apt and stops if a required package is missing |
| `TOOL_MENU` | `auto` | `auto` shows a numbered menu of tools (pick numbers, or `a` for all) when the script runs in a terminal and no `INSTALL_<TOOL>` variable is given; `yes` always asks; `no` never asks |
| `IVERILOG_REF` | empty | Empty builds the newest Icarus Verilog tag; a commit, tag or branch (e.g. `master`) builds that instead |
| `CIEL_VERSION` | `3.3.0` | ciel version to install |
| `SKY130_PDK_HASH` | `e7a6777d157a9d94c7ac757457b9e4309e9e9000` | open_pdks commit of the sky130 PDK that ciel enables (the one bridge_NVX uses); empty skips the PDK |
| `PDK_ROOT` | `~/.ciel` | Where ciel keeps the PDKs |

For example, to install into your home directory with 4 build jobs:

```bash
ROOT_INSTALLATION=no JOBS=4 bash install_all_tools.sh
```

To install only the analog tools (ngspice, xschem, OpenVAF):

```bash
INSTALL_YOSYS=no INSTALL_OPENROAD=no INSTALL_KLAYOUT=no INSTALL_VERILATOR=no INSTALL_IVERILOG=no INSTALL_COCOTB=no INSTALL_MAGIC=no INSTALL_NETGEN=no INSTALL_PDK=no bash install_all_tools.sh
```

Notes on Yosys:

- Yosys is built with CMake (3.28 or newer, which Ubuntu 24.04 and later provide).
- SystemVerilog support through [yosys-slang](https://github.com/povik/sv-elab) is built into Yosys, so no separate plugin is installed. Read SystemVerilog with `read_slang`, for example `yosys -p "read_slang top.sv --top top; synth -top top"`.

Notes on the analog tools:

- **ngspice** is built with X11 plotting, CIDER, XSPICE, OpenMP and OSDI, so it can load Verilog-A models compiled by OpenVAF.
- **OpenVAF** is built from the maintained [OpenVAF-Reloaded](https://github.com/OpenVAF-Reloaded/OpenVAF) fork. It needs LLVM 18 or newer: the script installs LLVM 18 (optional packages of OpenVAF) where Ubuntu provides it (24.04 and later); on older releases install it from [apt.llvm.org](https://apt.llvm.org). Rust is installed for your user with rustup if `cargo` is not found. The binary is called `openvaf-r`; an `openvaf` link is also created.

Notes on layout, verification and the PDK:

- **Icarus Verilog** (`iverilog`, `vvp`) is built from git, which needs `gperf` and `autoconf` (installed automatically as its packages).
- **Magic** and **Netgen** are built against Tcl/Tk 8.6. Netgen's releases are tagged on its `netgen-1.5` branch, which the script uses.
- **ciel** is installed in its own Python venv; its module only adds the `ciel` command to `PATH`. The script then runs `ciel enable --pdk-family sky130 <SKY130_PDK_HASH>`, which downloads that PDK version into `PDK_ROOT` if it is not there yet and makes it the active `sky130A`/`sky130B`. The PDK is per user (`~/.ciel`), not in `/opt/tools`.

The script is safe to re-run: it updates existing clones, overwrites modulefiles instead of appending to them, and builds as your user (only the install step uses sudo).

After installation, open a new shell and load every installed tool with:

```bash
source /opt/tools/env.sh
```

(use `~/tools/env.sh` when `ROOT_INSTALLATION=no`).


## Module System Setup

A **module system** allows users to load and unload tool environments easily, supporting multiple versions simultaneously. Each installed tool should have a corresponding modulefile in `/opt/modulefiles`. The modulefile sets environment variables, updates `PATH` and `LD_LIBRARY_PATH`, and ensures the correct version is active when loaded. This provides a clean, reproducible workflow across different projects or users.

`install_all_tools.sh` writes one modulefile per installed version, in `/opt/modulefiles/<tool>/<version>` (or `~/modulefiles` when `ROOT_INSTALLATION=no`), and sets up the shell so the `module` command works in every new terminal, login or not:

- **Root installation:** `/opt/modulefiles` is added to `/etc/environment-modules/modulespath`, and a short block in `/etc/bash.bashrc` defines the `module` command in non-login shells.
- **Home installation:** a short block in `~/.bashrc` defines the `module` command and adds `~/modulefiles`.

Open a new terminal after installing, then:

```bash
module avail                      # list tools and versions; (default) marks the newest install
module load yosys                 # load the default version
module load yosys/v0.71           # load a specific version
module switch yosys yosys/v0.70   # change version (two versions cannot be loaded together)
module list                       # show what is loaded
module whatis klayout             # one-line description
module unload yosys               # remove it from the environment
module purge                      # unload everything
```

Tool names: `yosys`, `openroad`, `klayout`, `verilator`, `iverilog`, `cocotb`, `ngspice`, `xschem`, `openvaf`, `magic`, `netgen`, `ciel`.

In a script (a non-interactive shell) initialise modules first:

```bash
source /usr/share/modules/init/bash
module use ~/modulefiles          # only needed when ROOT_INSTALLATION=no
module load yosys verilator
```



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
- [Icarus Verilog GitHub Repository](https://github.com/steveicarus/iverilog)
- [Magic GitHub Repository](https://github.com/RTimothyEdwards/magic)
- [Netgen GitHub Repository](https://github.com/RTimothyEdwards/netgen)
- [ciel GitHub Repository](https://github.com/fossi-foundation/ciel)


