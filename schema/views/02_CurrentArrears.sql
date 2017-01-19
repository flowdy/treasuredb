DROP VIEW IF EXISTS CurrentArrears;
CREATE VIEW CurrentArrears AS
    SELECT billId,
           debtor,
           targetCredit,
           purpose,
           date,
           value - paid AS difference
    FROM Debit
    WHERE value != paid
;
