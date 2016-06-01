Hyperledger Fabric Build for RHEL on Linux on z Systems
=========================================================
This document describes the steps to build, configure and install the
infrastructure components associated with IBM’s Open Blockchain
technology, Hyperledger Fabric, on the Linux on z Systems platform.

More importantly, you will create the Docker artifacts using the base
RHEL 7.x system on which you will deploy. The base Docker image will be
RHEL 7.x based and have access to the same yum repositories as the
system on which you deploy. This eliminates the need to download any
pre-built Docker images from the public Docker repository, eliminating
one potential security exposure. The Docker images you create will be
kept in a repository that you create, thus remaining within your
control.

The major components include:
- Golang programming language
- Docker client and daemon
- Docker registry
- Hyperledger Fabric
  - Peer
  - Membership and Security Services

Once all of the major components are built, custom Docker images are
created for the Golang programming language, Hyperledger Fabric Peer,
and Hyperledger Fabric Membership and Security Services. This allows for
a fully *dockerized* development or proof-of-concept Hyperledger Fabric
environment.

The procedures in this guide are tailored for Red Hat Enterprise Edition
(RHEL) 7.x. Due to the ongoing development activity within the
Hyperledger project, there is a chance that portions of this document
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
> The targeted directory is set in step 4 of [Building the Golang
> Toolchain](#building-the-golang-toolchain). Otherwise, if you have root access…
> Great! No need to worry about this.

Building Golang
===============
The Hyperledger Fabric and the Docker Registry are written using the
Golang programming language. Therefore, a Golang compiler needs to be
built in order to compile the Hyperledger Fabric and Docker Registry
source code.

Building Golang for Linux on z Systems is a two-step process:

1.  Cross-compile the Golang bootstrap tool on an x86-based
    machine running an up-to-date version of Linux.

2.  Build the Golang toolchain on Linux on z Systems using the bootstrap
    tool created in step 1.

For information on how the Golang bootstrapping process works, see the
blog entry at
<http://dave.cheney.net/2015/10/16/bootstrapping-go-1-5-on-non-intel-platforms>.

Cross-Compiling the Bootstrap Tool
----------------------------------
To build the Golang bootstrap tool you will need to use an
x86-based machine running an up-to-date version of Linux, e.g.,
RHEL 7.x.

1.  Install the dependencies:

    ```
    sudo yum install -y git wget tar gcc bzip2
    ```
2.  Create a directory for the amd64 version of the Golang toolchain:

    ```
    mkdir -p $HOME/go1.5.2
    cd $HOME/go1.5.2
    ```
3.  Download the amd64 Golang toolchain binary and extract it:

    ```
    wget https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz
    tar -xvf go1.5.2.linux-amd64.tar.gz
    ```

4.  Clone the source code for the z Systems port of Golang:

    ```
    cd $HOME
    git clone https://github.com/linux-on-ibm-z/go.git
    ```
5.  Build the bootstrap tool:

    ```
    export GOROOT_BOOTSTRAP=$HOME/go1.5.2/go
    cd $HOME/go/src
    GOOS=linux GOARCH=s390x ./bootstrap.bash
    ```
The bootstrap tool is placed into a bzip tarball named
**go-linux-s390x-bootstrap.tbz** located in **$HOME** and
is used in the next step to compile the Golang programming language
source code on Linux on z Systems.

Building the Golang Toolchain
-----------------------------
To build the Golang toolchain you need to have successfully built the
Golang bootstrap tool outlined in the [Cross-Compiling the Bootstrap Tool](#cross-compiling-the-bootstrap-tool)
section of this document. After building the bootstrap tool, login to
your Linux on z Systems instance and perform the steps below.

1.  Install the dependencies.

    ```
    sudo yum install -y git gcc
    ```
2.  Transfer the bootstrap file to your Linux on z Systems instance and clone the Golang source:

    ```
    cd $HOME
    # scp or ftp $HOME/go-linux-s390x-bootstrap.tbz from the x86 system to $HOME on your Linux on z Systems instance
    tar -xf go-linux-s390x-bootstrap.tbz
    git clone https://github.com/linux-on-ibm-z/go.git
    cd $HOME/go
    git checkout release-branch.go1.6
    ```
3.  Build the Golang toolchain on Linux on z Systems and run all tests.

    ```
    export GOROOT_BOOTSTRAP=$HOME/go-linux-s390x-bootstrap
    cd $HOME/go/src
    ./all.bash
    ```

4. Copy the Golang directory to the final install directory,
**\<golang_home\>**, and permanently update your **PATH**
environment variable to use the new toolchain.  The **go** directory is typically located under **/usr/local**.

    ```
    sudo cp -ra $HOME/go /<golang_home>/
    # Also add the following lines to ~/.bash_profile
    export PATH=/<golang_home>/go/bin:$PATH
    ```

5. Cleanup and delete bootstrap files:

    ```
    cd $HOME
    rm -rf go-linux-s390x-bootstrap*
    ```

Docker
======
The Hyperledger Fabric peer relies on Docker to deploy and run Chaincode
(aka Smart Contracts). In addition, for development purposes, the
Hyperledger Fabric peer service and the membership and security service
can both run in Docker containers. The Hyperledger Fabric peer unit
tests include tests that build both a peer service Docker image and a
membership and security service Docker image. This is covered later in
the document.

A Docker registry is required for the Hyperledger Fabric environment and
the process to build your own Docker registry from source is described
below.

Installing the Docker Client / Daemon
-------------------------------------
Refer to [Linux on z Systems Docker installation
instructions](https://www.ibm.com/developerworks/linux/linux390/docker.html)
for downloading and installing the RHEL distribution of Docker on Linux
on z Systems.

For a more permanent solution when starting the Docker Daemon:

1.  Copy the Docker binary file to a directory that is contained within the
    current **PATH** environment variable:

    ```
    sudo cp /<current_path_of_docker_file>/docker /usr/local/bin
    ```
2. Create a shell script in **/usr/local/bin** to start the Docker
Daemon and redirect all output to a logging file. Ensure that the
shell script has the executable attribute set.

    ```
    #!/bin/bash
    /usr/local/bin/docker daemon -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock --insecure-registry localhost:5050 > /var/log/docker.log 2>&1 &
    ```
    > ***NOTE:*** If your Docker Registry is running on another system, change
    > **localhost** to either the hostname or IP address of the system
    > running the Docker Registry. Also note that the port number of the
    > insecure registry matches the port number that the Docker Registry is
    > listening on.

3.  Ensure that the device-mapper package is up to date:

    ```
    sudo yum -y install device-mapper
    ```
4. Start the Docker Daemon shell script:

    ```
    sudo <docker-daemon-script-name>
    ```
    > ***NOTE:*** In order to run the Docker Daemon shell script from a
    > non-root user without prefixing the command with sudo, a docker group
    > needs to be created and the non-root user needs to be added to the
    > docker group:  
    > **sudo groupadd docker**  
    > **sudo usermod -a -G docker \<non-root-user\>**  
    >
    > The \<non-root-user\> will have to logout and then login to pick up the change.

Building the Docker Registry
----------------------------
The Docker Registry 2.0 implementation for storing and distributing
Docker images is part of the GitHub Docker Distribution project. The
Docker Distribution project consists of a toolset to pack, ship, store,
and deliver Docker content.

The reason to create your own registry is twofold. First, it is your
private registry. Second, you will create a registry for Linux on z
Systems Docker daemons, which will allow the use of the same unaltered
Dockerfile contents used by the Docker daemon on the x86 platform. This
eliminates source code changes to the Hyperledger fabric code.

1.  Install the dependencies:
    ```
    sudo yum install -y git make
    ```
    > ***NOTE:*** Golang is required to build the Docker Registry. See [Building Golang](#building-golang)
    > to build the Golang toolchain. You may have already
    > installed the **git** and **make** packages when building Golang. If
    > so, ignore the installation of the packages within this step.

2.  Create a distribution directory and clone the source code:

    ```
    mkdir -p $HOME/src/github.com/docker
    cd $HOME/src/github.com/docker
    git clone https://github.com/docker/distribution.git
    cd $HOME/src/github.com/docker/distribution
    git checkout v2.3.0
    ```
3.  Set **GOPATH** and **DISTRIBUTION_DIR** environment variables:

    ```
    export DISTRIBUTION_DIR=$HOME/src/github.com/docker/distribution
    export GOPATH=$HOME
    export GOPATH=$DISTRIBUTION_DIR/Godeps/_workspace:$GOPATH
    ```
4. Build the distribution binaries:

    ```
    cd $HOME/src/github.com/docker/distribution
    make PREFIX=$HOME clean binaries
    ```
5.  Run the Test Suite:

    ```
    make PREFIX=$HOME test
    ```
6.  Start the Docker Registry:

    > ***NOTE:*** The Docker Registry fetches the configuration from
    > **$DISTRIBUTION_DIR/ cmd/registry/config.yml**. The default
    > filesystem location where the Docker Registry stores images is
    > **/var/lib/registry.**

    a) Copy the **config-dev.yml** file to **config.yml**:

      ```
      cp $DISTRIBUTION_DIR/cmd/registry/config-dev.yml $DISTRIBUTION_DIR/cmd/registry/config.yml
      ```
    b)  Tailor the Docker Registry configuration file and save:

    - Change the default storage caching mechanism. If you are not
      using redis for storage caching, edit
      **$DISTRIBUTION_DIR/cmd/registry/config.yml** and change the
      **storage.cache.blobdescriptor** parameter from **redis** to
      **inmemory**.

    - Change the default listening port of the Docker Registry. Edit
     **$DISTRIBUTION_DIR/cmd/registry/config.yml** and change the
     **http.addr** parameter from **5000** to **5050**. This change
     is required because port 5000 conflicts with the Hyperledger
     Fabric peer’s REST service port, which uses port 5000.

    c) Create the default directory to store images, if it does not exist:

      ```
      sudo mkdir -p /var/lib/registry
      ```
    d) Start the Docker Registry:

    ```
    $HOME/bin/registry $DISTRIBUTION_DIR/cmd/registry/config.yml
    ```

