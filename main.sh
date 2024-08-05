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
        echo "Error: Screenshot list file '$json_file' is empty or not a valid JSON array!" >&2
        continueDownload="false";
      fi

    if [[ "$continueDownload" == "true" ]]; then
     
        counter=1

        for entry in $(jq -c '.[]' "$json_file"); do
            local signed_url=$(echo "$entry" | jq -r '.SignedUrl')
            local lang=$(echo "$entry" | jq -r '.Lang')
            local display_type=$(echo "$entry" | jq -r '.ScreenshotDisplayType')
            local filename=$(basename "$signed_url" | cut -d'?' -f1)
            local extension="${filename##*.}"  # Get the file extension
            new_filename="${counter}_${lang}_${display_type}.${extension}"

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

if [[ -f "$AC_METADATA_LOCALIZATION_LIST" && -s "$AC_METADATA_LOCALIZATION_LIST" ]]; then

    jq -c '.[]' "$AC_METADATA_LOCALIZATION_LIST" | while IFS= read -r entry; do

        language_code=$(echo "$entry" | jq -r '.lang')
        metadata=$(echo "$entry")

        target_dir="./fastlane/metadata/$language_code"
        
        if [[ ! -d "$target_dir" ]]; then
            mkdir -p "$target_dir"
        fi

        # Helper function to create file if value is not null
        write_file_if_not_null() {
            local value="$1"
            local file_path="$2"
            if [ "$value" != "null" ]; then
                echo "$value" > "$file_path"
            else
               echo " " > "$file_path"
            fi
        }

        title=$(echo "$metadata" | jq -r '.title')
        subtitle=$(echo "$metadata" | jq -r '.subtitle')
        description=$(echo "$metadata" | jq -r '.description')
        keywords=$(echo "$metadata" | jq -r '.keywords')
        supportUrl=$(echo "$metadata" | jq -r '.supportUrl')
        marketingUrl=$(echo "$metadata" | jq -r '.marketingUrl')

        whatsNew=$(echo "$metadata" | jq -r '.whatsNew')
        promotionalText=$(echo "$metadata" | jq -r '.promotionalText')

        write_file_if_not_null "$title" "./fastlane/metadata/$language_code/title.txt"
        write_file_if_not_null "$title" "./fastlane/metadata/$language_code/name.txt"
        write_file_if_not_null "$subtitle" "./fastlane/metadata/$language_code/subtitle.txt"
        write_file_if_not_null "$description" "./fastlane/metadata/$language_code/description.txt"
        write_file_if_not_null "$keywords" "./fastlane/metadata/$language_code/keywords.txt"
        write_file_if_not_null "$supportUrl" "./fastlane/metadata/$language_code/support_url.txt"
        write_file_if_not_null "$marketingUrl" "./fastlane/metadata/$language_code/marketing_url.txt"
        write_file_if_not_null "$promotionalText" "./fastlane/metadata/$language_code/promotional_text.txt"

        if [ "$whatsNew" != "null" ]; then
            echo "$whatsNew" > "./fastlane/metadata/$language_code/whatsNew.txt"
            echo "$whatsNew" > "./fastlane/metadata/$language_code/release_notes.txt"
        fi

    done
fi

     download_screenshots_or_apppreviews "$AC_SCREEN_SHOT_LIST" "screenshots"
     download_screenshots_or_apppreviews "$AC_APP_PREVIEW_LIST" "app_previews"

     if [ "$AC_APPLE_STORE_SUBMIT_API_TYPE" == 1 ] || [ "$AC_APPLE_STORE_SUBMIT_API_TYPE" == "AppStoreConnectApiConnection" ]; then
 
        bundle init
        echo "gem \"fastlane\"">>Gemfile
        bundle install
        mkdir fastlane
        touch fastlane/Appfile
        touch fastlane/Fastfile
        mv $AC_FASTFILE_CONFIG "fastlane/Fastfile"

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

