#########################################################################
#                   define installation directory                       #
#########################################################################
ROOT_INSTALLATION="no"

if [ "$ROOT_INSTALLATION" = "yes" ]; then
    ROOT_ARG="sudo "
    INSTALLATION_DIR="/opt/tools"
    MODULE_FILE_DIR="/opt/modulefiles"
    sudo sh -c "echo 'module use $MODULE_FILE_DIR' >> /etc/profile.d/modules.sh"
else
    ROOT_ARG=""
    INSTALLATION_DIR="~/tools"
    MODULE_FILE_DIR="~/modulefiles"
    sudo sh -c "echo 'module use $MODULE_FILE_DIR' >> ~/.bashrc"
fi

$ROOT_ARG mkdir -p $INSTALLATION_DIR
$ROOT_ARG mkdir -p $MODULE_FILE_DIR

#########################################################################
#                            Install yosys                              #
#########################################################################
cd ~  ; git clone https://github.com/YosysHQ/yosys.git ; cd yosys

YOSYS_VER=$(git describe --tags --abbrev=0)
YOSYS_HOME="$INSTALLATION_DIR/yosys/$YOSYS_VER"                                 ; sudo mkdir -p $YOSYS_HOME
YOSYS_MODULE_FILE="$MODULE_FILE_DIR/yosys/$YOSYS_VER"                           ; sudo mkdir -p $MODULE_FILE_DIR/yosys    ; sudo touch $YOSYS_MODULE_FILE

git checkout tags/$YOSYS_VER
git submodule update --init --recursive

### Install
make -j$(nproc)
$ROOT_ARG make install PREFIX=$YOSYS_HOME

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                                  >> $YOSYS_MODULE_FILE"
$ROOT_ARG sh -c "echo 'setenv YOSYS_HOME $YOSYS_HOME'                                >> $YOSYS_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(YOSYS_HOME)/bin'                      >> $YOSYS_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(YOSYS_HOME)/lib'           >> $YOSYS_MODULE_FILE"
#########################################################################
#                            Install OpenROAD                           #
#########################################################################
cd ~ ; git clone https://github.com/The-OpenROAD-Project/OpenROAD.git ; cd OpenROAD

OPENROAD_VER=$(git describe --tags --abbrev=0)
OPENROAD_HOME="$INSTALLATION_DIR/openroad/$OPENROAD_VER"                        ; sudo mkdir -p $OPENROAD_HOME
OPENROAD_MODULE_FILE="$MODULE_FILE_DIR/openroad/$OPENROAD_VER"                  ; sudo mkdir -p $MODULE_FILE_DIR/openroad ; sudo touch $OPENROAD_MODULE_FILE

git checkout tags/$OPENROAD_VER
git submodule update --init --recursive

### Build and Install
$ROOT_ARG ./etc/DependencyInstaller.sh -all
mkdir build && cd build
$ROOT_ARG cmake .. -DCMAKE_INSTALL_PREFIX=$OPENROAD_HOME
make -j$(nproc)
$ROOT_ARG make install

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                                  >> $OPENROAD_MODULE_FILE"
$ROOT_ARG sh -c "echo 'setenv OPENROAD_HOME $OPENROAD_HOME'                          >> $OPENROAD_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(OPENROAD_HOME)/bin'                   >> $OPENROAD_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(OPENROAD_HOME)/lib'        >> $OPENROAD_MODULE_FILE"
#########################################################################
#                            Install klayout                            #
#########################################################################
cd ~ ; git clone https://github.com/KLayout/klayout.git ; cd klayout

KLAYOUT_VER=$(git describe --tags --abbrev=0)
KLAYOUT_HOME="$INSTALLATION_DIR/klayout/$KLAYOUT_VER"                           ; sudo mkdir -p $KLAYOUT_HOME
KLAYOUT_MODULE_FILE="$MODULE_FILE_DIR/klayout/$KLAYOUT_VER"                     ; sudo mkdir -p $MODULE_FILE_DIR/klayout ; sudo touch $KLAYOUT_MODULE_FILE

git checkout tags/$KLAYOUT_VER
git submodule update --init --recursive

