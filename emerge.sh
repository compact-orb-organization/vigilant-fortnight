# Copy custom locale definitions into /etc and rebuild the locale database
cp /root/workspace/locale.gen /etc/
locale-gen

# Select the desired locale entry
eselect locale set 6

# Refresh the Portage tree from Gentoo mirrors
emerge-webrsync

# Select the desired profile
eselect profile set 26

# Deploy all Portage configuration files from the workspace
cp --recursive /root/workspace/portage/* /etc/portage/

# Remove default Gentoo binhost to use custom S3 bucket
rm /etc/portage/binrepos.conf/gentoobinhost.conf
# Substitute actual bucket name into custom binrepos config
sed --in-place "s|\$S3_BUCKET|${S3_BUCKET}|g" /etc/portage/binrepos.conf/vigilant-fortnight.conf

# Download and install rclone for interacting with S3 storage
wget --directory-prefix=/tmp https://downloads.rclone.org/v1.69.1/rclone-v1.69.1-linux-amd64.zip
unzip /tmp/rclone-v1.69.1-linux-amd64.zip rclone-v1.69.1-linux-amd64/rclone -d /tmp
mv /tmp/rclone-v1.69.1-linux-amd64/rclone /usr/local/bin
rm --recursive /tmp/rclone-v1.69.1-linux-amd64*

# Install fuse (needed for rclone mount) and then mount the remote binpkg cache
FEATURES="-buildpkg -getbinpkg" emerge sys-fs/fuse

# Mount S3 bucket to /var/cache/binpkgs using rclone
rclone --config /etc/portage/rclone.conf --s3-access-key-id $S3_ACCESS_KEY_ID --s3-endpoint $S3_ENDPOINT --s3-secret-access-key $S3_SECRET_ACCESS_KEY mount 1:$S3_BUCKET /var/cache/binpkgs --allow-other --daemon

# Re-emerge all previously installed packages
emerge @installed
