CREATE TRIGGER x_paidFromBeginning
    BEFORE INSERT ON Debit
BEGIN
    SELECT RAISE(FAIL, "Debt must be initially unpaid")
    WHERE NEW.paid <> 0;
END;
