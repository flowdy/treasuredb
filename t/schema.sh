#!/bin/bash
set -e
db=${1-`mktemp -t trsr-XXXXXXXXX.db`}

setup_database() {
    cat schema/{tables.sql,*/*} | sqlite3 $db
}

cleanup () { local rc=$?; rm -i $db; exit $rc; }
trap cleanup EXIT

echo "My database file: $db"

setup_database $db

echo -e "Test level #1: Plain SQL commands\n\t(Create accounts, debits, credits, transfers and revocation)";
diff t/schema.out <(sqlite3 $db < t/schema.sql 2>&1)

echo "Test level #2: Access via DBIx::Class API"
export TRSRDB_SQLITE_FILE=$db
: > $db; setup_database $db && perl t/01_schema.t

echo "Test level #3: Access via perl scripts and HTTP server"
: > $db; setup_database $db && perl t/02_http+scripts.t

