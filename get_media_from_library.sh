#!/bin/bash
PLEX_TOKEN="$PLS_TOKEN"
LIBRARIES_STRING="$PLS_LIBRARIES" #COMMA SEPARATED
INTERVAL="$PLS_INTERVAL"
OUTPUTS_STRING="$PLS_OUTPUTS" #COMMA SEPARATED, MATCH LIBRARIES ORDER
PLEX_DIRECT_URL="$PLS_URL"
PLEX_TOKEN_SCHEME="X-Plex-Token=${PLEX_TOKEN}"

function timestamp() {
  echo -e "| $(date +"%Y-%m-%d %R:%S.%N") | "
}

#INTERVALS
echo $(timestamp) "******************************"
echo $(timestamp) "** PLEX LIBRARY SYCHRONIZER **"
echo $(timestamp) "******************************"
while true; do
  echo $(timestamp) "Starting run" 
  PLEX_CAPABILITIES_URL="${PLEX_DIRECT_URL}/?${PLEX_TOKEN_SCHEME}"
  PLEX_MACHINE_ID="$(curl -s "${PLEX_CAPABILITIES_URL}" | xq .MediaContainer | jq -r '."@machineIdentifier"')"
  echo $(timestamp) "Retrieved Plex server info"
  echo $(timestamp) "Plex Machine ID: $PLEX_MACHINE_ID"
    
  #FOR EACH LIBRARY
  IFS=',' read -r -a LIBRARIES <<< "${LIBRARIES_STRING}"
  IFS=',' read -r -a OUTPUTS <<< "${OUTPUTS_STRING}"
  LIST_LIBRARIES_URL="${PLEX_DIRECT_URL}/library/sections?${PLEX_TOKEN_SCHEME}"
  for j in $(seq 0 $(( ${#LIBRARIES[@]}-1 ))); do
    LIBRARY="$(echo ${LIBRARIES[$j]} | xargs)"
    echo $(timestamp) "------------------------------"
    echo $(timestamp) "Processing Library: $LIBRARY"
    echo $(timestamp) "------------------------------"
    OUTPUT="$(echo ${OUTPUTS[$j]} | xargs)"
    echo $(timestamp) "Library Output Directory: $OUTPUT"
    LIBRARY_KEY_STRING=$(curl -s "${LIST_LIBRARIES_URL}")
    LIBRARIES_JSON=$(echo "$LIBRARY_KEY_STRING" | xq .MediaContainer.Directory)
    NUM_LIBRARIES=$(echo "${LIBRARIES_JSON}" | jq '. | length')
    LIBRARY_KEY=""
    echo $(timestamp) "Searching for Library on Plex Server: $LIBRARY"
    for i in $(seq 0 $((${NUM_LIBRARIES}-1))); do
      LIBRARY_JSON=$(echo "$LIBRARY_KEY_STRING" | xq .MediaContainer.Directory[$i])
      LIBRARY_NAME=$(echo "$LIBRARY_JSON" | jq -r '."@title"')
      if [[ "$LIBRARY" == "$LIBRARY_NAME" ]]; then
        echo $(timestamp) "  - Library Found $LIBRARY_NAME ... Match!"
        LIBRARY_KEY=$(echo "$LIBRARY_JSON" | jq -r '."@key"')
	LIBRARY_TYPE="$(echo "$LIBRARY_JSON" | jq -r '."@type"')"
        break
      else
        echo $(timestamp) "  - Library Found: $LIBRARY_NAME ... No match"
      fi 
    done
     
    if [[ ! -z $LIBRARY_KEY ]]; then
      LIST_MEDIA_URL="${PLEX_DIRECT_URL}/library/sections/${LIBRARY_KEY}/all?${PLEX_TOKEN_SCHEME}"
      MEDIAS="$(curl -s ${LIST_MEDIA_URL})"

      MEDIAS_JSON=$(echo ${MEDIAS} | xq .MediaContainer)
      NUM_MEDIAS=$(echo "${MEDIAS_JSON}" | jq -r '."@size"')
      echo $(timestamp) "Searching for media in library: $LIBRARY"
      echo $(timestamp) "Media items found: $NUM_MEDIAS"
      if (( $NUM_MEDIAS > 0 )); then
        echo $(timestamp) "------------------------------"
        echo $(timestamp) "Processing media in library: $LIBRARY."
        echo $(timestamp) "------------------------------"
        for i in $(seq 0 $((${NUM_MEDIAS}-1))); do
          if [[ "${LIBRARY_TYPE}" == "movie" ]]; then
            MEDIA="$(echo ${MEDIAS} | xq .MediaContainer.Video[$i])"
          elif [[ "${LIBRARY_TYPE}" == "show" ]]; then 
            MEDIA="$(echo ${MEDIAS} | xq .MediaContainer.Directory[$i])"
	  elif [[ "{$LIBRARY_TYPE}" == "photo" ]]; then
            MEDIA="$(echo ${MEDIAS} | xq .MediaContainer.Directory[$i])"
	  elif [[ "{$LIBRARY_TYPE}" == "artist" ]]; then
            MEDIA="$(echo ${MEDIAS} | xq .MediaContainer.Directory[$i])"
          fi
          MEDIA_KEY="/library/metadata/$(echo ${MEDIA} | jq -r '."@ratingKey"')"
          MEDIA_URL="${PLEX_DIRECT_URL}/web/index.html#!/server/${PLEX_MACHINE_ID}/details?key=$(urlencode ${MEDIA_KEY})"
          MEDIA_NAME="$(echo ${MEDIA} | jq -r '."@title"')"
          CUR_DIR=$PWD
          echo $(timestamp) "Starting download for media: $MEDIA_NAME"
          pushd $OUTPUT > /dev/null
          echo $(timestamp) "::: plexmedia-downloader output :::"
          python ${CUR_DIR}/main.py -t $PLEX_TOKEN "${MEDIA_URL}"
          echo $(timestamp) ":::::::::::::::::::::::::::::::::::"
          popd > /dev/null
        done
      fi
      echo $(timestamp) "Finished processing media in library: $LIBRARY"
    else
      echo $(timestamp) "No library found with the name: $LIBRARY"
    fi
    echo $(timestamp) "Finished processing library: $LIBRARY"
  done 
  echo $(timestamp) "Sleeping for interval: $INTERVAL"
  sleep $INTERVAL
done
  
  
