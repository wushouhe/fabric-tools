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

Golang programming language

Docker client and daemon

Docker registry

Hyperledger Fabric

Peer

Membership and Security Services

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

<span id="_Ref447909806" class="anchor"><span id="_Toc451280636" class="anchor"></span></span>Building Golang
=============================================================================================================

The Hyperledger Fabric and the Docker Registry are written using the
Golang programming language. Therefore, a Golang compiler needs to be
built in order to compile the Hyperledger Fabric and Docker Registry
source code.

Building Golang for Linux on z Systems is a two-step process:

1.  Cross-compile the Golang bootstrap tool on an Intel/AMD-based
    machine running an up-to-date version of Linux.

2.  Build the Golang toolchain on Linux on z Systems using the bootstrap
    tool created in step 1.

> **NOTE:** The instructions contained in this document assume that you
> are using a non-root user with sudo authority and that the non-root
> user has been added to the **wheel** group. In addition, update the
> **/etc/sudoers** file to enable the **wheel** group with no password
> access, and append **/usr/local/bin** and the targeted directory that
> will contain the **go** executable to the **secure\_path** variable.
> The targeted directory is set in step 4 of Building the Golang
> Toolchain. Otherwise, if you have root access… Great! No need to worry
> about this.

For information on how the Golang bootstrapping process works, see the
blog entry at
<http://dave.cheney.net/2015/10/16/bootstrapping-go-1-5-on-non-intel-platforms>.

<span id="_Cross-Compiling_the_Bootstrap" class="anchor"><span id="_Ref447908636" class="anchor"><span id="_Toc451280637" class="anchor"></span></span></span>Cross-Compiling the Bootstrap Tool
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

To build the Golang bootstrap tool you will need to use an
Intel/AMD-based machine running an up-to-date version of Linux, e.g.,
RHEL 7.x.

