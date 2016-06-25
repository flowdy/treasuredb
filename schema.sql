CREATE TABLE Account (
  ID PRIMARY KEY NOT NULL,
  type NOT NULL,
  altId NOT NULL, -- e.g. when type "member", no. in external member table 
  IBAN -- target account for returned payments (set '' to enable
       -- outgoing bank transfers to commercial partners from that account).
);
CREATE TABLE Debit (
  billId PRIMARY KEY NOT NULL,
  debtor NOT NULL, -- Account charged
  targetCredit INTEGER, -- record id in Credit table to pay into.
                   -- just understand it as virtual payment
                   -- NULL when debit is a bank transfer from the club account
  date DATE NOT NULL,
  purpose NOT NULL, -- description of receipt
  value INTEGER NOT NULL, -- Euro-Cent
  paid INTEGER DEFAULT 0, -- Euro-Cent, set and changed automatically (Cache)
  FOREIGN KEY (debtor) REFERENCES Account(ID),
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
  fromCredit INTEGER NOT NULL, 
  amount INTEGER, -- for later traceability, necessary when revoking transfers
  FOREIGN KEY (billId) REFERENCES Debit(billId),
  FOREIGN KEY (fromCredit) REFERENCES Credit(Id),
  UNIQUE (billId, fromCredit)
);

CREATE TABLE IF NOT EXISTS _temp (d, c, m);
CREATE TRIGGER balanceTransfer
     AFTER INSERT ON Transfer 
BEGIN

  SELECT RAISE(FAIL, "It is not the debtor who is set to pay")
    WHERE (SELECT debtor FROM Debit WHERE billId=NEW.billId)
       != (SELECT account FROM Credit WHERE Id=NEW.fromCredit)
    ;

  SELECT RAISE(FAIL, "Target of a debit cannot be an incoming payment")
  FROM Credit c
    JOIN Debit d ON c.Id = d.targetCredit
  WHERE c.Id = NEW.fromCredit
    AND c.value > 0
  GROUP BY c.Id
    HAVING count(d.billId) == 0
  ;

  INSERT INTO _temp
     SELECT remainingDebt, remainingCredit, min(remainingDebt,remainingCredit) 
     FROM (SELECT
         (SELECT value - paid FROM Debit WHERE billId=NEW.billId) AS remainingDebt, 
         (SELECT value - spent FROM Credit WHERE Id=NEW.fromCredit) AS remainingCredit
     )
  ;

  UPDATE Debit
      SET paid = paid + CASE
        WHEN (SELECT d FROM _temp) <= 0
          THEN RAISE(FAIL, "Debt settled")
        ELSE
          (SELECT m FROM _temp)
      END
      WHERE billId=NEW.billId;

  UPDATE Credit
      SET value = value + (SELECT m FROM _temp)
      WHERE Id = (
          SELECT targetCredit
          FROM Debit
          WHERE billId=NEW.billId
      );

  UPDATE Credit
      SET spent = spent + CASE
        WHEN (SELECT c FROM _temp) <= 0
          THEN RAISE(FAIL, "Credit spent")
        ELSE
          (SELECT m FROM _temp)
      END
      WHERE Id=NEW.fromCredit;

  UPDATE Transfer
      SET amount = (SELECT m FROM _temp)
      WHERE billId=NEW.billId AND fromCredit=NEW.fromCredit
        ;

  DELETE FROM _temp;

END;

CREATE TRIGGER revokeTransfer
    BEFORE DELETE ON Transfer
