CREATE TRIGGER enforceZeroPaidAtStart
    BEFORE INSERT ON Debit
BEGIN
    SELECT RAISE(FAIL, "Debt must be initially unpaid")
    WHERE NEW.paid <> 0;
END;

