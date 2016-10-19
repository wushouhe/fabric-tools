#!/bin/bash

# Build out the Hyperledger Fabric environment for Linux on z Systems

# Global Variables
BUILD_HYPERLEDGER_CORE_ONLY=0
MACHINE_TYPE=""
OS_FLAVOR=""
ROCKSDB_VERSION="4.1"
USE_DOCKER_HUB=1

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
<path-of-script>/zSystemsFabricBuild.sh options

NOTE: Prerequisite packages are required to build and use RocksDB which may not
reside in your default package management repositories.  There is the possibility
that extra steps might be needed to add the additional repositories to your system.

The default action of the script -- without any arguments -- is
to build the following components:
    - Docker and supporting Hyperledger Fabric Docker images
    - Golang
    - RocksDB
    - Hyperledger Fabric core components -- Peer and Membership Services

     Options:
-b   Build the hyperledger/fabric-baseimage. If this option is not specifed,
     the default action is to pull the hyperledger/fabric-base image from Docker Hub.

-c   Rebuild the Hyperledger Fabric components.  A previous installation is
     required to use this option.

EOF
  exit 1
}

# Install prerequisite packages for an RHEL Hyperledger build
prereq_rhel() {
  echo -e "\nInstalling RHEL prerequisite packages\n"
  yum -y -q install git gcc gcc-c++ snappy-devel zlib-devel bzip2-devel git wget tar python-setuptools device-mapper
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to install pre-requisite packages.\n"
    exit 1
  fi
}

# Install prerequisite packages for an SLES Hyperledger build
prereq_sles() {
  echo -e "\nInstalling SLES prerequisite packages\n"
  zypper --non-interactive in git-core gcc make gcc-c++ patterns-sles-apparmor zlib zlib-devel libsnappy1 snappy-devel libbz2-1 libbz2-devel python-setuptools
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to install pre-requisite packages.\n"
    exit 1
  fi
}

# Install prerequisite packages for an Unbuntu Hyperledger build
prereq_ubuntu() {
  echo -e "\nInstalling Ubuntu prerequisite packages\n"
  apt-get update
  apt-get -y install build-essential git libsnappy-dev zlib1g-dev libbz2-dev debootstrap python-setuptools
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
  cd $HOME

  if [ $1 == 'rhel' ] || [ $1 == 'sles' ]; then
    wget -q https://storage.googleapis.com/golang/go1.7.1.linux-s390x.tar.gz
    tar -xf go1.7.1.linux-s390x.tar.gz
    cp -ra go /usr/local

    export CC=gcc
    export GOROOT=/usr/local/go
  else
    # Install Golang when running Ubuntu
    apt-get -y install golang-1.6-go
    export GOROOT=/usr/lib/go-1.6
  fi
  echo -e "*** DONE ***\n"
}

