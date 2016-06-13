Hyperledger Fabric Build for Ubuntu on Linux on z Systems
=========================================================
This document describes the steps to build, configure and install the
infrastructure components associated with IBM’s Open Blockchain
technology, Hyperledger Fabric, on the Linux on z Systems platform.

More importantly, you will create the Docker artifacts using the base
Ubuntu system on which you will deploy. The base Docker image will be
Ubuntu based and have access to the same repositories as the
system on which you deploy. This eliminates the need to download any
pre-built Docker images from the public Docker repository, eliminating
one potential security exposure. The Docker images you create will be
kept in a repository that you create, thus remaining within your
control.

The major components include:
- [Golang programming language](#installing-golang)
- [Docker client and daemon](#docker-daemon--docker-registry)
- [Docker registry](#docker-daemon--docker-registry)
- [Hyperledger Fabric](#build-the-hyperledger-fabric-core)
  - Peer
  - Membership and Security Services

Once all of the major components are in place on the bulid system, custom Docker
images are created for the Golang programming language, Hyperledger Fabric Peer,
and Hyperledger Fabric Membership and Security Services. This allows for
a fully *dockerized* development or proof-of-concept Hyperledger Fabric
environment.

The procedures in this guide are tailored for Ubuntu. Due to the ongoing development activity within the Hyperledger project, there is a chance that portions of this document
may become obsolete or out of date.

For more information about the Hyperledger Fabric project, see
<https://github.com/hyperledger/fabric>.

> ***NOTE:***   
> The instructions contained in this document assume that you
> are using a non-root user with sudo authority and that the non-root
> user has been added to the **sudo** group. In addition, update the
> **/etc/sudoers** file to enable the **sudo** group with no password
> access, and append **/usr/local/bin** and the targeted directory that
> will contain the **go** executable, **/usr/lib/go-1.6/bin**, to the
> **secure_path** variable.

Installing Golang
=================
The Hyperledger Fabric and the Docker Registry are written using the
Golang programming language. Therefore, a Golang compiler needs to be
installed in order to compile the Hyperledger Fabric and Docker Registry
source code.

Ubuntu has packaged Go in 16.04 LTS (Xenial). Install it with the command:

```
    sudo apt-get -y install golang-1.6-go
    export PATH=$PATH:/usr/lib/go-1.6/bin
```

> ***NOTE:*** Also append **/usr/lib/go-1.6/bin** to the PATH environment variable
in your **.profile** file and root's **.profile** file for using the Golang toolchain.

Build and Install RocksDB
=========================
RocksDB is an embeddable persistent key-value store for fast storage and
is used by the Hyperledger Fabric peer, membership and security service
components.

1.  RocksDB is written using the C++ programming language. Make sure
    that the C++ compiler is installed along with the following compression packages:

    ```
    sudo apt-get -y install g++ libsnappy-dev zlib1g-dev libbz2-dev
    ```

2.  Download and build RocksDB:

    ```
    cd $HOME
    mkdir git && cd git
    git clone --branch v4.1 --single-branch --depth 1 https://github.com/facebook/rocksdb.git
    cd rocksdb
    sed -i -e "s/-march=native/-march=zEC12/" build_tools/build_detect_platform
    sed -i -e "s/-momit-leaf-frame-pointer/-DDUMMY/" Makefile
    make shared_lib && sudo INSTALL_PATH=/usr make install-shared && sudo ldconfig
    ```
    >***NOTE:*** Change the value of **-march** to the z Systems model type, e.g.,
    > **z196**, if your Linux system is not running on a z Systems EC12.

Docker Daemon & Docker Registry
===============================
The Hyperledger Fabric peer relies on Docker to deploy and run Chaincode
(aka Smart Contracts). In addition, for development purposes, the
Hyperledger Fabric peer service and the membership and security service
can both run in Docker containers. Instructions for building both a peer
service Docker image and a membership and security service Docker image
are covered later in this document.

A local Docker registry can be used for the Hyperledger Fabric environment
if you are not going to access public Docker images.


Installing the Docker Packages
-------------------------------------

1.  Install the Docker and Docker registry packages:

    ```
    sudo apt-get -y install docker.io docker-registry
    ```

    > ***NOTE:*** In order to issue Docker commands from a
    > non-root user without prefixing the command with sudo, the non-root user
    >needs to be added to the  docker group:  
    > **sudo usermod -a -G docker \<non-root-user\>**  
    >
    > The \<non-root-user\> may have to logout and then login to pick up the change.
    > If you didn't update your **.profile** file when installing Golang,
    > you'll have to update your PATH environment variable:  
    > **export PATH=$PATH:/usr/lib/go-1.6/bin**

Update Docker Configuration files  
---------------------------------

1.  Update the Docker daemon start options:

    ```
    sudo systemctl stop docker.service
    sudo sed -i "\$aDOCKER_OPTS=\"-H tcp://0.0.0.0:2375 --insecure-registry localhost:5050\"" /etc/default/docker
    ```

2.  Start the Docker daemon:

    ```
    sudo systemctl start docker.service
    ```

3.  Update the Docker Registry configuration file:

    ```
    sudo systemctl stop docker-registry.service
    sudo sed -i 's/5000/5050/g' /etc/docker/registry/config.yml
    ```

4.  Start the Docker registry:

    ```
    sudo systemctl start docker-registry.service
    ```

Build a Docker Image for Hyperledger Fabric Use
===============================================
This section describes the steps required to build a Docker image that is
comprised of the Golang programming language toolchain and RocksDB built upon the
Ubuntu operating system. There is no need to download any pre-existing
Docker images from the Docker Hub or from any other Docker registry that
is on the internet.

It is a two-step process to build the Docker image:

1.  Build your own Ubuntu Docker image from scratch.

2.  Build a Golang toolchain Docker image, which includes RocksDB, from the base
    Ubuntu Docker image built in step 1.

This Docker image is used by the Hyperledger Fabric peer component when
deploying Chaincode. The peer communicates with the Docker Daemon to
initially create docker images based on the Golang toolchain Docker
image and contains the compiled Chaincode built from source specified by
the **peer chaincode deploy** command. Docker containers are started by the peer
and execute the Chaincode binary awaiting further Blockchain
transactions, e.g., invoke or query.

Build a Base Ubuntu Docker Image
--------------------------------
1.  Make sure that your Docker Daemon and Docker Registry are started.
    Refer to the [Docker Daemon & Docker Registry](#docker-daemon--docker-registry) section
    above for installing, configuring and starting the Docker Daemon and Docker Registry.

2.  Install the **debootstrap** utility:

    ```
    sudo apt-get -y install debootstrap
    ```

3.  Execute the **debootsrap** utility to create a base Ubuntu image directory:

    ```
    cd $HOME
    sudo debootstrap xenial ubuntu-base > /dev/null
    ```

4.  Update the **sources.list** file for repository access:

    ```
    sudo cp /etc/apt/sources.list $HOME/ubuntu-base/etc/apt/
    ```

5.  Import the ubuntu-base image into docker:

    ```
    cd $HOME
    sudo tar -C ubuntu-base -c . | docker import - ubuntu-base
    ```

6.  Ensure that the image has been imported:

    ```
    docker images
    ```

    > ***NOTE:*** Optionally, you can place this base image into your Docker
    > registry’s repository by issuing the commands:
    >  
    > *docker tag ubuntu-base \<docker_registry_host_ip\>:5050/ubuntu-base  
    > docker push \<docker_registry_host_ip\>:5050/ubuntu-base*

Build a Golang and RocksDB Docker Image from the Base Ubuntu Docker Image
-------------------------------------------------------------------------
Once the base Ubuntu Docker image is created, complete the following steps
to build a Golang and RocksDB Docker image:

1.  Make sure that your Docker Daemon and Docker Registry are started.
    Refer to the [Docker Daemon & Docker Registry](#docker-daemon--docker-registry) section above
    for installing, configuring and starting the Docker Daemon and Docker Registry.

2.  Create a working directory for building the Docker images:
    ```
    cd $HOME
    mkdir dockerbuild
    mv git/rocksdb dockerbuild
    cd dockerbuild
    ```

3.  Create a Dockerfile:
    ```
    vim Dockerfile
    ```

4. Cut and paste the following lines into your Dockerfile and then save the file:
    ```
    FROM ubuntu-base:latest
    RUN apt-get update
    RUN apt-get -y install build-essential git golang-1.6-go gcc g++ make libbz2-dev zlib1g-dev libsnappy-dev libgflags-dev
    ENV GOROOT=/usr/lib/go-1.6
    COPY rocksdb /tmp/rocksdb
    WORKDIR /tmp/rocksdb
    RUN INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
    ENV GOPATH=/opt/gopath
    ENV PATH=$PATH:$GOROOT/bin:$GOPATH/bin
    WORKDIR $GOPATH
    ```

5.  Issue the **docker build** command:
    ```
    docker build -t hyperledger/fabric-baseimage -f Dockerfile .
    ```

6.  Confirm that your new image was created by issuing the **docker images** command.

7.  **Optional:** Push your new Golang toolchain and RocksDB Docker image
    to your Docker Registry:
    ```
    docker tag hyperledger/fabric-baseimage <docker_registry_host_ip>:5050/hyperledger/fabric-baseimage
    docker push <docker_registry_host_ip>:5050/hyperledger/fabric-baseimage
    ```
    > ***NOTE:*** Replace **<docker_registry_host_ip>** with the IP
    > address of the host that is running your Docker Registry.

Build the Hyperledger Fabric Core
=================================
The Hyperledger Fabric Core contains code for running validating peers and membership
services for enrollment and certificate authority tasks.

1.  Download the Hyperledger Fabric code into a working directory:

    ```
    cd $HOME
    mkdir -p fabricwork/src/github.com/hyperledger
    cd fabricwork/src/github.com/hyperledger
    git clone https://github.com/hyperledger/fabric.git
    ```

2.  Setup environment variable prior to building the Hyperledger Fabric components:
    ```
    export GOPATH=$HOME/fabricwork
    ```
    > ***NOTE:*** Also add the the GOPATH environment variable to root's
    > **.profile** file if you run the Hyperledger Fabric peer or
    > membersrvc executables natively.

3.  Build the Hyperledger Fabric executable binaries. The peer binary
    runs validating peer nodes and the membersrvc binary is the membership
    and security server that handles enrollment and certificate requests.
    In addition to the peer and membersrvc executables, supporting Docker images
    are created for development use. The **Makefile** is altered to allow for the
    use of your own **hyperledger/fabric-baseimage** Docker image:

    ```
    sed -i "/docker\.sh/d" $GOPATH/src/github.com/hyperledger/fabric/Makefile
    cd $GOPATH/src/github.com/hyperledger/fabric
    make peer membersrvc
    ```
    >***NOTE:*** The peer and membersrvc executables are placed into the **$GOPATH/src/github.com/hyperledger/fabric/build/bin** directory

***Optional:*** If you are planning to run the Fabric executables locally,
you can create shell scripts to start the peer and the membership
and security services executables in the background and re-direct
logging output to a file.

1.  Create a file called **fabric-peer.sh** located in
    **/usr/local/bin** with the executable attribute set:

    ```bash
    #!/bin/bash
    export GOPATH=<parent-directory>
    cd $GOPATH/src/github.com/hyperledger/fabric/build/bin
    ./peer node start --logging-level=debug > /var/log/fabric-peer.log 2>&1 &
    ```
    > **NOTE:** Change **\<parent-directory\>** to the root directory of where
    the Hyperledger Fabric code is located (up to, but not including the **src** directory).

2.  Create a file called **membersrvc.sh** located in **/usr/local/bin**
    with the executable attribute set:

    ```bash
    #!/bin/bash
    export GOPATH=<parent-directory>
    cd $GOPATH/src/github.com/hyperledger/fabric/build/bin
    ./membersrvc > /var/log/membersrvc.log 2>&1 &
    ```
    > **NOTE:** Change **\<parent-directory\>** to the root directory of where
    the Hyperledger Fabric code is located (up to, but not including the **src** directory).

Build Hyperledger Fabric Docker Images
--------------------------------------
If you have progressed through this document from the beginning, you
already built the components necessary to run the Hyperledger Fabric
peer along with the Hyperledger Fabric membership services and security
server on your Linux system.

However, if you would like to run your peer(s) or membership services
components in their own Docker containers, perform the following steps
to build their respective Docker images:

    ```
    cd $GOPATH/src/github.com/hyperledger/fabric
    make peer-image membersrvc-image
    ```

Unit Tests
==========
If you feel inclined to run the Hyperledger Fabric unit tests, follow
the steps below:

```
sudo rm -rf /var/hyperledger
cd $GOPATH/src/github.com/hyperledger/fabric
sudo GOPATH=<parent-directory> make unit-test
```

> **NOTE:** Change **\<parent-directory\>** to the root directory of where
the Hyperledger Fabric code is located (up to, but not including the **src** directory).

Behave Tests
============
A thorough suite of Behave tests are included with the Hyperledger Fabric code base.  These Behavior-driven development test cases are written in a natural language and backed up by python scripts.  The behave tests take advantage of the Docker Compose tool to setup multi-peer Hyperledger Fabric Docker containers and run scenarios that exercise security, consensus, and chaincode execution, to name a few.

1. Install prerequisites for Behave:

    ```
    cd $HOME
    sudo apt-get -y install python-setuptools
    curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
    sudo -H python get-pip.py
    sudo -H pip install --upgrade pip
    sudo -H pip install behave nose docker-compose
    sudo -H pip install -I flask==0.10.1 python-dateutil==2.2 pytz==2014.3 pyyaml==3.10 couchdb==1.0 flask-cors==2.0.1 requests==2.4.3
    ```
2. Add a firewall rule to ensure traffic flow on the docker0 interface with a  destination port of 2375 (docker daemon API port).  The Behave tests take advantage of Docker containers to test the Fabric peer's functionality.

    ```
    sudo iptables -I INPUT 1 -i docker0 -p tcp --dport 2375 -j ACCEPT
    ```

3.  Shutdown any peer instances prior to running the Behave tests:

    ```
    sudo killall peer
    ```

4. Run the Behave tests:

    ```
    cd $GOPATH/src/github.com/hyperledger/fabric
    make behave
    ```
