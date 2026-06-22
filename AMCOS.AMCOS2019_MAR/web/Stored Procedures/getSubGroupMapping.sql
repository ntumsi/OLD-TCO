


CREATE PROCEDURE [web].[getSubGroupMapping]
    @PayPlan NVARCHAR(3) ,
    @CategorySubGroupCode NVARCHAR(7)
AS
    IF @PayPlan = 'AE'
        BEGIN
            SELECT CategorySubGroupCode ,
                   CategorySubGroupCode + ' - ' + CategorySubGroupDescription AS Description
            FROM   data.CategorySubgroupWithInventory
            WHERE  PayPlan = 'AE'
                   AND CategorySubGroupCode = @CategorySubGroupCode;

            SELECT   CategorySubGroupCode ,
                     CategorySubGroupCode + ' - ' + CategorySubGroupDescription AS Description
            FROM     data.CategorySubgroupWithInventory
            WHERE    PayPlan = 'AO'
                     AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                     FROM   lookup.SubgroupMapping
                                                     WHERE  PayPlan = 'AO'
                                                            AND ToPayPlan = 'GS'
                                                            AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                              FROM   lookup.SubgroupMapping
                                                                                              WHERE  PayPlan = 'AE'
                                                                                                     AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                     AND ToPayPlan = 'GS'
                                                                                          )
                                                     UNION
                                                     SELECT CategorySubGroupCode
                                                     FROM   lookup.SubgroupMapping
                                                     WHERE  PayPlan = 'AO'
                                                            AND ToPayPlan = 'CCE'
                                                            AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                              FROM   lookup.SubgroupMapping
                                                                                              WHERE  PayPlan = 'AE'
                                                                                                     AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                     AND ToPayPlan = 'CCE'
                                                                                          )
                                                 )
            ORDER BY CategorySubGroupCode;
            -- AWO
            SELECT   CategorySubGroupCode ,
                     CategorySubGroupCode + ' - ' + CategorySubGroupDescription AS Description
            FROM     data.CategorySubgroupWithInventory
            WHERE    PayPlan = 'AWO'
                     AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                     FROM   lookup.SubgroupMapping
                                                     WHERE  PayPlan = 'AWO'
                                                            AND ToPayPlan = 'GS'
                                                            AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                              FROM   lookup.SubgroupMapping
                                                                                              WHERE  PayPlan = 'AE'
                                                                                                     AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                     AND ToPayPlan = 'GS'
                                                                                          )
                                                     UNION
                                                     SELECT CategorySubGroupCode
                                                     FROM   lookup.SubgroupMapping
                                                     WHERE  PayPlan = 'AWO'
                                                            AND ToPayPlan = 'CCE'
                                                            AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                              FROM   lookup.SubgroupMapping
                                                                                              WHERE  PayPlan = 'AE'
                                                                                                     AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                     AND ToPayPlan = 'CCE'
                                                                                          )
                                                 )
            ORDER BY CategorySubGroupCode;
            -- GS
            SELECT   CategorySubGroupCode ,
                     CategorySubGroupCode + ' - ' + CategorySubGroupDescription AS Description
            FROM     data.CategorySubgroupWithInventory
            WHERE    PayPlan = 'GS'
                     AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                     FROM   lookup.SubgroupMapping
                                                     WHERE  PayPlan = 'AE'
                                                            AND ToPayPlan = 'GS'
                                                            AND CategorySubGroupCode = @CategorySubGroupCode
                                                 )
            ORDER BY CategorySubGroupCode;
            -- PLM
            SELECT   CategorySubGroupCode ,
                     CategorySubGroupCode + ' - ' + CategorySubGroupDescription AS Description
            FROM     data.CategorySubgroupWithInventory
            WHERE    PayPlan = 'CCE'
                     AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                     FROM   lookup.SubgroupMapping
                                                     WHERE  PayPlan = 'AE'
                                                            AND ToPayPlan = 'CCE'
                                                            AND CategorySubGroupCode = @CategorySubGroupCode
                                                 )
            ORDER BY CategorySubGroupCode;
            -- for WG/WL/WS get count with mapping to civ 2299+
            SELECT COUNT(*)
            FROM   lookup.SubgroupMappingForCivOver2299
            WHERE  PayPlan = 'AE'
                   AND CategorySubGroupCode = @CategorySubGroupCode;

        END;
    ELSE IF @PayPlan = 'AO'
             BEGIN
                 -- AE
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AE'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'GS'
                                                                                               )
                                                          UNION
                                                          SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'CCE'
                                                                                               )
                                                      )
                 ORDER BY CategorySubGroupCode;
                 -- AO
                 SELECT CategorySubGroupCode ,
                        CategorySubGroupCode + ' - '
                        + CategorySubGroupDescription AS Description
                 FROM   data.CategorySubgroupWithInventory
                 WHERE  PayPlan = 'AO'
                        AND CategorySubGroupCode = @CategorySubGroupCode;
                 -- AWO
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AWO'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'GS'
                                                                                               )
                                                          UNION
                                                          SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'CCE'
                                                                                               )
                                                      )
                 ORDER BY CategorySubGroupCode;
                 -- GS
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'GS'
                          AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;
                 -- PLM
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'CCE'
                          AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;
                 -- for WG/WL/WS get count with mapping to civ 2299+
                 SELECT COUNT(*)
                 FROM   lookup.SubgroupMappingForCivOver2299
                 WHERE  PayPlan = 'AO'
                        AND CategorySubGroupCode = @CategorySubGroupCode;

             END;
    ELSE IF @PayPlan = 'AWO'
             BEGIN
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AE'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AWO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'GS'
                                                                                               )
                                                          UNION
                                                          SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AWO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'CCE'
                                                                                               )
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AO'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AWO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'GS'
                                                                                               )
                                                          UNION
                                                          SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                                                                   FROM   lookup.SubgroupMapping
                                                                                                   WHERE  PayPlan = 'AWO'
                                                                                                          AND CategorySubGroupCode = @CategorySubGroupCode
                                                                                                          AND ToPayPlan = 'CCE'
                                                                                               )
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT CategorySubGroupCode ,
                        CategorySubGroupCode + ' - '
                        + CategorySubGroupDescription AS Description
                 FROM   data.CategorySubgroupWithInventory
                 WHERE  PayPlan = 'AWO'
                        AND CategorySubGroupCode = @CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'GS'
                          AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'CCE'
                          AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND CategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 -- for WG/WL/WS get count with mapping to civ 2299+
                 SELECT COUNT(*)
                 FROM   lookup.SubgroupMappingForCivOver2299
                 WHERE  PayPlan = 'AWO'
                        AND CategorySubGroupCode = @CategorySubGroupCode;

             END;
    ELSE IF @PayPlan = 'GS'
             BEGIN
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AE'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AO'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AWO'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT CategorySubGroupCode ,
                        CategorySubGroupCode + ' - '
                        + CategorySubGroupDescription AS Description
                 FROM   data.CategorySubgroupWithInventory
                 WHERE  PayPlan = 'GS'
                        AND CategorySubGroupCode = @CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'CCE'
                          AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                                                                 FROM   lookup.SubgroupMapping
                                                                                                 WHERE  PayPlan = 'AE'
                                                                                                        AND ToPayPlan = 'GS'
                                                                                                        AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                                                             )
                                                          UNION
                                                          SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                                                                 FROM   lookup.SubgroupMapping
                                                                                                 WHERE  PayPlan = 'AO'
                                                                                                        AND ToPayPlan = 'GS'
                                                                                                        AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                                                             )
                                                          UNION
                                                          SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                                                                 FROM   lookup.SubgroupMapping
                                                                                                 WHERE  PayPlan = 'AWO'
                                                                                                        AND ToPayPlan = 'GS'
                                                                                                        AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                                                             )
                                                      )
                 ORDER BY CategorySubGroupCode;

                 -- for WG/WL/WS get count with mapping to civ 2299+
                 SELECT COUNT(*)
                 FROM   lookup.SubgroupMappingForCivOver2299
                 WHERE  (   PayPlan = 'AE'
                            AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                            FROM   lookup.SubgroupMapping
                                                            WHERE  PayPlan = 'AE'
                                                                   AND ToPayPlan = 'GS'
                                                                   AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                        )
                        )
                        OR (   PayPlan = 'AO'
                               AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                               FROM   lookup.SubgroupMapping
                                                               WHERE  PayPlan = 'AO'
                                                                      AND ToPayPlan = 'GS'
                                                                      AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                           )
                           )
                        OR (   PayPlan = 'AWO'
                               AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                               FROM   lookup.SubgroupMapping
                                                               WHERE  PayPlan = 'AWO'
                                                                      AND ToPayPlan = 'GS'
                                                                      AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                           )
                           );

             END;
    ELSE IF @PayPlan = 'CCE'
             BEGIN
                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AE'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AO'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'AWO'
                          AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'CCE'
                                                                 AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT   CategorySubGroupCode ,
                          CategorySubGroupCode + ' - '
                          + CategorySubGroupDescription AS Description
                 FROM     data.CategorySubgroupWithInventory
                 WHERE    PayPlan = 'GS'
                          AND CategorySubGroupCode IN (   SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AE'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                                                                 FROM   lookup.SubgroupMapping
                                                                                                 WHERE  PayPlan = 'AE'
                                                                                                        AND ToPayPlan = 'CCE'
                                                                                                        AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                                                             )
                                                          UNION
                                                          SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                                                                 FROM   lookup.SubgroupMapping
                                                                                                 WHERE  PayPlan = 'AO'
                                                                                                        AND ToPayPlan = 'CCE'
                                                                                                        AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                                                             )
                                                          UNION
                                                          SELECT ToCategorySubGroupCode
                                                          FROM   lookup.SubgroupMapping
                                                          WHERE  PayPlan = 'AWO'
                                                                 AND ToPayPlan = 'GS'
                                                                 AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                                                                 FROM   lookup.SubgroupMapping
                                                                                                 WHERE  PayPlan = 'AWO'
                                                                                                        AND ToPayPlan = 'CCE'
                                                                                                        AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                                                             )
                                                      )
                 ORDER BY CategorySubGroupCode;

                 SELECT CategorySubGroupCode ,
                        CategorySubGroupCode + ' - '
                        + CategorySubGroupDescription AS Description
                 FROM   data.CategorySubgroupWithInventory
                 WHERE  PayPlan = 'CCE'
                        AND CategorySubGroupCode = @CategorySubGroupCode;

                 -- for WG/WL/WS get count with mapping to civ 2299+
                 SELECT COUNT(*)
                 FROM   lookup.SubgroupMappingForCivOver2299
                 WHERE  (   PayPlan = 'AE'
                            AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                            FROM   lookup.SubgroupMapping
                                                            WHERE  PayPlan = 'AE'
                                                                   AND ToPayPlan = 'CCE'
                                                                   AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                        )
                        )
                        OR (   PayPlan = 'AO'
                               AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                               FROM   lookup.SubgroupMapping
                                                               WHERE  PayPlan = 'AO'
                                                                      AND ToPayPlan = 'CCE'
                                                                      AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                           )
                           )
                        OR (   PayPlan = 'AWO'
                               AND CategorySubGroupCode IN (   SELECT CategorySubGroupCode
                                                               FROM   lookup.SubgroupMapping
                                                               WHERE  PayPlan = 'AWO'
                                                                      AND ToPayPlan = 'CCE'
                                                                      AND ToCategorySubGroupCode = @CategorySubGroupCode
                                                           )
                           );
             END;