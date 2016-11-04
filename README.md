**NOTE: Due to the evolving Hyperledger Fabric codebase, there will be times that the
information contained in this repository will become obsolete. Every effort is
made to keep this documentation current and in sync with the codebase.
Thanks for your understanding.**


Overview
--------

The files contained in this repository focus on building out the Hyperledger Fabric environment on Linux on z Systems.

For those that are interested in what it takes to build a complete Hyperledger Fabric from scratch, the following documents can be found in the *manual-install* branch of this repository.  These documents take you through the manual process of setting up Hyperledger Fabric on your Linux on z Systems instances:
- build-hyperledgerFabric-for-RHEL-linux-on-z.md
- build-hyperledgerFabric-for-SLES-linux-on-z.md
- build-hyperledgerFabric-for-UBUNTU-linux-on-z.md


There is a build script is included in this repository that automates the creation of a Hyperledger Fabric environment for Linux on zSystems instances.

Help Information for zSystemsFabricBuild.sh
-------------------------------------------

```
Usage:  zSystemsFabricBuild.sh options

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
    - IBM Java 1.8
    - Nodejs 6.7.0
    - Hyperledger Fabric core components -- Peer and Membership Services

