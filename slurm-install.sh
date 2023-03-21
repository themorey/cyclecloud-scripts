#!/bin/bash

set -x
exec 1>/tmp/slurm_install.log 2>&1

export VER=22.05.3-1   #check available versions here:  https://github.com/Azure/cyclecloud-slurm/releases/tag/2.7.0
export ccSlurmVer=2.7.0

# Make placeholder dir for CycleCloud
mkdir -p /opt/cycle/jetpack/system/chef/cache/jetpack/downloads

# Determine OS version for pluginName
if [[ $VER == *"22.05"* ]]; then
    echo "job_submit.lua will be installed on Scheduler node on startup"
    if grep -q "el8" /etc/os-release; then
        OS=el8
    elif grep -q "ID=ubuntu" /etc/os-release; then
        OS=ubuntu
        groupadd -g 64030 slurm && useradd -u 64030 -g 64030 --no-create-home slurm
    else
        OS=el7
    fi
elif [[ ${ccSlurmVer} == "2.7."* ]]; then
    echo "Lua plugin to be installed by CC at boot"
else
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
    wget -O /usr/lib64/slurm/job_submit_cyclecloud.so  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${pluginName}
    touch /etc/cyclecloud-job-submit.installed
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
  apt update && apt upgrade -y
  apt autoclean
  apt install -y munge nfs-common libevent-dev
  #add library links
  ln -s /lib/x86_64-linux-gnu/libreadline.so.7 /usr/lib/x86_64-linux-gnu/libreadline.so.6
  ln -s /lib/x86_64-linux-gnu/libhistory.so.7 /usr/lib/x86_64-linux-gnu/libhistory.so.6
  ln -s /lib/x86_64-linux-gnu/libncurses.so.5 /usr/lib/x86_64-linux-gnu/libncurses.so.5
  ln -s /lib/x86_64-linux-gnu/libtinfo.so.5 /usr/lib/x86_64-linux-gnu/libtinfo.so.5
  ln -s /usr/lib/x86_64-linux-gnu/libreadline.so.8 /usr/lib/x86_64-linux-gnu/libreadline.so.7
  ln -s /usr/lib/x86_64-linux-gnu/libhistory.so.8 /usr/lib/x86_64-linux-gnu/libhistory.so.7
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
if [ "${OS}" == "ubuntu" ]; then
    slurmpkgs=( "slurm" "slurm-devel" "slurm-example-configs" "slurm-slurmctld" "slurm-slurmd" "slurm-torque" "slurm-openlava" "slurm-libpmi" )
else
    slurmpkgs=( "slurm" "slurm-devel" "slurm-example-configs" "slurm-slurmctld" "slurm-slurmd" "slurm-torque" "slurm-openlava" "slurm-libpmi" "slurm-perlapi" "slurm-contribs" )
fi

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
#wget -O /usr/lib64/slurm/job_submit_cyclecloud.so  https://github.com/Azure/cyclecloud-slurm/releases/download/${ccSlurmVer}/${pluginName}
#touch /etc/cyclecloud-job-submit.installed

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

export PATH=$PATH:/opt/pmix/v3/bin
