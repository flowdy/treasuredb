README
======

TreasureDB is a plain SQLite database application to observe and trace the finances of a
non-profit registered society or club.  The ideal state of balance is zero both in debit
and in credit because they even out. In Germany, such clubs may not accumulate reserves.

Basics
------

As it is a SQLite3 database with all consistency and calculatory logic built in, you only
need the `sqlite3` binary or any sqlite3 GUI software to run it. Please note the tools
beyond that are not yet portable. A part of them require the bash and a unix/linux system.

1. Ensure sqlite3 is installed

1. Run the test suite: `bash t/schema.sh` (on Linux and unix systems with Bash installed)

        # Or go by foot and test manually a little bit further
        treasuredb $ export TRSRDB_SQLITE_FILE="..." # wherever you want to save it
        treasuredb $ cat schema/{tables,*/*}.sql | sqlite3 $TRSRDB_SQLITE_FILE
        treasuredb $ sqlite3 $TRSRDB_SQLITE_FILE
        SQLite version 3.8.7.1 2014-10-29 13:59:56
        Enter ".help" for usage hints.
        sqlite> .read t/schema.sql
        ...

1. Use it:

  ```
  export TRSRDB_SQLITE_FILE="..." # wherever you want to save it 
  cat schema/{tables,*/*}.sql | sqlite3 $TRSRDB_SQLITE_FILE
  ./trsr $COMMAND
  ```

  `$COMMAND` can be one of the following:

    * `charge` - input a batch of csv lines representing incoming and outgoing payments
    * `ct` - charge, then make transfer (interactive assistent)
    * `cts` - like ct, but output finally status of all
    * `ctr` - like ct, but output finally reports of all
    * `report` - get only reports
    * `sql` - execute sqlite3 shell with all necessary pragmata and with line output
    * `status` - get only statuses
    * `transfer` - only make transfers (interactive assistent)
    * `tr` - transfer, and output report
    * `ts` - transfer, and output statuses

Input to `./trsr charge`
------------------------

You can separate the fields of each line by a comma and optional whitespace, or at least one whitespace. The order of columns is:

 * The booking date in format YYYY-MM-DD,
 * The account name,
 * The value if it is a debit,
 * The value if it is a credit,
 * The purpose (in the case of a debit, it must start with bill ID and colon),
 * Optional: "<< Comma-separated list of credit IDs used to pay the debt" or ">> Comma-separated list of bill IDs the booked income is used for", respectively

### Multi-line purposes

Multi-line purposes must either be surrounded by " (escape literal " by doubling it), or started in the next line and terminated with an empty one.

### How to book an incoming payment

In the credit column must be a value greater than 0. Cent must be passed as a decimal part, i.e. "100" really mean 100.00, not 1.00! In the debit column you MAY input a name starting with a letter (otherwise it needs to be just "+"), by which you can refer to a credit in lines below instead of the number.

### How to enter a target credit

A target credit is defined as initially equal 0.

### How to make an internal debt

A debit, recognized by an amount in the debit column, can have a target credit name or number in the credit column.

### How to book an outgoing payment

An outgoing payment must not have a target credit. Leave that field empty.

HTTP interface
--------------

Treasure DB includes a rudimentary HTTP interface. It requires Mojolicious. The interface
is developped and tested on version 7.13 onwards. 

You can start it with `./trsr server`. It will stay in the foreground. To start it in daemon mode,
use `./trsr server >/tmp/trsr_db.log 2>&1 & disown` in the bash shell.

After first start, you will need to create a user: `./httpuser -a $username -g 2`.
The link that will be output leads you to an extended login form. Please enter a (good) password
twice, so typos are unlikely. The -g (or --grade) argument can be 0, 1 or 2:

  * 2 is admin who has complete read-write access.
  * 1 means auditor with complete view without writing permission.
  * 0 means auditor who can view only the type-less accounts, e.g.
    the club account is recommended to be without type, or(!) an account
    named identically.


How does it work?
-----------------

There are four tables: Account, Credit, Debit and Transfers.

Account table stores the static details, i.e. the type of account, the record identifier for
another table that stores more information about the account owner, and the IBAN for outgoing
bank transfers.

The Credit table stores bank transfers from the member to the club, and also the target
records of internal transfers to the club and other members performing commercial services for
it. The value of the former sort is initially >0 and should not be altered afterwards.
The latter's value always starts at 0 and is increased automatically by transfers linked to the
according debts.

The Debit table stores the receipts documenting a debt, their link to the credit record of the
respective recipient as well as to the account from which it is paid.

The Transfer stores when which amount is transferred from which credit record to settle which debt.
So, a debt can be associated with n source credits, and a souce credit can settle multiple debts.
Transfers cannot be altered once inserted, they need to be revoked and re-entered. This is due to
triggers that have to rebalance the involved accounts. Whenever the view Balance contains positive
values for both credit and debt in a line, this indicates transfers yet to be entered.

Using the sqlite3 database purposefully means two things:

 1. Keep `ReconstructedBankStatement` view in sync with the actual statements received from your bank
   by entering the incoming and outcoming bank transfers in the Credit or Debit table, respectively,
   best as soon as they show up.

 2. Ideally, all records in the `Balance` view must be 0 in each of debit, credit and promised
   columns. If neither debit nor credit is zero in the same record, you need to make internal transfers
   linking records from the `CurrentDebts` and from the `AvailableCredits` tables. Otherwise,
   ensure that members make the transfers they are obligated to and return any money that is paid
   too much unless the indicated purposes, if any, also refer to dues in certain future.

License
-------

Copyright (c) 2016, Florian Heß.
All rights reserved.

See details in LICENSE file containing the General Public license, version 3.
