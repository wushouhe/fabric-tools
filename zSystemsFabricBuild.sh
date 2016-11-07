#!/bin/bash

# Build out the Hyperledger Fabric environment for Linux on z Systems

# Global Variables
MACHINE_TYPE=""
OS_FLAVOR=""
ROCKSDB_VERSION="4.1"

usage() {
  cat << EOF

Usage:  `basename $0` options

This script installs and configures a Hyperledger Fabric environment on a Linux on
IBM z Systems instance.  The execution of this script assumes that you are starting
from a new Linux on z Systems instance.  The script will autodetect the Linux
distribution (currently RHEL, SLES, and Ubuntu) as well as the z Systems machine
type, and build out the necessary components.  After running this script, logout and
then login to pick up updates to Hyperledger Fabric specific environment variables.

To run the script:
sudo su -  (if you currently are not root)
<path-of-script>/zSystemsFabricBuild.sh

NOTE: Prerequisite packages are required to build and use RocksDB which may not
reside in your default package management repositories.  There is the possibility
that extra steps might be needed to add the additional repositories to your system.

The default action of the script -- without any arguments -- is
to build the following components:
    - Docker and supporting Hyperledger Fabric Docker images
    - Golang
    - RocksDB
    - IBM Java 1.8
    - Nodejs 6.7.0
    - Hyperledger Fabric core components -- Peer and Membership Services

EOF
  exit 1
}

# Install prerequisite packages for an RHEL Hyperledger build
prereq_rhel() {
  echo -e "\nInstalling RHEL prerequisite packages\n"
  yum -y -q install git gcc gcc-c++ snappy-devel zlib-devel bzip2-devel git wget tar python-setuptools python-devel device-mapper
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to install pre-requisite packages.\n"
    exit 1
  fi
}

# Install prerequisite packages for an SLES Hyperledger build
prereq_sles() {
  echo -e "\nInstalling SLES prerequisite packages\n"
  zypper --non-interactive in git-core gcc make gcc-c++ patterns-sles-apparmor zlib zlib-devel libsnappy1 snappy-devel libbz2-1 libbz2-devel python-setuptools python-devel
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to install pre-requisite packages.\n"
    exit 1
  fi
}

# Install prerequisite packages for an Unbuntu Hyperledger build
prereq_ubuntu() {
  echo -e "\nInstalling Ubuntu prerequisite packages\n"
  apt-get update
  apt-get -y install build-essential git libsnappy-dev zlib1g-dev libbz2-dev debootstrap python-setuptools python-dev alien
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to install pre-requisite packages.\n"
    exit 1
  fi
}

# Determine flavor of Linux OS
get_linux_flavor() {
  OS_FLAVOR=`cat /etc/os-release | grep ^NAME | sed -r 's/.*"(.*)"/\1/'`

  if grep -iq 'red' <<< $OS_FLAVOR; then
    OS_FLAVOR="rhel"
  elif grep -iq 'sles' <<< $OS_FLAVOR; then
    OS_FLAVOR="sles"
  elif grep -iq 'ubuntu' <<< $OS_FLAVOR; then
    OS_FLAVOR="ubuntu"
  else
    echo -e "\nERROR: Unsupported Linux Operating System.\n"
    exit 1
  fi
}

# Extract z Systems machine type for compiling RocksDB
get_machine_type() {
  if [ $(uname -m) == "s390x" ]; then
    MACHINE_TYPE=`cat /proc/cpuinfo | grep -i -m 1 'machine' | awk -F "= " '{print $4}'`
    case $MACHINE_TYPE in
      2817)
      MACHINE_TYPE="z196"
      ;;
      2818)
      MACHINE_TYPE="z196"
      ;;
      2827)
      MACHINE_TYPE="zEC12"
      ;;
      2828)
      MACHINE_TYPE="zEC12"
      ;;
      2964)
      if [ $OS_FLAVOR == 'ubuntu' ]; then
        MACHINE_TYPE="z13"
      else
        MACHINE_TYPE="zEC12"
      fi
      ;;
      2965)
      if [ $OS_FLAVOR == 'ubuntu' ]; then
        MACHINE_TYPE="z13"
      else
        MACHINE_TYPE="zEC12"
      fi
      ;;
      *)
      echo -e "\nERROR: Unknown machine architecture.\n"
      exit 1
    esac
  else
    echo -e '\nERROR: Incorrect platform.  This script can only run on the s390x platform.\n'
    exit 1
  fi
}

