# AMCOS Lite on Babelfish (Aurora PostgreSQL) — `@ConversionType does not exist` fix

**Scope:** running the **original** AMCOS app (SQL Server T-SQL, unchanged VB) against **Babelfish for Aurora PostgreSQL** via the TDS (1433) endpoint.
**Symptom:** AMCOS Lite fails with `@ConversionType does not exist` when the inflation-rate header renders.
**Origin in code:** `AMCOS.Web/App/Lite/default.aspx.vb` → `PopulateRateHeader()` runs
`SELECT … FROM web.GetInflationRateHeader(@ConversionType,@Year,@AmcosVersionId)`.

> Apply everything in this doc **through the Babelfish TDS endpoint (port 1433)** using SSMS or `sqlcmd` — **not** the native PostgreSQL (5432) port — so the objects register in the Babelfish T-SQL catalog and the unchanged app can call them. No VB/app changes are required.

---

## 0. Target version (AWS Aurora / Babelfish)

Running on AWS, **one major behind the latest**. Babelfish is pinned to the Aurora PostgreSQL major version:

| Aurora PostgreSQL major | Babelfish version | Status |
|---|---|---|
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
|---|---|---|
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
|---|---|---|---|
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
|---|---|---|
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
   ```
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
|---|---|---|
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

## 8. TL;DR

- The `@ConversionType does not exist` error = **`web.GetInflationRateHeader` never created on Babelfish because it uses `PIVOT`**; the runtime call to the missing function surfaces as a bogus parameter error.
- **Do:** run §4 (drop + create the inline, conditional-aggregation version) through the **Babelfish 1433 endpoint**. No app changes.
- **Verify:** `CostsCCE`, `CostsCCEInflated`, `GetAmcosLiteCosts`, `spCrossTabGrades` — MSTVF/cursor/dynamic-SQL, all supported; convert only if one fails.
- **Later:** repeat the `SUM(CASE…)` conversion for the Cost-Compare/crunch `PIVOT`s in §6.