> **NOTE:** The directory **/&lt;work\_dir&gt;/** used in these
> instructions represents a temporary writeable directory of your
> choice.

1.  Install the dependencies:

sudo yum install -y git wget tar gcc bzip2

1.  Create a directory for the amd64 version of the Golang toolchain:

mkdir -p /&lt;work\_dir&gt;/go1.5.2

cd /&lt;work\_dir&gt;/go1.5.2

1.  Download the amd64 Golang toolchain binary and extract it:

wget https://storage.googleapis.com/golang/go1.5.2.linux-amd64.tar.gz

tar -xvf go1.5.2.linux-amd64.tar.gz

> **NOTE:** Even though the file name indicates that it is a *gzipped*
> file, it is just a regular tar file. There is no need to use the **z**
> tar flag.

1.  Clone the source code for the z Systems port of Golang:

cd /&lt;work\_dir&gt;/

git clone https://github.com/linux-on-ibm-z/go.git

1.  Build the bootstrap tool:

export GOROOT\_BOOTSTRAP=/&lt;work\_dir&gt;/go1.5.2/go

cd /&lt;work\_dir&gt;/go/src

GOOS=linux GOARCH=s390x ./bootstrap.bash

The bootstrap tool is placed into a bzip tarball named
**go-linux-s390x-bootstrap.tbz** located in /**&lt;work\_dir&gt;/** and
is used in the next step to compile the Golang programming language
source code on Linux on z Systems.

<span id="_Ref447966277" class="anchor"><span id="_Ref447966310" class="anchor"><span id="_Ref447966603" class="anchor"><span id="_Ref447966626" class="anchor"><span id="_Toc451280638" class="anchor"></span></span></span></span></span>Building the Golang Toolchain
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

To build the Golang toolchain you need to have successfully built the
Golang bootstrap tool outlined in the Cross-Compiling the Bootstrap Tool
section of this document. After building the bootstrap tool, login to
your Linux on z Systems machine and perform the steps below.

1.  Install the dependencies.

sudo yum install -y git gcc

1.  If you do not have a home directory that is shared (e.g., via NFS)
    with the AMD64/Intel machine, then scp or ftp
    **/&lt;work\_dir&gt;/go-linux-s390x-bootstrap.tbz** from the
    AMD64/Intel machine to **/&lt;work\_dir&gt;/** on the Linux on z
    Systems machine, and clone the source again:

mkdir /&lt;work\_dir&gt;/

cd /&lt;work\_dir&gt;/

\# scp/ftp /&lt;work\_dir&gt;/go-linux-s390x-bootstrap.tbz from the
AMD64/Intel system

tar -xf go-linux-s390x-bootstrap.tbz

git clone https://github.com/linux-on-ibm-z/go.git

1.  Build the Golang toolchain on z Systems and run all tests.

export GOROOT\_BOOTSTRAP=/&lt;work\_dir&gt;/go-linux-s390x-bootstrap

cd /&lt;work\_dir&gt;/go/src

./all.bash

> **NOTE:** If most of the tests pass then the Golang toolchain probably
> compiled OK and you can proceed to the next step.

1.  <span id="_Ref447966526" class="anchor"></span>Copy the Golang
    directory to the final install directory,
    **/&lt;golang\_home&gt;/**, and permanently update your **PATH**
    environment variable to use the new toolchain. Now you can compile
    Golang programs on Linux on z Systems.

sudo cp -ra /&lt;work\_dir&gt;/go /&lt;golang\_home&gt;/

\# Also add the following lines to **\~/.bash\_profile**

export PATH=/&lt;golang\_home&gt;/go/bin:\$PATH

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

<span id="_Ref448174147" class="anchor"><span id="_Toc451280640" class="anchor"></span></span>Installing the Docker Client / Daemon 
------------------------------------------------------------------------------------------------------------------------------------

Refer to [Linux on z Systems Docker installation
instructions](https://www.ibm.com/developerworks/linux/linux390/docker.html)
for downloading and installing the RHEL distribution of Docker on Linux
on z Systems.

For a more permanent solution when starting the Docker Daemon:

1.  Copy the Docker binary file to a directory contained within the
    current **PATH**:

sudo cp /&lt;current\_path\_of\_docker\_file&gt;/docker /usr/local/bin

1.  Create a shell script in **/usr/local/bin** to start the Docker
    Daemon and redirect all output to a logging file. Ensure that the
    shell script has the executable attribute set.

\#!/bin/bash

/usr/local/bin/docker daemon -H tcp://0.0.0.0:2375 -H
unix:///var/run/docker.sock --insecure-registry localhost:5050 &gt;
/var/log/docker.log 2&gt;&1 &

> **NOTE:** If your Docker Registry is running on another system, change
> **localhost** to either the hostname or IP address of the system
> running the Docker Registry. Also note that the port number of the
> insecure registry matches the port number that the Docker Registry is
> listening on.

1.  Ensure that the device-mapper package is up to date:

sudo yum -y install device-mapper

1.  Start the Docker Daemon shell script:

sudo &lt;docker-daemon-script-name&gt;

> **NOTE:** In order to run the Docker Daemon shell script from a
> non-root user without prefixing the command with sudo, a docker group
> needs to be created and the non-root user needs to be added to the
> docker group:\
> **sudo groupadd docker**
>
> **sudo usermod -a -G docker &lt;non-root-user&gt; **

<span id="_Ref448174167" class="anchor"><span id="_Toc451280641" class="anchor"></span></span>Building the Docker Registry
--------------------------------------------------------------------------------------------------------------------------

The Docker Registry 2.0 implementation for storing and distributing
Docker images is part of the GitHub Docker Distribution project. The
Docker Distribution project consists of a toolset to pack, ship, store,
and deliver Docker content.

The reason to create your own registry is twofold. First, it is your
private registry. Second, you will create a registry for Linux on z
Systems Docker daemons, which will allow the use of the same unaltered
Dockerfile contents used by the Docker daemon on the x86 platform. This
eliminates source code changes to the Hyperledger fabric code.

