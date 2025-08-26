#########################################################################
#                   define installation directory                       #
#########################################################################

ROOT_INSTALLATION="no"

if [ "$ROOT_INSTALLATION" = "yes" ]; then
    ROOT_ARG="sudo "
    INSTALLATION_DIR="/opt/tools"
    MODULE_FILE_DIR="/opt/modulefiles"
    $ROOT_ARG sh -c "echo 'module use $MODULE_FILE_DIR' >> /etc/profile.d/modules.sh"
else
    ROOT_ARG=""
    INSTALLATION_DIR="$HOME/tools"
    MODULE_FILE_DIR="$HOME/modulefiles"
    $ROOT_ARG sh -c "echo 'module use $MODULE_FILE_DIR' >> ~/.bashrc"
fi

$ROOT_ARG mkdir -p $INSTALLATION_DIR
$ROOT_ARG mkdir -p $MODULE_FILE_DIR

#########################################################################
#                            Install yosys                              #
#########################################################################
cd ~  ; git clone https://github.com/YosysHQ/yosys.git ; cd yosys

YOSYS_VER=$(git describe --tags --abbrev=0)
YOSYS_HOME="$INSTALLATION_DIR/yosys/$YOSYS_VER" && $ROOT_ARG mkdir -p $YOSYS_HOME 
YOSYS_MOD_D="$MODULE_FILE_DIR/yosys" && $ROOT_ARG mkdir -p $YOSYS_MOD_D
YOSYS_MOD_F="$MODULE_FILE_DIR/yosys/$YOSYS_VER" && $ROOT_ARG touch $YOSYS_MOD_F 

git checkout tags/$YOSYS_VER
git submodule update --init --recursive

### Install
make -j$(nproc)
$ROOT_ARG make install PREFIX=$YOSYS_HOME

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                        >> $YOSYS_MOD_F"
$ROOT_ARG sh -c "echo 'setenv YOSYS_HOME $YOSYS_HOME'                      >> $YOSYS_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(YOSYS_HOME)/bin'            >> $YOSYS_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(YOSYS_HOME)/lib' >> $YOSYS_MOD_F"

### yosys-slang for system verilog support ###
cd ~ ; git clone https://github.com/povik/yosys-slang.git ; cd yosys-slang
git submodule update --init --recursive

sed -i 's|^CMAKE_FLAGS.\=|CMAKE_FLAGS +=|' Makefile

make -j$(nproc) CMAKE_FLAGS="$(CMAKE_FLAGS) -DYOSYS_CONFIG=$YOSYS_HOME/bin/yosys-config -DCMAKE_CXX_FLAGS=\"-I$YOSYS_HOME/share/yosys/include\" -DYOSYS_CXXFLAGS=\"-I$YOSYS_HOME/share/yosys/include\" .."
mkdir -p $YOSYS_HOME/share/yosys/plugins && cp -r build/slang.so $YOSYS_HOME/share/yosys/plugins
#########################################################################
#                            Install OpenROAD                           #
#########################################################################
cd ~ ; git clone https://github.com/The-OpenROAD-Project/OpenROAD.git ; cd OpenROAD

OPENROAD_VER=$(git describe --tags --abbrev=0)
OPENROAD_HOME="$INSTALLATION_DIR/openroad/$OPENROAD_VER" && $ROOT_ARG mkdir -p $OPENROAD_HOME 
OPENROAD_MOD_D="$MODULE_FILE_DIR/openroad" && $ROOT_ARG mkdir -p $OPENROAD_MOD_D
OPENROAD_MOD_F="$MODULE_FILE_DIR/openroad/$OPENROAD_VER" && $ROOT_ARG touch $OPENROAD_MOD_F

git checkout tags/$OPENROAD_VER
git submodule update --init --recursive

### Build and Install
$ROOT_ARG ./etc/DependencyInstaller.sh -all
mkdir build && cd build
$ROOT_ARG cmake .. -DCMAKE_INSTALL_PREFIX=$OPENROAD_HOME
make -j$(nproc)
$ROOT_ARG make install

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                           >> $OPENROAD_MOD_F"
$ROOT_ARG sh -c "echo 'setenv OPENROAD_HOME $OPENROAD_HOME'                   >> $OPENROAD_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(OPENROAD_HOME)/bin'            >> $OPENROAD_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(OPENROAD_HOME)/lib' >> $OPENROAD_MOD_F"
#########################################################################
#                            Install klayout                            #
#########################################################################
cd ~ ; git clone https://github.com/KLayout/klayout.git ; cd klayout

KLAYOUT_VER=$(git describe --tags --abbrev=0)
KLAYOUT_HOME="$INSTALLATION_DIR/klayout/$KLAYOUT_VER" && $ROOT_ARG mkdir -p $KLAYOUT_HOME/bin
KLAYOUT_MOD_D="$MODULE_FILE_DIR/klayout" && $ROOT_ARG mkdir -p $KLAYOUT_MOD_D
KLAYOUT_MOD_F="$MODULE_FILE_DIR/klayout/$KLAYOUT_VER" && $ROOT_ARG touch $KLAYOUT_MOD_F

