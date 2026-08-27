# AMCOS Lite on Babelfish (Aurora PostgreSQL) — `@ConversionType does not exist` fix

**Scope:** running the **original** AMCOS app (SQL Server T-SQL, unchanged VB) against **Babelfish for Aurora PostgreSQL** via the TDS (1433) endpoint.
**Symptom:** AMCOS Lite fails with `@ConversionType does not exist` when the inflation-rate header renders.
**Origin in code:** `AMCOS.Web/App/Lite/default.aspx.vb` → `PopulateRateHeader()` runs
`SELECT … FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId)`.

> Apply everything in this doc **through the Babelfish TDS endpoint (port 1433)** using SSMS or `sqlcmd` — **not** the native PostgreSQL (5432) port — so the objects register in the Babelfish T-SQL catalog and the unchanged app can call them. No VB/app changes are required.

**Which codebase this targets (read first).**
This fix targets the **older / original AMCOS application** (SQL Server T-SQL objects + SqlClient VB, running on Babelfish) — **not** the migrated project on the dev machine (the .NET 8 / Npgsql / native-PostgreSQL port).

- **§1–§9 apply directly to the older app.** They fix its original SQL Server objects (`AMCOS.AMCOS2020_MAR/web/…`) and its original VB (`default.aspx.vb`).
- **§10–§11 are a *port*, not a switch.** The native PL/pgSQL functions and the Npgsql data-access helper referenced there live in **this migration repo** and are shown so you can **copy/deploy them into the older app's Aurora + codebase** — the older app does **not** already contain them. File paths like `AMCOS.PostgreSQL/migrations/…` and `AMCOS.Logic/DataAccessUtility.cs` are **sources on this dev machine**, not files that exist in the older app.

---

## 0. Target version (AWS Aurora / Babelfish)

Running on AWS, **one major behind the latest**. Babelfish is pinned to the Aurora PostgreSQL major version:

| Aurora PostgreSQL major | Babelfish version | Status |
| --- | --- | --- |
| PG 17 | Babelfish 5.x | latest |
| **PG 16** | **Babelfish 4.x** | **← target ("before the latest")** |
| PG 15 | Babelfish 3.x | prior |

**Confirm the exact version on your instance** before applying:

```sql
-- Babelfish TDS endpoint (1433):
SELECT @@version;                              -- shows "Babelfish for PostgreSQL ... Server v<X>"
SELECT SERVERPROPERTY('babelfishversion');     -- e.g. 4.2.0
-- Native PG endpoint (5432):
SELECT aurora_version(), version();
```

**Version-independent invariant:** `PIVOT` / `UNPIVOT` is **unsupported in every Babelfish release to date** (including 4.x and 5.x). So the §4 rewrite is required on any version — this is not something a newer/older engine changes.

**What the target version (4.x / PG 16) *does* give you:** multi-statement TVFs (`RETURNS @t TABLE`), table variables, `#temp` tables, `DROP TABLE IF EXISTS`, cursors + dynamic `EXEC`, and `CROSS APPLY` are all supported — so the §5 objects (`CostsCCE`, `CostsCCEInflated`, `GetAmcosLiteCosts`, `spCrossTabGrades`) should run **unchanged** on Babelfish 4.x. §5 stays "verify, convert only on failure."

---

## 1. Root cause

`web.GetInflationRateHeader` (original: `AMCOS.AMCOS2020_MAR/web/Functions/GetInflationRateHeader.sql`) is a **multi-statement table-valued function** that uses the T-SQL **`PIVOT`** operator:

```sql
RETURNS @Table_Var TABLE ( ... )          -- multi-statement TVF
...
) AS SourceTable
PIVOT ( SUM(Amount) FOR Appropriation IN ([Army CivPay],[Federal OM],[MPA], ... ) ) AS PivotTable;
```

**Babelfish does not support `PIVOT`/`UNPIVOT`.** When the original schema was deployed to Babelfish, the `CREATE FUNCTION` for this object **failed** (PIVOT is rejected at create time), so the function **does not exist** in the catalog.

At runtime the app calls the missing function. Because `web.GetInflationRateHeader(...)` can't be resolved, Babelfish falls through to the PostgreSQL engine, where `@ConversionType` is **not** a T-SQL variable — PG parses `@` as its absolute-value operator applied to an identifier `conversiontype`, which doesn't exist → **`@ConversionType does not exist`**. The message names the parameter, but the real failure is the **missing/incompatible function**.

**Confirm it** (through the Babelfish TDS endpoint):

```sql
SELECT * FROM sys.objects WHERE name = 'GetInflationRateHeader';   -- 0 rows  => never created (root cause confirmed)
```

---

## 2. Babelfish compatibility cheat-sheet (what actually breaks)

| Construct | Babelfish | Action |
| --- | --- | --- |
| `PIVOT` / `UNPIVOT` operator | ❌ Not supported | **Rewrite** as `SUM(CASE WHEN … THEN … END)` conditional aggregation |
| Multi-statement TVF `RETURNS @t TABLE … BEGIN … RETURN` | ✅ Supported | No rewrite needed — **verify** |
| Inline TVF `RETURNS TABLE AS RETURN (…)` | ✅ Supported | Preferred target for the PIVOT rewrite |
| Table variables, `#temp` tables, `DROP TABLE IF EXISTS` | ✅ Supported | OK |
| Cursors + dynamic `EXEC(@sql)` | ✅ Supported | OK (used by `spCrossTabGrades`) |
| `CROSS APPLY` / `OUTER APPLY` | ✅ Supported | OK |
| `CONVERT(MONEY, expr, style)` | ✅ Supported | OK |
| `MERGE`, `STRING_AGG`, `OPENJSON`, `FOR XML/JSON` | ⚠️ version-dependent | None on the Lite path (audited clean) |

Net: **the only thing on the Lite runtime path that Babelfish rejects is the `PIVOT` operator in `GetInflationRateHeader`.**

---

## 3. Lite-path object audit