**NOTE:** The directory **/&lt;work\_dir&gt;/** used in these
instructions represents a temporary writeable directory of your choice.

1.  Install the dependencies:

sudo yum install -y git make

> Golang is required to build the Docker Registry. See Building Golang
> on page 2 to build the Golang toolchain. You may have already
> installed the **git** and **make** packages when building Golang. If
> so, ignore the installation of the packages within this step.

1.  Create a distribution directory and clone the source code:

mkdir -p /&lt;work\_dir&gt;/src/github.com/docker

cd /&lt;work\_dir&gt;/src/github.com/docker

git clone https://github.com/docker/distribution.git

cd /&lt;work\_dir&gt;/src/github.com/docker/distribution

git checkout v2.3.0

1.  Set **GOPATH** and **DISTRIBUTION\_DIR** environment variables:

export
DISTRIBUTION\_DIR=/&lt;work\_dir&gt;/src/github.com/docker/distribution

export GOPATH=/&lt;work\_dir&gt;/

export GOPATH=\$DISTRIBUTION\_DIR/Godeps/\_workspace:\$GOPATH

1.  Build the distribution binaries:

cd /&lt;work\_dir&gt;/src/github.com/docker/distribution

make PREFIX=/&lt;work\_dir&gt;/ clean binaries

1.  Run the Test Suite:

make PREFIX=/&lt;work\_dir&gt;/ test

1.  Start the Docker Registry:

> The Docker Registry fetches the configuration from
> **\$DISTRIBUTION\_DIR/ cmd/registry/config.yml**. The default
> filesystem location where the Docker Registry stores images is
> **/var/lib/registry.**

a.  Copy the config-dev.yml file to config.yml:

cp \$DISTRIBUTION\_DIR/cmd/registry/config-dev.yml
\$DISTRIBUTION\_DIR/cmd/registry/config.yml

a.  Tailor the Docker Registry configuration file and save:

    i.  Change the default storage caching mechanism. If you are not
        using redis for storage caching, edit
        **\$DISTRIBUTION\_DIR/cmd/registry/config.yml** and change the
        **storage.cache.blobdescriptor** parameter from **redis** to
        **inmemory**.

    ii. Change the default listening port of the Docker Registry. Edit
        **\$DISTRIBUTION\_DIR/cmd/registry/config.yml** and change the
        **http.addr** parameter from **5000** to **5050**. This change
        is required because port 5000 conflicts with the Hyperledger
        Fabric peer’s REST service port, which uses port 5000.

b.  Create the default directory to store images, if it does not exist:

sudo mkdir -p /var/lib/registry

a.  Start the Docker Registry:

/&lt;work\_dir&gt;/bin/registry
\$DISTRIBUTION\_DIR/cmd/registry/config.yml

For a more permanent solution when starting the Docker Registry:

1.  Setup homes for the Docker Registry executable binary and its
    configuration file:

sudo mkdir /etc/docker-registry

sudo cp \$DISTRIBUTION\_DIR/cmd/registry/config.yml /etc/docker-registry

sudo cp /&lt;work\_dir&gt;/bin/registry /usr/local/bin

1.  Create a shell script in **/usr/local/bin** to start the Docker
    Registry in the background and redirect all output to a
    logging file. Ensure that the shell script has the executable
    attribute set.

\#!/bin/bash

/usr/local/bin/registry /etc/docker-registry/config.yml &gt;
/var/log/docker-registry.log 2&gt;&1 &

1.  Start the Docker Registry:

sudo &lt;docker-registry-script-name&gt;

For more information on the Docker Distribution project, see
<https://github.com/docker/distribution>.

Build and Install RocksDB
=========================

RocksDB is an embeddable persistent key-value store for fast storage and
is used by the Hyperledger Fabric peer, membership and security service
components.

