#!/bin/bash

      export LC_ALL=en_US.UTF-8
      export LANG=en_US.UTF-8
      export LANGUAGE=en_US.UTF-8
    
      echo "IPAFileName:$AC_APP_FILE_NAME"
      echo "IPAFileUrl:$AC_APP_FILE_URL"
      echo "AppleId:$AC_APPLE_ID"
      echo "BundleId:$AC_BUNDLE_ID"
      echo "AppleUserName:$AC_APPLE_APP_SPECIFIC_USERNAME"
      echo "ApplicationSpecificPassword:$AC_APPLE_APP_SPECIFIC_PASSWORD"
      echo "AppStoreConnectApiKey:$AC_API_KEY"
      echo "AppStoreConnectApiKeyFileName:$AC_API_KEY_FILE_NAME"
      echo "appleStoreSubmitApiType:$AC_APPLE_STORE_SUBMIT_API_TYPE"
      echo "Fastlane Version: $AC_FASTLANE_VERSION"
      
      locale
      curl -o "./$AC_APP_FILE_NAME" -k $AC_APP_FILE_URL
  
download_screenshots_or_apppreviews() {

      local json_file="$1"
      local itemTypeForPath="$2"
      local continueDownload="true"; 

      if [[ ! -f "$json_file" ]]; then
        echo "file '$json_file' not found for $itemTypeForPath !" >&2
        continueDownload="false";
      fi


      if [[ ! -s "$json_file" ]] || ! jq -e '.[]' "$json_file" > /dev/null 2>&1; then
        echo "Warning: file list '$json_file' is empty or not a valid, $json_file downloading is skipping..." >&2
        continueDownload="false";
      fi

    if [[ "$continueDownload" == "true" ]]; then
     
        counter=1

        for entry in $(jq -c '.[]' "$json_file"); do
            local signed_url=$(echo "$entry" | jq -r '.SignedUrl')
            local lang=$(echo "$entry" | jq -r '.Lang')
            local order=$(echo "$entry" | jq -r '.Order')
            local display_type=$(echo "$entry" | jq -r '.ScreenshotDisplayType')
            local filename=$(basename "$signed_url" | cut -d'?' -f1)
            local extension="${filename##*.}"  # Get the file extension
            new_filename="${order}_${counter}_${lang}_${display_type}.${extension}"

            target_dir="./fastlane/$itemTypeForPath/$lang"

            if [[ ! -d "$target_dir" ]]; then
                mkdir -p "$target_dir"
            fi
        
            ((counter++))

            curl -o "$target_dir/$new_filename" -k "$signed_url"
            echo "Downloaded screenshot: $new_filename to $target_dir"
        done
    fi
}

# Downloads the Apple reviewer attachment into ./fastlane/review_attachment/attachment.<ext>.
# Matches the path referenced by the generated Fastfile (File.exist?-guarded, so a skip/failure
# never breaks `fastlane deliver`). AC_REVIEW_ATTACHMENT may be an inline signed URL, or a path
# to a file the agent wrote (containing a bare URL or {SignedUrl,Extension} JSON).
download_review_attachment() {
    local raw="$1"
    local ext="${AC_REVIEW_ATTACHMENT_EXT:-}"

    if [[ -z "$raw" ]]; then
        echo "No app review attachment provided. Skipping."
        return 0
    fi

    local signed_url=""
    if [[ -f "$raw" ]]; then
        if jq -e '.SignedUrl' "$raw" > /dev/null 2>&1; then
            signed_url=$(jq -r '.SignedUrl' "$raw")
            [[ -z "$ext" ]] && ext=$(jq -r '.Extension // empty' "$raw" 2>/dev/null)
        else
            signed_url=$(tr -d ' \t\r\n' < "$raw")
        fi
    else
        signed_url="$raw"
    fi

    if [[ -z "$signed_url" ]]; then
        echo "App review attachment URL is empty. Skipping."
        return 0
    fi

    if [[ -z "$ext" ]]; then
        local fname; fname=$(basename "$signed_url" | cut -d'?' -f1)
        ext="${fname##*.}"
        [[ -z "$ext" || "$ext" == "$fname" ]] && ext="bin"
    fi

    mkdir -p ./fastlane/review_attachment
    if curl -fSL --retry 3 --retry-delay 2 -k -o "./fastlane/review_attachment/attachment.${ext}" "$signed_url"; then
        echo "Downloaded app review attachment -> ./fastlane/review_attachment/attachment.${ext}"
    else
        echo "Warning: app review attachment download failed, continuing without it." >&2
    fi
}

