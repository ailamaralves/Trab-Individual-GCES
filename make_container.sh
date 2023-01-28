echo $'#!/bin/bash

IMAGE_PATH=$1

for ARGUMENT in "$@"
    do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE=$(echo $ARGUMENT | cut -f2 -d=)

    case "$KEY" in
        CPU)   CPU=${VALUE} ;;
        RAM)   RAM=${VALUE} ;;     
        *)   
    esac    
done


function createRandomContainerName()
{
    local prefix=$(</dev/urandom tr -dc a-z | head -c 1)
    local randomName=$(</dev/urandom tr -dc a-z0-9_ | head -c 12)
    echo "$prefix$randomName"
}
containerName=$(createRandomContainerName)
export containerName


function prepareFoldersForOverlayFS() {
    mkdir -p /tmp/$containerName/{upper,workdir,overlay}
}


function createOverlayFS()
{
    mount -t \
        overlay -o lowerdir=$IMAGE_PATH,upperdir=/tmp/$containerName/upper,workdir=/tmp/$containerName/workdir \
        none \
        /tmp/$containerName/overlay
}


function installBusybox() {  
    chroot /tmp/$containerName/overlay/ /bin/busybox --install -s
}

function createCGroup() {
    sleep 1

    PID=$(ps aux | grep unshare | tail -2 | head -1 | awk \'{print $2}\') 
    
    cgcreate -a $containerName -g cpu,memory:$containerName

    set -x
    echo 5MB > /sys/fs/cgroup/memory/$containerName/memory.limit_in_bytes
    echo 100 > /sys/fs/cgroup/cpu/$containerName/cpu.shares

    # cgexec -g cpu,memory:$containerName $PID
    cgclassify -g cpu,memory:$containerName $PID
    set +x

    # Limit usage at 5% for a multi core system
    # cgset -r cpu.cfs_period_us=100 -r cpu.cfs_quota_us=$[ 5000 * $(getconf _NPROCESSORS_ONLN) ] $containerName

    # Set a limit of 80M
    # cgset -r memory.limit_in_bytes=80M $containerName
}

function setUpContainer() {
    export PS1="$containerName-# ";
    mkdir proc;
    mount -t proc none proc;
    bash
}
export -f setUpContainer

function launchContainer() {
    unshare --mount --uts --ipc --net --pid --fork --user --map-root-user \
    chroot /tmp/$containerName/overlay \
    bash -c "setUpContainer"
}
export -f launchContainer

function makeContainer() {
    set -x

    sudo -u $containerName bash -c "launchContainer"

    set +x
}

prepareFoldersForOverlayFS
createOverlayFS
installBusybox
adduser --disabled-password --gecos "" $containerName
usermod -aG sudo $containerName
printf "\n$containerName ALL=(ALL) NOPASSWD: /usr/sbin/chroot, /usr/bin/unshare\n" >> /etc/sudoers

createCGroup &

makeContainer
' > make_container.sh