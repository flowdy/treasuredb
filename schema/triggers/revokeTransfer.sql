CREATE TRIGGER revokeTransfer
    BEFORE DELETE ON Transfer
BEGIN

  INSERT INTO __DO_NOT_MANIPULATE__trigger_memory VALUES (null,null,OLD.amount);

  UPDATE Debit
      SET paid = paid - OLD.amount
      WHERE billId=OLD.billId
      ;

  UPDATE Credit
      SET value = value - OLD.amount
      WHERE credId = (
          SELECT targetCredit
          FROM Debit
          WHERE billId=OLD.billId
      );

  UPDATE Credit
      SET spent = spent - OLD.amount
      WHERE credId = OLD.credId;

  DELETE FROM __DO_NOT_MANIPULATE__trigger_memory;

END;