BEGIN

  INSERT INTO _temp VALUES (null,null,OLD.amount);

  UPDATE Debit
      SET paid = paid - OLD.amount
      WHERE billId=OLD.billId
      ;

  UPDATE Credit
      SET value = value - OLD.amount
      WHERE Id = (
          SELECT targetCredit
          FROM Debit
          WHERE billId=OLD.billId
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
    SELECT RAISE(FAIL, "Transfer cannot be updated, but needs to be replaced to make triggers run");
END;

CREATE TRIGGER enforceiZeroPaidAtStart
    BEFORE INSERT ON Debit
BEGIN
    SELECT RAISE(FAIL, "Debt must be initially unpaid")
    WHERE NEW.paid <> 0;
END;

-- Prevent modification of paid value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER enforceDebtImmutableOutsideTrigger
    BEFORE UPDATE OF paid ON Debit
    WHEN NOT EXISTS (SELECT * FROM Transfer t WHERE NEW.billId=t.billId AND amount IS NULL)
BEGIN
    SELECT RAISE(FAIL, "paid is set and adjusted automatically according to added Transfer records")
    WHERE (NEW.paid + IFNULL((SELECT m FROM _temp WHERE c IS NULL AND d IS NULL),0) ) <> OLD.paid;
END;

-- When a transfer is revoked, the targetCredit of the associated bill is reduced. Hence we must
-- check if we can still have paid the debts linked to this transfer in an "is paid from" relation,
-- otherwise we have to revoke these transfers as well.
CREATE TRIGGER rebalanceReducedCredit
    AFTER UPDATE OF value ON Credit
WHEN NEW.value < OLD.spent
BEGIN

    REPLACE INTO _temp (d, m)
    SELECT
        'from_' || NEW.Id,
        billId 
    FROM Transfer
    WHERE fromCredit = NEW.Id
    ORDER BY date DESC
    LIMIT 1
    ;

    DELETE
    FROM Transfer
    WHERE fromCredit = NEW.Id
      AND billId IN (
        SELECT billId
        FROM _temp
        WHERE c = 'from_' || NEW.Id
      )
    ;

    INSERT INTO Transfer (fromCredit, billId)
        SELECT NEW.Id, m
        FROM _temp
        WHERE d = 'from_' || NEW.Id
          AND NEW.value > (
              SELECT spent
              FROM Credit
              WHERE Id = NEW.Id
          )
    ;

    DELETE FROM _temp WHERE d = 'from_' || NEW.Id;

END;

-- When we enter a transfer, the targetCredit of the associated bill might already be the fromCredit
-- of a transfer for other dues itself. We can update (replace) the transfer for an unfullfilled one.
-- That way, a transfer may issue recursively chained transfers.
CREATE TRIGGER rebalanceIncreasedCredit
    AFTER UPDATE OF value ON Credit
WHEN NEW.value > OLD.spent
BEGIN

    REPLACE INTO Transfer
        SELECT OLD.Id AS fromCredit,
               billId
        FROM Transfer t
            JOIN CurrentDebts cd ON t.billId = cd.billId
    ;

END;

CREATE TRIGGER enforceFixedDebits
    BEFORE UPDATE OF value ON Debit
    WHEN EXISTS (SELECT * FROM Transfer WHERE billId=NEW.billId)
BEGIN
    SELECT RAISE(FAIL, "Debt is involved in transfers to revoke at first");
END;

CREATE TRIGGER enforceZeroSpentAtStart
    BEFORE INSERT ON Credit
BEGIN
    SELECT RAISE(FAIL, "credit must be initially unused")
    WHERE NEW.spent != 0;
END;

-- Prevent modification of spent value outside triggers which must adjust it exclusively
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
   FROM (
      SELECT instr(NEW.purpose, IBAN) AS fnd
      FROM Account
      WHERE ID=NEW.debtor
   ) AS matchingIBAN
   WHERE fnd IS NULL OR fnd = 0;
END;

CREATE VIEW CurrentDebts AS
    SELECT billId,
           debtor,
           targetCredit,
           purpose,
           date,
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
  SELECT Account.ID             AS ID,
      IFNULL(ac.allCredits,0)   AS credit,
      IFNULL(pr.allPromises, 0) AS promised,
      IFNULL(cd.allDebts, 0)    AS debt
  FROM Account
     LEFT OUTER JOIN (
         SELECT debtor, sum(difference) AS allDebts
         FROM CurrentDebts
         GROUP BY debtor
     )                          AS cd ON Account.ID=cd.debtor
     LEFT OUTER JOIN (
         SELECT account, sum(difference) AS allCredits
         FROM AvailableCredits
         GROUP BY account
     )                          AS ac ON Account.ID=ac.account
     LEFT OUTER JOIN (
         SELECT a.ID AS ID, sum(difference) AS allPromises
         FROM CurrentDebts cd
             JOIN Credit c ON cd.targetCredit = c.Id
             JOIN Account a ON a.ID = c.account
         GROUP BY a.ID
     )                          AS pr ON Account.ID=pr.ID
  ;

CREATE VIEW ReconstructedBankStatement AS
  SELECT c.date    AS date,
         c.purpose AS purpose,
         account,
         c.value   AS credit,
         NULL      AS debit
  FROM Credit AS c
    LEFT OUTER JOIN Debit AS d ON c.ID=d.targetCredit
  GROUP BY c.ID
    HAVING count(d.billId) == 0 -- exclude internal transfers
  UNION
  SELECT date,
         purpose,
         debtor     AS account,
         NULL       AS credit,
         value      AS debit
  FROM Debit
  WHERE targetCredit IS NULL    -- exclude internal transfers
  ORDER BY date ASC
;

-- History view: All incoming, outgoing payments and internal transfers
CREATE VIEW History AS
  SELECT c.date          AS date,
         c.purpose       AS purpose,
                            account,
         c.value         AS credit,
         NULL            AS debit,
         NULL            AS contra,    
         NULL            AS billId
  FROM Credit AS c
    LEFT OUTER JOIN Debit AS d ON c.ID=d.targetCredit
  GROUP BY c.ID
    HAVING count(d.billId) == 0 -- exclude internal transfers
  UNION -- internal transfers with account as source
  SELECT DATE(timestamp) AS date,
         d.purpose       AS purpose,
         d.debtor        AS account,
         NULL            AS credit,
         t.amount        AS debit,
         c.account       AS contra,
         d.billId        AS billId
  FROM Transfer t
    LEFT JOIN Credit AS c ON c.Id     = t.fromCredit
    LEFT JOIN Debit  AS d ON d.billId = t.billId
  UNION -- internal transfers with account as target
  SELECT DATE(timestamp) AS date,
         d.purpose       AS purpose,
         c.account       AS account,
         t.amount        AS credit,
         NULL            AS debit,
         d.debtor        AS contra,
         d.billId        AS billId
  FROM Transfer t
    LEFT JOIN Debit  AS d ON d.billId = t.billId
    LEFT JOIN Credit AS c ON c.Id     = t.fromCredit
  ORDER BY date ASC
;
