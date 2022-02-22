#!/bin/bash

set -e

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