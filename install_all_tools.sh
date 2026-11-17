#!/usr/bin/env bash
#########################################################################
#  Build and install open-source EDA tools, each with a versioned       #
#  modulefile:                                                          #
#    digital: Yosys (+ slang plugin), OpenROAD, KLayout, Verilator,     #
#             cocotb                                                    #
#    analog:  ngspice, xschem, OpenVAF                                  #
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
TOOLS=(yosys openroad klayout verilator cocotb ngspice xschem openvaf)
INSTALL_YOSYS="${INSTALL_YOSYS:-yes}"          # includes the slang SystemVerilog plugin
INSTALL_OPENROAD="${INSTALL_OPENROAD:-yes}"
INSTALL_KLAYOUT="${INSTALL_KLAYOUT:-yes}"
INSTALL_VERILATOR="${INSTALL_VERILATOR:-yes}"
INSTALL_COCOTB="${INSTALL_COCOTB:-yes}"
INSTALL_NGSPICE="${INSTALL_NGSPICE:-yes}"
INSTALL_XSCHEM="${INSTALL_XSCHEM:-yes}"
INSTALL_OPENVAF="${INSTALL_OPENVAF:-yes}"      # needs LLVM 18+ (see install_dependencies.sh)

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

# True when INSTALL_<TOOL> is "yes".
want() {
    local var="INSTALL_${1^^}"
    [[ "${!var:-yes}" == "yes" ]]
}

# checkout_latest_tag <url> <dir> [branch]
# Clone (or update) a repo, check out the newest tag on its release branch
# (default: the repo's default branch) and print that tag.
checkout_latest_tag() {
    local url=$1 dir=$2 ref="origin/${3:-HEAD}" ver
    if [[ -d "$dir/.git" ]]; then
        if [[ -n "$(find "$dir" -user root -print -quit)" ]]; then
            echo "ERROR: $dir contains root-owned files (left by an earlier sudo build)." >&2
            echo "       Fix with: sudo chown -R $USER: $dir" >&2
            exit 1
        fi
        git -C "$dir" fetch --tags --prune origin >&2
        git -C "$dir" remote set-head origin --auto >&2
    else
        git clone "$url" "$dir" >&2
    fi
    ver=$(git -C "$dir" describe --tags --abbrev=0 "$ref")
    git -C "$dir" checkout --force "tags/$ver" >&2
    git -C "$dir" submodule update --init --recursive >&2
    echo "$ver"
}

# write_modulefile <tool> <version> <HOME_VAR> <home> <modulefile lines...>
# Overwrites the modulefile, so re-running never duplicates lines.
write_modulefile() {
    local tool=$1 ver=$2 var=$3 home=$4
    shift 4
    as_root mkdir -p "$MODULE_FILE_DIR/$tool"
    {
        echo '#%Module1.0'
        echo "setenv $var $home"
        printf '%s\n' "$@"
    } | as_root tee "$MODULE_FILE_DIR/$tool/$ver" > /dev/null
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
install_yosys() {
    local src="$SRC_DIR/yosys" ver home
    ver=$(checkout_latest_tag https://github.com/YosysHQ/yosys.git "$src")
    home="$INSTALLATION_DIR/yosys/$ver"

    ### Build and Install
    # PREFIX is passed to the build as well as the install, so yosys-config
    # reports the real install paths (needed by the slang plugin build).
    make -C "$src" -j"$JOBS" PREFIX="$home"
    as_root make -C "$src" install PREFIX="$home"

    write_modulefile yosys "$ver" YOSYS_HOME "$home" \
        'prepend-path PATH $env(YOSYS_HOME)/bin' \
        'prepend-path LD_LIBRARY_PATH $env(YOSYS_HOME)/lib'
    register_env yosys "$ver"

    log "Yosys slang plugin"
    if ! build_slang "$home"; then
        echo "WARNING: slang plugin build failed; Yosys is installed without it." >&2
    fi
}

### slang plugin (SystemVerilog support), formerly yosys-slang, now sv-elab ###
# Optional: if it fails (e.g. this Yosys version is not supported by the
# plugin), the rest of the installation still continues.
build_slang() {
    local yosys_home=$1 src="$SRC_DIR/sv-elab"
    if [[ -d "$src/.git" ]]; then
        git -C "$src" pull --ff-only >&2 || return 1
    else
        git clone https://github.com/povik/sv-elab.git "$src" >&2 || return 1
    fi
    git -C "$src" submodule update --init --recursive >&2 || return 1
    # Put the new Yosys first in PATH so its yosys-config is the one found.
    PATH="$yosys_home/bin:$PATH" cmake -S "$src" -B "$src/build" \
        -DCMAKE_BUILD_TYPE=Release \
        -DYOSYS_CONFIG="$yosys_home/bin/yosys-config" || return 1
    PATH="$yosys_home/bin:$PATH" cmake --build "$src/build" -j"$JOBS" || return 1
    as_root mkdir -p "$yosys_home/share/yosys/plugins" || return 1
    as_root cp "$src/build/slang.so" "$yosys_home/share/yosys/plugins/" || return 1
}

#########################################################################
#                            Install OpenROAD                           #
#########################################################################
install_openroad() {
    local src="$SRC_DIR/OpenROAD" ver home build
    ver=$(checkout_latest_tag https://github.com/The-OpenROAD-Project/OpenROAD.git "$src")
    home="$INSTALLATION_DIR/openroad/$ver"
    build="$src/build_$ver"

    ### Build and Install
    # The dependency installer installs system packages, so it always needs sudo.
    (cd "$src" && sudo ./etc/DependencyInstaller.sh -all)
    cmake -S "$src" -B "$build" -DCMAKE_INSTALL_PREFIX="$home"
    cmake --build "$build" -j"$JOBS"
    as_root cmake --install "$build"

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
    as_root make -C "$src" install

    write_modulefile verilator "$ver" VERILATOR_HOME "$home" \
        'prepend-path PATH $env(VERILATOR_HOME)/bin' \
        'prepend-path LD_LIBRARY_PATH $env(VERILATOR_HOME)/lib'
    register_env verilator "$ver"
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
        'prepend-path PATH $env(COCOTB_HOME)/venv/bin' \
        'conflict cocotb'
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
    as_root make -C "$build" install

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
    as_root make -C "$src" install

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
#                       directories and MODULEPATH                      #
#########################################################################

as_root mkdir -p "$INSTALLATION_DIR" "$MODULE_FILE_DIR"
mkdir -p "$SRC_DIR"

MODULE_USE_LINE="module use $MODULE_FILE_DIR"
if [[ "$ROOT_INSTALLATION" == "yes" ]]; then
    # Own file instead of appending to the package-owned modules.sh. The "zz-"
    # prefix makes it run after modules.sh, which defines the module command.
    echo "$MODULE_USE_LINE" | sudo tee /etc/profile.d/zz-eda-modules.sh > /dev/null
    # Remove the lines that earlier versions of this script appended to modules.sh.
    if [[ -e /etc/profile.d/modules.sh ]]; then
        sudo sed -i --follow-symlinks "\|^$MODULE_USE_LINE\$|d" /etc/profile.d/modules.sh
    fi
else
    grep -qxF "$MODULE_USE_LINE" ~/.bashrc 2> /dev/null || echo "$MODULE_USE_LINE" >> ~/.bashrc
fi

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
