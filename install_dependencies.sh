#!/usr/bin/env bash
#########################################################################
#                        Install Dependencies                           #
#                                                                       #
#  Run with:  bash install_dependencies.sh                              #
#                                                                       #
#  Optional: install_all_tools.sh now installs the Ubuntu packages of   #
#  the tools it builds by itself, as its first step. This script only   #
#  installs packages, for every tool unless INSTALL_<TOOL>=no is given, #
#  e.g. to prepare a machine before building later.                    #
#  The package lists live in install_all_tools.sh (TOOL_PKGS).          #
#########################################################################

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "Do not source this script; run it with: bash ${BASH_SOURCE[0]}" >&2
    return 1
fi

set -euo pipefail

# Every tool, unless the caller turned it off.
for tool in YOSYS OPENROAD KLAYOUT VERILATOR IVERILOG COCOTB NGSPICE XSCHEM OPENVAF MAGIC NETGEN PDK; do
    var="INSTALL_$tool"
    export "$var=${!var:-yes}"
done

INSTALL_DEPS=only exec bash "$(dirname "${BASH_SOURCE[0]}")/install_all_tools.sh"