Objects the Lite screen actually calls (from `default.aspx.vb`, `LiteService.asmx.vb`, `AmcosLiteController.vb`):

| Object | Type | Babelfish issue | Verdict |
| --- | --- | --- | --- |
| `web.GetInflationRateHeader` | MSTVF **+ PIVOT** | `PIVOT` unsupported → **fails to create** | **FIX REQUIRED** — §4 |
| `web.GetAmcosLiteCosts` | Stored proc | "PIVOT" is only a **comment**; pivots via `EXEC web.spCrossTabGrades` | Verify only |
| `web.spCrossTabGrades` | Stored proc (dynamic) | Uses `SUM(CASE…)` + cursor + dynamic `EXEC` — no `PIVOT` operator | Verify only |
| `web.CostsCCE` | MSTVF (no PIVOT) | MSTVF supported | Verify; optional inline in §5 |
| `web.CostsCCEInflated` | MSTVF (no PIVOT) | MSTVF supported (`INSERT` then `UPDATE @t … FROM`) | Verify; §5 |

---

## 4. FIX (required) — rewrite `web.GetInflationRateHeader` without PIVOT

Ready to run through the **Babelfish TDS endpoint**. Keeps the exact T-SQL signature and column names, so `PopulateRateHeader()` needs **no changes**. Replaces `PIVOT` with conditional aggregation and converts the multi-statement TVF to an **inline** TVF.

```sql
-- ============================================================================
-- web.GetInflationRateHeader  (Babelfish-compatible, no PIVOT)
-- Run against the Babelfish TDS endpoint (port 1433), NOT native PG (5432).
-- ============================================================================

-- Drop whichever form currently exists (IF = inline TVF, TF = multi-statement TVF)
IF OBJECT_ID(N'web.GetInflationRateHeader', N'IF') IS NOT NULL
    DROP FUNCTION web.GetInflationRateHeader;
GO
IF OBJECT_ID(N'web.GetInflationRateHeader', N'TF') IS NOT NULL
    DROP FUNCTION web.GetInflationRateHeader;
GO

CREATE FUNCTION [web].[GetInflationRateHeader]
(
    @ConversionType NVARCHAR(25),
    @Year           NVARCHAR(4),
    @AmcosVersionId INT
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        [Year],
        CAST('Inflation Rate' AS NVARCHAR(25))                       AS Appropriation,
        SUM(CASE WHEN Appropriation = 'Army CivPay' THEN Amount END) AS [Army CivPay],
        SUM(CASE WHEN Appropriation = 'Federal OM'  THEN Amount END) AS [Federal OM],
        SUM(CASE WHEN Appropriation = 'MPA'         THEN Amount END) AS [MPA],
        SUM(CASE WHEN Appropriation = 'MPA Non-Pay' THEN Amount END) AS [MPA Non-Pay],
        SUM(CASE WHEN Appropriation = 'NGPA'        THEN Amount END) AS [NGPA],
        SUM(CASE WHEN Appropriation = 'OMA'         THEN Amount END) AS [OMA],
        SUM(CASE WHEN Appropriation = 'OMA_1'       THEN Amount END) AS [OMA_1],
        SUM(CASE WHEN Appropriation = 'OMAR'        THEN Amount END) AS [OMAR],
        SUM(CASE WHEN Appropriation = 'OMAR_1'      THEN Amount END) AS [OMAR_1],
        SUM(CASE WHEN Appropriation = 'OMDW'        THEN Amount END) AS [OMDW],
        SUM(CASE WHEN Appropriation = 'OMNG'        THEN Amount END) AS [OMNG],
        SUM(CASE WHEN Appropriation = 'OMNG_1'      THEN Amount END) AS [OMNG_1],
        SUM(CASE WHEN Appropriation = 'RPA'         THEN Amount END) AS [RPA]
    FROM lookup.JicInflationRates
    WHERE ConversionType = @ConversionType
      AND [Year]         = @Year
      AND AmcosVersionId = @AmcosVersionId
    GROUP BY [Year]
);
GO
```

**Why this is equivalent:** the original `PIVOT (SUM(Amount) FOR Appropriation IN (…))` groups by the only non-pivoted column, `Year`. `SUM(CASE WHEN Appropriation = '<x>' THEN Amount END) … GROUP BY Year` produces the identical rows and columns. Absent appropriations return `NULL` (same as PIVOT).

**Verify:**

```sql
SELECT * FROM sys.objects WHERE name = 'GetInflationRateHeader';       -- now 1 row
-- substitute a real ConversionType / Year / AmcosVersionId present in lookup.JicInflationRates:
SELECT * FROM web.GetInflationRateHeader('ThenToThen', '2025', 202501);
```

Then re-run AMCOS Lite → the inflation-rate header grid should populate and the `@ConversionType` error is gone.

---

## 4B. ALTERNATIVE — fix in `default.aspx.vb` only (no database changes)

Use this **instead of §4** if you don't want to deploy DDL to Babelfish. `web.GetInflationRateHeader` has **exactly one caller** in the whole app — `PopulateRateHeader()` in `AMCOS.Web/App/Lite/default.aspx.vb` — so removing the dependency there is a complete fix for this error. Nothing else references the function.

**Approach:** keep the existing `SqlClient` + T-SQL + `[bracket]` code (correct for Babelfish) and the same `@ConversionType/@Year/@AmcosVersionId` parameters; only replace the missing `web.GetInflationRateHeader(...)` function call with an inline **conditional-aggregation derived table** that returns the same columns. The five per-pay-plan `SELECT` lists are unchanged.

> Do **either** §4 (DB) **or** §4B (app) — not both required. §4 is cleaner long-term (fixes all future callers); §4B ships with the app and needs no TDS/DDL step.

### Corrected method — replace `PopulateRateHeader` in full

