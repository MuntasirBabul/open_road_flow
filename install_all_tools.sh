#!/usr/bin/env bash
#########################################################################
#  Build and install open-source EDA tools, each with a versioned       #
#  modulefile:                                                          #
#    digital: Yosys (with yosys-slang), OpenROAD, KLayout, Verilator,   #
#             Icarus Verilog, cocotb                                    #
#    analog:  ngspice, xschem, OpenVAF                                  #
#    layout:  Magic, Netgen                                             #
#    PDK:     ciel + the sky130 PDK                                     #
#                                                                       #
#  Run with:  bash install_all_tools.sh                                 #
#                                                                       #
#  Optional overrides (environment variables):                          #
#    ROOT_INSTALLATION=yes|no  install under /opt (sudo) or $HOME       #
#    SRC_DIR=<dir>             where sources are cloned (default $HOME) #
#    JOBS=<n>                  parallel build jobs (default nproc);     #
#                              lower it if WSL runs out of memory       #
#    INSTALL_<TOOL>=yes|no     pick tools (all default to yes), e.g.    #
#                              INSTALL_OPENROAD=no INSTALL_XSCHEM=no    #
#########################################################################

if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
    echo "Do not source this script; run it with: bash ${BASH_SOURCE[0]}" >&2
    return 1
fi

set -euo pipefail
shopt -s inherit_errexit

#########################################################################
#                       installation options                            #
#########################################################################

ROOT_INSTALLATION="${ROOT_INSTALLATION:-yes}"
SRC_DIR="${SRC_DIR:-$HOME}"
JOBS="${JOBS:-$(nproc)}"

# Tools, in installation order. Each one can be turned off with INSTALL_<TOOL>=no.
TOOLS=(yosys openroad klayout verilator iverilog cocotb ngspice xschem openvaf magic netgen pdk)
INSTALL_YOSYS="${INSTALL_YOSYS:-yes}"          # yosys-slang (SystemVerilog) is built in
INSTALL_OPENROAD="${INSTALL_OPENROAD:-yes}"
INSTALL_KLAYOUT="${INSTALL_KLAYOUT:-yes}"
INSTALL_VERILATOR="${INSTALL_VERILATOR:-yes}"
INSTALL_COCOTB="${INSTALL_COCOTB:-yes}"
INSTALL_NGSPICE="${INSTALL_NGSPICE:-yes}"
INSTALL_XSCHEM="${INSTALL_XSCHEM:-yes}"
INSTALL_OPENVAF="${INSTALL_OPENVAF:-yes}"      # needs LLVM 18+ (see install_dependencies.sh)
INSTALL_IVERILOG="${INSTALL_IVERILOG:-yes}"    # Icarus Verilog (iverilog, vvp)
INSTALL_MAGIC="${INSTALL_MAGIC:-yes}"          # layout editor, DRC, extraction
INSTALL_NETGEN="${INSTALL_NETGEN:-yes}"        # LVS
INSTALL_PDK="${INSTALL_PDK:-yes}"              # ciel, then enable the sky130 PDK below

# Icarus Verilog: empty builds its newest tag; a commit, tag or branch builds
# that instead (e.g. IVERILOG_REF=master for the current 14.0 development code).
IVERILOG_REF="${IVERILOG_REF:-}"

# PDK: ciel version, and the open_pdks commit of sky130 to enable (the one
# bridge_NVX uses; empty skips the PDK). PDK_ROOT is ciel's default location.
CIEL_VERSION="${CIEL_VERSION:-3.3.0}"
SKY130_PDK_HASH="${SKY130_PDK_HASH:-e7a6777d157a9d94c7ac757457b9e4309e9e9000}"
PDK_ROOT="${PDK_ROOT:-$HOME/.ciel}"

if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
    INSTALLATION_DIR="/opt/tools"
    MODULE_FILE_DIR="/opt/modulefiles"
else
    INSTALLATION_DIR="$HOME/tools"
    MODULE_FILE_DIR="$HOME/modulefiles"
fi
ENV_FILE="$INSTALLATION_DIR/env.sh"

#########################################################################
#                              helpers                                  #
#########################################################################

