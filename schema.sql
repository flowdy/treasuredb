CREATE TABLE Account (
  ID PRIMARY KEY NOT NULL,
  type NOT NULL,
  altId NOT NULL, -- z.B. bei Typ "Mitglied" Nr. laut externer Mitgliedertabelle 
  IBAN -- Zielkonto für etwaige Rückzahlungen.
);
CREATE TABLE Debit (
  receiptId PRIMARY KEY NOT NULL,
  debitor NOT NULL, -- Account charged
  targetCredit INTEGER, -- record id in Credit table to pay into.
                   -- just understand it as virtual payment
                   -- NULL when debit is a bank transfer from the club account
  date DATE NOT NULL,
  purpose NOT NULL, -- description of receipt
  value INTEGER NOT NULL, -- Euro-Cent
  paid INTEGER DEFAULT 0, -- Euro-Cent, set and changed automatically (Cache)
  FOREIGN KEY (debitor) REFERENCES Account(ID),
  FOREIGN KEY (targetCredit) REFERENCES Credit(Id)
);
CREATE TABLE Credit (
  Id INTEGER PRIMARY KEY NOT NULL,
  account NOT NULL, -- Account des Begünstigten
  date DATE NOT NULL,
  purpose NOT NULL, -- as originally indicated in statement of bank account
  value INTEGER NOT NULL, -- Euro-Cent. Caution, two distinct cases need to be considered:
                         --  Either deposit by bank transfer (>0) or target of internal payments (=0)
  spent INTEGER DEFAULT 0, -- Euro-Cent, set and changed automatically (Cache)
                           -- for later traceability, necessary when revoking transfers
  FOREIGN KEY (account) REFERENCES Account(ID)
);

-- Which credit pays/paid down which debt is recorded traceably so as to clarify any case of reminder
-- without ambuiguity about which debt is due yet. The user specifies, in accordance with any indicated
-- purpose of a received bank transfer, which credit is intended for which debt. Following triggers
-- verify this relation and mark a debit as paid and/or a credit as paid.
-- Debits to which applies value > paid, are meant to be suggested for assignment to newly inserted
-- credit records without indicated purpose. Likewise, credits to which applies value > spent are candidates
-- for payment of newly inserted debts.
CREATE TABLE Transfer (
  timestamp DATE DEFAULT CURRENT_TIMESTAMP,
  receiptId INTEGER NOT NULL,
  fromCredit INTEGER NOT NULL, 
  amount INTEGER, -- für spätere Nachvollziehbarkeit. Nötig auch bei Widerruf
  FOREIGN KEY (receiptId) REFERENCES Debit(receiptId),
  FOREIGN KEY (fromCredit) REFERENCES Credit(Id),
  UNIQUE (receiptId, fromCredit)
);

CREATE TABLE IF NOT EXISTS _temp (d, c, m);
CREATE TRIGGER balanceTransfer
     AFTER INSERT ON Transfer 
BEGIN

  SELECT RAISE(FAIL, "It is not the debitor who pays")
    WHERE (SELECT debitor FROM Debit WHERE receiptId=NEW.receiptId)
       != (SELECT account FROM Credit WHERE Id=NEW.fromCredit)
    ;

  INSERT INTO _temp
     SELECT remainingDebt, remainingCredit, min(remainingDebt,remainingCredit) 
     FROM (SELECT
         (SELECT value - paid FROM Debit WHERE receiptId=NEW.receiptId) AS remainingDebt, 
         (SELECT value - spent FROM Credit WHERE Id=NEW.fromCredit) AS remainingCredit
     ) AS microbalance
  ;

  UPDATE Debit
      SET paid = paid + CASE
        WHEN (SELECT d FROM _temp) <= 0
          THEN RAISE(ROLLBACK, "Debt is already paid")
        ELSE
          (SELECT m FROM _temp)
      END
      WHERE receiptId=NEW.receiptId;

  UPDATE Credit
      SET value = value + (SELECT m FROM _temp)
      WHERE Id = (
          SELECT targetCredit
          FROM Debit
          WHERE receiptId=NEW.receiptId
      );

  UPDATE Credit
      SET spent = spent + CASE
        WHEN (SELECT c FROM _temp) <= 0
          THEN RAISE(FAIL, "Credit is already spent")
        ELSE
          (SELECT m FROM _temp)
      END
      WHERE Id=NEW.fromCredit;

  UPDATE Transfer
      SET amount = (SELECT m FROM _temp)
      WHERE receiptId=NEW.receiptId AND fromCredit=NEW.fromCredit
        ;

  DELETE FROM _temp;

