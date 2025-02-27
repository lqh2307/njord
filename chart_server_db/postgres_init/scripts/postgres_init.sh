#!/usr/bin/env sh

set -e

until psql -c '\q'; do
  >&2 echo "Postgres is unavailable - sleeping"
  sleep 1
done

>&2 echo "Postgres is up - executing command"

createdb -w s57server

psql -a -q -f ./up.sql
