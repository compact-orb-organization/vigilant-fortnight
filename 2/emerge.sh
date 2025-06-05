#!/usr/bin/bash

set -eo pipefail

# Source environment variables.
source /tmp/env.sh

# Sync the main Gentoo ebuild repository using emerge-webrsync.
emerge-webrsync --revert=$PORTAGE_SNAPSHOT_DATE --quiet

if [ "$1" = first ]; then
    # Generate the specified locales.
    locale-gen --quiet

    # Set the system locale.
    eselect --brief locale set 6

    echo "*/* -pgo" > /etc/portage/package.use/temporary

    echo "*/* gcc.conf" > /etc/portage/package.env/temporary

    emerge llvm-core/clang

    rm /etc/portage/package.env/temporary
elif [ "$2" = long ]; then
    # Emerge the packages passed as the first argument ($1) to the script, with a timeout.
    timeout 34200 emerge $1
elif [ "$2" = oneapi ]; then
    emerge net-misc/aria2
    
    aria2c --dir=/mnt --header="AccessKey: $ACCESS_KEY" --header="accept: */*" https://$STORAGE_ENDPOINT/$STORAGE_ZONE_NAME/intel-dpcpp-cpp-compiler-2025.1.1.9_offline.sh
    bash /mnt/intel-dpcpp-cpp-compiler-2025.1.1.9_offline.sh -a --eula accept --silent
    rm /mnt/intel-dpcpp-cpp-compiler-2025.1.1.9_offline.sh

    timeout 19800 emerge $1
elif [ "$2" = ccache ]; then
    emerge dev-util/ccache

    export FEATURES="ccache" CCACHE_DIR="/var/tmp/ccache" CCACHE_MAXSIZE="0"

    timeout 19800 emerge $1
else
    # Emerge the packages passed as the first argument ($1) to the script, with a timeout.
    timeout 19800 emerge $1
fi

# Remove orphaned dependencies.
emerge --depclean