END;

CREATE TRIGGER revokeTransfer
    BEFORE DELETE ON Transfer
BEGIN

  INSERT INTO _temp VALUES (null,null,OLD.amount);

  UPDATE Debit
      SET paid = paid - OLD.amount
      WHERE receiptId=OLD.receiptId
      ;

  UPDATE Credit
      SET value = value - OLD.amount
      WHERE Id = (
          SELECT targetCredit
          FROM Debit
          WHERE receiptId=OLD.receiptId
      );

  UPDATE Credit
      SET spent = spent - OLD.amount
      WHERE Id = OLD.fromCredit;

  DELETE FROM _temp;

END;

CREATE TRIGGER enforceImmutableTransfer
    BEFORE UPDATE ON Transfer
    WHEN OLD.amount IS NOT NULL
BEGIN
    SELECT RAISE(FAIL, "Transfer cannot be updated, but needs to be revoked and re-inserted to ensure the triggers run");
END;

CREATE TRIGGER enforceiZeroPaidAtStart
    BEFORE INSERT ON Debit
BEGIN
    SELECT RAISE(FAIL, "debt must be initially unpaid")
    WHERE NEW.paid <> 0;
END;

-- Prevent modification with paid value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER enforceDebtImmutableOutsideTrigger
    BEFORE UPDATE OF paid ON Debit
    WHEN NOT EXISTS (SELECT * FROM Transfer t WHERE NEW.receiptId=t.receiptId AND amount IS NULL)
BEGIN
    SELECT RAISE(FAIL, "paid is set and adjusted automatically according to added Transfer records")
    WHERE (NEW.paid + IFNULL((SELECT m FROM _temp WHERE c IS NULL AND d IS NULL),0) ) <> OLD.paid;
END;

CREATE TRIGGER enforceFixedDebits
    BEFORE UPDATE OF value ON Debit
    WHEN EXISTS (SELECT * FROM Transfer WHERE receiptId=NEW.receiptId)
BEGIN
    SELECT RAISE(FAIL, "Debt is involved in transfers to revoke at first");
END;

CREATE TRIGGER enforceZeroSpentAtStart
    BEFORE INSERT ON Credit
BEGIN
    SELECT RAISE(FAIL, "credit must be initially unused")
    WHERE NEW.spent != 0;
END;

-- Prevent modification with spent value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER enforceSpentImmutableOutsideTrigger
    BEFORE UPDATE OF spent ON Credit
    WHEN NOT EXISTS (SELECT * FROM Transfer t WHERE NEW.Id=t.fromCredit AND amount IS NULL)
BEGIN
    SELECT RAISE(FAIL, "spent is set and adjusted automatically according to added Transfer records")
    WHERE (NEW.spent + IFNULL((SELECT m FROM _temp WHERE c IS NULL AND d IS NULL),0) ) <> OLD.spent;
END;

CREATE TRIGGER enforceFixedCredit
    BEFORE UPDATE OF value ON Credit
BEGIN
    SELECT RAISE(FAIL, "Credit involved in transactions to revoke at first")
    WHERE EXISTS (SELECT * FROM Transfer WHERE fromCredit=NEW.Id);
END;

CREATE TRIGGER checkIBANatTransfer
    BEFORE INSERT ON Debit
    WHEN NEW.targetCredit IS NULL
BEGIN
   SELECT RAISE(FAIL, "IBAN used does not match IBAN currently stored in account record")
   FROM (SELECT instr(NEW.purpose, IBAN) AS fnd FROM Account WHERE ID=NEW.debitor) AS matchingIBAN
   WHERE fnd IS NULL OR fnd = 0;
END;

CREATE VIEW CurrentDebts AS
    SELECT debitor, purpose, date,
           value - paid AS difference
    FROM Debit
    WHERE value != paid
;
      
CREATE VIEW AvailableCredits AS
    SELECT account, purpose, date,
           value - spent AS difference
    FROM Credit
    WHERE value != spent
;
      
CREATE VIEW Balance AS
  SELECT ID, IFNULL(ac.allCredits,0) credit, IFNULL(cd.allDebts, 0) debit
  FROM Account
     LEFT OUTER JOIN (SELECT debitor, sum(difference) AS allDebts FROM CurrentDebts GROUP BY debitor) AS cd ON ID=cd.debitor
     LEFT OUTER JOIN (SELECT account, sum(difference) AS allCredits FROM AvailableCredits GROUP BY account) AS ac ON ID=ac.account
  ;

