#! /bin/bash

assign_file_name () {
    if [ -v CI ]; then
        FILENAME="$1.iso"
    else
        IS_GIT=$(git rev-parse --is-inside-work-tree 2>&1)
        if [ $IS_GIT ]; then
            GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
            GIT_COMMIT=$(git rev-parse --short HEAD)
            DATE=$(date -u '+%Y%m%d')
            FILENAME="$(basename $GIT_BRANCH)-init-$DATE.$GIT_COMMIT.iso"
        fi
    fi
    echo $FILENAME
}

# check if above arrays have same length

build_linux_oses () {
    declare -a LINUXIMAGES=(
        "https://releases.ubuntu.com/22.04.5/ubuntu-22.04.5-live-server-amd64.iso"
    )

    declare -a LINUXOSDIRS=(
        # "ubuntu-server-22-04-5"
    )

    declare -a VAULTLINUXOSES=(
        "vault-ubuntu-minimal"
    )

    IMAGESLENGTH=${#LINUXIMAGES[@]}
    OSESLENGTH=${#LINUXOSDIRS[@]}
    VAULTSLENGTH=${#VAULTLINUXOSES[@]}

    if [ $IMAGESLENGTH -ne $OSESLENGTH ] || [ $OSESLENGTH -ne $VAULTLINUXOSES ] || [ $IMAGESLENGTH -ne $VAULTLINUXOSES ]; then
        echo "IMAGESLENGTH, OSESLENGTH, VAULTLINUXOSES are not of equal lengths. Recheck array entries."
        exit 1
    fi

    for (( i=0; i<${IMAGESLENGTH}; i++ ));
    do
        TARGETFILENAME=$(assign_file_name "${VAULTLINUXOSES[$i]}")
        echo "Building $TARGETFILENAME..."
        curl -X GET -OL ${LINUXIMAGES[$i]}
        SOURCEISO=${LINUXIMAGES[$i]##*/}
        echo $SOURCEISO
        7z x -y $SOURCEISO -oiso

        sed -i -e 's/---/ autoinstall  ---/g' iso/boot/grub/grub.cfg
        sed -i -e 's/---/ autoinstall  ---/g' iso/boot/grub/loopback.cfg
        sed -i -e 's,---, ds=nocloud\\;s=/cdrom/nocloud/  ---,g'  iso/boot/grub/grub.cfg
        sed -i -e 's,---, ds=nocloud\\;s=/cdrom/nocloud/  ---,g' iso/boot/grub/loopback.cfg

        mkdir -p iso/nocloud
        cp "${LINUXOSDIRS[$i]}/meta-data" iso/nocloud/
        cp "${LINUXOSDIRS[$i]}/user-data" iso/nocloud/

        xorriso -as mkisofs -r \
            -V ${LINUXOSDIRS[$i]} \
            -o $TARGETFILENAME \
            -J \
            -c '/boot.catalog' \
            -b '/boot/grub/i386-pc/eltorito.img' \
            -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
            -eltorito-alt-boot \
            -isohybrid-gpt-basdat -isohybrid-apm-hfsplus \
            iso/boot iso

        FILESIZE=$(stat -c %s $TARGETFILENAME 2>&1)
        if [[ $FILESIZE > 0 ]]; then
            printf '%s (%d bytes) ... done!\n' $TARGETFILENAME $FILESIZE
        else
            printf 'Something went wrong while trying to build %s\n' $TARGETFILENAME
        fi
    done
}

build_linux_oses