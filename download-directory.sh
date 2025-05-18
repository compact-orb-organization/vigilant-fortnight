#!/usr/bin/bash

# Recursively lists files and directories from the storage.
list_files() {
    # List files in the current directory.
    echo "$1" | jq -r --arg path "$2/" '.[] | select(.IsDirectory == false) | $path + .ObjectName'

    # List directories and recursively call list_files for each.
    echo "$1" | jq -r --arg path "$2/" '.[] | select(.IsDirectory == true) | $path + .ObjectName' | (
        local job_count=0 # Counter for active directory listing jobs.

        # Process each directory.
        while IFS= read -r directory; do
            # Limit parallel directory listing jobs.
            if [ $job_count -ge 50 ]; then
                wait -n # Wait for any single job to complete.

                job_count=$((job_count - 1))
            fi

            # Recursively list files in the subdirectory in the background.
            (
                local attempt=1

                # Retry up to 3 times.
                while [ $attempt -le 3 ]; do
                    # Fetch directory contents.
                    local request=$(curl --header "accept: application/json" --header "accesskey: $ACCESS_KEY" --request GET --silent --url "https://$STORAGE_ENDPOINT/$STORAGE_ZONE_NAME$directory/")

                    # Check if curl command was successful.
                    if [ "$?" -eq 0 ]; then
                        list_files "$request" $directory

                        break
                    else
                        # If not the last attempt, wait before retrying.
                        if [ $attempt -lt 3 ]; then
                            sleep 2
                        fi
                    fi
                done
            ) &

            job_count=$((job_count + 1)) # Increment active job count.
        done

        wait # Wait for all background directory listing jobs to complete.
    )
}

# Initial call to list_files for the root directory specified by $1.
# Pipe the output (list of all files) to the download logic.
attempt=1

# Retry up to 3 times.
while [ $attempt -le 3 ]; do
    # Fetch directory contents
    request=$(curl --header "accept: application/json" --header "accesskey: $ACCESS_KEY" --request GET --silent --url "https://$STORAGE_ENDPOINT/$STORAGE_ZONE_NAME$1/")

    # Check if curl command was successful.
    if [ "$?" -eq 0 ]; then
        break
    else
        # If not the last attempt, wait before retrying.
        if [ $attempt -lt 3 ]; then
            sleep 2
        fi
    fi
done

list_files "$request" $1 | (
    job_count=0 # Counter for active download jobs.

    # Process each file path for download.
    while IFS= read -r file; do
        # Limit parallel download jobs.
        if [ $job_count -ge 50 ]; then
                wait -n # Wait for any single job to complete.

                job_count=$((job_count - 1))
        fi

        # Download the file in the background.
        (
            # Extract the relative path of the file for local storage.
            path="${file%/*}"

            # Download the file using aria2c, preserving directory structure.
            # $2 is the local target directory.
            # ${path#$1} removes the initial remote path prefix to create the correct local subdirectory.
            aria2c --dir=$2${path#$1} --header="accesskey: $ACCESS_KEY" --header="accept: */*" --quiet https://$STORAGE_ENDPOINT/$STORAGE_ZONE_NAME$file
        ) &

        job_count=$((job_count + 1)) # Increment active job count.
    done

    wait # Wait for all background download jobs to complete.
)