7.  Cleanup Docker directories:

    ```
    cd $HOME
    rm docker-*
    ```

For a more permanent solution when starting the Docker Registry:

1.  Setup homes for the Docker Registry executable binary and its
    configuration file:

    ```
    sudo mkdir /etc/docker-registry
    sudo cp $DISTRIBUTION_DIR/cmd/registry/config.yml /etc/docker-registry
    sudo cp $HOME/bin/registry /usr/local/bin
    ```

2.  Create a shell script in **/usr/local/bin** to start the Docker
    Registry in the background and redirect all output to a
    logging file. Ensure that the shell script has the executable
    attribute set.

    ```bash
    #!/bin/bash
    /usr/local/bin/registry /etc/docker-registry/config.yml > /var/log/docker-registry.log 2>&1 &
    ```
3.  Start the Docker Registry:

    ```
    sudo <docker-registry-script-name>
    ```

For more information on the Docker Distribution project, see
<https://github.com/docker/distribution>.

Build and Install RocksDB
=========================
RocksDB is an embeddable persistent key-value store for fast storage and
is used by the Hyperledger Fabric peer, membership and security service
components.

1.  RocksDB is written using the C++ programming language. Make sure
    that the C++ compiler is installed along with the following compression packages:

    ```
    sudo yum -y install gcc-c++ zlib-devel snappy-devel bzip2-devel
    ```
