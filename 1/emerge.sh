# Set the date for the Portage snapshot
portage_snapshot_date="20250504"

# Set up error trapping: if any command fails, set the 'error' variable to true
error=false
trap 'error=true' ERR

# Generate the specified locales
locale-gen --quiet

# Set the system locale
eselect --brief locale set 6

# Sync the main Gentoo ebuild repository using emerge-webrsync
emerge-webrsync --revert=$portage_snapshot_date --quiet

# Set the Gentoo profile
eselect --brief profile set 26

# Emerge the packages passed as the first argument ($1) to the script, with a timeout
timeout 19800 emerge $1

# Exit with status 1 if any command failed during the script execution
if $error; then
    exit 1
fi
