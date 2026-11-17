#!/usr/bin/env bash
#########################################################################
#                        Install Dependencies                           #
#                                                                       #
#  Run with:  bash install_dependencies.sh                              #
#########################################################################

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "Do not source this script; run it with: bash ${BASH_SOURCE[0]}" >&2
    return 1
fi

set -euo pipefail

# Packages every tool in install_all_tools.sh needs. Installed in one call,
# so a missing package stops the script instead of being silently skipped.
REQUIRED_PKGS=(
    # module system
    environment-modules
    # toolchain
    build-essential gcc g++ clang make cmake pkg-config autoconf git perl help2man
    # yosys
    tcl tcl-dev libreadline-dev bison flex libffi-dev
    # python / cocotb
    python3 python3-dev python3-pip python3-venv python3-virtualenv libpython3-dev pipx
    # klayout
    qtbase5-dev qttools5-dev libqt5xmlpatterns5-dev qtmultimedia5-dev
    libqt5multimediawidgets5 libqt5svg5-dev ruby ruby-dev libz-dev zlib1g zlib1g-dev libgit2-dev
    # verilator
    libfl-dev
    # ngspice
    automake libtool libxaw7-dev libxmu-dev libxext-dev libxft-dev libfontconfig1-dev
    libxrender-dev libfreetype-dev libfftw3-dev
    # xschem (needs Tcl/Tk 8.x)
    tcl8.6-dev tk8.6-dev libx11-dev libxpm-dev libcairo2-dev libxcb1-dev libx11-xcb-dev gawk
    # openvaf (Rust is installed by install_all_tools.sh through rustup)
    curl libzstd-dev libxml2-dev
)

# Nice to have; not available on every Ubuntu release, so failures are only warnings.
OPTIONAL_PKGS=(
    libfl2                    # Ubuntu only
    ccache                    # if present at Verilator build time, needed at run time
    mold                      # if present at Verilator build time, needed at run time
    libgoogle-perftools-dev   # faster Verilator runtime (tcmalloc)
    numactl
    libsndfile1-dev           # ngspice: wav file support
    libsamplerate0-dev        # ngspice: wav file support
)

# OpenVAF needs LLVM 18 or newer. Ubuntu 24.04+ ships it; on older releases
# install it from https://apt.llvm.org instead (e.g. sudo ./llvm.sh 18).
OPENVAF_LLVM_PKGS=(llvm-18 llvm-18-dev libclang-18-dev clang-18)

sudo apt-get update
sudo apt-get install -y "${REQUIRED_PKGS[@]}"

for pkg in "${OPTIONAL_PKGS[@]}"; do
    sudo apt-get install -y "$pkg" || echo "WARNING: optional package '$pkg' could not be installed; continuing." >&2
done

sudo apt-get install -y "${OPENVAF_LLVM_PKGS[@]}" \
    || echo "WARNING: LLVM 18 is not available from apt here; OpenVAF needs LLVM 18+ (see https://apt.llvm.org)." >&2
