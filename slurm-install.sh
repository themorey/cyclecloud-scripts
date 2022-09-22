#!/bin/bash

set -x

export VER=20.11.7-1
export ccSlurmVer=2.4.7

# Make placeholder dir for CycleCloud
mkdir -p /opt/cycle/jetpack/system/chef/cache/jetpack/downloads

# Determine OS version for pluginName
if grep -q 'VERSION_ID="8"' /etc/os-release; then
    pluginName="job_submit_cyclecloud_centos8_${VER}.so"
    OS=el8
  else
    pluginName="job_submit_cyclecloud_centos_${VER}.so"
    OS=el7
fi

# Create slurm and munge users if needed (11100 and 11101 are CycleCloud default values for RHEL/CentOS/Alma)
if ! grep -q "slurm" /etc/passwd; then
    useradd -u 11100 --no-create-home slurm
fi
if ! grep -q "munge" /etc/passwd; then
    useradd -u 11101 --no-create-home munge
fi

yum install -y epel-release
yum install -y munge nfs-utils

# Remove existing Slurm placeholder files (if they exist)
if ls /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/slurm* 1> /dev/null 2>&1; then
    rm -rf /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/slurm*.rpm
fi

# Create a declarative array to index the slurm rpms
declare -a slurmrpms
slurmrpms=( "slurm" "slurm-devel" "slurm-example-configs" "slurm-slurmctld" "slurm-slurmd" "slurm-perlapi" "slurm-torque" "slurm-openlava" "slurm-libpmi" )

# Loop through the RPMs in the array to download and install each
for rpm in "${slurmrpms[@]}"; do
    # Download RPM from CycleCloud Slurm repo
    wget -O /tmp/${rpm}-${VER}.${OS}.x86_64.rpm  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${rpm}-${VER}.${OS}.x86_64.rpm
    
    # install RPM from CycleCloud Slurm repo
    yum install -y /tmp/${rpm}-${VER}.${OS}.x86_64.rpm
    
    # touch the filename in /opt/cycle/jetpack/system/chef/cache/jetpack/downloads so Cycle will not re-install it
    touch /opt/cycle/jetpack/system/chef/cache/jetpack/downloads/${rpm}-${VER}.${OS}.x86_64.rpm
done

# Install Job Submit Plugin for CycleCloud
wget -O /usr/lib64/slurm/job_submit_cyclecloud.so  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${pluginName}
touch /etc/cyclecloud-job-submit.installed

rm -rf /tmp/slurm*.rpm*
