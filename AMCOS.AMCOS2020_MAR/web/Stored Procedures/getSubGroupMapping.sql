CREATE PROCEDURE [web].[getSubGroupMapping]
    @PayPlan NVARCHAR(3),
    @CategorySubgroupCode NVARCHAR(7),
    @AmcosVersionId INT
AS
CREATE TABLE #SubgroupMapping
(
    [PayPlan] [NVARCHAR](3) NOT NULL,
    [CategorySubgroupCode] [NVARCHAR](7) NOT NULL,
    [ToPayPlan] [NVARCHAR](3) NOT NULL,
    [ToCategorySubgroupCode] [NVARCHAR](7) NOT NULL,
    [AmcosVersionIdStart] [INT] NULL,
    [AmcosVersionIdEnd] [INT] NOT NULL
);
INSERT INTO #SubgroupMapping
(
    PayPlan,
    CategorySubgroupCode,
    ToPayPlan,
    ToCategorySubgroupCode,
    AmcosVersionIdStart,
    AmcosVersionIdEnd
)
SELECT PayPlan,
       CategorySubgroupCode,
       ToPayPlan,
       ToCategorySubgroupCode,
       AmcosVersionIdStart,
       AmcosVersionIdEnd
FROM lookup.SubgroupMapping
WHERE (@AmcosVersionId
      BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
      );

IF @PayPlan = 'AE'
BEGIN
    /* AE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode = @CategorySubgroupCode;
    /* AO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AE'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'GS'
                            )
                  UNION
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AE'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'CCE'
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* AWO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AWO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AE'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'GS'
                            )
                  UNION
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AE'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'CCE'
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* GS */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'GS'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'GS'
                        AND CategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* CCE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'CCE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'CCE'
                        AND CategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* WG/WL/WS get count with mapping to civ 2299+ */
    SELECT COUNT(*)
    FROM lookup.SubgroupMappingForCivOver2299
    WHERE PayPlan = 'AE'
          AND CategorySubgroupCode = @CategorySubgroupCode
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );
END;
ELSE IF @PayPlan = 'AO'
BEGIN
    /* AE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'GS'
                            )
                  UNION
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'CCE'
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* AO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode = @CategorySubgroupCode;
    /* AWO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AWO'
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'GS'
                            )
                  UNION
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'CCE'
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* GS */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'GS'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'GS'
                        AND CategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* CCE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'CCE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'CCE'
                        AND CategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* WG/WL/WS get count with mapping to civ 2299+ */
    SELECT COUNT(*)
    FROM lookup.SubgroupMappingForCivOver2299
    WHERE PayPlan = 'AO'
          AND CategorySubgroupCode = @CategorySubgroupCode
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );
END;
ELSE IF @PayPlan = 'AWO'
BEGIN
    /* AE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AWO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'GS'
                            )
                  UNION
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AWO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'CCE'
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* AO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AWO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'GS'
                            )
                  UNION
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode IN
                            (
                                SELECT ToCategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AWO'
                                      AND CategorySubgroupCode = @CategorySubgroupCode
                                      AND ToPayPlan = 'CCE'
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* AWO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AWO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode = @CategorySubgroupCode;
    /* GS */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'GS'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'GS'
                        AND CategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* CCE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'CCE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'CCE'
                        AND CategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* WG/WL/WS get count with mapping to civ 2299+ */
    SELECT COUNT(*)
    FROM lookup.SubgroupMappingForCivOver2299
    WHERE PayPlan = 'AWO'
          AND CategorySubgroupCode = @CategorySubgroupCode
          AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
              );
