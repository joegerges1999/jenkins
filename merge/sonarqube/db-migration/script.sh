#!/bin/sh

echo "Removing connections and dropping database ..."
psql -U sonar postgres -f /var/lib/postgresql/migration-scripts/drop-table.sql

echo "Restoring database ..."
createdb -U sonar sonar
psql -U sonar sonar < /var/lib/postgresql/backups/db_dump.sql 

echo "Allowing connections back up ..."
psql -U sonar postgres -f /var/lib/postgresql/migration-scripts/allow-connections.sql
