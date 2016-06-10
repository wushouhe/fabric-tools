Hyperledger Fabric Build for Ubuntu on Linux on z Systems
=========================================================
This document describes the steps to build, configure and install the
infrastructure components associated with IBM’s Open Blockchain
technology, Hyperledger Fabric, on the Linux on z Systems platform.

More importantly, you will create the Docker artifacts using the base
Ubuntu system on which you will deploy. The base Docker image will be
Ubuntu based and have access to the same yum repositories as the
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

Once all of the major components are in place on the bulid system, custom Docker images are
created for the Golang programming language, Hyperledger Fabric Peer,
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
> user has been added to the **wheel** group. In addition, update the
> **/etc/sudoers** file to enable the **wheel** group with no password
> access, and append **/usr/local/bin** and the targeted directory that
> will contain the **go** executable to the **secure_path** variable.

Installing Golang
=================
The Hyperledger Fabric and the Docker Registry are written using the
Golang programming language. Therefore, a Golang compiler needs to be
installed in order to compile the Hyperledger Fabric and Docker Registry
source code.

Ubuntu has packaged Go in 16.04 LTS (Xenial). Install it with the command:

    sudo apt-get install golang-1.6-go

Docker Daemon & Docker Registry
===============================
The Hyperledger Fabric peer relies on Docker to deploy and run Chaincode
(aka Smart Contracts). In addition, for development purposes, the
Hyperledger Fabric peer service and the membership and security service
can both run in Docker containers. The Hyperledger Fabric peer unit
tests include tests that build both a peer service Docker image and a
membership and security service Docker image. This is covered later in
the document.

A Docker registry is required for the Hyperledger Fabric environment if you
are not going to access public Docker images.
The reason to create your own registry is twofold. First, it is your
private registry. Second, it allows for the use of the same unaltered
Dockerfile contents used by the Docker daemon on the x86 platform. This
eliminates source code changes to the Hyperledger fabric code.

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
    > The \<non-root-user\> will have to logout and then login to pick up the change.

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

2.  Start the Docker registry:

    ```
    sudo systemctl start docker-registry.service
    ```

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
    >***NOTE:*** Change the value of **-march** to **z196** if your Linux system is not running on a z Systems EC12 or later model.

Build the Hyperledger Fabric Core
=================================
The Hyperledger Fabric Core contains code for running validating peers and membership services for enrollment and certificate authority tasks.

1.  Download the Hyperledger Fabric code into a working directory:

    ```
    cd $HOME
    mkdir fabricwork
    export GOPATH=$HOME/fabricwork
    go get -d -v github.com/hyperledger/fabric
    ```

2.  Build the Hyperledger Fabric executable binaries. The peer binary
    runs validating peer nodes and the membersrvc
    binary is the membership and security server that handles enrollment
    and certificate requests:

    ```
    cd $GOPATH/src/github.com/hyperledger/fabric/peer
    go build -v
    cd $GOPATH/src/github.com/hyperledger/fabric//membersrvc
    go build -v -o membersrvc server.go
    ```

***Optional:*** If you are planning to run the Fabric executibles locally and not inside docker containainers,
you can create shell scripts to start the
peer and the membership and security services executables in the
background and re-direct logging output to a file.

1.  Create a file called **fabric-peer.sh** located in
    **/usr/local/bin** with the executable attribute set:

    ```bash
    #!/bin/bash
    cd <parent-directory>/src/github.com/hyperledger/fabric/peer
    ./peer node start --logging-level=debug > /var/log/fabric-peer.log 2>&1 &
    ```
    > **NOTE:** Change **\<parent-directory\>** to the root directory of where the Hyperledger Fabric code is located.

2.  Create a file called **membersrvc.sh** located in **/usr/local/bin**
    with the executable attribute set:

    ```bash
    #!/bin/bash
    cd <parent-directory>/src/github.com/hyperledger/fabric/membersrvc
    ./membersrvc > /var/log/membersrvc.log 2>&1 &
    ```
    > **NOTE:** Change **\<parent-directory\>** to the root directory of where the Hyperledger Fabric code is located.

