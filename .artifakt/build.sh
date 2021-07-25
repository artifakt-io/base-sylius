#!/bin/bash

set -e

echo ">>>>>>>>>>>>>> START CUSTOM BUILD SCRIPT <<<<<<<<<<<<<<<<< "

# used by entrypoint to init JWT
apt-get update && \
    apt-get install -y --no-install-recommends acl && \
    rm -rf /var/lib/apt/lists/*

chmod 755 /var/www/html/bin/console

echo ">>>>>>>>>>>>>> END CUSTOM BUILD SCRIPT <<<<<<<<<<<<<<<<< "
