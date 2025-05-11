# Set the date for the Portage snapshot
portage_snapshot_date="20250504"

# Set up error trapping: if any command fails, set the 'error' variable to true
error=false
trap 'error=true' ERR

if [ "$2" = first ]; then
    # Generate the specified locales
    locale-gen --quiet

    # Set the system locale
    eselect --brief locale set 6
fi

# Sync the main Gentoo ebuild repository using emerge-webrsync
emerge-webrsync --revert=$portage_snapshot_date --quiet

# Emerge the packages passed as the first argument ($1) to the script, with a timeout
timeout 18000 emerge $1

# Remove orphaned dependencies
emerge --depclean
