DROP VIEW IF EXISTS AvailableCredits;
CREATE VIEW AvailableCredits AS
    SELECT credId, account, purpose, date,
           value - spent AS difference
    FROM Credit
    WHERE value != spent
;