END;
ELSE IF @PayPlan = 'GS'
BEGIN
    /* AE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* AO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* AWO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AWO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'GS'
                        AND ToCategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* GS */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'GS'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode = @CategorySubgroupCode;
    /* CCE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'CCE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'CCE'
                        AND CategorySubgroupCode IN
                            (
                                SELECT CategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AE'
                                      AND ToPayPlan = 'GS'
                                      AND ToCategorySubgroupCode = @CategorySubgroupCode
                            )
                  UNION
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'CCE'
                        AND CategorySubgroupCode IN
                            (
                                SELECT CategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AO'
                                      AND ToPayPlan = 'GS'
                                      AND ToCategorySubgroupCode = @CategorySubgroupCode
                            )
                  UNION
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'CCE'
                        AND CategorySubgroupCode IN
                            (
                                SELECT CategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AWO'
                                      AND ToPayPlan = 'GS'
                                      AND ToCategorySubgroupCode = @CategorySubgroupCode
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* WG/WL/WS get count with mapping to civ 2299+ */
    SELECT COUNT(*)
    FROM lookup.SubgroupMappingForCivOver2299
    WHERE (
              PayPlan = 'AE'
              AND CategorySubgroupCode IN
                  (
                      SELECT CategorySubgroupCode
                      FROM #SubgroupMapping
                      WHERE PayPlan = 'AE'
                            AND ToPayPlan = 'GS'
                            AND ToCategorySubgroupCode = @CategorySubgroupCode
                  )
          )
          OR
          (
              PayPlan = 'AO'
              AND CategorySubgroupCode IN
                  (
                      SELECT CategorySubgroupCode
                      FROM #SubgroupMapping
                      WHERE PayPlan = 'AO'
                            AND ToPayPlan = 'GS'
                            AND ToCategorySubgroupCode = @CategorySubgroupCode
                  )
          )
          OR (
                 PayPlan = 'AWO'
                 AND CategorySubgroupCode IN
                     (
                         SELECT CategorySubgroupCode
                         FROM #SubgroupMapping
                         WHERE PayPlan = 'AWO'
                               AND ToPayPlan = 'GS'
                               AND ToCategorySubgroupCode = @CategorySubgroupCode
                     )
             )
             AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                 );
END;
ELSE IF @PayPlan = 'CCE'
BEGIN
    /* AE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* AO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* AWO */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'AWO'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT CategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'CCE'
                        AND ToCategorySubgroupCode = @CategorySubgroupCode
              )
    ORDER BY CategorySubgroupCode;
    /* GS */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'GS'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode IN
              (
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AE'
                        AND ToPayPlan = 'GS'
                        AND CategorySubgroupCode IN
                            (
                                SELECT CategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AE'
                                      AND ToPayPlan = 'CCE'
                                      AND ToCategorySubgroupCode = @CategorySubgroupCode
                            )
                  UNION
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AO'
                        AND ToPayPlan = 'GS'
                        AND CategorySubgroupCode IN
                            (
                                SELECT CategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AO'
                                      AND ToPayPlan = 'CCE'
                                      AND ToCategorySubgroupCode = @CategorySubgroupCode
                            )
                  UNION
                  SELECT ToCategorySubgroupCode
                  FROM #SubgroupMapping
                  WHERE PayPlan = 'AWO'
                        AND ToPayPlan = 'GS'
                        AND CategorySubgroupCode IN
                            (
                                SELECT CategorySubgroupCode
                                FROM #SubgroupMapping
                                WHERE PayPlan = 'AWO'
                                      AND ToPayPlan = 'CCE'
                                      AND ToCategorySubgroupCode = @CategorySubgroupCode
                            )
              )
    ORDER BY CategorySubgroupCode;
    /* CCE */
    SELECT CategorySubgroupCode,
           CategorySubgroupDisplay
    FROM warehouse.Category
    WHERE PayPlan = 'CCE'
          AND @AmcosVersionId = @AmcosVersionId
          AND CategorySubgroupCode = @CategorySubgroupCode;
    /* WG/WL/WS get count with mapping to civ 2299+ */
    SELECT COUNT(*)
    FROM lookup.SubgroupMappingForCivOver2299
    WHERE (
              PayPlan = 'AE'
              AND CategorySubgroupCode IN
                  (
                      SELECT CategorySubgroupCode
                      FROM #SubgroupMapping
                      WHERE PayPlan = 'AE'
                            AND ToPayPlan = 'CCE'
                            AND ToCategorySubgroupCode = @CategorySubgroupCode
                  )
          )
          OR
          (
              PayPlan = 'AO'
              AND CategorySubgroupCode IN
                  (
                      SELECT CategorySubgroupCode
                      FROM #SubgroupMapping
                      WHERE PayPlan = 'AO'
                            AND ToPayPlan = 'CCE'
                            AND ToCategorySubgroupCode = @CategorySubgroupCode
                  )
          )
          OR (
                 PayPlan = 'AWO'
                 AND CategorySubgroupCode IN
                     (
                         SELECT CategorySubgroupCode
                         FROM #SubgroupMapping
                         WHERE PayPlan = 'AWO'
                               AND ToPayPlan = 'CCE'
                               AND ToCategorySubgroupCode = @CategorySubgroupCode
                     )
             )
             AND (@AmcosVersionId
          BETWEEN AmcosVersionIdStart AND AmcosVersionIdEnd
                 );
END;