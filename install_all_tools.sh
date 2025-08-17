
sudo mkdir -p /opt/tools
sudo mkdir -p /opt/modulefiles
sudo sh -c 'echo "module use /opt/modulefiles" >> /etc/profile.d/modules.sh'

#sudo apt install ssh
#ssh-keygen -t rsa

INSTALLATION_DIR="/opt/tools"

#########################################################################
#     			  Install yosys					#
#########################################################################
YOSYS_HOME="$INSTALLATION_DIR/yosys"
cd ~ 
git clone https://github.com/YosysHQ/yosys.git
cd yosys
git submodule update --init --recursive
make -j$(nproc)
sudo make install PREFIX=$YOSYS_HOME

# create module according to yosys version
YOSYS_VER=$($YOSYS_HOME/bin/yosys -V | awk '{print $2}'  | awk -F'+' '{print $1}')
YOSYS_MODULE_FILE="/opt/modulefiles/yosys/$YOSYS_VER"
sudo mkdir -p /opt/modulefiles/yosys

sudo touch $YOSYS_MODULE_FILE
sudo sh -c "echo '#%Module1.0' 						>> $YOSYS_MODULE_FILE"
sudo sh -c "echo 'setenv YOSYS_HOME /opt/tools/yosys' 			>> $YOSYS_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(YOSYS_HOME)/bin' 		>> $YOSYS_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(YOSYS_HOME)/lib' 	>> $YOSYS_MODULE_FILE"
#########################################################################
#     			  Install OpenROAD				#
#########################################################################
cd ~
git clone https://github.com/The-OpenROAD-Project/OpenROAD.git
cd OpenROAD
git submodule update --init --recursive
sudo ./etc/DependencyInstaller.sh -all

OPENROAD_HOME="/opt/tools/openroad"
sudo mkdir -p $OPENROAD_HOME 
mkdir build && cd build
sudo cmake .. -DCMAKE_INSTALL_PREFIX=$OPENROAD_HOME
make -j$(nproc)
sudo make install

OPENROAD_VER=$($OPENROAD_HOME/bin/openroad -version | awk -F'-' '{print $1}' | awk -F'v' '{print $2}')
OPENROAD_MODULE_FILE="/opt/modulefiles/openroad/$OPENROAD_VER"

sudo mkdir -p /opt/modulefiles/openroad
sudo touch $OPENROAD_MODULE_FILE
sudo sh -c "echo '#%Module1.0' 							>> $OPENROAD_MODULE_FILE"
sudo sh -c "echo 'setenv OPENROAD_HOME /opt/tools/openroad' 			>> $OPENROAD_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(OPENROAD_HOME)/bin' 			>> $OPENROAD_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(OPENROAD_HOME)/lib' 	>> $OPENROAD_MODULE_FILE"

#########################################################################
#     			  Install klayout				#
#########################################################################
cd ~
KLAYOUT_VER=$(git ls-remote --tags https://github.com/KLayout/klayout.git | awk -F/ '{print $3}' | grep -E '^v[0-9]+' | sort -V | tail -1)
git clone https://github.com/KLayout/klayout.git
git checkout $KLAYOUT_VER
cd klayout

KLAYOUT_HOME="/opt/tools/klayout"
sudo mkdir -p $KLAYOUT_HOME
sudo mkdir -p $KLAYOUT_HOME/bin
mkdir build 
sudo ./build.sh -build ./build -bin $KLAYOUT_HOME/bin -option "-j$(nproc)" -noruby

KLAYOUT_VER=$($KLAYOUT_HOME/klayout -v | awk '{print $2}')
KLAYOUT_MODULE_FILE="/opt/modulefiles/klayout/$KLAYOUT_VER"

sudo mkdir -p /opt/modulefiles/klayout
sudo touch $KLAYOUT_MODULE_FILE
sudo sh -c "echo '#%Module1.0' 							>> $KLAYOUT_MODULE_FILE"
sudo sh -c "echo 'setenv KLAYOUT_HOME /opt/tools/klayout' 			>> $KLAYOUT_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(KLAYOUT_HOME)/bin' 			>> $KLAYOUT_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(KLAYOUT_HOME)/lib' 	>> $KLAYOUT_MODULE_FILE"
#########################################################################
#     			  Install Verilator				#
#########################################################################
cd ~
git clone https://github.com/verilator/verilator   # Only first time
unset VERILATOR_ROOT  # For bash
cd verilator
git checkout stable      # Use most recent stable release

VERILATOR_HOME="/opt/tools/verilator"
autoconf         			  # Create ./configure script
./configure --prefix $VERILATOR_HOME      # Configure and create Makefile
make -j `nproc`  			  # Build Verilator itself (if error, try just 'make')
sudo make install

VERILATOR_VER=$(/opt/tools/verilator/bin/verilator -version | awk '{print $2}')
VERILATOR_MODULE_FILE="/opt/modulefiles/verilator/$VERILATOR_VER"

sudo mkdir -p /opt/modulefiles/verilator
sudo touch $VERILATOR_MODULE_FILE
sudo sh -c "echo '#%Module1.0' 							>> $VERILATOR_MODULE_FILE"
sudo sh -c "echo 'setenv VERILATOR_HOME /opt/tools/verilator' 			>> $VERILATOR_MODULE_FILE"
sudo sh -c "echo 'prepend-path PATH \$env(VERILATOR_HOME)/bin' 			>> $VERILATOR_MODULE_FILE"
sudo sh -c "echo 'prepend-path LD_LIBRARY_PATH \$env(VERILATOR_HOME)/lib' 	>> $VERILATOR_MODULE_FILE"
#########################################################################
#     			  Install cocotb				#
#########################################################################


