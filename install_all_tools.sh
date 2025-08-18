#########################################################################
#                   define installation directory                       #
#########################################################################
INSTALLATION_DIR="/opt/tools"
MODULE_FILE_DIR="/opt/modulefiles"

sudo mkdir -p $INSTALLATION_DIR
sudo mkdir -p $MODULE_FILE_DIR

sudo sh -c 'echo "module use /opt/modulefiles" >> /etc/profile.d/modules.sh'
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
sudo make install PREFIX=$YOSYS_HOME

### create module according to tool version
sudo sh -c "echo '#%Module1.0'                                                  >> $YOSYS_MODULE_FILE"
sudo sh -c "echo 'setenv YOSYS_HOME $YOSYS_HOME'                                >> $YOSYS_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(YOSYS_HOME)/bin'                      >> $YOSYS_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(YOSYS_HOME)/lib'           >> $YOSYS_MODULE_FILE"
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
sudo ./etc/DependencyInstaller.sh -all
mkdir build && cd build
sudo cmake .. -DCMAKE_INSTALL_PREFIX=$OPENROAD_HOME
make -j$(nproc)
sudo make install

### create module according to tool version
sudo sh -c "echo '#%Module1.0'                                                  >> $OPENROAD_MODULE_FILE"
sudo sh -c "echo 'setenv OPENROAD_HOME $OPENROAD_HOME'                          >> $OPENROAD_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(OPENROAD_HOME)/bin'                   >> $OPENROAD_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(OPENROAD_HOME)/lib'        >> $OPENROAD_MODULE_FILE"
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
sudo mkdir -p $KLAYOUT_HOME/bin
mkdir build 
sudo ./build.sh -build ./build -bin $KLAYOUT_HOME/bin -option "-j$(nproc)" -noruby

### create module according to tool version
sudo sh -c "echo '#%Module1.0'                                                  >> $KLAYOUT_MODULE_FILE"
sudo sh -c "echo 'setenv KLAYOUT_HOME $KLAYOUT_HOME'                            >> $KLAYOUT_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(KLAYOUT_HOME)/bin'                    >> $KLAYOUT_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(KLAYOUT_HOME)/lib'         >> $KLAYOUT_MODULE_FILE"
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
sudo make install

### create module according to tool version
sudo sh -c "echo '#%Module1.0'                                                  >> $VERILATOR_MODULE_FILE"
sudo sh -c "echo 'setenv VERILATOR_HOME $VERILATOR_HOME'                        >> $VERILATOR_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(VERILATOR_HOME)/bin'                  >> $VERILATOR_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(VERILATOR_HOME)/lib'       >> $VERILATOR_MODULE_FILE"
#########################################################################
#                           Install cocotb                              #
#########################################################################
cd ~ ; git clone https://github.com/cocotb/cocotb.git ; cd cocotb

#COCOTB_VER=$(git describe --tags --abbrev=0)
COCOTB_VER="v1.9.2" # Latest version is beta version; using the stable one
#COCOTB_HOME="$INSTALLATION_DIR/cocotb/$COCOTB_VER"                              ; sudo mkdir -p $COCOTB_HOME
COCOTB_MODULE_FILE="$MODULE_FILE_DIR/cocotb/$COCOTB_VER"                        ; sudo mkdir -p $MODULE_FILE_DIR/cocotb ; sudo touch $COCOTB_MODULE_FILE

# cocotb will be installed pipx virtual env
PIPX_HOME="$INSTALLATION_DIR/pipx"
PIPX_VENV_DIR="$PIPX_HOME/venvs"
COCOTB_HOME="$PIPX_VENV_DIR/cocotb"
COCOTB_MODULE_FILE="$MODULE_FILE_DIR/cocotb/$COCOTB_VER"

# Create directories if they don't exist
sudo mkdir -p $PIPX_HOME $PIPX_VENV_DIR $PIPX_MODULE_DIR
sudo chown -R $USER:$USER $TOOLS_DIR

# Set environment for this session
export PIPX_HOME=$PIPX_HOME
export PIPX_VENV_DIR=$PIPX_VENV_DIR
export PATH=$PIPX_HOME/bin:$PATH

# Install Cocotb via pipx
pipx install cocotb==$COCOTB_VER

### create module according to tool version
sudo sh -c "echo '#%Module1.0'                                                  >> $COCOTB_MODULE_FILE"
sudo sh -c "echo 'setenv COCOTB_HOME $COCOTB_HOME'                              >> $COCOTB_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH $PIPX_HOME/bin'				>> $COCOTB_MODULE_FILE"
#sudo sh -c "echo 'prepend-path PATH \$env(COCOTB_HOME)/bin'                     >> $COCOTB_MODULE_FILE"
#sudo sh -c "echo 'prepend-path PYTHONPATH \$env(COCOTB_HOME)'                     >> $COCOTB_MODULE_FILE"
#sudo sh -c "prepend-path PYTHONPATH $env(COCOTB_HOME)/lib/python3.11/site-packages >> $COCOTB_MODULE_FILE"