**NOTE:** The directory **/&lt;work\_dir&gt;/** used in these
instructions represents a temporary writeable directory of your choice.

1.  RocksDB is written using the C++ programming language. Make sure
    that the C++ compiler is installed:

sudo yum -y install gcc-c++

1.  Download and build RocksDB:

cd /&lt;work\_dir&gt;/

git clone --branch v4.5.1 --single-branch --depth 1
https://github.com/facebook/rocksdb.git

cd rocksdb

sed -i -e "s/-march=native/-march=z196/"
build\_tools/build\_detect\_platform

sed -i -e "s/-momit-leaf-frame-pointer/-DDUMMY/" Makefile

make shared\_lib

1.  Copy rocksdb to path /opt:

sudo cp -ra /&lt;work\_dir&gt;/rocksdb /opt/

<span id="_Ref448238924" class="anchor"><span id="_Ref448238936" class="anchor"><span id="_Toc451280643" class="anchor"></span></span></span>Build the Hyperledger Fabric Core
==============================================================================================================================================================================

The Hyperledger Fabric Core contains code for running peers, either
validating or non-validating, and membership services for enrollment and
certificate authority tasks.

**NOTE:** The directory **/&lt;work\_dir&gt;/** used in these
instructions represents the location of the Hyperledger Fabric source
code. The **/&lt;golang\_home&gt;/go** directory represents where Golang
was installed after performing step 4 in Building the Golang Toolchain.
If you built Golang using this document, you have already added the
Golang **bin** directory to your **PATH**.

1.  Install pre-req packages:

sudo yum -y install zlib zlib-devel snappy snappy-devel bzip2
bzip2-devel

1.  Download the Hyperledger Fabric code into a writeable directory:

mkdir -p /&lt;work\_dir&gt;/src/github.com/hyperledger

export GOPATH=&lt;work\_dir&gt;

cd /&lt;work\_dir&gt;/src/github.com/hyperledger

git clone https://github.com/hyperledger/fabric.git

cd fabric

1.  Setup environment variables:

export GOROOT=/&lt;golang\_home&gt;/go

export PATH=/&lt;golang\_home&gt;/go/bin:\$PATH

export CGO\_LDFLAGS="-L/opt/rocksdb -lrocksdb -lstdc++ -lm -lz "

export CGO\_CFLAGS="-I/opt/rocksdb/include"

export LD\_LIBRARY\_PATH=/opt/rocksdb:\$LD\_LIBRARY\_PATH

> **NOTE:** If you are going to be rebuilding Golang or RocksDB, add the
> environment variables in steps 2 and 3 to your **.bash\_profile**
> file. The **LD\_LIBRARY\_PATH** variable must be set when executing
> the peer or membership and security services executable binaries, and
> therefore, should be set in your **.bash\_profile** file.

1.  Build the Hyperledger Fabric executable binaries. The peer binary
    runs validating or non-validating peer nodes and the membersrvc
    binary is the membership and security server that handles enrollment
    and certificate requests:

cd \$GOPATH/src/github.com/hyperledger/fabric/peer

go build -v

cd \$GOPATH/src/github.com/hyperledger/fabric/membersrvc

go build -v

For a more permanent solution, you can create shell scripts to start the
peer and the membership and security services executables in the
background and re-direct logging output to a file.

1.  Create a file called **fabric-peer.sh** located in
    **/usr/local/bin** with the executable attribute set:

\#!/bin/bash

export LD\_LIBRARY\_PATH=/opt/rocksdb

cd **/&lt;work\_dir&gt;/**src/github.com/hyperledger/fabric/peer

./peer node start --logging-level=debug &gt; /var/log/fabric-peer.log
2&gt;&1 &

1.  Create a file called **membersrvc.sh** located in **/usr/local/bin**
    with the executable attribute set:

\#!/bin/bash

export LD\_LIBRARY\_PATH=/opt/rocksdb

cd /&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/membersrvc

./membersrvc &gt; /var/log/membersrvc.log 2&gt;&1 &

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
the **peer deploy** command. Docker containers are started by the peer
and execute the Chaincode binary awaiting further Blockchain
transactions, e.g., invoke or query.

<span id="_Ref448235458" class="anchor"><span id="_Ref448235477" class="anchor"><span id="_Ref448235515" class="anchor"><span id="_Toc451280645" class="anchor"></span></span></span></span>Build a Base RHEL Docker Image
--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

