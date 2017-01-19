CREATE TRIGGER balanceTransfer
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

  INSERT INTO __DO_NOT_MANIPULATE__trigger_memory
     SELECT remainingDebt, remainingCredit, min(remainingDebt,remainingCredit) 
     FROM (SELECT
         (SELECT value - paid FROM Debit WHERE billId=NEW.billId) AS remainingDebt, 
         (SELECT value - spent FROM Credit WHERE credId=NEW.credId) AS remainingCredit
     )
  ;

  UPDATE Debit
      SET paid = paid + CASE
        WHEN (SELECT d FROM __DO_NOT_MANIPULATE__trigger_memory) <= 0
          THEN RAISE(FAIL, "Debt settled")
        ELSE
          (SELECT m FROM __DO_NOT_MANIPULATE__trigger_memory)
      END
      WHERE billId=NEW.billId;

  UPDATE Credit
      SET spent = spent + CASE
        WHEN (SELECT c FROM __DO_NOT_MANIPULATE__trigger_memory) <= 0
          THEN RAISE(FAIL, "Credit spent")
        ELSE IFNULL(
          (SELECT m FROM __DO_NOT_MANIPULATE__trigger_memory),
          RAISE(FAIL,"Oops, lost __DO_NOT_MANIPULATE__trigger_memory record before increasing spent")
        )
      END
      WHERE credId=NEW.credId;

  UPDATE Transfer
      SET amount = (SELECT m FROM __DO_NOT_MANIPULATE__trigger_memory)
      WHERE billId=NEW.billId AND credId=NEW.credId
        ;

  UPDATE Credit
      SET value = value + IFNULL(
          (SELECT m FROM __DO_NOT_MANIPULATE__trigger_memory),
          RAISE(FAIL, "Oops, lost __DO_NOT_MANIPULATE__trigger_memory record before increasing value")
      )
      WHERE credId = (
          SELECT targetCredit
          FROM Debit
          WHERE billId=NEW.billId
      );

  DELETE FROM __DO_NOT_MANIPULATE__trigger_memory;

END;