Build a Golang Toolchain Docker Image
=====================================
This section describes the steps required to build a Docker image that is
comprised of the Golang programming language toolchain built upon the
Ubuntu operating system. There is no need to download any pre-existing
Docker images from the Docker Hub or from any other Docker registry that
is on the internet.

***Alternative:*** This process is optional, as go and the go libraries can be installed from the Ubuntu repositories. Instead of rebuilding the whole toolchain inside the docker image, you can simply issue a ```RUN apt-get install golang-1.6-go``` command inside the Dockerfile after building your base image in the next section.

It is a two-step process to build the Golang toolchain Docker image:

1.  Build your own Ubuntu Docker image from scratch.

2.  Build a Golang toolchain Docker image from the base Ubuntu Docker
    image built in step 1.

This Docker image is used by the Hyperledger Fabric peer component when
deploying Chaincode. The peer communicates with the Docker Daemon to
initially create docker images based on the Golang toolchain Docker
image and contains the compiled Chaincode built from source specified by
the **peer chaincode deploy** command. Docker containers are started by the peer
and execute the Chaincode binary awaiting further Blockchain
transactions, e.g., invoke or query.

Build a Base Ubuntu Docker Image
------------------------------
1.  Make sure that your Docker Daemon and Docker Registry are started.
    Refer to the [Docker Daemon & Docker Registry](#docker-daemon--docker-registry) section above for installing, configuring and starting the Docker Daemon and Docker Registry.

2.  Install the **debootstrap** utility:
    ```
    sudo apt-get -y install debootstrap
    ```

3.  Execute the **debootsrap** utility to create a base Ubuntu image directory:
    ```
    sudo debootstrap xenial ubuntu-base > /dev/null
    ```

4.  Alter the ubuntu-base/etc/apt/sources.list file to include the universe repository:
    ```
    $ sudo vim ubuntu-base/etc/apt/sources.list
    $ cat ubuntu-base/etc/apt/sources.list
    deb http://ports.ubuntu.com/ubuntu-ports xenial main universe
    ```

5.  Import the base ubuntu image into docker:
    ```
    sudo tar -C ubuntu-base -c . | docker import - ubuntu-base
    ```

6.  Ensure that the image has been imported:
    ```
    docker images
    ```

    > ***NOTE:*** Optionally, you can place this base image into your Docker
    > registry’s repository by issuing the commands:
    >  
    > *docker tag ubuntu-base:latest \<docker_registry_host_ip\>:5050/ubuntu-base:latest  
    > docker push \<docker_registry_host_ip\>:5050/ubuntu-base:latest*

Build a Golang and RocksDB Docker Image from the Base Ubuntu Docker Image
-------------------------------------------------------------------------
Once the base Ubuntu Docker image is created, complete the following steps
to build a Golang and RocksDB Docker image:

1.  Make sure that your Docker Daemon and Docker Registry are started.
    Refer to the [Docker Daemon & Docker Registry](#docker-daemon--docker-registry) section above for installing, configuring and starting the Docker Daemon and Docker Registry.

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

4. Cut and paste the following lines into your Dockerfile and then save
the file:
    ```
    FROM ubuntu-base:latest
    RUN apt-get update
    RUN apt-get -y install build-essential git golang-1.6-go gcc g++ make libbz2-dev zlib1g-dev libsnappy-dev libgflags-dev
    RUN ln -s /usr/lib/go-1.6/bin/go /usr/bin/go
    COPY rocksdb /tmp/rocksdb
    WORKDIR /tmp/rocksdb
    RUN INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
    ENV GOPATH=/root
    WORKDIR $GOPATH
    ```

5.  Issue the **docker build** command:
    ```
    docker build -t <docker_registry_host_ip>:5050/s390x/golang_rocksdb -f Dockerfile .
    ```
    > ***NOTE:*** Replace **\<docker_registry_host_ip\>** with the IP
    > address of the host that is running your Docker Registry.

6.  Confirm that your new image was created by issuing the **docker images** command.

7.  **Optional:** Push your new Golang toolchain Docker image to your Docker Registry:
    ```
    docker push <docker_registry_host_ip>:5050/s390x/golang_rocksdb
    ```
    > ***NOTE:*** Replace **<docker_registry_host_ip>** with the IP
    > address of the host that is running your Docker Registry.

8.  **Optional:** If running fabric peers locally (not inside Docker images), update your
    Hyperledger Fabric peer’s configuration file and save.
    The following changes inform the peer to use your Golang toolchain
    Docker image when executing Chaincode transactions locally:

    ```
    cd $GOPATH/src/github.com/hyperledger/fabric/peer
    vim core.yaml
    ```

    a) Replace the **chaincode.golang.Dockerfile** parameter (located within lines 280-290) with the following:

    ```
    Dockerfile: |
      FROM <docker_registry_host_ip>:5050/s390x/golang_rocksdb
      COPY src $GOPATH/src
      WORKDIR $GOPATH
    ```

    b) Replace the **chaincode.car.Dockerfile** parameter (located within lines 295-300) with the following:

    ```
    Dockerfile: |
      FROM <docker_registry_host_ip>:5050/s390x/golang_rocksdb
    ```

