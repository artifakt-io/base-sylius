#!/bin/bash

set -e

echo ">>>>>>>>>>>>>> START CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "

# set runtime env. vars on the fly
export APP_ENV=prod
export APP_DATABASE_NAME=${ARTIFAKT_MYSQL_DATABASE_NAME:-changeme}
export APP_DATABASE_USER=${ARTIFAKT_MYSQL_USER:-changeme}
export APP_DATABASE_PASSWORD=${ARTIFAKT_MYSQL_PASSWORD:-changeme}
export APP_DATABASE_HOST=${ARTIFAKT_MYSQL_HOST:-mysql}
export APP_DATABASE_PORT=${ARTIFAKT_MYSQL_PORT:-3306}

export DATABASE_URL=mysql://$APP_DATABASE_USER:$APP_DATABASE_PASSWORD@$APP_DATABASE_HOST:$APP_DATABASE_PORT/$APP_DATABASE_NAME

# generate jwt data if not present yet
su www-data -s /bin/bash -c '
  set -e
  if [[ ! -f /data/config/jwt/private.pem ]]; then
    source /data/passphrase
    jwt_passphrase=${JWT_PASSPHRASE:-$(grep ''^JWT_PASSPHRASE='' .env | cut -f 2 -d ''='')}
    echo "$jwt_passphrase" | openssl genpkey -out config/jwt/private.pem -pass stdin -aes256 -algorithm rsa -pkeyopt rsa_keygen_bits:4096
    echo "$jwt_passphrase" | openssl pkey -in config/jwt/private.pem -passin stdin -out config/jwt/public.pem -pubout
    setfacl -R -m u:www-data:rX -m u:"$(whoami)":rwX config/jwt
    setfacl -dR -m u:www-data:rX -m u:"$(whoami)":rwX config/jwt
  fi
'

wait-for $APP_DATABASE_HOST:$APP_DATABASE_PORT --timeout=180


lockdir="/data/docker-entrypoint.mutex"
while ! mkdir "$lockdir"; do
    echo 'Can not get lock. Waiting...' >&2
    sleep 10
done

trap 'rmdir "$lockdir"; exit' EXIT INT TERM HUP

# etc.
# no need to rmdir the lock dir at the end

su www-data -s /bin/bash -c 'php ./bin/console doctrine:migrations:status'
# only run install on first deployment, checks if migrations are done or not
IS_MIGRATED=0
su www-data -s /bin/bash -c 'php ./bin/console doctrine:migrations:status | grep "Already at latest version"' || IS_MIGRATED=$?

echo IS_MIGRATED=$IS_MIGRATED

if [ $IS_MIGRATED -ne 0 ]; then
  echo FIRST DEPLOYMENT, RUNNING AUTOMATED INSTALL
   su www-data -s /bin/sh -c '
    set -e
    rm -rf var/cache/*
    mkdir -p public/media/image
    composer require doctrine/dbal:"^2.6"
    bin/console sylius:install -n
    bin/console sylius:fixtures:load -n
    bin/console assets:install --symlink --relative public
    bin/console cache:clear
  '
else
  echo MIGRATIONS DETECTED, SKIPPING AUTOMATED INSTALL
fi

rmdir "$lockdir"

echo ">>>>>>>>>>>>>> END CUSTOM ENTRYPOINT SCRIPT <<<<<<<<<<<<<<<<< "