1.  Make sure that your Docker Daemon and Docker Registry are started.
    Refer to Installing the Docker Client / Daemon and Building the
    Docker Registry sections above for building and starting the Docker
    Daemon and Docker Registry.

2.  Copy and paste the contents of
    <https://github.com/docker/docker/blob/master/contrib/mkimage-yum.sh>
    into an empty file on your local RHEL system where the Docker image
    will be created. Place the script into **/usr/local/bin**. Ensure
    the new script file has the executable attribute set.

3.  If you are not using the Red Hat subscription service to update
    packages on your system, add the following lines to your
    **mkimage-yum.sh** script just before the **yum -c "\$yum\_config"
    --installroot="\$target" -y clean** command:

cp -ra /etc/yum/\* "\$target"/etc/yum/\
cp -ra /etc/yum.repos.d "\$target"/etc

yum -c "\$yum\_config" --installroot="\$target" -y install net-tools

> This command will copy all of your existing yum repository definitions
> during the build of the RHEL Docker image. Additional build steps
> access the repositories to install pre-requisite packages during the
> building of additional Docker images used within the Hyperledger
> Fabric environment.

1.  Execute the **mkimage-yum.sh** script to create and import the RHEL
    Docker image:

sudo mkimage-yum.sh rhelbase

1.  <span id="_Ref448235426" class="anchor"></span>Obtain the
    **rhelbase** Docker image’s **TAG**. The **rhelbase:&lt;TAG&gt;** is
    required to build the Golang toolchain Docker image:

docker images

> Look for **rhelbase** in the REPOSITORY column and note the TAG name
> for **rhelbase**.
>
> In the example below the TAG is 7.2.
>
> ![](./media/image4.tmp){width="5.65in" height="0.4in"}
>
> NOTE: Optionally, you can place this base image into your Docker
> registry’s repository by issuing the commands:\
> **docker tag rhelbase:&lt;TAG&gt;
> &lt;docker\_registry\_host\_ip&gt;:5050/rhelbase:&lt;TAG&gt;\
> docker push
> &lt;docker\_registry\_host\_ip&gt;:5050/rhelbase:&lt;TAG&gt;**

Build a Golang Toolchain Docker Image from the Base RHEL Docker Image
---------------------------------------------------------------------

Once the base RHEL Docker image is created, complete the following steps
to build a Golang toolchain Docker image:

**NOTE:** The directory **/&lt;work\_dir&gt;/** used in these
instructions represents a temporary writeable directory of your choice.
The same **/&lt;work\_dir&gt;/** used in the creating of the Golang
toolchain in section Building the Golang Toolchain should be used here.

1.  Make sure that the Docker Daemon and Docker Registry have
    been started. Refer to Installing the Docker Client / Daemon and
    Building the Docker Registry sections above for building and
    starting the Docker Daemon and Docker Registry.

2.  Create a Dockerfile:

cd /&lt;work\_dir&gt;/

vi Dockerfile

> Cut and paste the following lines into your Dockerfile and then save
> the file:

FROM rhelbase:**&lt;TAG&gt;**

RUN yum -y groupinstall "Development Tools"

COPY go /usr/local/go

ENV GOPATH=/opt/gopath

ENV GOROOT=/usr/local/go

ENV PATH=\$GOPATH/bin:/usr/local/go/bin:\$PATH

RUN mkdir -p "\$GOPATH/src" "\$GOPATH/bin" && chmod -R 777 "\$GOPATH"

WORKDIR \$GOPATH

> **NOTE:** Replace **&lt;TAG&gt;** with the TAG value obtained above in
> step 5 of Build a Base RHEL Docker Image.

1.  Make sure that a copy of the **go** directory is in your
    **/&lt;work\_dir&gt;/** directory. If you used the same
    **/&lt;work\_dir&gt;/** directory when performing the instructions
    in section Building the Golang Toolchain then you should already
    have your built **go** directory contained in
    **/&lt;work\_dir&gt;/**.

2.  Issue the **docker build** command:

cd /&lt;work\_dir&gt;/

docker build -t **&lt;docker\_registry\_host\_ip&gt;**:5050/s390x/golang
-f **&lt;docker\_file&gt;** .

> **NOTE:** Replace **&lt;docker\_registry\_host\_ip&gt;** with the IP
> address of the host that is running your Docker Registry. Replace
> **&lt;docker\_file&gt;** with **Dockerfile** or the name of your file
> containing the Docker statements listed in step 2.

1.  Confirm that your new image was created by issuing the **docker
    images** command.

2.  Push your new Golang toolchain Docker image to your Docker Registry:

docker push **&lt;docker\_registry\_host\_ip&gt;**:5050/s390x/golang

> **NOTE:** Replace **&lt;docker\_registry\_host\_ip&gt;** with the IP
> address of the host that is running your Docker Registry.

1.  Update your Hyperledger Fabric peer’s configuration file and save.
    The following change informs the peer to use your Golang toolchain
    Docker image when executing Chaincode transactions:

cd /&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/peer

vi core.yaml

> **NOTE:** The **/&lt;work\_dir&gt;/** directory was established in
> Build the Hyperledger Fabric Core on page 9.
>
> Replace the **chaincode.golang.Dockerfile** parameter (located within
> lines 280-290) with the following:

Dockerfile: |

from **&lt;docker\_registry\_host\_ip&gt;**:5050/s390x/golang

COPY src \$GOPATH/src

WORKDIR \$GOPATH

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

cd /&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/peer

vi core.yaml

> **NOTE:** The **/&lt;work\_dir&gt;/** directory was established in
> Build the Hyperledger Fabric Core on page 9.
>
> Replace the **peer.Dockerfile** parameter (located within lines
> 90-100) with the following:

Dockerfile: |

from **&lt;docker\_registry\_host\_ip&gt;**:5050/s390x/golang

\# Install RocksDB

RUN cd /opt && git clone --branch v4.5.1 --single-branch --depth 1
https://github.com/facebook/rocksdb.git && cd rocksdb

WORKDIR /opt/rocksdb

RUN sed -i -e "s/-march=native/-march=zEC12/"
build\_tools/build\_detect\_platform

RUN sed -i -e "s/-momit-leaf-frame-pointer/-DDUMBDUMMY/" Makefile

RUN make shared\_lib

ENV LD\_LIBRARY\_PATH=/opt/rocksdb:\$LD\_LIBRARY\_PATH

RUN yum -y install snappy-devel zlib-devel bzip2-devel

\# Copy GOPATH src and install Peer

COPY src \$GOPATH/src

RUN mkdir -p /var/hyperledger/db

WORKDIR \$GOPATH/src/github.com/hyperledger/fabric/peer

ENV PATH \$GOPATH/bin:\$PATH

RUN CGO\_CFLAGS="-I/opt/rocksdb/include" CGO\_LDFLAGS="-L/opt/rocksdb
-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy" go install && cp
\$GOPATH/src/github.com/hyperledger/fabric/peer/core.yaml \$GOPATH/bin

> **NOTE:** Replace **&lt;docker\_registry\_host\_ip&gt;** with the IP
> address of the host that is running your Docker Registry.

1.  Build the **hyperledger-peer** and **membersrvc** Docker images:

cd
**/&lt;work\_dir&gt;/**src/github.com/hyperledger/fabric/core/container

go test -timeout=20m -run BuildImage\_Peer

go test -timeout=20m -run BuildImage\_Obcca

> **NOTE:** The **/&lt;work\_dir&gt;/** directory was established in
> Build the Hyperledger Fabric Core on page 9. Both of the images are
> also built when running the Unit Tests.

1.  Verify that the **hyperledger-peer** and **membersrvc** images are
    displayed after issuing a **docker images** command:

docker images

Unit Tests
==========

If you feel inclined to run the Hyperledger Fabric unit tests, there are
a few minor changes that need to be made to some Golang test files prior
to invoking the unit tests.

Test File Changes
-----------------

1.  Edit
    **/&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/membersrvc/ca/ca\_test.yaml**
    and replace the **peer.Dockerfile** parameter with the following:

Dockerfile: |