### Build and Install
$ROOT_ARG mkdir -p $KLAYOUT_HOME/bin
mkdir build 
$ROOT_ARG ./build.sh -build ./build -bin $KLAYOUT_HOME/bin -option "-j$(nproc)" -noruby

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                                  >> $KLAYOUT_MODULE_FILE"
$ROOT_ARG sh -c "echo 'setenv KLAYOUT_HOME $KLAYOUT_HOME'                            >> $KLAYOUT_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(KLAYOUT_HOME)/bin'                    >> $KLAYOUT_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(KLAYOUT_HOME)/lib'         >> $KLAYOUT_MODULE_FILE"
#########################################################################
#                         Install Verilator                             #
#########################################################################
cd ~ ; git clone https://github.com/verilator/verilator ; cd verilator ; unset VERILATOR_ROOT 

VERILATOR_VER=$(git describe --tags --abbrev=0)
VERILATOR_HOME="$INSTALLATION_DIR/verilator/$VERILATOR_VER"                     ; sudo mkdir -p $VERILATOR_HOME
VERILATOR_MODULE_FILE="$MODULE_FILE_DIR/verilator/$VERILATOR_VER"               ; sudo mkdir -p $MODULE_FILE_DIR/verilator ; sudo touch $VERILATOR_MODULE_FILE

git checkout tags/$VERILATOR_VER
git submodule update --init --recursive

### Build and Install
autoconf
./configure --prefix $VERILATOR_HOME
make -j `nproc`
$ROOT_ARG make install

### create module according to tool version
$ROOT_ARG sh -c "echo '#%Module1.0'                                                  >> $VERILATOR_MODULE_FILE"
$ROOT_ARG sh -c "echo 'setenv VERILATOR_HOME $VERILATOR_HOME'                        >> $VERILATOR_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$env(VERILATOR_HOME)/bin'                  >> $VERILATOR_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(VERILATOR_HOME)/lib'       >> $VERILATOR_MODULE_FILE"
#########################################################################
#                           Install cocotb                              #
#########################################################################
#cd ~ ; git clone https://github.com/cocotb/cocotb.git ; cd cocotb

#COCOTB_VER=$(git describe --tags --abbrev=0)
COCOTB_VER="v1.9.2" # Latest version is beta version; using the stable one
COCOTB_HOME="$INSTALLATION_DIR/cocotb/$COCOTB_VER"                              ; sudo mkdir -p $COCOTB_HOME
COCOTB_MODULE_FILE="$MODULE_FILE_DIR/cocotb/$COCOTB_VER"                        ; sudo mkdir -p $MODULE_FILE_DIR/cocotb ; sudo touch $COCOTB_MODULE_FILE

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
$ROOT_ARG sh -c "echo '#%Module1.0'                                                  >> $COCOTB_MODULE_FILE"
$ROOT_ARG sh -c "echo 'setenv COCOTB_HOME $COCOTB_HOME'                              >> $COCOTB_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path PATH \$envCOCOTB_HOME/venv/bin'                  >> $COCOTB_MODULE_FILE"
$ROOT_ARG sh -c "echo 'prepend-path PYTHONPATH \$env(COCOTB_HOME)/venv/lib/$PYTHON_VER/site-packages' >> $COCOTB_MODULE_FILE"
$ROOT_ARG sh -c "echo 'conflict cocotb'                                              >> $COCOTB_MODULE_FILE"
#########################################################################
#                   Create Environment file to source                   #
#########################################################################
# source the env.sh to load all the modules
$ROOT_ARG sh -c "echo 'module load verilator/$VERILATOR_VER'                         >> env.sh"
$ROOT_ARG sh -c "echo 'module load yosys/$YOSYS_VER'                                 >> env.sh"
$ROOT_ARG sh -c "echo 'module load openroad/$OPENROAD_VER'                           >> env.sh"
$ROOT_ARG sh -c "echo 'module load klayout/$KLAYOUT_VER'                             >> env.sh"
$ROOT_ARG sh -c "echo 'module load cocotb/$COCOTB_VER'                               >> env.sh"
