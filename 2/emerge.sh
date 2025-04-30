# Set up error trapping: if any command fails, set the 'error' variable to true
error=false
trap 'error=true' ERR

# Copy the custom Portage configuration from the workspace into the container's /etc/
cp --recursive /root/workspace/portage/ /etc/

# Remove the default Gentoo binary package host configuration
rm /etc/portage/binrepos.conf/gentoobinhost.conf

# Sync the main Gentoo ebuild repository using emerge-webrsync
emerge-webrsync --quiet

# Download, extract, install, and clean up the AWS CLI v2
wget --directory-prefix=/tmp/ --no-verbose https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.0.30.zip
unzip -q /tmp/awscli-exe-linux-x86_64-2.0.30.zip -d /tmp/
rm /tmp/awscli-exe-linux-x86_64-2.0.30.zip
/tmp/aws/install
rm --recursive /tmp/aws/

# Download, extract, install, and clean up the mount-s3 tool
wget --directory-prefix=/tmp/ --no-verbose https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.tar.gz
mkdir --parents /opt/aws/mountpoint-s3
tar --extract --directory=/opt/aws/mountpoint-s3/ --file=/tmp/mount-s3.tar.gz
rm /tmp/mount-s3.tar.gz
ln --symbolic /opt/aws/mountpoint-s3/bin/mount-s3 /usr/local/bin/mount-s3

# Emerge sys-fs/fuse, explicitly disabling binary package creation for this specific package
# FUSE is needed for mount-s3
FEATURES="-buildpkg" emerge sys-fs/fuse:0

# Create the AWS credentials directory and file using environment variables
mkdir /root/.aws
echo -e "[$S3_BUCKET]\naws_access_key_id = $S3_ACCESS_KEY_ID\naws_secret_access_key = $S3_SECRET_ACCESS_KEY" > /root/.aws/credentials
chmod 600 /root/.aws/credentials

# Create a mount point and mount the specified S3 bucket/prefix using mount-s3
# The mount uses a temporary directory for caching and is read-only
mkdir /tmp/mountpoint
mount-s3 --cache /tmp/ --endpoint-url https://$S3_ENDPOINT --force-path-style --prefix 2/ --profile $S3_BUCKET --read-only --region $S3_REGION $S3_BUCKET /tmp/mountpoint/

# Set up an overlay filesystem for the binary package cache (/var/cache/binpkgs)
# The lower directory is the read-only S3 mount, upper and work directories are temporary local storage
# This allows new binary packages to be written locally before being uploaded
mkdir /tmp/upperdir /tmp/workdir
mount --types overlay overlay --options lowerdir=/tmp/mountpoint/,upperdir=/tmp/upperdir/,workdir=/tmp/workdir/ /var/cache/binpkgs/

# Emerge Git, needed for syncing overlays like GURU
emerge dev-vcs/git

# Sync the GURU overlay repository
emerge --sync guru

# Emerge the packages passed as the first argument ($1) to the script, with a timeout
timeout 19800 emerge $1

# Copy the newly built binary packages (from the overlay's upperdir) to the S3 bucket
aws s3 cp /tmp/upperdir/ s3://$S3_BUCKET/2/ --endpoint-url https://$S3_ENDPOINT --no-progress --profile $S3_BUCKET --recursive --region $S3_REGION

# Exit with status 1 if any command failed during the script execution
if $error; then
    exit 1
fi
