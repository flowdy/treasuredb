CREATE TRIGGER linkTransferTightly
    AFTER INSERT ON Transfer 
BEGIN

  SELECT RAISE(FAIL, "It is not the debtor who is set to pay")
    WHERE (SELECT debtor FROM Debit WHERE billId=NEW.billId)
       != (SELECT account FROM Credit WHERE credId=NEW.credId)
    ;

  SELECT RAISE(FAIL, "Target of a debit cannot be an incoming payment")
  FROM Credit c
    JOIN Debit d ON c.credId = d.targetCredit
  WHERE c.credId = NEW.credId
    AND c.value > 0
  GROUP BY c.credId
    HAVING count(d.billId) == 0
  ;

  INSERT INTO __INTERNAL_TRIGGER_STACK
      SELECT NEW.ROWID,
          CASE remainingDebt   WHEN 0 THEN RAISE(FAIL, "Debt settled") ELSE NEW.billId END,
          CASE remainingCredit WHEN 0 THEN RAISE(FAIL, "Credit spent") ELSE NEW.credId END,
          min(remainingDebt, remainingCredit) 
      FROM (SELECT
          (SELECT value - paid FROM Debit WHERE billId=NEW.billId) AS remainingDebt, 
          (SELECT value - spent FROM Credit WHERE credId=NEW.credId) AS remainingCredit
      )
  ;

END;

CREATE TRIGGER reflectTransfer
    AFTER INSERT ON __INTERNAL_TRIGGER_STACK
    WHEN NEW.id > 0
BEGIN

  UPDATE Debit
      SET paid = paid + NEW.m
      WHERE billId = NEW.d;

  UPDATE Credit
      SET spent = spent + NEW.m
      WHERE credId = NEW.c;

  UPDATE Transfer
      SET amount = ifnull(amount,0) + NEW.m
      WHERE ROWID = NEW.id;

  UPDATE Credit
      SET value = value + NEW.m
      WHERE credId = (
          SELECT targetCredit
          FROM Debit
          WHERE billId = NEW.d
      );

  DELETE FROM __INTERNAL_TRIGGER_STACK WHERE id=NEW.id;

END;

CREATE TRIGGER refreshTransfer
    AFTER UPDATE OF amount ON Transfer
BEGIN

    DELETE FROM Transfer
        WHERE ROWID = NEW.ROWID AND amount = 0;

    UPDATE Transfer
        SET timestamp=CURRENT_TIMESTAMP
        WHERE ROWID=NEW.ROWID;   

END;

