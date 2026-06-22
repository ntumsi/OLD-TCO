




CREATE VIEW [analysis].[PythonOutBriefCompareATRM]
AS
SELECT *,
       CASE
           WHEN delta > 300000 THEN
               '1 over 300,000'
           WHEN delta > 150000 THEN
               '2 over 150,000'
           WHEN delta > 100000 THEN
               '3 over 100,000'
           WHEN delta > 50000 THEN
               '4 over 50,000'
           WHEN delta > 25000 THEN
               '5 over 25,000'
           ELSE
               'All other'
       END AS bin
FROM
(
    SELECT *,
           Total_cost - prior_Cost AS delta,
           ABS(Total_cost - prior_Cost) AS deltaabs,
           (Total_cost - prior_Cost) / prior_Cost AS percchange
    FROM
    (
        SELECT *,
               LAG(Total_cost) OVER (PARTITION BY SchoolCode, CourseNumber ORDER BY [AmcosVersionId]) AS prior_Cost
        FROM
        (
            SELECT *,
                   SchoolCode + CourseNumber AS mykey,
                   MPA_Cost + OMACivPay_Cost + OMANonPay_Cost + Other_Cost AS Total_cost
            FROM load_training.ATRM
        ) AS a
    ) AS a
) AS a;