```vb
    Private Sub PopulateRateHeader(ConversionType As String, PayPlan As String, Year As String, AmcosVersionId As Integer)

        Dim payPlanObject As PayPlan = New PayPlan(PayPlan)
        Dim SqlStatement As String = ""

        ' Babelfish (Aurora PostgreSQL) does not support the T-SQL PIVOT operator, so the
        ' web.GetInflationRateHeader table-valued function fails to create there. Rather than depend
        ' on that function, compute the identical result inline with conditional aggregation
        ' (SUM(CASE ...)) over lookup.JicInflationRates. This derived table exposes the same columns
        ' the function returned, so the per-pay-plan SELECT lists below are unchanged. The
        ' @ConversionType / @Year / @AmcosVersionId parameters are still bound (see below) and are
        ' now referenced inside the derived table.
        Dim RateHeader As String =
            "(SELECT CAST('Inflation Rate' AS NVARCHAR(25)) AS [Appropriation]," &
            " SUM(CASE WHEN Appropriation = 'Army CivPay' THEN Amount END) AS [Army CivPay]," &
            " SUM(CASE WHEN Appropriation = 'Federal OM'  THEN Amount END) AS [Federal OM]," &
            " SUM(CASE WHEN Appropriation = 'MPA'         THEN Amount END) AS [MPA]," &
            " SUM(CASE WHEN Appropriation = 'MPA Non-Pay' THEN Amount END) AS [MPA Non-Pay]," &
            " SUM(CASE WHEN Appropriation = 'NGPA'        THEN Amount END) AS [NGPA]," &
            " SUM(CASE WHEN Appropriation = 'OMA'         THEN Amount END) AS [OMA]," &
            " SUM(CASE WHEN Appropriation = 'OMA_1'       THEN Amount END) AS [OMA_1]," &
            " SUM(CASE WHEN Appropriation = 'OMAR'        THEN Amount END) AS [OMAR]," &
            " SUM(CASE WHEN Appropriation = 'OMAR_1'      THEN Amount END) AS [OMAR_1]," &
            " SUM(CASE WHEN Appropriation = 'OMDW'        THEN Amount END) AS [OMDW]," &
            " SUM(CASE WHEN Appropriation = 'OMNG'        THEN Amount END) AS [OMNG]," &
            " SUM(CASE WHEN Appropriation = 'OMNG_1'      THEN Amount END) AS [OMNG_1]," &
            " SUM(CASE WHEN Appropriation = 'RPA'         THEN Amount END) AS [RPA]" &
            " FROM lookup.JicInflationRates" &
            " WHERE ConversionType = @ConversionType AND [Year] = @Year AND AmcosVersionId = @AmcosVersionId" &
            " GROUP BY [Year]) AS RateHeader"

        If payPlanObject.GetTags().Contains("Active Military") Then
            SqlStatement = "SELECT [Appropriation], [MPA], [MPA Non-Pay], [OMA], [OMA_1], [OMDW], [Federal OM] FROM " & RateHeader & ";"
        ElseIf payPlanObject.GetTags().Contains("National Guard") Then
            SqlStatement = "SELECT [Appropriation], [NGPA], [MPA], [OMNG], [OMA], [OMA_1], [OMNG_1] FROM " & RateHeader & ";"
        ElseIf payPlanObject.GetTags().Contains("Reserves") Then
            SqlStatement = "SELECT [Appropriation], [RPA], [MPA], [OMAR], [OMA], [OMA_1], [OMAR_1] FROM " & RateHeader & ";"
        ElseIf payPlanObject.GetTags().Contains("Civilian") Or payPlanObject.GetTags().Contains("GFEBS") Or payPlanObject.GetTags().Contains("Wage") Then
            SqlStatement = "SELECT [Appropriation], [Army CivPay], [OMA], [Federal OM] FROM " & RateHeader & ";"
        ElseIf PayPlan = "CCE" Then
            SqlStatement = "SELECT [Appropriation], [OMA] FROM " & RateHeader & ";"
        End If

        If SqlStatement <> "" Then
            Using connection As New SqlConnection(ConnectionStrings("AmcosAdo").ConnectionString)
                connection.Open()
                Using command As SqlCommand = New SqlCommand(SqlStatement, connection)
                    command.Parameters.AddWithValue("@ConversionType", ConversionType)
                    command.Parameters.AddWithValue("@Year", Year)
                    command.Parameters.AddWithValue("@AmcosVersionId", AmcosVersionId)
                    command.CommandType = CommandType.Text
                    Using reader As SqlDataReader = command.ExecuteReader()
                        InflationRatesGridView.DataSource = reader
                        InflationRatesGridView.DataBind()
                        InflationRatesGridView.Visible = True
                    End Using
                End Using
            End Using
        End If

    End Sub
```

**Only lines changed** vs. the original: the added `RateHeader` derived-table string, and each `FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId)` → `FROM " & RateHeader & "`. Everything else (the `SqlConnection`/`SqlCommand`, the three `AddWithValue` parameters, the grid binding) is untouched.

**Why it's equivalent:** the derived table produces exactly the columns the function returned (via `SUM(CASE …)` = the old `PIVOT`), grouped by `Year`; the parameters are bound identically, so each pay plan's `SELECT` subset returns the same rows.

**Notes / caveats:**

