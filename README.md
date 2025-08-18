# EDA Tools Setup on Ubuntu / WSL

This repository provides guidance for setting up **open-source EDA tools** such as **Yosys, OpenROAD, KLayout, cocotb, verilator** on Ubuntu or WSL. It focuses on creating a **reproducible environment**, configuring tools with the **module system**, and ensuring smooth workflow for ASIC design and physical design verification.



## Overview

The setup allows users to install EDA tools in a centralized location, typically `/opt/tools`, and manage multiple versions through modules. By using tagged releases and modulefiles, designers can maintain a stable environment while experimenting with new tool versions without disrupting existing workflows.



## Prerequisites

Before installing tools, ensure your system has **basic development libraries** and dependencies installed. A working Ubuntu or WSL environment is required, with sufficient CPU, memory, and optional GPU support for GUI-enabled tools. Python3 and standard development packages are also recommended for scripting and flow automation.

Before proceeding, run the following script to install all required Ubuntu dependencies:

```bash
source install_dependencies.sh
```


## Installing Tools

Tools such as **Yosys, OpenROAD, KLayout, cocotb and verilator** should be installed from their official repositories, preferably using the **latest stable tagged release**. Installing in `/opt/tools` helps maintain a consistent location and prevents conflicts with system-installed versions. After installation, each tool should be tested to ensure the binaries are functional and accessible.

Note: User can change the installation location if user wants to avoid root location

run the following script to install all tools:

```bash

source install_all_tools.sh  
```


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


