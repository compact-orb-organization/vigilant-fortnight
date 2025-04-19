# Copy custom locale definitions into /etc and rebuild the locale database
cp /root/workspace/locale.gen /etc/
locale-gen

# Select the desired locale entry
eselect locale set 6

# Refresh the Portage tree from Gentoo mirrors
emerge-webrsync

# Select the desired profile
eselect profile set 26

# Deploy Portage configuration files
cp --recursive /root/workspace/portage/ /etc/

# Remove default Gentoo binhost
rm /etc/portage/binrepos.conf/gentoobinhost.conf

# Copy and configure AWS credentials
cp --recursive /root/workspace/.aws/ /root/
sed --in-place "s/aws_access_key_id = /aws_access_key_id = $S3_ACCESS_KEY_ID/" /root/.aws/credentials
sed --in-place "s/aws_secret_access_key = /aws_secret_access_key = $S3_SECRET_ACCESS_KEY/" /root/.aws/credentials

# Download and install mountpoint-s3 binary
wget --directory-prefix=/tmp/ https://s3.amazonaws.com/mountpoint-s3-release/latest/x86_64/mount-s3.tar.gz
mkdir --parents /opt/aws/mountpoint-s3
tar --extract --directory=/opt/aws/mountpoint-s3/ --file=/tmp/mount-s3.tar.gz
rm /tmp/mount-s3.tar.gz
ln --symbolic /opt/aws/mountpoint-s3/bin/mount-s3 /usr/local/bin/mount-s3

# Install fuse 2
FEATURES="-buildpkg -getbinpkg" emerge sys-fs/fuse:0

# Mount S3 bucket as Portage binary package cache
mkdir /tmp/s3
mount-s3 --cache /tmp/s3/ --endpoint-url $S3_ENDPOINT --region $S3_REGION $S3_BUCKET /var/cache/binpkgs/

# Re-emerge all previously installed packages and timeout if it takes too long
emerge @installed
