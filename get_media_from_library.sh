#!/bin/bash
PLEX_TOKEN="$PLS_TOKEN"
LIBRARIES_STRING="$PLS_LIBRARIES" #SERVER:LIBRARY format, COMMA SEPARATED
OUTPUTS_STRING="$PLS_OUTPUTS" #COMMA SEPARATED, MATCH LIBRARIES ORDER
INTERVAL="$PLS_INTERVAL"
PLEX_URL="$PLS_URL"

function timestamp() {
  echo -e "| $(date +"%Y-%m-%d %R:%S.%N") | "
}

echo $(timestamp) "******************************"
echo $(timestamp) "** PLEX LIBRARY SYCHRONIZER **"
echo $(timestamp) "******************************"

if [[ -z $PLEX_TOKEN ]];       then echo $(timestamp) "Missing environment variable \$PLS_TOKEN"; exit; fi
if [[ -z $LIBRARIES_STRING ]]; then echo $(timestamp) "Missing environment variable \$PLS_LIBRARIES"; exit; fi
if [[ -z $OUTPUTS_STRING ]];   then echo $(timestamp) "Missing environment variable \$PLS_OUTPUTS"; exit; fi
if [[ -z $INTERVAL ]];         then echo $(timestamp) "Missing environment variable \$PLS_INTERVAL, will run once."; fi
if [[ ! -z $PLEX_URL ]];       then echo $(timestamp) "Environment variable \$PLS_URL is not empty, will only connect via $PLEX_URL."; fi

HEADERS=(
          "X-Plex-Client-Identifier:PlexLibrarySynchronizer"
          "X-Plex-Token:$PLEX_TOKEN"
          "Accept:application/json"
        )
for HEADER in "${HEADERS[@]}"; do
  HEADER_CURL_STRING="$HEADER_CURL_STRING -H $HEADER"
done

PLEX_TOKEN_SCHEME="X-Plex-Token=${PLEX_TOKEN}"