# Build and install the RocksDB database component
build_rocksdb() {
  echo -e "\n*** build_rocksdb ***\n"
  cd $HOME

  if [ -d $HOME/rocksdb ]; then
    rm -rf $HOME/rocksdb
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

# Build a base hyperledger/fabric-baseimage for RHEL
docker_base_image_rhel() {
  name="rhelbase"

  mkdir img || exit
  mkdir -m 755 img/dev
  mknod -m 600 img/dev/console c 5 1
  mknod -m 600 img/dev/initctl p
  mknod -m 666 img/dev/full c 1 7
  mknod -m 666 img/dev/null c 1 3
  mknod -m 666 img/dev/ptmx c 5 2
  mknod -m 666 img/dev/random c 1 8
  mknod -m 666 img/dev/tty c 5 0
  mknod -m 666 img/dev/tty0 c 4 0
  mknod -m 666 img/dev/urandom c 1 9
  mknod -m 666 img/dev/zero c 1 5

  test -d /etc/yum && yum --installroot=$PWD/img --releasever=/ --setopt=tsflags=nodocs \
  --setopt=group_package_types=mandatory -y install bash yum vim-minimal
  test -d /etc/yum && cp -a /etc/yum* /etc/rhsm/* /etc/pki/* img/etc/
  test -d /etc/yum && yum --installroot=$PWD/img clean all

  # in some cases the following line is needed. I still have not understood, why...
  # test -d /etc/zypp && mkdir img/etc && cp -a /etc/zypp* /etc/products.d img/etc/
  test -d /etc/zypp && zypper --root $PWD/img  -D /etc/zypp/repos.d/ \
  --no-gpg-checks -n install -l bash zypper vim
  test -d /etc/zypp && cp -a /etc/zypp* /etc/products.d img/etc/

  rm -fr img/usr/{{lib,share}/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive}
  rm -fr img/usr/share/{man,doc,info,gnome/help}
  rm -fr img/usr/share/cracklib
  rm -fr img/usr/share/i18n
  rm -fr img/etc/ld.so.cache
  rm -fr img/var/cache/ldconfig/*

  version=`grep "VERSION_ID=" img/etc/os-release | sed 's/\"//g' | awk -F= '{print $2}'`

  if [ -z "$version" ]; then
      echo >&2 "warning: cannot autodetect OS version, using '$name' as tag"
      version=$name
  fi

  # Create base SLES Docker image
  tar --numeric-owner -c -C img . | docker import - $name:$version
  docker run -i -t --rm $name:$version /bin/bash -c 'echo success'
  rm -rf img

  # Create Dockerfile for creating the hyperledger/fabric-baseimage Docker image
  cd $HOME
  cat > Dockerfile <<EOF
FROM rhelbase:$version
RUN yum -y install gcc gcc-c++ make git snappy-devel zlib-devel bzip2-devel
# Install Golang
COPY go /usr/local/go
ENV GOROOT=/usr/local/go
# Install RocksDB
COPY rocksdb /tmp/rocksdb
WORKDIR /tmp/rocksdb
RUN INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
ENV GOPATH=/opt/gopath
ENV PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH
EOF

  # Build hyperledger/fabric-baseimage
  docker build -t hyperledger/fabric-baseimage -f $HOME/Dockerfile $HOME
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to build the Docker image: hyperledger/fabric-baseimage.\n"
    exit 1
  fi
}

# Build a base hyperledger/fabric-baseimage for SLES
docker_base_image_sles() {
  name="slesbase"

  mkdir img || exit
  mkdir -m 755 img/dev
  mknod -m 600 img/dev/console c 5 1
  mknod -m 600 img/dev/initctl p
  mknod -m 666 img/dev/full c 1 7
  mknod -m 666 img/dev/null c 1 3
  mknod -m 666 img/dev/ptmx c 5 2
  mknod -m 666 img/dev/random c 1 8
  mknod -m 666 img/dev/tty c 5 0
  mknod -m 666 img/dev/tty0 c 4 0
  mknod -m 666 img/dev/urandom c 1 9
  mknod -m 666 img/dev/zero c 1 5

  test -d /etc/yum && yum --installroot=$PWD/img --releasever=/ --setopt=tsflags=nodocs \
  --setopt=group_package_types=mandatory -y install bash yum vim-minimal
  test -d /etc/yum && cp -a /etc/yum* /etc/rhsm/* /etc/pki/* img/etc/
  test -d /etc/yum && yum --installroot=$PWD/img clean all

  # in some cases the following line is needed. I still have not understood, why...
  test -d /etc/zypp && mkdir img/etc && cp -a /etc/zypp* /etc/products.d img/etc/
  test -d /etc/zypp && zypper --root $PWD/img  -D /etc/zypp/repos.d/ \
  --no-gpg-checks -n install -l bash zypper vim
  test -d /etc/zypp && cp -a /etc/zypp* /etc/products.d img/etc/

  rm -fr img/usr/{{lib,share}/locale,{lib,lib64}/gconv,bin/localedef,sbin/build-locale-archive}
  rm -fr img/usr/share/{man,doc,info,gnome/help}
  rm -fr img/usr/share/cracklib
  rm -fr img/usr/share/i18n
  rm -fr img/etc/ld.so.cache
  rm -fr img/var/cache/ldconfig/*

  version=`grep "VERSION_ID=" img/etc/os-release | sed 's/\"//g' | awk -F= '{print $2}'`

  if [ -z "$version" ]; then
    echo >&2 "warning: cannot autodetect OS version, using '$name' as tag"
    version=$name
  fi

  # Create base SLES Docker image
  tar --numeric-owner -c -C img . | docker import - $name:$version
  docker run -i -t --rm $name:$version /bin/bash -c 'echo success'
  rm -rf img

  # Create Dockerfile for creating the hyperledger/fabric-baseimage Docker image
  cd $HOME
  cat > Dockerfile <<EOF
FROM slesbase:$version
RUN zypper --non-interactive --no-gpg-check in gcc gcc-c++ make git-core zlib zlib-devel libsnappy1 snappy-devel libbz2-1 libbz2-devel
# Install Golang
COPY go /usr/local/go
ENV GOROOT=/usr/local/go
# Install RocksDB
COPY rocksdb /tmp/rocksdb
WORKDIR /tmp/rocksdb
RUN INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
ENV GOPATH=/opt/gopath
ENV PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH
EOF

  # Build hyperledger/fabric-baseimage
  docker build -t hyperledger/fabric-baseimage -f $HOME/Dockerfile $HOME
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to build the Docker image: hyperledger/fabric-baseimage.\n"
    exit 1
  fi
}

docker_base_image_ubuntu() {
  cd $HOME
  debootstrap xenial ubuntu-base > /dev/null
  cp /etc/apt/sources.list $HOME/ubuntu-base/etc/apt/
  tar -C ubuntu-base -c . | docker import - ubuntu-base

  # Create Dockerfile for creating the hyperledger/fabric-baseimage Docker image
  cd $HOME
  cat > Dockerfile <<EOF
FROM ubuntu-base:latest
RUN apt-get update
RUN apt-get -y install build-essential git golang-1.6-go gcc g++ make libbz2-dev zlib1g-dev libsnappy-dev libgflags-dev
ENV GOROOT=/usr/lib/go-1.6
# Install RocksDB
COPY rocksdb /tmp/rocksdb
WORKDIR /tmp/rocksdb
RUN INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
ENV GOPATH=/opt/gopath
ENV PATH=\$GOPATH/bin:\$GOROOT/bin:\$PATH
EOF

  # Build hyperledger/fabric-baseimage
  docker build -t hyperledger/fabric-baseimage -f $HOME/Dockerfile $HOME
  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to build the Docker image: hyperledger/fabric-baseimage.\n"
    exit 1
  fi
}

# Build and install the Docker Daemon
build_docker() {
  echo -e "\n*** build_docker ***\n"

  # Setup Docker for RHEL or SLES
  if [ $1 == "rhel" ] || [ $1 == "sles" ]; then
    case $1 in
      rhel)
        DOCKER_URL="ftp://ftp.unicamp.br/pub/linuxpatch/s390x/redhat/rhel7.2/docker-1.10.1-rhel7.2-20160408.tar.gz"
        DOCKER_DIR="docker-1.10.1-rhel7.2-20160408"
        ;;
      sles)
        DOCKER_URL="ftp://ftp.unicamp.br/pub/linuxpatch/s390x/suse/sles12/docker/docker-1.9.1-sles12-20151127.tar.gz"
        DOCKER_DIR="docker-1.9.1-sles12-20151127"
       ;;
    esac

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
    cp $DOCKER_DIR/docker /usr/bin

    # Setup Docker Daemon service
    if [ ! -d /etc/docker ]; then
      mkdir -p /etc/docker
    fi

    # Create environment file for the Docker service
    touch /etc/docker/docker.conf
    chmod 664 /etc/docker/docker.conf
    echo 'DOCKER_OPTS="-H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock"' >> /etc/docker/docker.conf
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
    systemctl start docker.service

    rm -rf /tmp/$DOCKER_DIR*

  else      # Setup Docker for Ubuntu
    apt-get -y install docker.io=1.10.3-0ubuntu6
    systemctl stop docker.service
    sed -i "\$aDOCKER_OPTS=\"-H tcp://0.0.0.0:2375\"" /etc/default/docker
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
  # git clone http://gerrit.hyperledger.org/r/fabric.git
  # git clone https://github.com/hyperledger/fabric.git
  git clone https://github.com/hyperledger-archives/fabric

  # Build the Hyperledger Fabric core components
  if [ $USE_DOCKER_HUB -eq 0 ] || [ $OS_FLAVOR == "sles" ]; then
    docker_base_image_$1
    # Update the Makefile to allow make to run for
    # installations that created their own Docker base images.
    sed -i "/docker\.sh/d" $GOPATH/src/github.com/hyperledger/fabric/Makefile
  fi
  cd $GOPATH/src/github.com/hyperledger/fabric
  make peer membersrvc peer-image membersrvc-image

  if [ $? != 0 ]; then
    echo -e "\nERROR: Unable to build the Hyperledger Fabric components.\n"
    exit 1
  fi

  echo -e "*** DONE ***\n"
}

# Install Behave and its pre-requisites.  Firewall rules are also set.
setup_behave() {
  echo -e "\n*** setup_behave ***\n"
  # Setup Firewall Rules if they don't already exist
  grep -q '2375' <<< `iptables -L INPUT -nv`
  if [ $? != 0 ]; then
    iptables -I INPUT 1 -p tcp --dport 30303 -j ACCEPT
    iptables -I INPUT 1 -p tcp --dport 50051 -j ACCEPT
    iptables -I INPUT 1 -p tcp --dport 5000 -j ACCEPT
    iptables -I INPUT 1 -i docker0 -p tcp --dport 2375 -j ACCEPT
  fi

  # Install Behave Tests Pre-Reqs
  cd $HOME
  curl -s "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
  python get-pip.py > /dev/null 2>&1
  pip install -q --upgrade pip > /dev/null 2>&1
  pip install -q behave nose docker-compose > /dev/null 2>&1
  pip install -q -I flask==0.10.1 python-dateutil==2.2 pytz==2014.3 pyyaml==3.10 couchdb==1.0 flask-cors==2.0.1 requests==2.4.3 > /dev/null 2>&1

  echo -e "*** DONE ***\n"
}

# Update profile with environment variables required for Hyperledger Fabric use
# Also, clean up work directories and files
post_build() {
  echo -e "\n*** post_build ***\n"

cat <<EOF >/etc/profile.d/goroot.sh
export GOROOT=$GOROOT
export GOPATH=$GOPATH
export PATH=\$PATH:$GOROOT/bin:$GOPATH/bin
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
  rm -f $HOME/copygo.sh
  rm -f $HOME/get-pip.py
  rm -f $HOME/go1.7.1.linux-s390x.tar.gz

  echo -e "Cleanup Docker artifacts\n"
  # Delete any temporary Docker containers created during the build process
  if [[ ! -z $(docker ps -aq) ]]; then
      docker rm -f $(docker ps -aq)
  fi

  # Delete the temporary Docker image created during the build process
  docker images | grep "brunswick"
  if [ $?  == 0 ]; then
      docker rmi brunswickheads/openchain-peer
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

# Process script arguments
while getopts ":bc" opt; do
  case $opt in
    b)
      USE_DOCKER_HUB=0
      ;;
    c)
      BUILD_HYPERLEDGER_CORE_ONLY=1
      ;;
  \?)
    echo "Invalid option: -$OPTARG" >&2
    exit 1
    ;;
  *)
    usage
    ;;
 esac
done

# Determine s390x environment
get_linux_flavor      # Determine Linux distribution
get_machine_type      # Determine IBM z Systems machine type

# Main build routines
if [ $BUILD_HYPERLEDGER_CORE_ONLY -eq 1 ]; then
  if [ -f /usr/bin/docker ] && [ -f /usr/lib/librocksdb.so.${ROCKSDB_VERSION} ] && [[ -f /usr/local/go/bin/go || -f /usr/lib/go-1.6/bin/go ]]; then
    # Install pre-reqs for detected Linux OS Distribution
    prereq_$OS_FLAVOR
    if [ $? != 0 ]; then
      echo -e "\nERROR: Unable to install pre-requisite packages.\n"
      exit 1
    fi
    build_hyperledger_core $OS_FLAVOR
    exit 0
  else
    echo -e "\nThe Hyperledger core cannot be built.\nDocker, RocksDB, and Go must be installed prior to building the Hyperledger core components.\n"
    exit 1
  fi
fi

# Install pre-reqs for detected Linux OS Distribution
prereq_$OS_FLAVOR

# Default action is to build all components for the Hyperledger Fabric environment
build_docker $OS_FLAVOR
build_golang $OS_FLAVOR
build_rocksdb
build_hyperledger_core $OS_FLAVOR
setup_behave
post_build

echo -e "\n\nThe Hyperledger Fabric and its supporting components have been successfully installed.\n"
exit 0