# Install the Golang compiler for the s390x platform
build_golang() {
  echo -e "\n*** build_golang ***\n"
  cd /tmp
  wget --quiet --no-check-certificate https://storage.googleapis.com/golang/go1.7.1.linux-s390x.tar.gz
  tar -xvf go1.7.1.linux-s390x.tar.gz
  cd /opt
  git clone http://github.com/linux-on-ibm-z/go.git go
  cd go/src
  git checkout release-branch.go1.6-p256
  export GOROOT_BOOTSTRAP=/tmp/go
  ./make.bash
  export GOROOT="/opt/go"
  echo -e "*** DONE ***\n"
}

# Build and install the RocksDB database component
build_rocksdb() {
  echo -e "\n*** build_rocksdb ***\n"
  cd /tmp

  if [ -d /tmp/rocksdb ]; then
    rm -rf /tmp/rocksdb
  fi

  git clone --branch v${ROCKSDB_VERSION} --single-branch --depth 1 https://github.com/facebook/rocksdb.git
  cd  rocksdb
  sed -i "s/-march=native/-march=$MACHINE_TYPE/" build_tools/build_detect_platform
  sed -i "s/-momit-leaf-frame-pointer/-DDUMBDUMMY/" Makefile
  make shared_lib && INSTALL_PATH=/usr make install-shared && ldconfig
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to build the RocksDB shared library.\n"
    exit 1
  fi
  echo -e "*** DONE ***\n"
}

# Build and install the Docker Daemon
install_docker() {
  echo -e "\n*** install_docker ***\n"

  # Setup Docker for RHEL or SLES
  if [ $1 == "rhel" ]; then
    DOCKER_URL="ftp://ftp.unicamp.br/pub/linuxpatch/s390x/redhat/rhel7.2/docker-1.11.2-rhel7.2-20160623.tar.gz"
    DOCKER_DIR="docker-1.11.2-rhel7.2-20160623"

    # Install Docker
    cd /tmp
    wget -q $DOCKER_URL
    if [ $? != 0 ]; then
      echo -e "\nERROR: Unable to download the Docker binary tarball.\n"
      exit 1
    fi
    tar -xzf $DOCKER_DIR.tar.gz
    if [ -f /usr/bin/docker ]; then
      mv /usr/bin/docker /usr/bin/docker.orig
    fi
    cp $DOCKER_DIR/docker* /usr/bin

    # Setup Docker Daemon service
    if [ ! -d /etc/docker ]; then
      mkdir -p /etc/docker
    fi

    # Create environment file for the Docker service
    touch /etc/docker/docker.conf
    chmod 664 /etc/docker/docker.conf
    echo 'DOCKER_OPTS="-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock -s overlay"' >> /etc/docker/docker.conf
    touch /etc/systemd/system/docker.service
    chmod 664 /etc/systemd/system/docker.service

    # Create Docker service file
    cat > /etc/systemd/system/docker.service <<EOF
[Unit]
Description=Docker Application Container Engine
Documentation=https://docs.docker.com

[Service]
Type=notify
ExecStart=/usr/bin/docker daemon \$DOCKER_OPTS
EnvironmentFile=-/etc/docker/docker.conf

[Install]
WantedBy=default.target
EOF
    # Start Docker Daemon
    systemctl daemon-reload
    systemctl enable docker.service
    systemctl start docker.service
  elif [ $1 == "sles" ]; then
    zypper --non-interactive in docker
    systemctl stop docker.service
    sed '/^DOCKER_OPTS/ s/\"$/ \-H tcp\:\/\/0\.0\.0\.0\:2375\"/' /etc/sysconfig/docker
    systemctl enable docker.service
    systemctl start docker.service
  else      # Setup Docker for Ubuntu
    apt-get -y install docker.io
    systemctl stop docker.service
    sed -i "\$aDOCKER_OPTS=\"-H tcp://0.0.0.0:2375\"" /etc/default/docker
    systemctl enable docker.service
    systemctl start docker.service
  fi

  echo -e "*** DONE ***\n"
}