Build Hyperledger Fabric Docker Images
--------------------------------------
If you have progressed through this document from the beginning, you
already built the components necessary to run the Hyperledger Fabric
peer along with the Hyperledger Fabric membership services and security
server on your Linux system.

However, if you would like to run your peer(s) or membership services
components in their own Docker containers, perform the following steps
to build their respective Docker images.

1.  Update the Hyperledger Fabric’s core.yaml file:
    ```
    cd $GOPATH/src/github.com/hyperledger/fabric/peer
    vim core.yaml
    ```

2. Replace the **peer.Dockerfile** parameter in the following section (around line 100):
    ```
    Dockerfile: |
      FROM <docker_registry_host_ip>:5050/s390x/golang_rocksdb
      # Copy GOPATH src and install Peer
      COPY src $GOPATH/src
      RUN mkdir -p /var/hyperledger/db
      WORKDIR $GOPATH/src/github.com/hyperledger/fabric/peer
      RUN CGO_CFLAGS=" " CGO_LDFLAGS="-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy" go install && cp $GOPATH/src/github.com/hyperledger/fabric/peer/core.yaml $GOPATH/bin
    ```
    > ***NOTE:*** Replace **\<docker_registry_host_ip\>** with the IP
    > address of the host that is running your Docker Registry.  

3.  Alter the same FROM statement in the chaincode.golang.Dockerfile and chaincode.car.Dockerfile sections around like 285:
    ```
    golang:
      Dockerfile:  |
        FROM 10.20.92.155:5050/s390x/golang_rocksdb:latest
        COPY src $GOPATH/src
        WORKDIR $GOPATH

    car:
      Dockerfile:  |
        FROM 10.20.92.155:5050/s390x/golang_rocksdb:latest
    ```

4.  Build the **hyperledger-peer** and **membersrvc** Docker images:
    ```
    cd $GOPATH/src/github.com/hyperledger/fabric/core/container
    go test -timeout=20m -run BuildImage_Peer
    go test -timeout=20m -run BuildImage_Obcca
    ```
    > ***NOTE:*** Both of the images are also built when running the Unit Tests.

4.  Verify that the **hyperledger-peer** and **membersrvc** images are
    displayed after issuing a **docker images** command:
    ```
    docker images
    ```

Unit Tests
==========
If you feel inclined to run the Hyperledger Fabric unit tests, there are
a few minor changes that need to be made to some Golang test files prior
to invoking the unit tests.

