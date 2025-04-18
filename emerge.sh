# Copy custom locale definitions into /etc and rebuild the locale database
cp /root/workspace/locale.gen /etc/
locale-gen
# Select the desired locale entry
eselect locale set 6

# Deploy all Portage configuration files from the workspace
cp --recursive /root/workspace/portage/* /etc/portage/

# Persist S3 credentials into a script for later use by rclone
echo s3_access_key_id=$S3_ACCESS_KEY_ID >> /etc/portage/s3.sh
echo s3_endpoint=$S3_ENDPOINT >> /etc/portage/s3.sh
echo s3_secret_access_key=$S3_SECRET_ACCESS_KEY >> /etc/portage/s3.sh
echo s3_bucket=$S3_BUCKET >> /etc/portage/s3.sh

# Create the binrepos.conf file for Portage
if [[ ! " $* " =~ " --no-binpkg " ]]; then
    echo $BINREPOS_CONF | base64 --decode > /etc/portage/binrepos.conf
fi

# Download and install rclone for interacting with S3 storage
wget --directory-prefix=/tmp https://downloads.rclone.org/v1.69.1/rclone-v1.69.1-linux-amd64.zip
unzip /tmp/rclone-v1.69.1-linux-amd64.zip rclone-v1.69.1-linux-amd64/rclone -d /tmp
mv /tmp/rclone-v1.69.1-linux-amd64/rclone /usr/local/bin
rm --recursive /tmp/rclone-v1.69.1-linux-amd64*

# Refresh the Portage tree from Gentoo mirrors
emerge-webrsync

# Select the desired profile
eselect profile set 26

# Load S3 credentials and download Packages to binpkgs
source /etc/portage/s3.sh
if [[ ! " $* " =~ " --new-packages " ]]; then
    rclone --config /etc/portage/rclone.conf --s3-access-key-id $s3_access_key_id --s3-endpoint $s3_endpoint --s3-secret-access-key $s3_secret_access_key copy 1:$s3_bucket/Packages /var/cache/binpkgs/
fi

# Re-emerge all previously installed packages
emerge @installed
