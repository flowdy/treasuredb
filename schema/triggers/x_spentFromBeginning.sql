CREATE TRIGGER x_spentFromBeginning
    BEFORE INSERT ON Credit
BEGIN
    SELECT RAISE(ABORT, "credit must be initially unused")
    WHERE NEW.spent != 0;
END;

