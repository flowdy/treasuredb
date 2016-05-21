README
======

TreasureDB is a plain SQLite database application to observe and trace the finances of a
non-profit registered society or club. In Germany, such clubs may not accumulate reserves.
Therefore, the ideal state of balance is zero both in debit and in credit because they even
out.

How does it work?
-----------------

There are four tables: Account, Credit, Debit and Transfers.

Account table stores the static details, i.e. the type of account, the record identifier for
another table that stores more information about the account owner, and the IBAN for outgoing
bank transfers.

The Credit table stores bank transfers from the member to the club, and also the target
records of internal transfers to the club and other members performing services for it.
The value of the former sort is initially >0 and normally not altered afterwards. The latter's
value always starts at 0 and is increased by transfers linked to it.

The Debit table stores the receipts documenting a debt, their link to the credit record of the
respective recipient as well as to the account from which it is paid.

The Transfer stores when which amount is transferred from which credit record to settle which debt.
So, a debt can be associated with n source credits, and a souce credit can settle multiple debts.
Transfers cannot be altered once inserted, they need to be revoked and re-entered. This is due to
triggers that have to rerun.


Installation
------------

As it is a SQLite3 database with all consistency and calculatory logic built in, you only
need the `sqlite3` binary or any sqlite3 GUI software to run it.

1. Ensure sqlite3 is installed
1. Run the test suite: `bash schema.t.sh` (on Linux and unix systems)
1. Setup the database: `sqlite3 treasure.db < schema.sql`
1. Study the files to learn how to work with the system: `less schema.*`