# Build the Hyperledger Fabric peer and membership services components
build_hyperledger_core() {
  echo -e "\n*** build_hyperledger_core ***\n"
  # Setup Environment Variables
  export GOPATH=$HOME
  export CGO_LDFLAGS="-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy"
  export CGO_CFLAGS=" "
  export PATH=$GOROOT/bin:$PATH

  # Download latest Hyperledger Fabric codebase
  if [ ! -d $HOME/src/github.com/hyperledger ]; then
    mkdir -p $HOME/src/github.com/hyperledger
  fi
  cd $HOME/src/github.com/hyperledger
  # Delete fabric directory, if it exists
  rm -rf fabric
  git clone -b debian_s390x_v0.6 https://github.com/vpaprots/fabric.git

  # Pull down docker fabric-baseimage to reduce build time
  docker pull hyperledger/fabric-baseimage:s390x-0.2.1
  docker tag hyperledger/fabric-baseimage:s390x-0.2.1 hyperledger/fabric-baseimage:s390x-0.0.11
  docker rmi hyperledger/fabric-baseimage:s390x-0.2.1

  cd $GOPATH/src/github.com/hyperledger/fabric
  git rm -rf core/chaincode/platforms/java/test
  git -c user.email="name@email.com" -c user.name="Name" commit -am 'Remove test'
  mkdir -p build/image/javaenv && touch build/image/javaenv/.dummy
  make peer membersrvc peer-image membersrvc-image

  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to build the Hyperledger Fabric components.\n"
    exit 1
  fi

  echo -e "*** DONE ***\n"
}