- Requires a rebuild + redeploy of `AMCOS.Web` (it's a code change). §4 needs no app rebuild.
- Fixes only this screen. If any **other** app (or a future feature) ever calls `web.GetInflationRateHeader`, it will still fail — §4 is the durable fix for that case. (Audited today: no other caller exists.)
- Keep an eye on `web.GetPMReportInflationRateHeader` (PM report screen) — it has the same PIVOT problem and is a separate caller/function; the §4 approach or an equivalent inline edit in its caller is needed there too.

---

## 5. Precautionary — MSTVFs on the Lite path (`CostsCCE`, `CostsCCEInflated`)

These are **multi-statement TVFs with no `PIVOT`**, so they should create and run on Babelfish unchanged. **Verify first** — only convert if a specific one misbehaves.

```sql
SELECT name, type_desc FROM sys.objects WHERE name IN ('CostsCCE','CostsCCEInflated');   -- expect both present
SELECT * FROM web.CostsCCE('15-1252', '10420', 0, 202501);                                -- smoke test
```

### 5a. Optional — `web.CostsCCE` as an inline TVF (only if the MSTVF form fails)

The body is four `UNION` `SELECT`s over `BLS_OES.OccupationalEmploymentStatisticsMetro`; the only procedural parts are two scalar lookups, which fold into `CROSS JOIN`ed subqueries:

```sql
IF OBJECT_ID(N'web.CostsCCE', N'IF') IS NOT NULL DROP FUNCTION web.CostsCCE;
GO
IF OBJECT_ID(N'web.CostsCCE', N'TF') IS NOT NULL DROP FUNCTION web.CostsCCE;
GO
CREATE FUNCTION [web].[CostsCCE]
(
    @StandardOccupationCode NVARCHAR(10),
    @Area                   NVARCHAR(10),
    @OverheadPercent        MONEY,
    @AmcosVersionId         INTEGER = 202001
)
RETURNS TABLE
AS
RETURN
(
    WITH k AS (
        SELECT
            CAST(crunch.GetSingleValue('CCE','MaxPayFootnote',@AmcosVersionId) AS MONEY) AS MaxPayFootnote,
            CAST(crunch.GetSingleValue('CCE','Benefits_All',  @AmcosVersionId) AS NUMERIC(26,6)) AS BenefitRatio
    ),
    src AS (
        SELECT A_PCT10, A_PCT25, A_MEDIAN, A_PCT75, A_PCT90
        FROM BLS_OES.OccupationalEmploymentStatisticsMetro
        WHERE SOC = @StandardOccupationCode AND MSACode = @Area AND AmcosVersionId = @AmcosVersionId
    )
    -- Salary
    SELECT 'CCE' AS appnGroup, 'zzz1Avg Cost of Salary' AS CostElementName,
           'Annual salary received in the private sector.' AS [Description],
           CASE WHEN s.A_PCT10 = 9999999 THEN k.MaxPayFootnote ELSE CONVERT(MONEY, s.A_PCT10, 1) END AS A_PCT10,
           CASE WHEN s.A_PCT25 = 9999999 THEN k.MaxPayFootnote ELSE CONVERT(MONEY, s.A_PCT25, 1) END AS A_PCT25,
           CASE WHEN s.A_MEDIAN= 9999999 THEN k.MaxPayFootnote ELSE CONVERT(MONEY, s.A_MEDIAN,1) END AS A_MEDIAN,
           CASE WHEN s.A_PCT75 = 9999999 THEN k.MaxPayFootnote ELSE CONVERT(MONEY, s.A_PCT75, 1) END AS A_PCT75,
           CASE WHEN s.A_PCT90 = 9999999 THEN k.MaxPayFootnote ELSE CONVERT(MONEY, s.A_PCT90, 1) END AS A_PCT90
    FROM src s CROSS JOIN k
    UNION
    -- Benefits
    SELECT 'CCE', 'zzz2Avg Cost of Benefits',
           'Employer Costs for Employee Compensation (ECEC) …',
           CASE WHEN s.A_PCT10 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*k.BenefitRatio,1) ELSE CONVERT(MONEY, s.A_PCT10*k.BenefitRatio,1) END,
           CASE WHEN s.A_PCT25 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*k.BenefitRatio,1) ELSE CONVERT(MONEY, s.A_PCT25*k.BenefitRatio,1) END,
           CASE WHEN s.A_MEDIAN= 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*k.BenefitRatio,1) ELSE CONVERT(MONEY, s.A_MEDIAN*k.BenefitRatio,1) END,
           CASE WHEN s.A_PCT75 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*k.BenefitRatio,1) ELSE CONVERT(MONEY, s.A_PCT75*k.BenefitRatio,1) END,
           CASE WHEN s.A_PCT90 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*k.BenefitRatio,1) ELSE CONVERT(MONEY, s.A_PCT90*k.BenefitRatio,1) END
    FROM src s CROSS JOIN k
    UNION
    -- Overhead
    SELECT 'CCE', 'zzz3Overhead', 'An ongoing business expense …',
           CASE WHEN s.A_PCT10 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*@OverheadPercent/100,1) ELSE CONVERT(MONEY, s.A_PCT10*@OverheadPercent/100,1) END,
           CASE WHEN s.A_PCT25 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*@OverheadPercent/100,1) ELSE CONVERT(MONEY, s.A_PCT25*@OverheadPercent/100,1) END,
           CASE WHEN s.A_MEDIAN= 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*@OverheadPercent/100,1) ELSE CONVERT(MONEY, s.A_MEDIAN*@OverheadPercent/100,1) END,
           CASE WHEN s.A_PCT75 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*@OverheadPercent/100,1) ELSE CONVERT(MONEY, s.A_PCT75*@OverheadPercent/100,1) END,
           CASE WHEN s.A_PCT90 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*@OverheadPercent/100,1) ELSE CONVERT(MONEY, s.A_PCT90*@OverheadPercent/100,1) END
    FROM src s CROSS JOIN k
    UNION
    -- Total
    SELECT 'CCE', 'zzz3Total', 'Total cost',
           CASE WHEN s.A_PCT10 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*(1+k.BenefitRatio+@OverheadPercent/100),1) ELSE CONVERT(MONEY, s.A_PCT10*(1+k.BenefitRatio+@OverheadPercent/100),1) END,
           CASE WHEN s.A_PCT25 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*(1+k.BenefitRatio+@OverheadPercent/100),1) ELSE CONVERT(MONEY, s.A_PCT25*(1+k.BenefitRatio+@OverheadPercent/100),1) END,
           CASE WHEN s.A_MEDIAN= 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*(1+k.BenefitRatio+@OverheadPercent/100),1) ELSE CONVERT(MONEY, s.A_MEDIAN*(1+k.BenefitRatio+@OverheadPercent/100),1) END,
           CASE WHEN s.A_PCT75 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*(1+k.BenefitRatio+@OverheadPercent/100),1) ELSE CONVERT(MONEY, s.A_PCT75*(1+k.BenefitRatio+@OverheadPercent/100),1) END,
           CASE WHEN s.A_PCT90 = 9999999 THEN CONVERT(MONEY, k.MaxPayFootnote*(1+k.BenefitRatio+@OverheadPercent/100),1) ELSE CONVERT(MONEY, s.A_PCT90*(1+k.BenefitRatio+@OverheadPercent/100),1) END
    FROM src s CROSS JOIN k
);
GO
```

> Note: an inline TVF cannot carry the original `ORDER BY CostElementName` internally — the `zzz1/zzz2/zzz3` prefixes already encode order, and the app/caller orders on display. If exact ordering matters, keep the MSTVF form (supported) instead of converting.

### 5b. `web.CostsCCEInflated`

Same shape as `CostsCCE` **plus** a trailing `UPDATE @Costs … FROM lookup.JicInflationRates` (max-version join) that multiplies each percentile by the OMA inflation factor. `UPDATE @tablevar … FROM` and table variables are supported by Babelfish, so **keep it as an MSTVF and verify**. If you ever need it inline, fold the inflation factor into each percentile expression via a `CROSS JOIN` to:

```sql
SELECT r.Amount
FROM lookup.JicInflationRates r
JOIN (SELECT ConversionType, Year, Appropriation, MAX(AmcosVersionId) AS v
      FROM lookup.JicInflationRates GROUP BY ConversionType, Year, Appropriation) m
  ON r.ConversionType=m.ConversionType AND r.Year=m.Year AND r.Appropriation=m.Appropriation AND r.AmcosVersionId=m.v
WHERE r.ConversionType=@InflationConversion AND r.Year=@InflationYear AND r.Appropriation='OMA'
```

---

## 6. Broader cost / Cost-Compare paths (follow-up, not Lite runtime)

`PIVOT` also appears **outside** the Lite path. These power Cost Compare / crunch, not the Lite screen, but will hit the same wall on Babelfish. Convert with the same `SUM(CASE…)` technique when you get to them:

| Object | Path | Construct |
| --- | --- | --- |
| `analysis.CompareCosts` | Cost Compare | `PIVOT` |
| `analysis.MAD` | Cost Compare (median abs deviation) | `PIVOT` |
| `analysis.CompareInventory` | Cost Compare | `PIVOT` (comment/dynamic — verify) |
| `crunch.CostOfBasicAllowanceforHousingandCOLA` | Crunch engine | `PIVOT` |
| `crunch.CrunchGFEBS` | Crunch engine | `PIVOT` |
| `web.GetPMReportInflationRateHeader` | PM report | MSTVF + `CROSS APPLY` (PM version of §4) — convert like §4 |

`CROSS APPLY` itself is fine on Babelfish; only the `PIVOT` inside these needs rewriting.

---

## 7. How to apply on the testing machine

1. Connect to the **Babelfish TDS endpoint** (`<aurora-endpoint>,1433`) with **SSMS** or `sqlcmd` — use SQL Server auth, the Babelfish logical database the app connects to.

   ```text
   sqlcmd -S <babelfish-endpoint>,1433 -U <user> -P <pwd> -d <logical_db> -i GetInflationRateHeader.babelfish.sql
   ```

2. Run the confirm query in §1 → then the §4 script → then the §4 verify.
3. Ensure the `web` schema is in scope for the logical database (Babelfish maps T-SQL db → PG db+schema). If objects "can't be found," check the database mapping / `search_path` for that logical DB.
4. Smoke-test the MSTVFs in §5, then load AMCOS Lite and confirm the inflation header renders.

**Order of operations if you deploy the whole schema fresh:** apply the §4 (and any §6) rewrites *in place of* the original `PIVOT` definitions so the `CREATE` succeeds the first time — otherwise those objects silently never get created and every dependent screen throws the misleading `@<param> does not exist`.

---

## 9. After the fix: Lite hangs / shows no data / no error  →  it's SLOW, not broken

**Confirmed by testing:** `EXEC web.GetAmcosLiteCosts …` returns correct data but takes **~2 minutes** on Babelfish. So the proc is **not** mistranslated — it is **too slow**, and a timeout layer between the browser and the database drops the request before it finishes. The dropped-connection exception is swallowed → **empty grid, no visible error, apparent "hang."**

### What is actually timing out (2-min query vs. shorter limits)

| Layer | Default limit | Notes |
| --- | --- | --- |
| **AWS ALB idle timeout** | **60 s** | If an Application Load Balancer fronts the app, it cuts the connection at 60 s. **Most common cause in AWS.** |
| **ADO `CommandTimeout`** (SqlClient → Babelfish) | **30 s** | Original app uses the default unless raised. |
| IIS / browser | varies | Secondary. |

`~120 s query` > `60 s ALB` (or `30 s ADO`) ⇒ connection killed ⇒ empty grid, no error.

> Note: this repo's *ported* Npgsql path (`AMCOS.Logic/DataAccessUtility.cs:44`) already sets `CommandTimeout = 900`; that only helps the native-PG (5432) path, not a SqlClient→Babelfish original app, and it does nothing about a 60 s ALB.

### Track A — unblock now (band-aid)

Raise **both** relevant limits so the 2-min run can complete while you tune it:

- ADO: set `CommandTimeout` ≥ 180 on the command that runs `web.GetAmcosLiteCosts`.
- ALB: EC2 → Load Balancers → your ALB → **Attributes → Idle timeout** → 180 s (or higher).

A 2-minute Lite screen isn't acceptable UX, so treat Track A as temporary.

### Track B — make it fast (the real fix)

Babelfish runs on the PostgreSQL engine; a proc that was fast on SQL Server is usually slow because the **PG planner lacks statistics/indexes** on the migrated tables and falls back to sequential scans + nested loops.

**1. Update statistics first — cheapest, biggest win.** Right after a bulk migration the tables often have no stats. On the **native PG (5432) endpoint**:

```sql
ANALYZE VERBOSE;                       -- whole database, or target the hot tables:
-- ANALYZE lookup.jicinflationrates; ANALYZE <cost/inventory tables feeding #AmcosLite>;
```

Re-time the proc after this alone — it frequently drops from minutes to seconds.

**2. Find where the 2 minutes goes.** In SSMS (Babelfish TDS endpoint):

```sql
SET STATISTICS TIME ON;
EXEC web.GetAmcosLiteCosts @PayPlan='GS', @CostSummaryName='Default',
     @InflationConversion='ThenToThen', @InflationYear='2025', @AmcosVersionId=202501, @Debug=1;
```

Read the per-statement elapsed times to see whether the cost is in **building `#AmcosLite`** (the INSERT/UPDATE joins) or in **`spCrossTabGrades`** (the cursor + dynamic pivot). Then, on the native PG endpoint, `EXPLAIN (ANALYZE, BUFFERS)` the dominant statement to see the bad plan (look for `Seq Scan` on big tables, huge `Nested Loop` row counts).

**3. Add the indexes the plan is missing.** Typically on the join/filter keys of the tables feeding `#AmcosLite` — e.g. `AmcosVersionId`, `PayPlan`, `CategoryGroupCode`/`CategorySubgroupCode`, `ConversionType`+`Year`+`Appropriation` on `lookup.JicInflationRates`, `WeaponSystemId` + version range on `lookup.WeaponSystem`. Create them through whichever endpoint owns the tables (native PG `CREATE INDEX`).

**4. Index the temp table.** `#AmcosLite` is built then joined/updated/pivoted repeatedly with no index → repeated scans. After it's populated, add a covering index before `spCrossTabGrades`:

```sql
CREATE INDEX IX_AmcosLite ON #AmcosLite (Grade, GradeLevel, appnGroup, APPN, CostElementName);
```

**5. `SET NOCOUNT ON`.** Uncomment `--SET NOCOUNT ON;` at the top of `GetAmcosLiteCosts` — removes the per-INSERT/UPDATE rowcount chatter (minor perf + cleaner ADO result handling).

**6. Only if `spCrossTabGrades` dominates:** replace its row-by-row **cursor** that builds `@sqlCase` with a set-based accumulation (`SELECT @sqlCase = @sqlCase + … FROM #PivotConfiguration ORDER BY PivotSort`, or `STRING_AGG` if your Babelfish version supports it). The cursor is over one row per grade (~10–15), so this is usually *not* the bottleneck — confirm with step 2 before spending time here.

### Bottom line

The `@ConversionType` fix was correct; this is a **separate performance issue**. Do **Track B step 1 (`ANALYZE`) first** — it's a one-liner and most often the whole fix. Use Track A only to keep testing while you tune. If, after `ANALYZE` + indexes, the proc runs in a few seconds, the grid will populate normally with no app change.

---

## 10. Performance strategy — the right long-term fix (native PostgreSQL, not Babelfish tuning)

**Confirmed:** the proc is correct but slow under Babelfish. Before investing in §9 Track B tuning, know the ceiling: **Babelfish is a migration *bridge*, not a high-performance destination.** It translates T-SQL→PostgreSQL per statement at runtime and cannot optimize procedural / cursor / dynamic-SQL code — which is exactly what the Lite cost crunch (`GetAmcosLiteCosts` → `spCrossTabGrades`) is. Tuning it under Babelfish raises the floor but never reaches native-PG performance, and it's work you throw away when Babelfish is retired (AWS's intended end state: move hot paths to native PG, then decommission Babelfish).