if [[ -f "$AC_METADATA_LOCALIZATION_LIST" && -s "$AC_METADATA_LOCALIZATION_LIST" ]]; then

    jq -c '.[]' "$AC_METADATA_LOCALIZATION_LIST" | while IFS= read -r entry; do

        language_code=$(echo "$entry" | jq -r '.lang')
        metadata=$(echo "$entry")

        target_dir="./fastlane/metadata/$language_code"
        
        if [[ ! -d "$target_dir" ]]; then
            mkdir -p "$target_dir"
        fi

        # Set empty string for any null values
        description=$(echo "$metadata" | jq -r '.description // ""')
        keywords=$(echo "$metadata" | jq -r '.keywords // ""')
        supportUrl=$(echo "$metadata" | jq -r '.supportUrl // ""')
        marketingUrl=$(echo "$metadata" | jq -r '.marketingUrl // ""')
        whatsNew=$(echo "$metadata" | jq -r '.whatsNew // ""')
        promotionalText=$(echo "$metadata" | jq -r '.promotionalText // ""')
     
        echo "$description" > "$target_dir/description.txt"
        echo "$keywords" > "$target_dir/keywords.txt"
        echo "$supportUrl" > "$target_dir/support_url.txt"
        echo "$marketingUrl" > "$target_dir/marketing_url.txt"
        echo "$promotionalText" > "$target_dir/promotional_text.txt"

        if [ -n "$whatsNew" ]; then
            echo "$whatsNew" > "$target_dir/whatsNew.txt"
            echo "$whatsNew" > "$target_dir/release_notes.txt"
        else
            echo "" > "$target_dir/whatsNew.txt"
            echo "" > "$target_dir/release_notes.txt"
        fi

    done
fi

     download_screenshots_or_apppreviews "$AC_SCREEN_SHOT_LIST" "screenshots"
     download_screenshots_or_apppreviews "$AC_APP_PREVIEW_LIST" "app_previews"
     download_review_attachment "$AC_REVIEW_ATTACHMENT"

     if [ "$AC_APPLE_STORE_SUBMIT_API_TYPE" == 1 ] || [ "$AC_APPLE_STORE_SUBMIT_API_TYPE" == "AppStoreConnectApiConnection" ]; then
 
        bundle init

        if [ -z "$AC_FASTLANE_VERSION" ] || [ "$AC_FASTLANE_VERSION" = "latest" ]; then
                echo 'gem "fastlane"' >> Gemfile
                echo "Using latest fastlane version"
        else
                echo "Using fastlane version: $AC_FASTLANE_VERSION"
                echo "gem \"fastlane\", \"$AC_FASTLANE_VERSION\"" >> Gemfile
        fi

        bundle add multi_json
        bundle install
        mkdir fastlane
        touch fastlane/Appfile
        touch fastlane/Fastfile
        mv $AC_FASTFILE_CONFIG "fastlane/Fastfile"

        # --- GECICI DEBUG: Fastfile + review_attachment kontrolu (kok neden bulununca KALDIR) ---
        echo "---FASTFILE BEGIN---"
        cat fastlane/Fastfile
        echo "---FASTFILE END---"
        echo "---REVIEW_ATTACHMENT DIR---"
        ls -la fastlane/review_attachment/ 2>/dev/null || echo "review_attachment klasoru YOK"
        echo "---AC_REVIEW_ATTACHMENT_EXT=$AC_REVIEW_ATTACHMENT_EXT---"
        echo "---END DEBUG---"

        # cat $FastFileConfig || true
        # cat $ScreenShotList || true
        # cat $AppPreviewList || true

        mv "$AC_API_KEY" "$AC_API_KEY_FILE_NAME"
 
          bundle exec fastlane doMetaData --verbose
          if [ $? -eq 0 ] 
          then
            echo "Metadata progress succeeded"
            exit 0
          else
            echo "Metadata progress failed :" >&2
            exit 1
          fi
        fi