from **&lt;docker\_registry\_host\_ip&gt;**:5050/s390x/golang

\# Install RocksDB

RUN cd /opt && git clone --branch v4.5.1 --single-branch --depth 1
https://github.com/facebook/rocksdb.git && cd rocksdb

WORKDIR /opt/rocksdb

RUN sed -i -e "s/-march=native/-march=zEC12/"
build\_tools/build\_detect\_platform

RUN sed -i -e "s/-momit-leaf-frame-pointer/-DDUMBDUMMY/" Makefile

RUN make shared\_lib

ENV LD\_LIBRARY\_PATH=/opt/rocksdb:\$LD\_LIBRARY\_PATH

RUN yum -y install snappy-devel zlib-devel bzip2-devel

\# Copy GOPATH src and install Peer

COPY src \$GOPATH/src

RUN mkdir -p /var/hyperledger/db

WORKDIR \$GOPATH/src/github.com/hyperledger/fabric/peer

ENV PATH \$GOPATH/bin:\$PATH

RUN CGO\_CFLAGS="-I/opt/rocksdb/include" CGO\_LDFLAGS="-L/opt/rocksdb
-lrocksdb -lstdc++ -lm -lz -lbz2 -lsnappy" go install && cp
\$GOPATH/src/github.com/hyperledger/fabric/peer/core.yaml \$GOPATH/bin

1.  Edit
    **/&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/membersrvc/ca/ca\_test.yaml**
    and replace the **chaincode.golang.Dockerfile** parameter with the
    following:

Dockerfile: |

from **&lt;docker\_registry\_host\_ip&gt;**:5050/s390x/golang

COPY src \$GOPATH/src

WORKDIR \$GOPATH

1.  Perform steps 1 and 2 for file
    **/&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/core/ledger/genesis/genesis\_test.yaml.**

2.  Edit
    **/&lt;work\_dir&gt;/src/github.com/hyperledger/fabric/core/container/controller\_test.go**
    and replace **busybox** with **s390x/busybox**.

> **NOTE:** The **/&lt;work\_dir&gt;/** directory was established in
> Build the Hyperledger Fabric Core on page 9. Replace
> **&lt;docker\_registry\_host\_ip&gt;** with the IP address of the host
> that is running your Docker Registry.

Running the Unit Tests
----------------------

1.  Bring up a window (via ssh or screen) of the system where you built
    the Hyperledger Fabric components and start the Fabric Peer:

cd **/&lt;work\_dir&gt;/**src/github.com/hyperledger/fabric/peer

sudo LD\_LIBRARY\_PATH=/opt/rocksdb:\$LD\_LIBRARY\_PATH ./peer node
start

1.  From another window of the same Linux system, create an executable
    script called **unit-tests.sh** in **/&lt;work\_dir&gt;/** using the
    following lines:

\#!/bin/bash

export GOPATH=/&lt;work\_dir&gt;/

export GOROOT=/&lt;golang\_home&gt;/go

export PATH=/&lt;golang\_home&gt;/go/bin:\$PATH

export CGO\_LDFLAGS="-L/opt/rocksdb -lrocksdb -lstdc++ -lm -lz "

export CGO\_CFLAGS="-I/opt/rocksdb/include"

export LD\_LIBRARY\_PATH=/opt/rocksdb:\$LD\_LIBRARY\_PATH

go test -timeout=20m \$(go list github.com/hyperledger/fabric/... | grep
-v /vendor/ | grep -v /examples/)

> **NOTE:** If you have root access and would like to run the unit
> tests, simply set the environment variables listed above and then
> issue the go test command. Also, replace **/&lt;work\_dir&gt;/** with
> the directory used when building the Hyperledger Fabric components in
> Build the Hyperledger Fabric Core on page 9. Replace
> **/&lt;golang\_home&gt;/** with the directory where Golang was
> installed after performing step 4 in Building the Golang Toolchain on
> page 4.

1.  Invoke the unit-tests.sh script:

cd /&lt;work\_dir&gt;/

sudo ./unit-tests.sh
