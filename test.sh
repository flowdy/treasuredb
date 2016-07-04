#!/bin/bash

abort () {
   echo Database not deleted.
   exit ${1:-1}
}

db=$(mktemp -t trsr-XXXXXXXXX.db);
bash t/schema.sh $db
if [ $? == 0 ]; then
   echo Tests passed.
else abort
fi

> $db; sqlite3 $db < schema.sql
export TRSRDB_SQLITE_FILE=$db
if prove -r t; then
    rm $db
else abort $?
fi
