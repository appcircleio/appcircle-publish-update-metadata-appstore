#!/bin/bash

      export LC_ALL=en_US.UTF-8
      export LANG=en_US.UTF-8
      export LANGUAGE=en_US.UTF-8
    
      echo "IPAFileName:$IPAFileName"
      echo "IPAFileUrl:$IPAFileUrl"
      echo "AppleId:$AppleId"
      echo "BundleId:$BundleId"
      echo "AppleUserName:$AppleUserName"
      echo "ApplicationSpecificPassword:$ApplicationSpecificPassword"
      echo "AppStoreConnectApiKey:$AppStoreConnectApiKey"
      echo "AppStoreConnectApiKeyFileName:$AppStoreConnectApiKeyFileName"
      echo "appleStoreSubmitApiType:$appleStoreSubmitApiType"
      
      locale
      curl -o "./$IPAFileName" -k $IPAFileUrl

 
download_screenshots_or_apppreviews() {

      local json_file="$1"
      local itemTypeForPath = "$2"
      
      local continueDownload = "true"; 
      if [[ ! -f "$json_file" ]]; then
        echo "Screenshot list file '$json_file' not found!" >&2
        continueDownload="false";
      fi


      if [[ ! -s "$json_file" ]] || ! jq -e '.[]' "$json_file" > /dev/null 2>&1; then
        echo "Error: Screenshot list file '$json_file' is empty or not a valid JSON array!" >&2
        continueDownload="false";
      fi

    if [[ "$continueDownload" == "true" ]]; then
    
        for entry in $(jq -c '.[]' "$json_file"); do
          local signed_url=$(echo "$entry" | jq -r '.SignedUrl')
          local lang=$(echo "$entry" | jq -r '.Lang')
          local display_type=$(echo "$entry" | jq -r '.ScreenshotDisplayType')
          local filename=$(echo "$signed_url" | awk -F '/' '{print $NF}')
          
          target_dir="./fastlane/metadata/$itemTypeForPath/$lang/$display_type"
         
            if [[ ! -d "$target_dir" ]]; then
                mkdir -p "$target_dir"
            fi
            
          
          curl -o "$target_dir/$filename" -k "$signed_url"
          echo "Downloaded screenshot: $filename to $target_dir"
        done
      fi
}

if [[ -f "$MetaDataLocalizationList" && -s "$MetaDataLocalizationList" ]]; then

    jq -c '.[]' "$MetaDataLocalizationList" | while IFS= read -r entry; do

        language_code=$(echo "$entry" | jq -r '.lang')
        metadata=$(echo "$entry")

        target_dir="./fastlane/metadata/$language_code"
        
        if [[ ! -d "$target_dir" ]]; then
            mkdir -p "$target_dir"
        fi

        title=$(echo "$metadata" | jq -r '.title')
        subtitle=$(echo "$metadata" | jq -r '.subtitle')
        description=$(echo "$metadata" | jq -r '.description')
        keywords=$(echo "$metadata" | jq -r '.keywords')
        supportUrl=$(echo "$metadata" | jq -r '.supportUrl')
        marketingUrl=$(echo "$metadata" | jq -r '.marketingUrl')
        version=$(echo "$metadata" | jq -r '.version')
        copyright=$(echo "$metadata" | jq -r '.copyright')
        whatsNew=$(echo "$metadata" | jq -r '.whatsNew')

        echo "$title" > "./fastlane/metadata/$language_code/title.txt"
        echo "$subtitle" > "./fastlane/metadata/$language_code/subtitle.txt"
        echo "$description" > "./fastlane/metadata/$language_code/description.txt"
        echo "$keywords" > "./fastlane/metadata/$language_code/keywords.txt"
        echo "$supportUrl" > "./fastlane/metadata/$language_code/support_url.txt"
        echo "$marketingUrl" > "./fastlane/metadata/$language_code/marketing_url.txt"
        echo "$copyright" > "./fastlane/metadata/$language_code/copyright.txt"

        if [ "$whatsNew" != "null" ]; then
            echo "$whatsNew" > "./fastlane/metadata/$language_code/whatsNew.txt"
        fi

    done
fi


     download_screenshots_or_apppreviews "$ScreenShotList" "screenshots"
     download_screenshots_or_apppreviews "$AppPreviewList" "app_previews"

     if [ "$appleStoreSubmitApiType" == 1 ] || [ "$appleStoreSubmitApiType" == "AppStoreConnectApiConnection" ]; then
 
        bundle init
        echo "gem \"fastlane\"">>Gemfile
        bundle install
        mkdir fastlane
        touch fastlane/Appfile
        touch fastlane/Fastfile
        mv $FastFileConfig "fastlane/Fastfile"

        # cat $FastFileConfig || true
        # cat $ScreenShotList || true
        # cat $AppPreviewList || true

        mv "$AppStoreConnectApiKey" "$AppStoreConnectApiKeyFileName"
 
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