2.  Download and build RocksDB:

    ```
    cd $HOME
    git clone --branch v4.1 --single-branch --depth 1 https://github.com/facebook/rocksdb.git
    cd rocksdb
    sed -i -e "s/-march=native/-march=zEC12/" build_tools/build_detect_platform
    sed -i -e "s/-momit-leaf-frame-pointer/-DDUMMY/" Makefile
    make shared_lib && sudo INSTALL_PATH=/usr make install-shared && sudo ldconfig
    ```
3.  Delete the rocksdb build directory:

    ```
    cd $HOME
    rm -rf $HOME/rocksdb
    ```

Build the Hyperledger Fabric Core
=================================
The Hyperledger Fabric Core contains code for running validating peers and membership services for enrollment and certificate authority tasks.

>***NOTE:*** The **/\<golang_home\>/go** directory represents where Golang
>was installed after performing step 4 in [Building the Golang Toolchain](#building-the-golang-toolchain).
>If you built Golang using this document, you have already added the
>Golang **bin** directory to your **PATH**.

1.  Download the Hyperledger Fabric code into a writeable directory:

    ```
    mkdir -p $HOME/src/github.com/hyperledger
    export GOPATH=$HOME
    cd $HOME/src/github.com/hyperledger
    git clone https://github.com/hyperledger/fabric.git
    cd fabric
    ```
2.  Setup environment variables:

    ```
    export GOROOT=/<golang_home>/go
    export PATH=/<golang_home>/go/bin:$PATH
    export CGO_LDFLAGS="-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy"
    export CGO_CFLAGS=" "
    ```
    > ***NOTE:*** If you are going to be rebuilding Golang or RocksDB, add the
    > environment variables in steps 2 and 3 to your **.bash_profile** file.

3.  Build the Hyperledger Fabric executable binaries. The peer binary
    runs validating peer nodes and the membersrvc
    binary is the membership and security server that handles enrollment
    and certificate requests:

    ```
    cd $GOPATH/src/github.com/hyperledger/fabric/peer
    go build
    cd $GOPATH/src/github.com/hyperledger/fabric/membersrvc
    go build -o membersrvc server.go
    ```
For a more permanent solution, you can create shell scripts to start the
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
The section describes the steps required to build a Docker image that is
comprised of the Golang programming language toolchain built upon the
RHEL operating system. There is no need to download any pre-existing
Docker images from the Docker Hub or from any other Docker registry that
is on the internet.

It is a two-step process to build the Golang toolchain Docker image:

1.  Build your own RHEL Docker image from scratch.

2.  Build a Golang toolchain Docker image from the base RHEL Docker
    image built in step 1.

This Docker image is used by the Hyperledger Fabric peer component when
deploying Chaincode. The peer communicates with the Docker Daemon to
initially create docker images based on the Golang toolchain Docker
image and contains the compiled Chaincode built from source specified by
the **peer chaincode deploy** command. Docker containers are started by the peer
and execute the Chaincode binary awaiting further Blockchain
transactions, e.g., invoke or query.

Build a Base RHEL Docker Image
------------------------------

1.  Make sure that your Docker Daemon and Docker Registry are started.
    Refer to [Installing the Docker Client / Daemon](#installing-the-docker-client--daemon) and [Building the Docker Registry](#building-the-docker-registry) sections above for building and starting the Docker Daemon and Docker Registry.

2.  Copy and paste the contents of
    <https://github.com/docker/docker/blob/master/contrib/mkimage-yum.sh>
    into a new file, **mkimage-yum.sh**, file on your local RHEL system where the Docker image
    will be created. Place the script into **/usr/local/bin**. Ensure
    the new script file has the executable attribute set.

3.  If you are not using the Red Hat subscription service to update
    packages on your system, add the following lines to your
    **mkimage-yum.sh** script just before the **yum -c "$yum_config"
    --installroot="$target" -y clean** command:

    ```
    cp -ra /etc/yum/* "$target"/etc/yum/
    cp -ra /etc/yum.repos.d "$target"/etc
    yum -c "$yum_config" --installroot="$target" -y install net-tools
    ```
    > ***NOTE:*** This command will copy all of your existing yum repository definitions
    > during the build of the RHEL Docker image. Additional build steps
    > access the repositories to install pre-requisite packages during the
    > building of additional Docker images used within the Hyperledger
    > Fabric environment.

4.  Execute the **mkimage-yum.sh** script to create and import the RHEL
    Docker image:

    ```
    sudo mkimage-yum.sh rhelbase
    ```
5.  Obtain the **rhelbase** Docker image’s **TAG**.
    The **rhelbase:\<TAG\>** is required to build the Golang
    toolchain Docker image:

    ```
    docker images
    ```
    > Look for **rhelbase** in the REPOSITORY column and note the TAG name
    > for **rhelbase**.
    >
    > In the example below the TAG is 7.2.
    >
    > ![](./media/docker-images-rhel.jpg)
    >
    > ***NOTE:*** Optionally, you can place this base image into your Docker
    > registry’s repository by issuing the commands:
    >  
    > *docker tag rhelbase:\<TAG\> \<docker_registry_host_ip\>:5050/rhelbase:\<TAG\>   
    > docker push \<docker_registry_host_ip\>:5050/rhelbase:\<TAG\>*

Build a Golang Toolchain Docker Image from the Base RHEL Docker Image
---------------------------------------------------------------------
Once the base RHEL Docker image is created, complete the following steps
to build a Golang toolchain Docker image:

1.  Make sure that the Docker Daemon and Docker Registry have
    been started. Refer to [Installing the Docker Client / Daemon](#installing-the-docker-client--daemon) and
    [Building the Docker Registry](#building-the-docker-registry) sections above
    for building and starting the Docker Daemon and Docker Registry.

2.  Create a Dockerfile:

    ```
    cd $HOME
    vi Dockerfile
    ```
3. Cut and paste the following lines into your Dockerfile and then save
the file:

    ```
    FROM rhelbase:<TAG>
    RUN yum -y groupinstall "Development Tools"
    COPY go /usr/local/go
    ENV GOPATH=/opt/gopath
    ENV GOROOT=/usr/local/go
    ENV PATH=$GOPATH/bin:/usr/local/go/bin:$PATH
    RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
    WORKDIR $GOPATH
    ```
    > ***NOTE:*** Replace **\<TAG\>** with the TAG value obtained above in
    > step 5 of [Build a Base RHEL Docker Image](#build-a-base-rhel-docker-image).

4.  Make sure that a copy of the **go** directory is in your
    **$HOME** directory. If you used the
    **$HOME** directory when performing the instructions
    in section [Building the Golang Toolchain](#building-the-golang-toolchain)
    then you should already have your built **go** directory contained in
    **$HOME**.

5.  Issue the **docker build** command:

    ```
    cd $HOME
    docker build -t <docker_registry_host_ip>:5050/s390x/golang -f <docker_file> .
    ```
    > ***NOTE:*** Replace **\<docker_registry_host_ip\>** with the IP
    > address of the host that is running your Docker Registry. Replace
    > **\<docker_file\>** with **Dockerfile** or the name of your file
    > containing the Docker statements listed in step 3.

6.  Confirm that your new image was created by issuing the **docker
    images** command.

7.  Push your new Golang toolchain Docker image to your Docker Registry:

    ```
    docker push <docker_registry_host_ip>:5050/s390x/golang
    ```
    > ***NOTE:*** Replace **<docker_registry_host_ip>** with the IP
    > address of the host that is running your Docker Registry.

8.  Update your Hyperledger Fabric peer’s configuration file and save.
    The following change informs the peer to use your Golang toolchain
    Docker image when executing Chaincode transactions:

    ```
    cd $HOME/src/github.com/hyperledger/fabric/peer
    vi core.yaml
    ```

    a) Replace the **chaincode.golang.Dockerfile** parameter (located within lines 280-290) with the following:

      ```
      Dockerfile: |
        from <docker_registry_host_ip>:5050/s390x/golang
        COPY src $GOPATH/src
        WORKDIR $GOPATH
      ```

      b) Replace the **chaincode.car.Dockerfile** parameter (located within lines 295-300) with the following:

      ```
      Dockerfile: |
        from <docker_registry_host_ip>:5050/s390x/golang
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

1.  Update the Hyperledger Fabric’s core.yaml file and save:

    ```
    cd $HOME/src/github.com/hyperledger/fabric/peer
    vi core.yaml
    ```

2. Replace the **peer.Dockerfile** parameter (located within lines 90-100) with the following:

    ```
    Dockerfile: |
      from <docker_registry_host_ip>:5050/s390x/golang
      # Install RocksDB
      RUN cd /tmp && git clone --branch v4.1 --single-branch --depth 1 https://github.com/facebook/rocksdb.git && cd rocksdb
      WORKDIR /tmp/rocksdb
      RUN sed -i -e "s/-march=native/-march=zEC12/" build_tools/build_detect_platform
      RUN sed -i -e "s/-momit-leaf-frame-pointer/-DDUMBDUMMY/" Makefile
      RUN yum -y install snappy-devel zlib-devel bzip2-devel
      RUN make shared_lib  && INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
      # Copy GOPATH src and install Peer
      COPY src $GOPATH/src
      RUN mkdir -p /var/hyperledger/db
      WORKDIR $GOPATH/src/github.com/hyperledger/fabric/peer
      ENV PATH $GOPATH/bin:$PATH
      RUN CGO_CFLAGS=" " CGO_LDFLAGS="-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy" go install && cp $GOPATH/src/github.com/hyperledger/fabric/peer/core.yaml $GOPATH/bin
    ```
    > ***NOTE:*** Replace **\<docker_registry_host_ip\>** with the IP
    > address of the host that is running your Docker Registry.

3.  Build the **hyperledger-peer** and **membersrvc** Docker images:

    ```
    cd $HOME/src/github.com/hyperledger/fabric/core/container
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
    *$HOME/src/github.com/hyperledger/fabric/membersrvc/ca/ca_test.yaml*
    and replace the **peer.Dockerfile** parameter with the following:

    ```
    Dockerfile: |
      from <docker_registry_host_ip>:5050/s390x/golang
      # Install RocksDB
      RUN cd /tmp && git clone --branch v4.1 --single-branch --depth 1 https://github.com/facebook/rocksdb.git && cd rocksdb
      WORKDIR /tmp/rocksdb
      RUN sed -i -e "s/-march=native/-march=zEC12/" build_tools/build_detect_platform
      RUN sed -i -e "s/-momit-leaf-frame-pointer/-DDUMBDUMMY/" Makefile
      RUN yum -y install snappy-devel zlib-devel bzip2-devel
      RUN make shared_lib && INSTALL_PATH=/usr make install-shared && ldconfig && rm -rf /tmp/rocksdb
      # Copy GOPATH src and install Peer
      COPY src $GOPATH/src
      RUN mkdir -p /var/hyperledger/db
      WORKDIR $GOPATH/src/github.com/hyperledger/fabric/peer
      ENV PATH $GOPATH/bin:$PATH
      RUN CGO_CFLAGS=" " CGO_LDFLAGS="-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy" go install && cp $GOPATH/src/github.com/hyperledger/fabric/peer/core.yaml $GOPATH/bin
    ```
2.  Edit
    *$HOME/src/github.com/hyperledger/fabric/membersrvc/ca/ca_test.yaml*
    and replace the **chaincode.golang.Dockerfile** parameter with the
    following:

    ```
    Dockerfile: |
      from <docker_registry_host_ip>:5050/s390x/golang
      COPY src $GOPATH/src
      WORKDIR $GOPATH
    ```

3.  Perform steps 1 and 2 for file:  
    *$HOME/src/github.com/hyperledger/fabric/core/ledger/genesis/genesis_test.yaml*  

4.  Edit *$HOME/src/github.com/hyperledger/fabric/core/chaincode/chaincodetest.yaml*:  

    a) Perform steps 1 and 2 for the chaincodetest.yaml file.

    b) Replace the **chaincode.car.Dockerfile** parameter (located within lines 295-300) with the following:

    ```
    Dockerfile: |
      from <docker_registry_host_ip>:5050/s390x/golang
    ```

5.  Edit
    *$HOME/src/github.com/hyperledger/fabric/core/container/controller_test.go*
    and replace **busybox** with **s390x/busybox**.

> ***NOTE:*** Replace **\<docker_registry_host_ip\>** with the IP address of the host
> that is running your Docker Registry.

Running the Unit Tests
----------------------

1.  Bring up a window (via ssh or screen) of the system where you built
    the Hyperledger Fabric components and start the Fabric Peer:

    ```
    cd $HOME/src/github.com/hyperledger/fabric/peer
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
    sudo yum -y install python-setuptools
    curl "https://bootstrap.pypa.io/get-pip.py" -o "get-pip.py"
    sudo python get-pip.py
    sudo pip install --upgrade pip
    sudo pip install behave nose docker-compose
    sudo pip install -I flask==0.10.1 python-dateutil==2.2 pytz==2014.3 pyyaml==3.10 couchdb==1.0 flask-cors==2.0.1 requests==2.4.3
    ```

2. Run the Behave tests:

    ```
    cd $HOME/src/github.com/hyperledger/fabric/bddtests
    behave
    ```
