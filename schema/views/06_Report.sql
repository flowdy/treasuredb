DROP VIEW IF EXISTS CreditsInFocus;
CREATE VIEW CreditsInFocus AS
  SELECT account, date, credId, value, purpose
  FROM Credit
  WHERE value > spent
  UNION
  SELECT c.account, date, credId, value, purpose
  FROM Credit c
    JOIN Balance b ON b.ID = c.account
  WHERE c.date >= b.even_until
  GROUP BY c.credId
;

-- Report view may be of use in communication with club members who are due
-- of outstanding fees, listing what they have paid and what is yet to pay.
DROP VIEW IF EXISTS Report;
CREATE VIEW Report AS
  SELECT *
  FROM (
    SELECT account, date, credId, value, purpose        -- relevant incomes
    FROM CreditsInFocus
    UNION
    SELECT debtor        AS account,                    -- partial payments
           DATE(t.timestamp)
                         AS date,
           t.credId      AS credId,
           t.amount * -1 AS value,
           d.purpose || ' [' || d.billId || ']'
             || CASE WHEN t.note IS NULL
                  THEN ''
                  ELSE ( x'0a' || '(' || t.note || ')' )
                END
                         AS purpose
    FROM Debit d
      JOIN Transfer t ON t.billId = d.billId
      JOIN CreditsInFocus fc ON fc.credId=t.credId
    UNION
    SELECT debtor          AS account,                  -- current arrears
           date,
           NULL            AS credId,
           difference * -1 AS value,
           purpose || ' [' || billId || ']'
                   || x'0a' || '(YET TO PAY)'
    FROM CurrentArrears
  )
  ORDER BY account, credId IS NULL, credId,
    value < 0, date ASC
;