# Install IBM Java 1.8
install_java() {
  echo -e "\n*** install_java ***\n"
  JAVA_VERSION=1.8.0_sr3fp12
  ESUM_s390x="46766ac01bc2b7d2f3814b6b1561e2d06c7d92862192b313af6e2f77ce86d849"
  ESUM_ppc64le="6fb86f2188562a56d4f5621a272e2cab1ec3d61a13b80dec9dc958e9568d9892"
  eval ESUM=\$ESUM_s390x
  BASE_URL="https://public.dhe.ibm.com/ibmdl/export/pub/systems/cloud/runtimes/java/meta/"
  YML_FILE="sdk/linux/s390x/index.yml"
  wget -q -U UA_IBM_JAVA_Docker -O /tmp/index.yml $BASE_URL/$YML_FILE
  JAVA_URL=$(cat /tmp/index.yml | sed -n '/'$JAVA_VERSION'/{n;p}' | sed -n 's/\s*uri:\s//p' | tr -d '\r')
  wget -q -U UA_IBM_JAVA_Docker -O /tmp/ibm-java.bin $JAVA_URL
  echo "$ESUM  /tmp/ibm-java.bin" | sha256sum -c -
  if [ $? != 0 ]; then
    echo -e "\nERROR: Java image digests do not match.\n Unable to build the Hyperledger Fabric components.\n"
    exit 1
  fi
  echo "INSTALLER_UI=silent" > /tmp/response.properties
  echo "USER_INSTALL_DIR=/opt/ibm/java" >> /tmp/response.properties
  echo "LICENSE_ACCEPTED=TRUE" >> /tmp/response.properties
  mkdir -p /opt/ibm
  chmod +x /tmp/ibm-java.bin
  /tmp/ibm-java.bin -i silent -f /tmp/response.properties
  ln -s /opt/ibm/java/jre/bin/* /usr/local/bin/
  echo -e "*** DONE ***\n"
}

# Install Nodejs
install_nodejs() {
  echo -e "\n*** install_nodejs ***\n"
  cd /tmp
  wget -q https://nodejs.org/dist/v6.7.0/node-v6.7.0-linux-s390x.tar.gz
  cd /usr/local && tar --strip-components 1 -xzf /tmp/node-v6.7.0-linux-s390x.tar.gz
  echo -e "*** DONE ***\n"
}

# Install Behave and its pre-requisites.  Firewall rules are also set.
setup_behave() {
  echo -e "\n*** setup_behave ***\n"
  # Setup Firewall Rules if they don't already exist
  grep -q '2375' <<< `iptables -L INPUT -nv`
  if [ $? != 0 ]; then
    iptables -I INPUT 1 -p tcp --dport 7050 -j ACCEPT
    iptables -I INPUT 1 -p tcp --dport 7051 -j ACCEPT
    iptables -I INPUT 1 -p tcp --dport 7053 -j ACCEPT
    iptables -I INPUT 1 -p tcp --dport 7054 -j ACCEPT
    iptables -I INPUT 1 -i docker0 -p tcp --dport 2375 -j ACCEPT
  fi

  # Install Behave Tests Pre-Reqs
  cd /tmp
  curl -s "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
  python get-pip.py > /dev/null 2>&1
  pip install -q --upgrade pip > /dev/null 2>&1
  pip install -q behave nose docker-compose > /dev/null 2>&1
  pip install -q -I flask==0.10.1 python-dateutil==2.2 pytz==2014.3 pyyaml==3.10 couchdb==1.0 flask-cors==2.0.1 requests==2.4.3 > /dev/null 2>&1

  # Install grpcio package for unit tests
  wget http://download.sinenomine.net/OSS/7/s390x/grpcio-1.0.0-1.cl7.s390x.rpm
  if [ $OS_FLAVOR == 'rhel' ]; then
    yum -y localinstall grpcio-1.0.0-1.cl7.s390x.rpm
  elif [ $OS_FLAVOR == 'sles' ]; then
    zypper --non-interactive --no-gpg-checks install grpcio-1.0.0-1.cl7.s390x.rpm
  else
    alien -i grpcio-1.0.0-1.cl7.s390x.rpm
  fi
  echo -e "*** DONE ***\n"
}

# Update profile with environment variables required for Hyperledger Fabric use
# Also, clean up work directories and files
post_build() {
  echo -e "\n*** post_build ***\n"

cat <<EOF >/etc/profile.d/goroot.sh
export GOROOT=$GOROOT
export GOPATH=$GOPATH
export PATH=\$PATH:$GOROOT/bin:$GOPATH/bin:/usr/local/bin
EOF

cat <<EOF >>/etc/environment
GOROOT=$GOROOT
GOPATH=$GOPATH
EOF

  if [ $OS_FLAVOR == "rhel" ] || [ $OS_FLAVOR == "sles" ]; then
cat <<EOF >>/etc/environment
CC=gcc
EOF
  fi

  # Add non-root user to docker group
  BC_USER=`who am i | awk '{print $1}'`
  if [ $BC_USER != "root" ]; then
    usermod -aG docker $BC_USER
  fi

  # Cleanup files and Docker images and containers
  rm -rf /tmp/*

  echo -e "Cleanup Docker artifacts\n"
  # Delete any temporary Docker containers created during the build process
  if [[ ! -z $(docker ps -aq) ]]; then
      docker rm -f $(docker ps -aq)
  fi

  echo -e "*** DONE ***\n"
}

################
# Main Routine #
################

# Check for help flags
if [ $# == 1 ] && ([[ $1 == "-h"  ||  $1 == "--help" || $1 == "-?" || $1 == "?" || -z $(grep "-" <<< $1) ]]); then
  usage
fi

# Ensure that the user running this script is root.
if [ xroot != x$(whoami) ]; then
  echo -e "\nERROR: You must be root to run this script.\n"
  exit 1
fi

# Determine s390x environment
get_linux_flavor      # Determine Linux distribution
get_machine_type      # Determine IBM z Systems machine type

# Install pre-reqs for detected Linux OS Distribution
prereq_$OS_FLAVOR

# Default action is to build all components for the Hyperledger Fabric environment
install_java
install_nodejs
install_docker $OS_FLAVOR
build_golang $OS_FLAVOR
build_rocksdb
build_hyperledger_core $OS_FLAVOR
setup_behave
post_build

echo -e "\n\nThe Hyperledger Fabric and its supporting components have been successfully installed.\n"
exit 0