Test File Changes
-----------------
1.  Edit
    *$GOPATH/src/github.com/hyperledger/fabric/membersrvc/ca/ca_test.yaml*
    and replace the **peer.Dockerfile** parameter with the following:
    ```
    Dockerfile: |
      FROM <docker_registry_host_ip>:5050/s390x/golang_rocksdb
      # Copy GOPATH src and install Peer
      COPY src $GOPATH/src
      RUN mkdir -p /var/hyperledger/db
      WORKDIR $GOPATH/src/github.com/hyperledger/fabric/peer
      RUN CGO_CFLAGS=" " CGO_LDFLAGS="-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy" go install && cp $GOPATH/src/github.com/hyperledger/fabric/peer/core.yaml $GOPATH/bin
    ```

2.  Edit
    *$GOPATH/src/github.com/hyperledger/fabric/membersrvc/ca/ca_test.yaml*
    and replace the **chaincode.golang.Dockerfile** parameter with the
    following:

    ```
    Dockerfile: |
      FROM <docker_registry_host_ip>:5050/s390x/golang_rocksdb
      COPY src $GOPATH/src
      WORKDIR $GOPATH
    ```

3.  Perform steps 1 and 2 for file:  
    *$GOPATH/src/github.com/hyperledger/fabric/core/ledger/genesis/genesis_test.yaml*  

4.  Edit *$GOPATH/src/github.com/hyperledger/fabric/core/chaincode/chaincodetest.yaml*:  
    a) Perform steps 1 and 2 for the chaincodetest.yaml file.
    b) Replace the **chaincode.car.Dockerfile** parameter (located within lines 295-300) with the following:
    ```
    Dockerfile: |
      FROM <docker_registry_host_ip>:5050/s390x/golang_rocksdb
    ```

5.  Edit
    *$GOPATH/src/github.com/hyperledger/fabric/core/container/controller_test.go*
    and replace **busybox** with **s390x/busybox**.

> ***NOTE:*** Replace **\<docker_registry_host_ip\>** with the IP address of the host
> that is running your Docker Registry.

Running the Unit Tests
----------------------
1.  Bring up a window (via ssh or screen) of the system where you built
    the Hyperledger Fabric components and start the Fabric Peer:
    ```
    cd $GOPATH/src/github.com/hyperledger/fabric/peer
    sudo ./peer node start
    ```

2.  From another window of the same Linux system, create an executable
    script called **unit-tests.sh** in **$HOME** using the
    following lines:
    ```bash
    #!/bin/bash
    export GOPATH=<parent-directory>
    export GOROOT=/<golang_home>/go
    export PATH=/<golang_home>/go/bin:$PATH
    go test -timeout=20m $(go list github.com/hyperledger/fabric/... | grep -v /vendor/ | grep -v /examples/)
    ```
    > ***NOTE:*** If you have root access and would like to run the unit
    > tests, simply set the environment variables listed above and then
    > issue the go test command. Replace
    > **\<golang_home\>** with the directory where Golang was
    > installed after performing step 4 in [Building the Golang Toolchain](#building-the-golang-toolchain).
    > Change **\<parent-directory\>** to the root directory of where the Hyperledger Fabric code is located.

3.  Invoke the unit-tests.sh script:

    ```
    cd $HOME
    sudo ./unit-tests.sh
    ```

Behave Tests
============
A thorough suite of Behave tests are included with the Hyperledger Fabric code base.  These Behavior-driven development test cases are written in a natural language and backed up by python scripts.  The behave tests take advantage of the Docker Compose tool to setup multi-peer Hyperledger Fabric Docker containers and run scenarios that exercise security, consensus, and chaincode execution, to name a few.

1. Install pre-reqs for Behave:

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
    iptables -I INPUT 1 -i docker0 -p tcp --dport 2375 -j ACCEPT
    ```

3.  Shutdown any peer instances prior to running the Behave tests:

    ```
    sudo killall peer
    ```

4. Run the Behave tests:

    ```
    cd $HOME/src/github.com/hyperledger/fabric/bddtests
    behave
    ```
