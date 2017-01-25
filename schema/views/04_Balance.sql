DROP VIEW IF EXISTS Balance;
CREATE VIEW Balance AS
  SELECT Account.ID             AS ID,
      IFNULL(ac.allCredits,0)   AS available,
      IFNULL(hi.credit,0)       AS earned,
      IFNULL(hi.debit,0)        AS spent,
      IFNULL(pr.allPromises, 0) AS promised,
      IFNULL(ca.allArrears, 0)  AS arrears,
      even.until                AS even_until
  FROM Account
     LEFT OUTER JOIN (
         SELECT debtor, sum(difference) AS allArrears
         FROM CurrentArrears
         GROUP BY debtor
     )                          AS ca ON Account.ID=ca.debtor
     LEFT OUTER JOIN (
         SELECT account, sum(difference) AS allCredits
         FROM AvailableCredits
         GROUP BY account
     )                          AS ac ON Account.ID=ac.account
     LEFT OUTER JOIN (
         SELECT a.ID AS ID, sum(difference) AS allPromises
         FROM CurrentArrears ca
             JOIN Credit c ON ca.targetCredit = c.credId
             JOIN Account a ON a.ID = c.account
         GROUP BY a.ID
     )                          AS pr ON Account.ID=pr.ID
     LEFT OUTER JOIN (
         SELECT account,
                sum(credit) AS credit,
                sum(debit) AS debit
         FROM History
         GROUP BY account
     )                          AS hi ON Account.ID=hi.account
     LEFT OUTER JOIN (
         SELECT d.debtor     AS account,
                max(d.date)  AS until
         FROM Debit d
         LEFT OUTER JOIN (
             SELECT debtor, min(date) uneven_from
             FROM CurrentArrears
             GROUP BY debtor
         ) AS ca ON d.debtor=ca.debtor
         WHERE d.date < IFNULL( ca.uneven_from, '9999-99-99' )
         GROUP BY d.debtor
     )                          AS even ON Account.ID=even.account
  ;

