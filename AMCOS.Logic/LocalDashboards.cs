using System.Data;

namespace AMCOS.Logic
{
    // Data-access for the local (non-QuickSight) dashboards. Each method runs a
    // parameterised query against the migrated Postgres views/tables via
    // DataAccessUtility and returns a display-ready DataTable. Kept deliberately thin:
    // the Razor page handlers shape these into the JSON the C3 charts consume.
    public static class LocalDashboards
    {
        // ---- Cost Compare -------------------------------------------------------

        // Distinct pay plans that actually have cost rows for the given version, so the
        // filter only offers selections that will render something.
        public static DataTable GetCostPayPlans(int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT DISTINCT payplan
                  FROM data.costs
                  WHERE amcosversionid = @version
                  ORDER BY payplan",
                new[] { "@version" },
                new object[] { amcosVersionId });
        }

        // Pay plans that have cost data in ANY version — the filter for the two-version
        // comparison (a plan may exist in one of the two chosen versions but not the other).
        public static DataTable GetAllCostPayPlans()
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT DISTINCT payplan FROM data.costs ORDER BY payplan");
        }

        // AMCOS versions that have cost data, newest first (used to default the filter).
        public static DataTable GetCostVersions()
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT DISTINCT amcosversionid
                  FROM data.costs
                  ORDER BY amcosversionid DESC");
        }

        // Total cost amount by grade level and cost-element category for one pay plan /
        // version — the grouped-bar source for the Cost Compare chart.
        public static DataTable GetCostCompare(string payPlan, int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT gradelevel,
                         COALESCE(NULLIF(costelementcategory, ''), 'Other') AS costelementcategory,
                         SUM(amount) AS amount
                  FROM data.costs
                  WHERE payplan = @payplan
                    AND amcosversionid = @version
                  GROUP BY gradelevel, COALESCE(NULLIF(costelementcategory, ''), 'Other')
                  ORDER BY gradelevel",
                new[] { "@payplan", "@version" },
                new object[] { payPlan, amcosVersionId });
        }

        // Total cost amount by grade level for one pay plan / version — the per-version
        // series for the Cost Compare version-vs-version chart (summed across categories).
        public static DataTable GetCostTotalByGrade(string payPlan, int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT gradelevel, SUM(amount) AS amount
                  FROM data.costs
                  WHERE payplan = @payplan
                    AND amcosversionid = @version
                  GROUP BY gradelevel
                  ORDER BY gradelevel",
                new[] { "@payplan", "@version" },
                new object[] { payPlan, amcosVersionId });
        }

        // ---- Inventory ----------------------------------------------------------

        // All defined AMCOS versions (newest first). Used where a dashboard must offer a
        // version selector even when its fact table is empty (e.g. inventory before ETL).
        public static DataTable GetAmcosVersions()
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT amcosversionid, description
                  FROM lookup.amcosversion
                  ORDER BY amcosversionid DESC");
        }

        // Pay plans with inventory in ANY version (filter for the two-version comparison).
        public static DataTable GetAllInventoryPayPlans()
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT DISTINCT payplan FROM data.inventory ORDER BY payplan");
        }

        public static DataTable GetInventoryPayPlans(int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT DISTINCT payplan
                  FROM data.inventory
                  WHERE amcosversionid = @version
                  ORDER BY payplan",
                new[] { "@version" },
                new object[] { amcosVersionId });
        }

        // Inventory head-count by grade level and category group for one pay plan /
        // version. (data.inventory is empty until inventory ETL runs; the dashboard
        // renders an empty state in that case.)
        public static DataTable GetInventoryByGrade(string payPlan, int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT gradelevel,
                         COALESCE(NULLIF(categorygroupcode, ''), 'Other') AS categorygroupcode,
                         SUM(inventory) AS inventory
                  FROM data.inventory
                  WHERE payplan = @payplan
                    AND amcosversionid = @version
                  GROUP BY gradelevel, COALESCE(NULLIF(categorygroupcode, ''), 'Other')
                  ORDER BY gradelevel",
                new[] { "@payplan", "@version" },
                new object[] { payPlan, amcosVersionId });
        }

        // Total inventory head-count by grade level for one pay plan / version — the
        // per-version series for the Inventory version-vs-version chart.
        public static DataTable GetInventoryTotalByGrade(string payPlan, int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT gradelevel, SUM(inventory) AS inventory
                  FROM data.inventory
                  WHERE payplan = @payplan
                    AND amcosversionid = @version
                  GROUP BY gradelevel
                  ORDER BY gradelevel",
                new[] { "@payplan", "@version" },
                new object[] { payPlan, amcosVersionId });
        }

        // ---- GS Locality Rates by ZIP ------------------------------------------

        // Resolve a 5-digit ZIP to its GS locality pay area(s) and rate. Chain:
        //   fips_zip (ZIP -> FIPS state+county)
        //   -> xwalk.localitypayareatofips (FIPS -> localitycode)
        //   -> lookup.localitypayarea (localitycode -> area name)
        //   -> "PaySchedule".localitypay (localitycode -> rate).
        // Returns 0..n matches (a ZIP can span more than one locality city code).
        public static DataTable GetLocalityRateByZip(string zip, int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT DISTINCT
                         lpa.localitycode,
                         lpa.localitypayarea AS localityname,
                         lp.localityrate
                  FROM lookup.fips_zip fz
                  JOIN xwalk.localitypayareatofips x
                       ON x.statecode = substr(fz.fipscode, 1, 2)
                      AND x.countycode = substr(fz.fipscode, 3, 3)
                      AND x.amcosversionid = @version
                  JOIN lookup.localitypayarea lpa
                       ON lpa.localitycode = x.localitycode
                      AND lpa.amcosversionid = @version
                  JOIN ""PaySchedule"".localitypay lp
                       ON lp.localitycode = x.localitycode
                      AND lp.amcosversionid = @version
                  WHERE trim(fz.zipcode) = @zip
                    AND @version BETWEEN fz.amcosversionidstart AND fz.amcosversionidend
                  ORDER BY lpa.localitypayarea",
                new[] { "@zip", "@version" },
                new object[] { zip, amcosVersionId });
        }

        // All GS locality areas and their rates for the version — the comparison-bar
        // backdrop the single-ZIP result is highlighted against.
        public static DataTable GetAllLocalityRates(int amcosVersionId)
        {
            return DataAccessUtility.GetDataTableByStaticSql(
                @"SELECT lpa.localitycode,
                         lpa.localitypayarea AS localityname,
                         lp.localityrate
                  FROM lookup.localitypayarea lpa
                  JOIN ""PaySchedule"".localitypay lp
                       ON lp.localitycode = lpa.localitycode
                      AND lp.amcosversionid = lpa.amcosversionid
                  WHERE lpa.amcosversionid = @version
                  ORDER BY lp.localityrate DESC",
                new[] { "@version" },
                new object[] { amcosVersionId });
        }
    }
}
