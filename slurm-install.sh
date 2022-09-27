#!/bin/bash

set -x

export VER=20.11.7-1
export ccSlurmVer=2.6.5

# Make placeholder dir for CycleCloud
mkdir -p /opt/cycle/jetpack/system/chef/cache/jetpack/downloads

# Determine OS version for pluginName
if grep -q "el8" /etc/os-release; then
    pluginName="job_submit_cyclecloud_centos8_${VER}.so"
    OS=el8
elif grep -q "ID=ubuntu" /etc/os-release; then
    pluginName="job_submit_cyclecloud_ubuntu_${VER}.so"
    OS=ubuntu
    groupadd -g 64030 slurm && useradd -u 64030 -g 64030 --no-create-home slurm
else
    pluginName="job_submit_cyclecloud_centos_${VER}.so"
    OS=el7
fi

# Create slurm and munge users if needed (11100 and 11101 are CycleCloud default values for RHEL/CentOS/Alma)
if ! grep -q "slurm" /etc/passwd && [ "${OS}" != "ubuntu" ]; then
    useradd -u 11100 --no-create-home slurm
fi
if ! grep -q "munge" /etc/passwd; then
    useradd -u 11101 --no-create-home munge
fi


# Install dependencies
if [ "${OS}" == "ubuntu" ]; then
  apt update && apt upgrade
  apt autoclean
  apt install -y munge nfs-common libevent-dev
else
  yum install -y epel-release
  yum install -y perl munge nfs-utils libevent-devel
fi


# Remove existing Slurm placeholder files (if they exist)
if ls /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/slurm* 1> /dev/null 2>&1; then
    rm -rf /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/slurm*.{rpm*,deb*}
fi

# Create a declarative array to index the slurm rpms
declare -a slurmrpms
slurmpkgs=( "slurm" "slurm-devel" "slurm-example-configs" "slurm-slurmctld" "slurm-slurmd" "slurm-perlapi" "slurm-torque" "slurm-openlava" "slurm-libpmi" )

# Loop through the RPMs in the array to download and install each
for pkg in "${slurmpkgs[@]}"; do
    if [ "${OS}" == "ubuntu" ]; then
        # Download DEB from CycleCloud Slurm repo
        wget -O /tmp/${pkg}_${VER}_amd64.deb  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${pkg}_${VER}_amd64.deb
    
        # install RPM from CycleCloud Slurm repo
        apt install -y /tmp/${pkg}_${VER}_amd64.deb
    
        # touch the filename in /opt/cycle/jetpack/system/chef/cache/jetpack/downloads so Cycle will not re-install it
        touch /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/${pkg}_${VER}_amd64.deb
    else
        # Download RPM from CycleCloud Slurm repo
        wget -O /tmp/${pkg}-${VER}.${OS}.x86_64.rpm  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${pkg}-${VER}.${OS}.x86_64.rpm
    
        # install RPM from CycleCloud Slurm repo
        yum install -y /tmp/${pkg}-${VER}.${OS}.x86_64.rpm
    
        # touch the filename in /opt/cycle/jetpack/system/chef/cache/jetpack/downloads so Cycle will not re-install it
        touch /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/${pkg}-${VER}.${OS}.x86_64.rpm
    fi
done

# Install Job Submit Plugin for CycleCloud
wget -O /usr/lib64/slurm/job_submit_cyclecloud.so  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${pluginName}
touch /etc/cyclecloud-job-submit.installed

rm -rf /tmp/slurm*.{deb*,rpm*}

#Install PMIx_v3
mkdir -p /opt/pmix/v3
cd /tmp
wget https://github.com/openpmix/openpmix/archive/refs/tags/v3.1.6.tar.gz -O openpmix-v3.1.6.tar.gz
tar xzf openpmix-v3.1.6.tar.gz
cd openpmix-3.1.6/
./autogen.sh
./configure --prefix=/opt/pmix/v3
make -j install >/dev/null
