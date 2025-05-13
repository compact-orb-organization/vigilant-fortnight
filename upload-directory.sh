#!/usr/bin/bash

# Find all files (-type f) in the source directory ($1) and print their paths.
find "$1" -type f -print | (
    # Read each file path line by line.
    job_count=0

    while IFS= read -r file; do
        # If the maximum number of jobs are running, wait for one to finish.
        if [ $job_count -ge 100 ]; then
            wait -n # Waits for any single job to complete

            job_count=$((job_count - 1))
        fi

        # Extract the filename relative to the source directory.
        # This will preserve the subdirectory structure on the server.
        filename_on_server="${file#$1/}"
        # Start a subshell for each file to enable parallel uploads.
        (
            attempt=1

            # Retry up to 3 times.
            while [ $attempt -le 3 ]; do
                # Perform the upload using curl.
                # Use filename_on_server to construct the correct target path.
                http_status=$(curl --header "accept: application/json" --header "accesskey: $ACCESS_KEY" --header "content-type: application/octet-stream" --output /dev/null --silent --upload-file "$file" --url "https://$STORAGE_ENDPOINT/$STORAGE_ZONE_NAME$2/" --write-out %{http_code})

                # Check if curl command was successful and HTTP status is 2xx.
                if [ "$?" -eq 0 ] && [ "$http_status" -ge 200 ] && [ "$http_status" -lt 300 ]; then
                    echo "Uploaded $file to $2/$filename_on_server"
                    # Break the retry loop on success.
                    break
                else
                    echo "[$attempt/3] Failed to upload $file to $2/$filename_on_server"
                    # If not the last attempt, wait before retrying.
                    if [ $attempt -lt 3 ]; then
                        sleep 2
                    fi
                fi

                attempt=$((attempt + 1))
            done
        ) & # Run the subshell in the background.

        job_count=$((job_count + 1)) # Increment active job count
    done

    # Wait for all background upload processes to complete.
    wait
)
echo "Done"
