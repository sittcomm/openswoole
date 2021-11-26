#!/bin/sh
set -e

# first arg is `-f` or `--some-option`
if [ "${1#-}" != "$1" ]; then
  php "/app/public/index.php"
  set -- php-fpm "$@"
fi

if [ "$1" = 'app' ] || [ "$1" = 'php' ] || [ "$1" = 'bin/console' ] || [ "$1" = 'setup' ]; then
  composer install --prefer-dist --no-scripts --no-progress

  echo "Create Database if not exists"
  bin/console doctrine:database:create --if-not-exists

  echo "Waiting for db to be ready..."
  until bin/console doctrine:query:sql "SELECT 1" >/dev/null 2>&1; do
    sleep 1
  done

  echo "Migrations..."
  bin/console doctrine:migrations:migrate --no-interaction

  php "/app/public/index.php"
  sleep 1
fi

exec docker-php-entrypoint "$@"