# Run a command as root only for a root installation. Builds always run as
# the normal user; only installation into $INSTALLATION_DIR uses this.
as_root() {
    if [[ "$ROOT_INSTALLATION" == "yes" ]]; then sudo "$@"; else "$@"; fi
}

log() { echo -e "\n===== $* =====\n" >&2; }

# install_from <dir> <command...>
# Run an install command with as_root, then give <dir> (the source or build
# folder it ran in) back to the current user. "sudo make install" and
# "sudo cmake --install" leave root-owned files there (e.g.
# install_manifest.txt), which would break the next update and rebuild.
install_from() {
    local dir=$1
    shift
    as_root "$@"
    if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
        sudo chown -R "$(id -u):$(id -g)" "$dir"
    fi
}

# find_cmake: full path of the cmake to use for one build.
# OpenROAD's dependency installer adds a second cmake in /usr/local/bin
# part-way through a run, and sudo searches its own PATH. Looking cmake up
# once per build and calling it by full path keeps configure, build and the
# sudo install step on the same cmake.
find_cmake() {
    local bin version
    bin=$(type -P cmake)
    version=$("$bin" --version)
    log "Using $bin (${version%%$'\n'*})"
    echo "$bin"
}

# True when INSTALL_<TOOL> is "yes".
want() {
    local var="INSTALL_${1^^}"
    [[ "${!var:-yes}" == "yes" ]]
}

# update_repo <url> <dir>
# Clone the repo, or fetch the newest commits and tags if it is already there.
update_repo() {
    local url=$1 dir=$2
    if [[ -d "$dir/.git" ]]; then
        if [[ -n "$(find "$dir" -user root -print -quit)" ]]; then
            # Left by an earlier sudo build or install.
            if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
                echo "Giving root-owned files in $dir back to $USER" >&2
                sudo chown -R "$(id -u):$(id -g)" "$dir"
            else
                echo "ERROR: $dir contains root-owned files (left by an earlier sudo build)." >&2
                echo "       Fix with: sudo chown -R $USER: $dir" >&2
                exit 1
            fi
        fi
        git -C "$dir" fetch --tags --prune origin >&2
        git -C "$dir" remote set-head origin --auto >&2
    else
        git clone "$url" "$dir" >&2
    fi
}

# checkout_latest_tag <url> <dir> [branch]
# Clone (or update) a repo, check out the newest tag on its release branch
# (default: the repo's default branch) and print that tag.
checkout_latest_tag() {
    local url=$1 dir=$2 ref="origin/${3:-HEAD}" ver
    update_repo "$url" "$dir"
    ver=$(git -C "$dir" describe --tags --abbrev=0 "$ref")
    git -C "$dir" checkout --force "tags/$ver" >&2
    git -C "$dir" submodule update --init --recursive >&2
    echo "$ver"
}

# checkout_ref <url> <dir> <ref>
# Clone (or update) a repo, check out a branch, tag or commit, and print its
# "git describe" name (e.g. s20260301-871-g66f0e8a1), used as the version.
checkout_ref() {
    local url=$1 dir=$2 ref=$3
    update_repo "$url" "$dir"
    # A branch name means the remote branch, not a stale local copy.
    if git -C "$dir" rev-parse --verify --quiet "origin/$ref^{commit}" > /dev/null; then
        ref="origin/$ref"
    fi
    git -C "$dir" checkout --force --detach "$ref" >&2
    git -C "$dir" submodule update --init --recursive >&2
    git -C "$dir" describe --tags
}

# One-line descriptions, shown by "module whatis" and "module avail -l".
declare -A TOOL_DESC=(
    [yosys]="Yosys RTL synthesis with the yosys-slang SystemVerilog frontend"
    [openroad]="OpenROAD RTL-to-GDS physical design"
    [klayout]="KLayout layout viewer and editor"
    [verilator]="Verilator Verilog/SystemVerilog simulator"
    [cocotb]="cocotb Python testbench framework, in its own Python venv"
    [ngspice]="ngspice circuit simulator, with OSDI support for OpenVAF models"
    [xschem]="xschem schematic editor"
    [openvaf]="OpenVAF-Reloaded Verilog-A compiler producing OSDI models"
    [iverilog]="Icarus Verilog simulator (iverilog, vvp)"
    [magic]="Magic VLSI layout editor, DRC and extraction"
    [netgen]="Netgen LVS (layout vs schematic) netlist comparison"
    [ciel]="ciel PDK version manager (sky130, gf180mcu)"
)

