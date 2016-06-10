> **NOTE:** On June 9, 2016, a number of changes were applied to the Hyperledger Fabric codebase.  This has affected numerous sections of the documentation contained within this repository.  We are working on updating this documentation as soon as possible.  Thanks for your understanding.


Overview
--------

The files contained in this repository focus on building out the Hyperledger Fabric environment on Linux on z Systems.

For those that are interested in what it takes to build a complete Hyperledger Fabric from scratch, the following documents take you through the manual process of setting up Hyperledger Fabric on your Linux on z Systems instances:
- build-hyperledgerFabric-for-RHEL-linux-on-z.md
- build-hyperledgerFabric-for-SLES-linux-on-z.md
- build-hyperledgerFabric-for-UBUNTU-linux-on-z.md


In addition to the manual build documents, a build script is included in this repository that automates the creation of a Hyperledger Fabric environment for Linux on zSystems instances.

Help Information for zSystemsFabricBuild.sh
-------------------------------------------

```
Usage:  zSystemsFabricBuild.sh options

This script installs and configures a Hyperledger Fabric environment on a Linux on
IBM z Systems instance.  The execution of this script assumes that you are starting
from a new Linux on z Systems instance.  The script will autodetect the Linux distribution
(currently RHEL, SLES, and Ubuntu) as well as the z Systems machine type, and build out
the necessary components.

NOTE: Upon completion of the script, source .bash_profile
(or .profile for Ubuntu) to update your PATH and Hyperledger Fabric related
environment variables.

The default action of the script -- without any arguments -- is
to build the following components:
    - Docker and supporting Hyperledger Fabric Docker images
    - Golang
    - RocksDB
    - Hyperledger Fabric core components -- Peer and Membership Services

     Options:
-b   Build the hyperledger/fabric-baseimage. If this option is not specifed,
     the default action is to pull the hyperledger/fabric-base image from Docker Hub.

-c   Rebuild the Hyperledger Fabric components.  A previous installation is required to use this option.
```