### A native replacement already exists in the migration repo (to port over)

The **migration project on the dev machine** (not the older app) contains a complete native-PostgreSQL port of this path. Use it as the source to deploy into the older app's Aurora + add to its codebase — the older app does not have these yet:

| Piece | Location | Notes |
| --- | --- | --- |
| `web.getamcoslitecosts(...)` | `AMCOS.PostgreSQL/migrations/007_stored_procedures.sql:3222` | native PL/pgSQL function |
| `web.spcrosstabgrades(...)` | `007_stored_procedures.sql:69` | **set-based**; uses `format(… %I …)` (proper identifier quoting) + `to_jsonb` — structurally avoids the cursor / single-quote-alias / nested-`EXEC` issues Babelfish struggles with |
| `DataAccessUtility.ExecuteStoredProcDataSet` | `AMCOS.Logic/DataAccessUtility.cs:28` | already calls these over **Npgsql** (native PG 5432, `CommandTimeout=900`) and re-expands the `(result_set_name, row_data jsonb)` shape back into the same multi-grid `DataSet` the app binds |

So the fast path is not something to design from scratch — the native functions and the Npgsql helper already exist here to lift into the older app; they return the same multi-grid shape its UI expects.

### Options, ranked

**A. Route the hot paths to native PG via Npgsql (recommended — strangler pattern).**
Keep Babelfish (TDS 1433) for the bulk of the app, but point the **perf-critical calls** (Lite cost grid first; later the crunch / Cost-Compare procs) at the **native PG endpoint (5432)** through the existing Npgsql `DataAccessUtility` + the native `web.*` functions. Same Aurora cluster, two connection strings, chosen per call. Biggest win for the least new work because the native functions and data-access layer already exist.