# write_modulefile <tool> <version> <HOME_VAR> <home> <modulefile lines...>
# Writes <MODULE_FILE_DIR>/<tool>/<version> and makes it the default, so
# "module load <tool>" loads the version installed last. Overwrites the
# files, so re-running never duplicates lines.
write_modulefile() {
    local tool=$1 ver=$2 var=$3 home=$4
    shift 4
    as_root mkdir -p "$MODULE_FILE_DIR/$tool"
    {
        echo '#%Module1.0'
        echo "module-whatis \"${TOOL_DESC[$tool]} ($ver)\""
        # Only one version of a tool can be loaded at a time.
        echo "conflict $tool"
        echo "setenv $var $home"
        printf '%s\n' "$@"
    } | as_root tee "$MODULE_FILE_DIR/$tool/$ver" > /dev/null
    printf '%s\n' '#%Module1.0' "set ModulesVersion \"$ver\"" \
        | as_root tee "$MODULE_FILE_DIR/$tool/.version" > /dev/null
}

#########################################################################
#              make "module load <tool>" work in every shell            #
#########################################################################
# Ubuntu only defines the module command in login shells (/etc/profile.d).
# These settings add the modulefiles to MODULEPATH and define the module
# command in non-login interactive shells too (new terminal tabs, VS Code,
# tmux). Paths are variables so the setup can be tested on scratch files.
MODULES_INIT="/usr/share/modules/init/bash"
SYS_MODULESPATH="/etc/environment-modules/modulespath"
SYS_BASHRC="/etc/bash.bashrc"
PROFILE_D="/etc/profile.d"
USER_BASHRC="$HOME/.bashrc"
BLOCK_START="# >>> eda-tools modules >>>"
BLOCK_END="# <<< eda-tools modules <<<"

# write_block <file> <text>
# Put <text> between the eda-tools markers at the end of <file>, replacing an
# existing block, so re-running never duplicates it. Uses sudo when needed.
write_block() {
    local file=$1 text=$2 run=()
    if [[ ! -w "$file" ]] && ! [[ ! -e "$file" && -w "$(dirname "$file")" ]]; then
        run=(sudo)
    fi
    "${run[@]}" touch "$file"
    "${run[@]}" sed -i --follow-symlinks "/^$BLOCK_START\$/,/^$BLOCK_END\$/d" "$file"
    printf '%s\n' "$BLOCK_START" "$text" "$BLOCK_END" | "${run[@]}" tee -a "$file" > /dev/null
}

setup_modulepath() {
    local init_module
    init_module="if ! type module > /dev/null 2>&1 && [ -f $MODULES_INIT ]; then
    . $MODULES_INIT
fi"

    if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
        # environment-modules reads its default MODULEPATH from this file, in
        # login and non-login shells alike, for every user.
        if ! grep -qxF "$MODULE_FILE_DIR" "$SYS_MODULESPATH" 2> /dev/null; then
            echo "$MODULE_FILE_DIR" | sudo tee -a "$SYS_MODULESPATH" > /dev/null
        fi
        write_block "$SYS_BASHRC" "$init_module"
    else
        write_block "$USER_BASHRC" "$init_module
type module > /dev/null 2>&1 && module use $MODULE_FILE_DIR"
    fi

    # Remove what earlier versions of this script set up instead (only
    # touching files that need it, so a non-root install never needs sudo).
    local old_line="module use $MODULE_FILE_DIR"
    if [[ -e "$PROFILE_D/zz-eda-modules.sh" ]]; then
        sudo rm -f "$PROFILE_D/zz-eda-modules.sh"
    fi
    if grep -qxF "$old_line" "$PROFILE_D/modules.sh" 2> /dev/null; then
        sudo sed -i --follow-symlinks "\|^$old_line\$|d" "$PROFILE_D/modules.sh"
    fi
    if grep -qxF "$old_line" "$USER_BASHRC" 2> /dev/null; then
        sed -i --follow-symlinks "\|^$old_line\$|d" "$USER_BASHRC"
    fi
}

