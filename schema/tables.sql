CREATE TABLE Account (
  ID PRIMARY KEY NOT NULL,
  type NOT NULL,
  altId NOT NULL, -- e.g. when type "member", no. in external member table 
  IBAN -- target account for returned payments (set '' to enable
       -- outgoing bank transfers to commercial partners from that account).
);

CREATE TABLE Category (
  ID INTEGER PRIMARY KEY,
  label
);

CREATE TABLE Debit (
  billId PRIMARY KEY NOT NULL,
  debtor NOT NULL, -- Account charged
  targetCredit INTEGER, -- record id in Credit table to pay into.
                   -- just understand it as virtual payment
                   -- NULL when debit is a bank transfer from the club account
  date DATE NOT NULL,
  purpose NOT NULL, -- description of receipt
  category,
  value INTEGER NOT NULL, -- Euro-Cent
  paid INTEGER DEFAULT 0, -- Euro-Cent, set and changed automatically (Cache)
  FOREIGN KEY (debtor) REFERENCES Account(ID),
  FOREIGN KEY (targetCredit) REFERENCES Credit(credId),
  FOREIGN KEY (category) REFERENCES Category(ID),
  CHECK ( abs(cast(value as integer)) == value
      AND abs(cast( paid as integer)) == paid
      AND value > 0 AND value >= paid
  )
);

CREATE TABLE Credit (
  credId INTEGER PRIMARY KEY NOT NULL,
  account NOT NULL, -- Account des Begünstigten
  date DATE NOT NULL,
  purpose NOT NULL, -- as originally indicated in statement of bank account
  category,
  value INTEGER NOT NULL, -- Euro-Cent. Caution, two distinct cases need to be considered:
                         --  Either deposit by bank transfer (>0) or target of internal payments (=0)
  spent INTEGER DEFAULT 0, -- Euro-Cent, set and changed automatically (Cache)
                           -- for later traceability, necessary when revoking transfers
  FOREIGN KEY (account) REFERENCES Account(ID),
  FOREIGN KEY (category) REFERENCES Category(ID),
  CHECK ( abs(cast(value as integer)) == value
      AND abs(cast(spent as integer)) == spent
      AND value >= spent
  )
);

-- Which credit pays/paid down which debt is recorded traceably so as to clarify any case of reminder,
-- without ambuiguity about, which debt is actually due yet, or to clarify which transfer is used for
-- which debts. The user specifies which credit is intended for which debt, in accordance with the
-- purpose if any is indicated in a received bank transfer. Following triggers verify this relation
-- and mark a debit as paid and/or a credit as paid.
-- Debits to which applies value > paid are meant to be suggested for assignment to newly inserted
-- credit records without indicated purpose. Likewise, credits without indicated purpose to which
-- applies value > spent are candidates for payment of newly inserted debts.
CREATE TABLE Transfer (
  timestamp DATE DEFAULT CURRENT_TIMESTAMP,
  billId INTEGER NOT NULL,
  credId INTEGER NOT NULL, 
  amount INTEGER, -- for later traceability, necessary when revoking transfers
  note,
  FOREIGN KEY (billId) REFERENCES Debit(billId),
  FOREIGN KEY (credId) REFERENCES Credit(credId),
  UNIQUE (billId, credId)
);

-- For internal purposes: Memory of rebalance triggers
-- Do not fiddle with it! I.e. if you do, don't expect any support.
CREATE TABLE __INTERNAL_TRIGGER_STACK (id integer primary key, d, c, m);

-- Only for use of HTTP interface
CREATE TABLE web_auth ( user_id primary key, password, grade not null, username, email );