git checkout tags/$KLAYOUT_VER
git submodule update --init --recursive

### Build and Install
mkdir build 
$ROOT_ARG ./build.sh -build ./build -bin $KLAYOUT_HOME/bin -option "-j$(nproc)" -noruby

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                          >> $KLAYOUT_MOD_F"
$ROOT_ARG sh -c "echo 'setenv KLAYOUT_HOME $KLAYOUT_HOME'                    >> $KLAYOUT_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(KLAYOUT_HOME)/bin'            >> $KLAYOUT_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(KLAYOUT_HOME)/lib' >> $KLAYOUT_MOD_F"
#########################################################################
#                         Install Verilator                             #
#########################################################################
cd ~ ; git clone https://github.com/verilator/verilator ; cd verilator ; unset VERILATOR_ROOT 

VERILATOR_VER=$(git describe --tags --abbrev=0)
VERILATOR_HOME="$INSTALLATION_DIR/verilator/$VERILATOR_VER" && $ROOT_ARG mkdir -p $VERILATOR_HOME
VERILATOR_MOD_D="$MODULE_FILE_DIR/verilator" && $ROOT_ARG mkdir -p $VERILATOR_MOD_D
VERILATOR_MOD_F="$MODULE_FILE_DIR/verilator/$VERILATOR_VER" && $ROOT_ARG touch $VERILATOR_MOD_F

git checkout tags/$VERILATOR_VER
git submodule update --init --recursive

### Build and Install
autoconf
./configure --prefix $VERILATOR_HOME
make -j `nproc`
$ROOT_ARG make install

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                            >> $VERILATOR_MOD_F"
$ROOT_ARG sh -c "echo 'setenv VERILATOR_HOME $VERILATOR_HOME'                  >> $VERILATOR_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(VERILATOR_HOME)/bin'            >> $VERILATOR_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(VERILATOR_HOME)/lib' >> $VERILATOR_MOD_F"
#########################################################################
#                           Install cocotb                              #
#########################################################################
#cd ~ ; git clone https://github.com/cocotb/cocotb.git ; cd cocotb

#COCOTB_VER=$(git describe --tags --abbrev=0)
COCOTB_VER="v1.9.2" # Latest version is beta version; using the stable one
COCOTB_HOME="$INSTALLATION_DIR/cocotb/$COCOTB_VER" && $ROOT_ARG mkdir -p $COCOTB_HOME
COCOTB_MOD_D="$MODULE_FILE_DIR/cocotb" && $ROOT_ARG mkdir -p $COCOTB_MOD_D
COCOTB_MOD_F="$MODULE_FILE_DIR/cocotb/$COCOTB_VER" && $ROOT_ARG touch $COCOTB_MOD_F

# Creating virutal directory
$ROOT_ARG python3 -m venv $COCOTB_HOME/venv
#source  $COCOTB_HOME/venv/bin/activate

# Calling Virutal env pip to install in virtual env
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install cocotb==$COCOTB_VER
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install cocotb[bus]
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install cocotb-coverage
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install cocotb-test
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install pytest
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install numpy
$ROOT_ARG $COCOTB_HOME/venv/bin/pip install regression

PYTHON_VER=$(python3 --version | awk '{print $2}' | awk -F '.' '{print "python"$1"."$2}')
#deactivate

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                                                   >> $COCOTB_MOD_F"
$ROOT_ARG sh -c "echo 'setenv COCOTB_HOME $COCOTB_HOME'                                               >> $COCOTB_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$envCOCOTB_HOME/venv/bin'                                   >> $COCOTB_MOD_F"
$ROOT_ARG sh -c "echo 'prepend-path PYTHONPATH \$env(COCOTB_HOME)/venv/lib/$PYTHON_VER/site-packages' >> $COCOTB_MOD_F"
$ROOT_ARG sh -c "echo 'conflict cocotb'                                                               >> $COCOTB_MOD_F"
#########################################################################
#                   Create Environment file to source                   #
#########################################################################
# source the env.sh to load all the modules
$ROOT_ARG sh -c "echo 'module load verilator/$VERILATOR_VER' >> env.sh"
$ROOT_ARG sh -c "echo 'module load yosys/$YOSYS_VER'         >> env.sh"
$ROOT_ARG sh -c "echo 'module load openroad/$OPENROAD_VER'   >> env.sh"
$ROOT_ARG sh -c "echo 'module load klayout/$KLAYOUT_VER'     >> env.sh"
$ROOT_ARG sh -c "echo 'module load cocotb/$COCOTB_VER'       >> env.sh"
