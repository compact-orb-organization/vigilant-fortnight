# Initialize error flag and trap any command failure to set it
error=false
trap 'error=true' ERR

# Copy custom locale definitions into /etc and rebuild the locale database
cp /root/workspace/locale.gen /etc/
locale-gen --quiet

# Select the desired locale entry
eselect --brief locale set 6

# Refresh the Portage tree from Gentoo mirrors
emerge-webrsync --quiet

# Select the desired profile
eselect --brief profile set 26

# Deploy Portage configuration files
cp --recursive /root/workspace/portage/ /etc/

# Remove default Gentoo binhost
rm /etc/portage/binrepos.conf/gentoobinhost.conf

# Copy and configure AWS credentials
mkdir /root/.aws
echo -e "[$S3_BUCKET]\naws_access_key_id = $S3_ACCESS_KEY_ID\naws_secret_access_key = $S3_SECRET_ACCESS_KEY" > /root/.aws/credentials
chmod 600 /root/.aws/credentials

# Download and install AWS CLI
wget --directory-prefix=/tmp/ --no-verbose https://awscli.amazonaws.com/awscli-exe-linux-x86_64-2.22.7.zip
unzip -q /tmp/awscli-exe-linux-x86_64-2.22.7.zip -d /tmp/
rm /tmp/awscli-exe-linux-x86_64-2.22.7.zip
/tmp/aws/install
rm --recursive /tmp/aws/

# Download and install mountpoint-s3 binary
wget --directory-prefix=/tmp/ --no-verbose https://s3.amazonaws.com/mountpoint-s3-release/1.12.0/x86_64/mount-s3-1.12.0-x86_64.tar.gz
mkdir --parents /opt/aws/mountpoint-s3
tar --extract --directory=/opt/aws/mountpoint-s3/ --file=/tmp/mount-s3-1.12.0-x86_64.tar.gz
rm /tmp/mount-s3-1.12.0-x86_64.tar.gz
ln --symbolic /opt/aws/mountpoint-s3/bin/mount-s3 /usr/local/bin/mount-s3

# Install fuse 2
FEATURES="-buildpkg" emerge sys-fs/fuse:0

# Mount S3 bucket as Portage binary package cache
mkdir /tmp/mountpoint
mount-s3 --cache /tmp/ --endpoint-url https://$S3_ENDPOINT --profile $S3_BUCKET --region $S3_REGION $S3_BUCKET /tmp/mountpoint/

# Overlay the remote cache with local changes
mkdir /tmp/upperdir /tmp/workdir
mount --types overlay overlay --options lowerdir=/tmp/mountpoint/,upperdir=/tmp/upperdir/,workdir=/tmp/workdir/ /var/cache/binpkgs/

# Install git
emerge dev-vcs/git

# Sync GURU repository
emerge --sync guru

# Re-emerge all previously installed packages and timeout if it takes too long
timeout 19800 emerge $1

# Copy the local changes to the remote cache
aws s3 cp /tmp/upperdir/ s3://$S3_BUCKET --endpoint-url https://$S3_ENDPOINT --no-progress --profile $S3_BUCKET --recursive --region $S3_REGION

# Exit script with status 1 if any previous command failed
if $error; then
    exit 1
fi
