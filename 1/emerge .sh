#!/usr/bin/bash

set -eo pipefail

# Set the date for the Portage snapshot.
portage_snapshot_date="20250504"

if [ "$2" = first ]; then
    # Generate the specified locales.
    locale-gen --quiet

    # Set the system locale.
    eselect --brief locale set 6

    # Set the Gentoo profile
    eselect --brief profile set 26
fi

# Sync the main Gentoo ebuild repository using emerge-webrsync.
emerge-webrsync --revert=$portage_snapshot_date --quiet

# Emerge the packages passed as the first argument ($1) to the script, with a timeout.
timeout 18000 emerge $1

# Remove orphaned dependencies.
emerge --depclean
