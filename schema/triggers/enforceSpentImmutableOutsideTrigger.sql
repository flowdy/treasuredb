-- Prevent modification of spent value outside triggers which must adjust it exclusively
-- when new transfer records are inserted
CREATE TRIGGER enforceSpentImmutableOutsideTrigger
    BEFORE UPDATE OF spent ON Credit
    WHEN NOT EXISTS (SELECT * FROM Transfer t WHERE NEW.credId=t.credId AND amount IS NULL)
BEGIN
    SELECT RAISE(FAIL, "spent is set and adjusted automatically according to added Transfer records")
    WHERE (NEW.spent + IFNULL(
            (SELECT m FROM __DO_NOT_MANIPULATE__trigger_memory WHERE c IS NULL AND d IS NULL), 0
        ) ) <> OLD.spent;
END;

