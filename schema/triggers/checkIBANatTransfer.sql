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

