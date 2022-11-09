#!/bin/bash

# /this is in the linked ENV file from docker-compose /config/jbrowse/env.conf
# export JBROWSE_SAMPLE_DATA=/jbrowse/sample_data/
# export JBROWSE_DATA=/jbrowse/data/
# export JBROWSE=/jbrowse/
# export DATA_DIR=/data/

echo "In sequenceserver entrypoint.sh"
# if [ -d "/data/" ];
# then
#     for f in /data/*.sh;
#     do
#         [ -f "$f" ] && . "$f"
#     done
# fi

# mkdir -p $JBROWSE_DATA/json/

# nginx -g "daemon off;"

echo "new"

bundle exec sequenceserver -D 