# Record "module load <tool>/<ver>" in the central env.sh, replacing any
# older version of the same tool.
register_env() {
    local tool=$1 ver=$2
    as_root touch "$ENV_FILE"
    as_root sed -i "\|^module load $tool/|d" "$ENV_FILE"
    echo "module load $tool/$ver" | as_root tee -a "$ENV_FILE" > /dev/null
}

#########################################################################
#                            Install yosys                              #
#########################################################################
# Yosys builds with CMake (3.28+). SystemVerilog support through yosys-slang
# (sv-elab + slang) is built in: both come as git submodules pinned to the
# Yosys release, so no separate plugin build is needed. Use it with:
#   yosys -p "read_slang top.sv --top top; synth -top top"
install_yosys() {
    local src="$SRC_DIR/yosys" ver home build cmake_bin
    ver=$(checkout_latest_tag https://github.com/YosysHQ/yosys.git "$src")
    home="$INSTALLATION_DIR/yosys/$ver"
    build="$src/build_$ver"

    ### Build and Install
    # Bundled third-party libraries (fmt, tomlplusplus, boost regex) keep the
    # build independent of whatever versions the system happens to have.
    cmake_bin=$(find_cmake)
    "$cmake_bin" -S "$src" -B "$build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$home" \
        -DYOSYS_USE_BUNDLED_LIBS=ON \
        -DYOSYS_ENABLE_UNIT_TESTS=OFF
    "$cmake_bin" --build "$build" -j"$JOBS"
    install_from "$build" "$cmake_bin" --install "$build"

    # Check that the built-in slang frontend is there.
    if ! "$home/bin/yosys" -q -p "help read_slang" > /dev/null; then
        echo "ERROR: Yosys $ver was installed without the read_slang command." >&2
        exit 1
    fi

    write_modulefile yosys "$ver" YOSYS_HOME "$home" \
        'prepend-path PATH $env(YOSYS_HOME)/bin'
    register_env yosys "$ver"
}

#########################################################################
#                            Install OpenROAD                           #
#########################################################################
install_openroad() {
    local src="$SRC_DIR/OpenROAD" ver home build cmake_bin
    ver=$(checkout_latest_tag https://github.com/The-OpenROAD-Project/OpenROAD.git "$src")
    home="$INSTALLATION_DIR/openroad/$ver"
    build="$src/build_$ver"

    ### Build and Install
    # The dependency installer installs system packages, so it always needs sudo.
    (cd "$src" && sudo ./etc/DependencyInstaller.sh -all)
    sudo chown -R "$(id -u):$(id -g)" "$src"

    # Look cmake up only now: the dependency installer may just have added
    # its own cmake in /usr/local/bin, which its libraries were built with.
    cmake_bin=$(find_cmake)
    "$cmake_bin" -S "$src" -B "$build" -DCMAKE_INSTALL_PREFIX="$home"
    "$cmake_bin" --build "$build" -j"$JOBS"
    install_from "$build" "$cmake_bin" --install "$build"

    write_modulefile openroad "$ver" OPENROAD_HOME "$home" \
        'prepend-path PATH $env(OPENROAD_HOME)/bin' \
        'prepend-path LD_LIBRARY_PATH $env(OPENROAD_HOME)/lib'
    register_env openroad "$ver"
}

#########################################################################
#                            Install klayout                            #
#########################################################################
install_klayout() {
    local src="$SRC_DIR/klayout" ver home
    ver=$(checkout_latest_tag https://github.com/KLayout/klayout.git "$src")
    home="$INSTALLATION_DIR/klayout/$ver"

    ### Build and Install
    # Build as the normal user into a staging dir, then copy it into place.
    (cd "$src" && ./build.sh \
        -build "build_$ver" \
        -bin "bin_$ver" \
        -option "-j$JOBS" \
        -noruby)
    as_root mkdir -p "$home/bin"
    as_root cp -a "$src/bin_$ver/." "$home/bin/"

    # KLayout keeps its shared libraries next to the executables in bin/.
    write_modulefile klayout "$ver" KLAYOUT_HOME "$home" \
        'prepend-path PATH $env(KLAYOUT_HOME)/bin' \
        'prepend-path LD_LIBRARY_PATH $env(KLAYOUT_HOME)/bin'
    register_env klayout "$ver"
}

#########################################################################
#                         Install Verilator                             #
#########################################################################
install_verilator() {
    local src="$SRC_DIR/verilator" ver home
    unset VERILATOR_ROOT
    ver=$(checkout_latest_tag https://github.com/verilator/verilator.git "$src")
    home="$INSTALLATION_DIR/verilator/$ver"

    ### Build and Install
    (
        cd "$src"
        autoconf
        ./configure --prefix "$home"
        make -j"$JOBS"
    )
    install_from "$src" make -C "$src" install

    write_modulefile verilator "$ver" VERILATOR_HOME "$home" \
        'prepend-path PATH $env(VERILATOR_HOME)/bin' \
        'prepend-path LD_LIBRARY_PATH $env(VERILATOR_HOME)/lib'
    register_env verilator "$ver"
}

#########################################################################
#                       Install Icarus Verilog                          #
#########################################################################
install_iverilog() {
    local src="$SRC_DIR/iverilog" url=https://github.com/steveicarus/iverilog.git ver home
    if [[ -n "$IVERILOG_REF" ]]; then
        ver=$(checkout_ref "$url" "$src" "$IVERILOG_REF")
    else
        ver=$(checkout_latest_tag "$url" "$src")
    fi
    home="$INSTALLATION_DIR/iverilog/$ver"

    ### Build and Install
    # Building from git needs autoconf and gperf (install_dependencies.sh).
    (
        cd "$src"
        sh autoconf.sh
        ./configure --prefix="$home"
        make -j"$JOBS"
    )
    install_from "$src" make -C "$src" install

    write_modulefile iverilog "$ver" IVERILOG_HOME "$home" \
        'prepend-path PATH $env(IVERILOG_HOME)/bin'
    register_env iverilog "$ver"
}

#########################################################################
#                           Install cocotb                              #
#########################################################################
install_cocotb() {
    # Deliberately pinned to the 1.9.x series; cocotb 2.x has breaking API changes.
    local ver="v1.9.2" home pip
    home="$INSTALLATION_DIR/cocotb/$ver"
    pip="$home/venv/bin/pip"

    # Virtual environment owned by this cocotb version
    as_root mkdir -p "$home"
    as_root python3 -m venv "$home/venv"
    as_root "$pip" install --upgrade pip
    # One pip call, with cocotb pinned, so no extra package can upgrade cocotb.
    as_root "$pip" install \
        "cocotb[bus]==${ver#v}" \
        cocotb-coverage \
        cocotb-test \
        pytest \
        numpy

    # The venv's bin/ (python3, pip, cocotb-config, pytest) goes first in PATH;
    # its python finds the venv's site-packages by itself, so no PYTHONPATH.
    write_modulefile cocotb "$ver" COCOTB_HOME "$home" \
        'prepend-path PATH $env(COCOTB_HOME)/venv/bin'
    register_env cocotb "$ver"
}

#########################################################################
#                           Install ngspice                             #
#########################################################################
install_ngspice() {
    local src="$SRC_DIR/ngspice" tag ver home build
    # ngspice's default branch is the development branch (pre-master-NN);
    # releases are tagged on master.
    tag=$(checkout_latest_tag https://git.code.sf.net/p/ngspice/ngspice "$src" master)
    ver="${tag#ngspice-}"          # tags look like ngspice-47
    home="$INSTALLATION_DIR/ngspice/$ver"
    build="$src/release_$ver"

    ### Build and Install
    # readline, OpenMP, XSPICE and OSDI (for OpenVAF models) are on by default;
    # X11 plotting and CIDER (device simulator) have to be asked for.
    (cd "$src" && ./autogen.sh)
    mkdir -p "$build"
    (
        cd "$build"
        "$src/configure" --prefix="$home" --with-x --enable-cider --disable-debug
        make -j"$JOBS"
    )
    install_from "$build" make -C "$build" install

    write_modulefile ngspice "$ver" NGSPICE_HOME "$home" \
        'prepend-path PATH $env(NGSPICE_HOME)/bin' \
        'prepend-path LD_LIBRARY_PATH $env(NGSPICE_HOME)/lib'
    register_env ngspice "$ver"
}

#########################################################################
#                            Install xschem                             #
#########################################################################
install_xschem() {
    local src="$SRC_DIR/xschem" ver home
    ver=$(checkout_latest_tag https://github.com/StefanSchippers/xschem.git "$src")
    home="$INSTALLATION_DIR/xschem/$ver"

    ### Build and Install
    (
        cd "$src"
        ./configure --prefix="$home"
        make -j"$JOBS"
    )
    install_from "$src" make -C "$src" install

    write_modulefile xschem "$ver" XSCHEM_HOME "$home" \
        'prepend-path PATH $env(XSCHEM_HOME)/bin'
    register_env xschem "$ver"
}

#########################################################################
#                     Install OpenVAF (OpenVAF-Reloaded)                #
#########################################################################
# Verilog-A compiler producing OSDI models that ngspice loads. The original
# OpenVAF is archived; this uses the maintained OpenVAF-Reloaded fork.

# find_llvm <OpenVAF source dir>
# Print the newest LLVM version that this OpenVAF release supports (its
# llvmNN cargo features) and that is installed with development files.
find_llvm() {
    local src=$1 v
    for v in $(grep -oE '^llvm[0-9]+' "$src/openvaf/openvaf-driver/Cargo.toml" | tr -d 'lvm' | sort -rn); do
        if [[ -x /usr/lib/llvm-$v/bin/llvm-config && -e /usr/lib/llvm-$v/include/llvm-c/Core.h ]]; then
            echo "$v"
            return 0
        fi
    done
    return 1
}

install_openvaf() {
    local src="$SRC_DIR/OpenVAF" tag ver home llvm bin

    tag=$(checkout_latest_tag https://github.com/OpenVAF-Reloaded/OpenVAF.git "$src")
    ver="${tag#_}"                 # release tags look like _20260616
    home="$INSTALLATION_DIR/openvaf/$ver"

    if ! llvm=$(find_llvm "$src"); then
        echo "ERROR: OpenVAF $tag needs one of these LLVM versions with development files:" \
            "$(grep -oE '^llvm[0-9]+' "$src/openvaf/openvaf-driver/Cargo.toml" | tr '\n' ' ')" >&2
        echo "       Ubuntu 24.04+: sudo apt install llvm-18 llvm-18-dev libclang-18-dev clang-18" >&2
        echo "       Older Ubuntu:  use https://apt.llvm.org, or rerun with INSTALL_OPENVAF=no" >&2
        exit 1
    fi

    # Rust toolchain for the current user (not root), installed only if missing.
    if ! command -v cargo > /dev/null; then
        if [[ ! -f "$HOME/.cargo/env" ]]; then
            curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
                | sh -s -- -y --profile default --no-modify-path
        fi
        # shellcheck source=/dev/null
        source "$HOME/.cargo/env"
    fi

    ### Build and Install
    # Same as upstream build.sh, but only the compiler package (openvaf-driver).
    # llvm-sys finds LLVM through LLVM_SYS_<major>1_PREFIX (e.g. LLVM_SYS_181_PREFIX).
    log "OpenVAF: building with LLVM $llvm"
    (
        cd "$src"
        export "LLVM_SYS_${llvm}1_PREFIX=/usr/lib/llvm-$llvm"
        export PATH="/usr/lib/llvm-$llvm/bin:$PATH"
        cargo build --release -p openvaf-driver --features "llvm$llvm"
    )

    # Current releases name the binary openvaf-r; older ones call it openvaf.
    for bin in openvaf-r openvaf; do
        [[ -x "$src/target/release/$bin" ]] && break
    done
    if [[ ! -x "$src/target/release/$bin" ]]; then
        echo "ERROR: no openvaf binary found in $src/target/release" >&2
        exit 1
    fi
    as_root mkdir -p "$home/bin"
    as_root cp "$src/target/release/$bin" "$home/bin/"
    # Keep the plain "openvaf" name working for scripts that expect it.
    if [[ "$bin" != "openvaf" ]]; then
        as_root ln -sf "$bin" "$home/bin/openvaf"
    fi

    write_modulefile openvaf "$ver" OPENVAF_HOME "$home" \
        'prepend-path PATH $env(OPENVAF_HOME)/bin'
    register_env openvaf "$ver"
}

#########################################################################
#                            Install Magic                              #
#########################################################################
# Tcl/Tk 8.6 is given explicitly, so a Tcl 9 installed alongside is not
# picked up (Magic and Netgen are Tcl 8 applications).
TCL_CONFIG_DIR="/usr/lib/tcl8.6"
TK_CONFIG_DIR="/usr/lib/tk8.6"

install_magic() {
    local src="$SRC_DIR/magic" ver home
    ver=$(checkout_latest_tag https://github.com/RTimothyEdwards/magic.git "$src")
    home="$INSTALLATION_DIR/magic/$ver"

    ### Build and Install
    (
        cd "$src"
        ./configure --prefix="$home" --with-tcl="$TCL_CONFIG_DIR" --with-tk="$TK_CONFIG_DIR"
        make -j"$JOBS"
    )
    install_from "$src" make -C "$src" install

    write_modulefile magic "$ver" MAGIC_HOME "$home" \
        'prepend-path PATH $env(MAGIC_HOME)/bin'
    register_env magic "$ver"
}

#########################################################################
#                            Install Netgen                             #
#########################################################################
install_netgen() {
    local src="$SRC_DIR/netgen" ver home
    # Netgen tags its releases on the netgen-1.5 branch, not on master.
    ver=$(checkout_latest_tag https://github.com/RTimothyEdwards/netgen.git "$src" netgen-1.5)
    home="$INSTALLATION_DIR/netgen/$ver"

    ### Build and Install
    # -std=gnu17: GCC 15 defaults to C23, where Netgen's old-style function
    # pointers (int (*f)()) no longer compile.
    (
        cd "$src"
        ./configure --prefix="$home" --with-tcl="$TCL_CONFIG_DIR" --with-tk="$TK_CONFIG_DIR" \
            CFLAGS="-g -O2 -std=gnu17"
        make -j"$JOBS"
    )
    install_from "$src" make -C "$src" install

    write_modulefile netgen "$ver" NETGEN_HOME "$home" \
        'prepend-path PATH $env(NETGEN_HOME)/bin'
    register_env netgen "$ver"
}

#########################################################################
#                   Install ciel and the sky130 PDK                     #
#########################################################################
# ciel downloads prebuilt open_pdks releases into PDK_ROOT (default ~/.ciel)
# and switches between them. The PDK itself goes into the user's PDK_ROOT,
# not into $INSTALLATION_DIR.
install_pdk() {
    local ver="$CIEL_VERSION" home
    home="$INSTALLATION_DIR/ciel/$ver"

    # ciel lives in its own venv; only the ciel command is put on PATH (not
    # the venv's python3/pip), so loading the module leaves python3 alone.
    as_root mkdir -p "$home/bin"
    as_root python3 -m venv "$home/venv"
    as_root "$home/venv/bin/pip" install --upgrade pip
    as_root "$home/venv/bin/pip" install "ciel==$ver"
    as_root ln -sf ../venv/bin/ciel "$home/bin/ciel"

    write_modulefile ciel "$ver" CIEL_HOME "$home" \
        'prepend-path PATH $env(CIEL_HOME)/bin'
    register_env ciel "$ver"

    if [[ -n "$SKY130_PDK_HASH" ]]; then
        # As the current user: downloads this version unless it is already
        # there, and makes it the active sky130A/sky130B in PDK_ROOT.
        log "sky130 PDK $SKY130_PDK_HASH in $PDK_ROOT"
        "$home/bin/ciel" enable --pdk-family sky130 --pdk-root "$PDK_ROOT" "$SKY130_PDK_HASH"
    fi
}

#########################################################################
#                       directories and MODULEPATH                      #
#########################################################################

as_root mkdir -p "$INSTALLATION_DIR" "$MODULE_FILE_DIR"
mkdir -p "$SRC_DIR"

setup_modulepath

#########################################################################
#                               install                                 #
#########################################################################

for tool in "${TOOLS[@]}"; do
    if want "$tool"; then
        log "Installing $tool"
        "install_$tool"
    else
        log "Skipping $tool (INSTALL_${tool^^}=no)"
    fi
done

#########################################################################
log "Done"
echo "Modulefiles: $MODULE_FILE_DIR"
echo "Load all tools in a new shell with: source $ENV_FILE"