**B. Cut over to the Core app (strategic end state).**
`AMCOS.Web.Core` (.NET 8, Npgsql, native PG) already computes Lite natively. This is the destination Babelfish was bridging to; migrating screens here retires both the T-SQL procs and Babelfish over time.

**C. Keep tuning under Babelfish (only if you can't route to native yet).**
The §9 Track B steps (ANALYZE, indexes, temp-table index, de-cursor). A ceiling, not parity — use as a stopgap, not the plan.

### Recommended path for AMCOS Lite specifically

1. Point `Lite.Costs` / the Lite cost-grid call at the **native `web.getamcoslitecosts` over Npgsql (5432)** — the `DataAccessUtility` overload already does exactly this and returns the multi-grid `DataSet` the WebForms grid binds. This removes Babelfish from the hottest path entirely.
2. On the native side, ensure `ANALYZE` has run and the join/filter-key indexes exist (§9 Track B 1 & 3) — native PG + indexes + stats is where the real speed comes from.
3. Leave the rest of the classic app on Babelfish for now; migrate additional heavy procs (crunch, `analysis.CompareCosts`/`MAD`) to native functions as needed.
4. Endgame: as paths move to native PG, Babelfish traffic trends to zero and you decommission the 1433 endpoint — the standard AWS Babelfish exit.

**Bottom line:** don't optimize the T-SQL proc under Babelfish as the long-term answer — **route the hot Lite call to the native PL/pgSQL function via Npgsql** (already present), keep Babelfish only for the parts that are fast enough, and let the Core app be the destination. That maintains good performance instead of paying the translation tax on every crunch.

---

## 11. Bypassing Babelfish for the Lite cost path — the code

Route just the hot cost-grid call to the **native PostgreSQL endpoint (5432) via Npgsql**, calling the native `web.getamcoslitecosts` PL/pgSQL function, while the rest of the app stays on Babelfish. Same Aurora cluster, second connection string.

### Prerequisites

1. **Deploy the native functions to the PG side.** The native PL/pgSQL versions live in the repo but must be applied to the Aurora **PostgreSQL** database (not through Babelfish). Via `psql` on the 5432 endpoint, run at least:
   - `AMCOS.PostgreSQL/migrations/006b_costengine_functions.sql` (inflation/cost helpers)
   - `AMCOS.PostgreSQL/migrations/007_stored_procedures.sql` (`web.getamcoslitecosts`, `web.spcrosstabgrades`)
   They create `web.*` functions that return `(result_set_name text, row_data jsonb)`.
2. **NuGet packages** (net48 classic app): `Npgsql` (4.1.x, already referenced) and `System.Text.Json`.
3. **A native-PG connection string** (see below). The native functions must exist in the **PG database/schema** you point at (the DB Babelfish maps to, or wherever step 1 deployed them).

### Connection string (native PG endpoint, port 5432 — not Babelfish 1433)

Add a second connection string alongside the existing Babelfish/`AmcosAdo` one. Aurora exposes PostgreSQL on 5432 on the same cluster endpoint Babelfish uses for 1433:

```xml
<!-- Web.config <connectionStrings> -->
<add name="AmcosPostgres"
     connectionString="Host=YOUR-CLUSTER-ENDPOINT;Port=5432;Database=YOUR_PG_DB;Username=YOUR_USER;Password=YOUR_PWD;SSL Mode=Require;Trust Server Certificate=true;Timeout=15;Command Timeout=180"
     providerName="Npgsql" />
```

> `Database` = the PostgreSQL database that holds the `web.*` functions (in single-db Babelfish this is the mapped DB, e.g. `babelfish_db`; confirm with `\l` in `psql`). `Command Timeout=180` gives the crunch room while you tune indexes/stats.

### Drop-in native data-access helper (self-contained)

Add this class to the classic app (or reference `AMCOS.Logic.DataAccessUtility`, which already contains equivalent logic). It executes `SELECT * FROM web.getamcoslitecosts(...)` over Npgsql and re-expands the `(result_set_name, row_data jsonb)` shape into one `DataTable` per grid — so callers get the same multi-grid `DataSet` the WebForms grid binds.

```csharp
using Npgsql;
using NpgsqlTypes;
using System;
using System.Data;
using System.Linq;
using System.Text.Json;

public static class NativePg
{
    // Reads the native-PG connection string (NOT the Babelfish/AmcosAdo one).
    private static string ConnString =>
        System.Configuration.ConfigurationManager.ConnectionStrings["AmcosPostgres"].ConnectionString;

    // Calls a native web.* function that returns (result_set_name text, row_data jsonb)
    // and returns the expanded multi-grid DataSet.
    public static DataSet ExecuteFunctionDataSet(
        string functionName, string[] parameterNames, NpgsqlDbType[] parameterTypes, object[] parameterValues)
    {
        var argList = string.Join(", ", parameterNames.Select(p => "@" + p.TrimStart('@')));
        var sql = $"SELECT * FROM {functionName}({argList})";

        using (var connection = new NpgsqlConnection(ConnString))
        {
            connection.Open();
            using (var command = new NpgsqlCommand(sql, connection))
            {
                command.CommandType = CommandType.Text;
                command.CommandTimeout = 180; // seconds; tune with indexes/ANALYZE (see 9 & 10)
                for (int i = 0; i < parameterNames.Length; i++)
                    command.Parameters.Add(parameterNames[i].TrimStart('@'), parameterTypes[i]).Value =
                        parameterValues[i] ?? DBNull.Value;

                var raw = new DataSet();
                new NpgsqlDataAdapter { SelectCommand = command }.Fill(raw);
                return IsJsonbResultShape(raw) ? ExpandJsonbResultSets(raw.Tables[0]) : raw;
            }
        }
    }

    private static bool IsJsonbResultShape(DataSet ds) =>
        ds.Tables.Count == 1
        && ds.Tables[0].Columns.Count == 2
        && ds.Tables[0].Columns.Contains("result_set_name")
        && ds.Tables[0].Columns.Contains("row_data");

    private static DataSet ExpandJsonbResultSets(DataTable raw)
    {
        var ds = new DataSet();
        foreach (DataRow row in raw.Rows)
        {
            var name = row["result_set_name"] == DBNull.Value ? "Result" : row["result_set_name"].ToString();
            var json = row["row_data"] == DBNull.Value ? null : row["row_data"].ToString();
            if (string.IsNullOrEmpty(json)) continue;

            using (var doc = JsonDocument.Parse(json))
            {
                var root = doc.RootElement;
                if (root.ValueKind != JsonValueKind.Object) continue;

                // (b) single nested payload: { costs:[...], appropriationsummary:[...] }
                bool nested = root.EnumerateObject().Any(p => p.Value.ValueKind == JsonValueKind.Array);
                if (nested)
                {
                    foreach (var prop in root.EnumerateObject())
                    {
                        if (prop.Value.ValueKind != JsonValueKind.Array) continue;
                        var t = ds.Tables.Contains(prop.Name) ? ds.Tables[prop.Name] : ds.Tables.Add(prop.Name);
                        foreach (var el in prop.Value.EnumerateArray()) AppendRow(t, el);
                    }
                }
                else // (a) one row per data row: { col: val, ... }
                {
                    var t = ds.Tables.Contains(name) ? ds.Tables[name] : ds.Tables.Add(name);
                    AppendRow(t, root);
                }
            }
        }
        if (ds.Tables.Count == 0) ds.Tables.Add("Result");
        return ds;
    }

    private static void AppendRow(DataTable table, JsonElement obj)
    {
        if (obj.ValueKind != JsonValueKind.Object) return;
        var newRow = table.NewRow();
        foreach (var prop in obj.EnumerateObject())
        {
            if (!table.Columns.Contains(prop.Name)) table.Columns.Add(prop.Name, typeof(object));
            newRow[prop.Name] = ToClr(prop.Value);
        }
        table.Rows.Add(newRow);
    }

    private static object ToClr(JsonElement e)
    {
        switch (e.ValueKind)
        {
            case JsonValueKind.Null:
            case JsonValueKind.Undefined: return DBNull.Value;
            case JsonValueKind.Number:    return e.TryGetDecimal(out var d) ? d : (object)e.GetDouble();
            case JsonValueKind.True:
            case JsonValueKind.False:     return e.GetBoolean();
            case JsonValueKind.String:    return e.GetString();
            default:                      return e.GetRawText(); // nested object/array -> raw JSON
        }
    }
}
```

### Call-site swap (in the Lite cost-grid load)

Replace the Babelfish/SqlClient `web.GetAmcosLiteCosts` call with the native call. The parameter list matches the native function's signature (`p_payplan, p_costsummaryname, … p_amcosversionid`); Npgsql binds by position via the `@name` placeholders:

```csharp
// BEFORE (SqlClient -> Babelfish): SqlCommand("web.GetAmcosLiteCosts", conn){ CommandType = StoredProcedure } ... adapter.Fill(ds);

// AFTER (Npgsql -> native PG, bypassing Babelfish):
string[] names = { "@PayPlan", "@CostSummaryName", "@CategoryGroupCode", "@CategorySubgroupCode",
                   "@CareerProgramNumber", "@LocationId", "@STRL", "@DependentStatus",
                   "@NumberOfDependents", "@InflationConversion", "@InflationYear", "@AmcosVersionId" };
NpgsqlDbType[] types = { NpgsqlDbType.Varchar, NpgsqlDbType.Varchar, NpgsqlDbType.Varchar, NpgsqlDbType.Varchar,
                         NpgsqlDbType.Varchar, NpgsqlDbType.Integer, NpgsqlDbType.Varchar, NpgsqlDbType.Varchar,
                         NpgsqlDbType.Integer, NpgsqlDbType.Varchar, NpgsqlDbType.Varchar, NpgsqlDbType.Integer };
object[] values = { PayPlan, CostSummaryName, CategoryGroupCode, CategorySubgroupCode,
                    CareerProgramNumber, LocationId, ScienceTechnologyReinventionLaboratory, DependentStatus,
                    NumberOfDependents, InflationConversionType, InflationYear, AmcosVersionId };

DataSet ds = NativePg.ExecuteFunctionDataSet("web.getamcoslitecosts", names, types, values);

CostsGridView.DataSource = ds.Tables[0];   // main cost grid (same shape as before)
CostsGridView.DataBind();
```

> The native function defaults `p_includevisualizationdata` to true and `p_debug` to false; omit them (they have DEFAULTs) or append them to the arrays if you need to toggle them.

### Same technique for the inflation header (optional — replaces §4/§4B)

`web.getinflationrateheader` also exists natively (`006b_costengine_functions.sql`). To run the header on native PG too, call it the same way instead of the §4B inline SQL:

```csharp
string[] n = { "@ConversionType", "@Year", "@AmcosVersionId" };
NpgsqlDbType[] t = { NpgsqlDbType.Varchar, NpgsqlDbType.Varchar, NpgsqlDbType.Integer };
object[] v = { ConversionType, Year, AmcosVersionId };
DataSet header = NativePg.ExecuteFunctionDataSet("web.getinflationrateheader", n, t, v);
InflationRatesGridView.DataSource = header.Tables[0];
InflationRatesGridView.DataBind();
```

### Notes

- **Two connection strings coexist:** `AmcosAdo` (SqlClient → Babelfish 1433) for the un-migrated parts, `AmcosPostgres` (Npgsql → native PG 5432) for the hot native functions. Choose per call.
- **Performance still needs stats/indexes** (10 §Track B): native PG is faster *and* optimizable — run `ANALYZE` and add the join-key indexes on the PG side.
- **This is the strangler pattern in miniature:** each call you move to `NativePg.ExecuteFunctionDataSet` is one less thing paying the Babelfish translation tax. Move the crunch / Cost-Compare heavies next, then retire Babelfish.
- `AMCOS.Logic/DataAccessUtility.cs` already contains this exact helper — if the app references `AMCOS.Logic`, call `DataAccessUtility.ExecuteStoredProcDataSet("web.GetAmcosLiteCosts", …)` instead of copying `NativePg`.

---

## 8. TL;DR

- The `@ConversionType does not exist` error = **`web.GetInflationRateHeader` never created on Babelfish because it uses `PIVOT`**; the runtime call to the missing function surfaces as a bogus parameter error.
- **Do:** run §4 (drop + create the inline, conditional-aggregation version) through the **Babelfish 1433 endpoint**. No app changes.
- **Verify:** `CostsCCE`, `CostsCCEInflated`, `GetAmcosLiteCosts`, `spCrossTabGrades` — MSTVF/cursor/dynamic-SQL, all supported; convert only if one fails.
- **Later:** repeat the `SUM(CASE…)` conversion for the Cost-Compare/crunch `PIVOT`s in §6.