while true; do
  echo $(timestamp) "Starting run" 
  #FOR EACH LIBRARY
  IFS=',' read -r -a LIBRARIES <<< "${LIBRARIES_STRING}"
  IFS=',' read -r -a OUTPUTS <<< "${OUTPUTS_STRING}"
  for j in $(seq 0 $(( ${#LIBRARIES[@]}-1 ))); do
    SERVER_LIBRARY="$(echo ${LIBRARIES[$j]} | xargs)"
    SERVER="$(echo ${SERVER_LIBRARY%;*} | xargs)"
    LIBRARY="$(echo ${SERVER_LIBRARY##*;} | xargs)"
    echo $(timestamp) "------------------------------"
    echo $(timestamp) "Processing Library: $LIBRARY"
    echo $(timestamp) "From Server: $SERVER"
    echo $(timestamp) "------------------------------"
    if [[ -z $PLEX_URL ]]; then 
      PLEX_API_URL="https://plex.tv/api/v2"
      PLEX_RESOURCE_URL="${PLEX_API_URL}/resources?includeHttps=1&includeRelay=1"
      CONNECTIONS=$(curl -s ${HEADER_CURL_STRING} "${PLEX_RESOURCE_URL}" | \
          jq '
          .[] | 
          select(.product | 
            contains("Plex Media Server")) |
          select(.name | 
            contains("'"$SERVER"'")) |
          .connections
          ')
      LOCAL_CONNECTIONS=( $(echo "$CONNECTIONS" | jq -r '.[] | select(.relay==false) | to_entries | map(select(.key | match("address";"i"))) | map(.value) | .[]') )
      LOCAL_PORTS=( $(echo "$CONNECTIONS" | jq -r '.[] | select(.relay==false) | to_entries | map(select(.key | match("port";"i"))) | map(.value) | .[]') )
      echo $(timestamp) "Trying to connect to LOCAL connections for server: $SERVER"
      for i in $(seq 0 $(( ${#LOCAL_CONNECTIONS[@]}-1 ))); do
        CONNECTION=$(echo "${LOCAL_CONNECTIONS[$i]}")
        PORT=$(echo "${LOCAL_PORTS[$i]}")
        CONNECT_RESULT=$(curl --connect-timeout 30 -s "http://$CONNECTION:$PORT" > /dev/null && echo "Success")
        if [[ "$CONNECT_RESULT" == "Success" ]]; then
          echo $(timestamp) "LOCAL Connection successful to server: $SERVER"
          PLEX_URL="http://$CONNECTION:$PORT"
          break;
        fi
      done
      if [[ -z "${PLEX_URL}" ]]; then
        echo $(timestamp) "No LOCAL connections accessible for: $SERVER"
        echo $(timestamp) "Trying to connect to REMOTE connections for server: $SERVER"
        RELAY_CONNECTIONS=$(echo "$CONNECTIONS" | jq -r '.[] | select(.relay==true) | to_entries | map(select(.key | match("uri";"i"))) | map(.value) | .[]')
        for CONNECTION in ${RELAY_CONNECTIONS}; do
          CONNECT_RESULT=$(curl --connect-timeout 30 -s "$CONNECTION" > /dev/null && echo "Success")
          if [[ "$CONNECT_RESULT" == "Success" ]]; then
            echo $(timestamp) "REMOTE Connection successful to server: $SERVER"
            PLEX_URL=$CONNECTION
            break;
          fi
        done
      fi
      if [[ -z "${PLEX_URL}" ]]; then
        echo $(timestamp) "No REMOTE connections accessible for: $SERVER"
        echo $(timestamp) "Connection failed to server: $SERVER"
        continue
      fi
    fi 
    LIST_LIBRARIES_URL="${PLEX_URL}/library/sections?${PLEX_TOKEN_SCHEME}"
    PLEX_CAPABILITIES_URL="${PLEX_URL}/?${PLEX_TOKEN_SCHEME}"
    PLEX_MACHINE_ID="$(curl -s "${PLEX_CAPABILITIES_URL}" | xq .MediaContainer | jq -r '."@machineIdentifier"')"
    echo $(timestamp) "Retrieved Plex server info"
    echo $(timestamp) "  - Direct URL:      $PLEX_URL"
    echo $(timestamp) "  - Plex Machine ID: $PLEX_MACHINE_ID"
    OUTPUT="$(echo ${OUTPUTS[$j]} | xargs)"
    echo $(timestamp) "Library Output Directory: $OUTPUT"
    LIBRARY_KEY_STRING=$(curl -s "${LIST_LIBRARIES_URL}")
    LIBRARIES_JSON=$(echo "$LIBRARY_KEY_STRING" | xq .MediaContainer.Directory)
    LIBRARY_JSON=$(echo "$LIBRARY_KEY_STRING" | xq .MediaContainer.Directory | jq -r '.[] | select(."@title" | match("^'"$LIBRARY"'$"))')
    LIBRARY_NAME=$(echo "$LIBRARY_JSON" | jq -r '."@title"')
    LIBRARY_KEY=$(echo "$LIBRARY_JSON" | jq -r '."@key"')
    LIBRARY_TYPE="$(echo "$LIBRARY_JSON" | jq -r '."@type"')"
     
    if [[ ! -z $LIBRARY_KEY ]]; then
      echo $(timestamp) "Library found with the name: $LIBRARY"
      LIST_MEDIA_URL="${PLEX_URL}/library/sections/${LIBRARY_KEY}/all?${PLEX_TOKEN_SCHEME}"
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
          MEDIA_URL="${PLEX_URL}/web/index.html#!/server/${PLEX_MACHINE_ID}/details?key=$(urlencode ${MEDIA_KEY})"
          MEDIA_NAME="$(echo ${MEDIA} | jq -r '."@title"')"
          CUR_DIR=$PWD
          echo $(timestamp) "Starting download for media: $MEDIA_NAME"
          echo $(timestamp) "::: plexmedia-downloader output :::"
          echo "---------------------------------------------------------------------"
          pushd $OUTPUT > /dev/null
          python ${CUR_DIR}/main.py -t $PLEX_TOKEN "${MEDIA_URL}"
          popd > /dev/null
          echo "---------------------------------------------------------------------"
        done
      fi
      echo $(timestamp) "Finished processing media in library: $LIBRARY"
    else
      echo $(timestamp) "No library found with the name: $LIBRARY"
    fi
    echo $(timestamp) "Finished processing library: $LIBRARY"
  done 
  echo $(timestamp) "Sleeping for interval: $INTERVAL"
  echo $(timestamp) ":::::::::::::::::::::::::::::::::::"
  if [[ -z $INTERVAL ]]; then 
    exit; 
  fi
  sleep $INTERVAL
done
  
  
