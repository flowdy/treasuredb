CREATE TRIGGER enforceZeroSpentAtStart
    BEFORE INSERT ON Credit
BEGIN
    SELECT RAISE(FAIL, "credit must be initially unused")
    WHERE NEW.spent != 0;
END;

