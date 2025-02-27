# Image for initializing the PostGIS Db
FROM debian:buster-slim

RUN apt-get update -y \
  && apt-get install -y \
    postgresql-client \
  && apt-get -y --purge autoremove \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /postgres_init

COPY scripts/up.sql .
COPY scripts/postgres_init.sh .

# https://www.postgresql.org/docs/current/libpq-envars.html
ENV PGUSER=admin
ENV PGPASSWORD=mysecretpassword
ENV PGHOST=localhost
ENV PGPORT=5432
ENV PGDATABASE=s57server
