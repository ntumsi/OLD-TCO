using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using AMCOS.Data.Entities;
using AMCOS.Logic.ViewModels;
using System;
using System.Collections.Generic;
using System.Data;
using Npgsql;
using NpgsqlTypes;
using System.Linq;
using System.Web.Mvc;

namespace AMCOS.Logic.Helpers
{
    public static class PcsPropertyHelper
    {
        /// <summary>
        /// Returns an enumeration of civilian PCS location data by AmcosVersionId
        /// </summary>
        /// <param name="amcosVersionId"></param>
        /// <returns>IEnumerable of LocationDto</returns>
        public static IEnumerable<LocationDto> GetAllCivPCSLocations(int amcosVersionId)
        {
            return ExecuteStoredProcedure("web.GetCivPCSLocations", new NpgsqlParameter("@AmcosVersionId", amcosVersionId)).Tables[0].AsEnumerable().Select(p => new LocationDto()
            {
                Value = p["LocationId"].ToString(),
                OptionGroup = p["LocationType"].ToString(),
                Text = p["LocationType"].ToString() == "Zip" ? $"{p["DisplayName"]}, {p["SourceSystemCode"]}" : p["DisplayName"].ToString()
            });
        }
        /// <summary>
        /// Saves a new project to webuser.PCSProject or updates an existing project for the same.
        /// </summary>
        /// <param name="pcsProject"></param>
        /// <param name="userId"></param>
        public static void SaveProject(PCSProject pcsProject, string userId)
        {
            pcsProject.UserId = userId;
            pcsProject.ProjectSaveDate = DateTime.Now;
            pcsProject.ProjectName = pcsProject.ProjectName?.Trim();

            if (!PCSProjectValid(pcsProject))
                return;
            using (var context = new ApplicationDbContext())
            {
                var project = context.PCSProject.Where(p => p.ProjectName == pcsProject.ProjectName && p.UserId == pcsProject.UserId).FirstOrDefault();
                if (project == null)
                {
                    context.PCSProject.Add(pcsProject);
                    context.SaveChanges();
                }
                else
                {
                    context.Entry(project).CurrentValues.SetValues(pcsProject);
                    context.SaveChanges();
                }
            }
        }
        /// <summary>
        /// Sets the Deleted flag to true for an existing PCSProject
        /// </summary>
        /// <param name="projectName"></param>
        /// <param name="userId"></param>
        public static void SetProjectDeleted(string projectName, string userId)
        {
            using (var context = new ApplicationDbContext())
            {
                var project = context.PCSProject.Where(p => p.ProjectName == projectName && p.UserId == userId).FirstOrDefault();
                if (project != null)
                {
                    project.Deleted = true;
                    context.SaveChanges();
                }
            }
        }
        private static bool PCSProjectValid(PCSProject pcsProject)
        {
            return !string.IsNullOrWhiteSpace(pcsProject.UserId) && pcsProject.ProjectSaveDate != null && !string.IsNullOrWhiteSpace(pcsProject.ProjectName)
                && pcsProject.OriginationId.HasValue && pcsProject.OriginationId.Value > 0 && pcsProject.DestinationId.HasValue && pcsProject.DestinationId > 0
                && !string.IsNullOrWhiteSpace(pcsProject.ConversionType) && !string.IsNullOrWhiteSpace(pcsProject.Appropriation) && pcsProject.AmcosVersionId.HasValue
                && pcsProject.AmcosVersionId.Value > 0 && pcsProject.Year.HasValue && pcsProject.Year > 0;
        }
        /// <summary>
        /// Returns an enumeration LocationDto from the stored procedure web.GetCivPCSLocationsByQuery
        /// </summary>
        /// <param name="query"></param>
        /// <param name="amcosVersionId"></param>
        /// <returns></returns>
        public static IEnumerable<LocationDto> GetCivPCSLocations(int amcosVersionId, string query)
        {
            //TODO: Remove these literals from front end as well to notify user these characters cannot be used.
            query = query.Replace("%", string.Empty).Replace("_", string.Empty).Replace("=", string.Empty);
            var queries = query.Split(' ').ToList();
            var zips = new List<string>();
            queries.ForEach(q => { if (int.TryParse(q, out int zip)) { zips.Add(q); } });
            return ExecuteStoredProcedure("web.GetCivPCSLocationsByQuery", new NpgsqlParameter("@AmcosVersionId", amcosVersionId), new NpgsqlParameter("@query", query), new NpgsqlParameter("@zipcode", zips.Count > 0 ? (object)zips.First() : DBNull.Value)).Tables[0].AsEnumerable().Select(p => new LocationDto()
            {
                Value = p["LocationId"].ToString(),
                OptionGroup = p["LocationType"].ToString(),
                Text = p["LocationType"].ToString() == "Zip" ? $"{p["DisplayName"]}, {p["SourceSystemCode"]}" : p["DisplayName"].ToString()
            });
        }
        /// <summary>
        /// Returns civilian PCS location data by AmcosVersionId and locationId
        /// </summary>
        /// <param name="amcosVersionId"></param>
        /// <returns>IEnumerable of LocationDto</returns>
        public static LocationDto GetCivPCSLocationById(int locationId, int amcosVersionId)
        {
            var dataset = ExecuteStoredProcedure("web.GetCivPCSLocationById", new NpgsqlParameter("@LocationId", locationId), new NpgsqlParameter("@AmcosVersionId", amcosVersionId));
            if (dataset?.Tables != null && dataset.Tables.Count > 0 && dataset.Tables[0].Rows.Count > 0 && dataset.Tables[0].Rows[0] != null)
            {
                var row = dataset.Tables[0].Rows[0];
                return new LocationDto()
                {
                    Value = row["LocationId"].ToString(),
                    OptionGroup = row["LocationType"].ToString(),
                    Text = row["LocationType"].ToString() == "Zip" ? $"{row["DisplayName"]}, {row["SourceSystemCode"]}" : row["DisplayName"].ToString()
                };
            }
            else
                return null;
        }
        /// <summary>
        /// Returns a list of jicinflationrate entities by defined input parameters
        /// </summary>
        /// <param name="conversionType"></param>
        /// <param name="appropriation"></param>
        /// <param name="amcosVersionId"></param>
        /// <returns></returns>
        public static List<SelectListItem> GetJicInflationRateYears(string conversionType, string appropriation, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.JicInflationRates.AsNoTracking()
                    .Where(j => j.ConversionType == conversionType && j.Appropriation == appropriation && j.AmcosVersionId == amcosVersionId)
                    .Select(j => new SelectListItem() { Text = j.Year.ToString(), Value = j.Year.ToString() }).ToList();
            }
        }
        /// <summary>
        /// Returns the jicInflationRate for input parameters
        /// </summary>
        /// <param name="conversionType"></param>
        /// <param name="appropriation"></param>
        /// <param name="year"></param>
        /// <param name="amcosVersionId"></param>
        /// <returns></returns>
        public static decimal GetJicInflationRate(string conversionType, string appropriation, short year, int amcosVersionId)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.JicInflationRates.AsNoTracking()
                    .Where(j => j.ConversionType == conversionType && j.Appropriation == appropriation && j.AmcosVersionId == amcosVersionId && j.Year == year)
                    .Select(j => j.Amount).FirstOrDefault();
            }
        }
        /// <summary>
        /// Returns the max available amcosReleaseVersion from the JicInflationRates table
        /// </summary>
        /// <returns></returns>
        public static int GetMaxReleaseVersion()
        {
            using (var context = new ApplicationDbContext())
            {
                return context.JicInflationRates.AsNoTracking().Max(j => j.AmcosVersionId);
            }
        }
        /// <summary>
        /// Returns the list of available appropriation items for civilian PCS
        /// </summary>
        /// <returns></returns>
        public static List<SelectListItem> GetCivPCSAppropriationList()
        {
            return new List<SelectListItem>()
            {
                new SelectListItem() { Text = "Army CivPay", Value = "Army CivPay"},
                new SelectListItem() { Text = "Federal OM", Value = "Federal OM"},
                new SelectListItem() { Text = "OMA", Value = "OMA"},
                new SelectListItem() { Text = "OMAR", Value = "OMAR"},
                new SelectListItem() { Text = "OMDW", Value = "OMDW"},
                new SelectListItem() { Text = "OMNG", Value = "OMNG"},
            };
        }
        /// <summary>
        /// Returns the max release versions grouped by year with a minimum range determined by the input startYear
        /// </summary>
        /// <param name="startYear"></param>
        /// <returns></returns>
        public static IEnumerable<SelectListItem> GetMaxReleaseVersionPerYear(int startYear)
        {
            return ExecuteStoredProcedure("web.GetMaxReleaseVersionsPerYear", new NpgsqlParameter("@start", startYear)).Tables[0].AsEnumerable().Select(p => new SelectListItem { Value = $"{p["CY"]}{p["Release"]}", Text = p["CY"]?.ToString() });
        }

        /// <summary>
        /// Calculate the distance in miles between two locations using a source locationId and target locationId
        /// </summary>
        /// <param name="sourceLocation"></param>
        /// <param name="targetLocation"></param>
        /// <returns></returns>
        public static float CalculateDistance(CivLocationPerDiem sourceLocation, CivLocationPerDiem targetLocation)
        {
            if (sourceLocation == null || targetLocation == null) return 0;

            // Coordinates are EF-ignored in the PostgreSQL model (no geography column was migrated
            // into web.CivLocationPerDiem), so they are null at runtime. Without coordinates we can
            // not auto-compute the great-circle distance; return 0 so the user supplies the mileage
            // manually rather than throwing a NullReferenceException during CalculateAll.
            if (sourceLocation.Coordinates == null || targetLocation.Coordinates == null) return 0;

            var distance = sourceLocation.Coordinates.Distance(targetLocation.Coordinates);
            if (distance.HasValue)
                return (float)(distance.Value / 1609.34); //Convert meters to miles
            else
                return 0;
        }
        /// <summary>
        /// Geodesic distance in statute miles between two warehouse.Location points using PostGIS
        /// ST_Distance over the geography column (returns meters on the spheroid). This replaces the
        /// in-memory coordinate math, which is unavailable in the Core model because
        /// CivLocationPerDiem.Coordinates is EF-ignored. Returns null when either location has no
        /// coordinates so the caller can fall back to manual mileage entry.
        /// </summary>
        public static int? GetDistanceMiles(int originationId, int destinationId)
        {
            if (originationId <= 0 || destinationId <= 0) return null;
            using (var connection = new NpgsqlConnection(AppConfiguration.GetConnectionString()))
            {
                connection.Open();
                using (var command = new NpgsqlCommand(
                    @"SELECT ST_Distance(o.coordinates, d.coordinates)
                      FROM warehouse.location o, warehouse.location d
                      WHERE o.locationid = @o AND d.locationid = @d
                        AND o.coordinates IS NOT NULL AND d.coordinates IS NOT NULL", connection))
                {
                    command.Parameters.AddWithValue("@o", originationId);
                    command.Parameters.AddWithValue("@d", destinationId);
                    var result = command.ExecuteScalar();
                    if (result == null || result == DBNull.Value) return null;
                    return (int)Math.Round(Convert.ToDouble(result) / 1609.34);
                }
            }
        }
        /// <summary>
        /// Return a single CivLocationPerDiem by locationId
        /// </summary>
        /// <param name="locationId"></param>
        /// <returns></returns>
        public static CivLocationPerDiem GetCivLocationPerDiemById(int locationId, int amcosVersionId)
        {
            if (locationId == 0) return null;
            using (var context = new ApplicationDbContext())
            {
                return context.CivLocationPerDiem.AsNoTracking().Where(c => c.LocationId == locationId && c.AmcosVersionId == amcosVersionId).FirstOrDefault();
            }
        }
        /// <summary>
        /// Get project by project name and userid
        /// </summary>
        /// <param name="projectName"></param>
        /// <param name="userId"></param>
        /// <returns></returns>
        public static CivPcsJson OpenProject(string projectName, string userId)
        {
            projectName = projectName.Trim();
            using (var context = new ApplicationDbContext())
            {
                var pcsJson = context.PCSProject.AsNoTracking().Where(p => p.ProjectName == projectName && p.UserId == userId).FirstOrDefault()?.ConvertToCivPCSjson();
                if (pcsJson != null)
                {
                    pcsJson.InitialState = false;
                }
                return pcsJson;
            }
        }
        private static IOrderedEnumerable<PCSProject> OrderBy(this IQueryable<PCSProject> project, string sortColumn, string sortOrder)
        {
            Func<PCSProject, object> column = null;
            if (sortColumn?.Trim().ToLower() == "projectname")
                column = (PCSProject p) => { return p.ProjectName; };
            else
                column = (PCSProject p) => { return p.ProjectSaveDate; };

            if (sortOrder?.Trim().ToLower() == "asc")
                return project.OrderBy(column);
            else
                return project.OrderByDescending(column);
        }
        /// <summary>
        /// Get a list of projects by userId 
        /// </summary>
        /// <param name="userId"></param>
        /// <returns>Tuple of ProjectName and SaveDate</returns>
        public static List<Tuple<string, DateTime>> GetProjects(string userId, string sortColumn, string sortOrder)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.PCSProject.AsNoTracking().Where(p => p.UserId == userId && p.Deleted != true).OrderBy(sortColumn, sortOrder).Select(d => new Tuple<string, DateTime>(d.ProjectName, d.ProjectSaveDate)).ToList();
            }
        }
        /// <summary>
        /// Processes civilian pcs user input data and returns the resultant calculated values
        /// </summary>
        /// <param name="json"></param>
        /// <returns></returns>
        public static CivPcsJson ProcessJsonInput(CivPcsJson json)
        {
            int amcosVersion = json.AmcosVersionId;
            CivLocationPerDiem origination = null;
            CivLocationPerDiem destination = null;
            json.JicInflationRate = GetJicInflationRate(json.ConversionType, json.Appropriation, json.Year, amcosVersion);
            if (json.OriginationId > 0 && json.DestinationId > 0)
            {
                origination = GetCivLocationPerDiemById(json.OriginationId, amcosVersion);
                destination = GetCivLocationPerDiemById(json.DestinationId, amcosVersion);
            }
            if (origination == null || destination == null)
                return json;

            //Mileage            
            ProcessMileageInput(json, origination, destination);
            //House Hunting
            ProcessHouseHunting(json, destination, amcosVersion, json.JicInflationRate);
            //Transportation
            ProcessTransportation(json, json.CalculatedDistance, amcosVersion);
            //TQSE
            ProcessTQSE(json, destination, amcosVersion, json.JicInflationRate);
            //Goods / Home Transportation
            ProcessGoodsHomeTransportation(json, amcosVersion, json.JicInflationRate);
            //MEA
            ProcessMEA(json, json.CalculatedDistance, json.InitialState, amcosVersion);
            //Real Estate
            ProcessRealEstateLease(json, json.InitialState, json.LocationChanged, json.CalculatedDistance, amcosVersion, json.JicInflationRate, origination, destination);
            //NTS
            ProcessNTS(json, json.InitialState, json.CalculatedDistance, amcosVersion, json.JicInflationRate);
            //RITA
            ProcessRITA(json, destination, amcosVersion);
            //GrandTotal
            ProcessGrandTotal(json);

            return json;
        }
        private static AvalaraStateTax GetStateTax(string zipCode)
        {
            using (var context = new ApplicationDbContext())
            {
                return context.AvalaraStateTax.AsNoTracking().Where(a => a.ZipCode == zipCode.Trim()).FirstOrDefault();
            }
        }
        private static void ProcessGrandTotal(CivPcsJson json)
        {
            json.GrandTotal = json.HouseHuntingTotal + json.TransportationSubTotal + json.TQSETotal + json.GHTransportationTotal +
                json.MEASubtotal + json.RealEstateLeaseTotal + json.NTSSubtotal + json.RITASubtotal;
        }
        private static void ProcessRITA(CivPcsJson json, CivLocationPerDiem destination, int amcosVersion)
        {
            if (json.InitialState)
            {
                json.FederalTaxRate = json.DefaultFederalTaxRate = SingleValue.Get("AA", "PCS_CivDefaultTax", amcosVersion);
                json.SocialSecurityTaxRate = SingleValue.Get("AA", "PercentSocialSecurity", amcosVersion) * 100;
                json.MedicareTaxRate = SingleValue.Get("AA", "percentMedicare", amcosVersion) * 100;
            }
            if (json.LocationChanged)
            {
                if (destination.LocationType == "Zip")
                {
                    var tax = GetStateTax(destination.SourceSystemCode);
                    json.StateTaxRate = tax == null ? 0 : tax.StateRate * 100;
                    json.CountyTaxRate = tax == null ? 0 : tax.EstimatedCountyRate * 100;
                    json.CityTaxRate = tax == null ? 0 : tax.EstimatedCityRate * 100;
                }
                else
                {
                    json.StateTaxRate = 0;
                    json.CountyTaxRate = 0;
                    json.CityTaxRate = 0;
                }
            }
            json.TotalTaxRate = json.FederalTaxRate + json.SocialSecurityTaxRate + json.MedicareTaxRate + json.StateTaxRate + json.CountyTaxRate + json.CityTaxRate;
            var totalTaxRate = json.TotalTaxRate / 100;
            json.HouseHuntingRITA = Math.Round(totalTaxRate * json.HouseHuntingTotal, 2);
            json.TransportationRITA = Math.Round(totalTaxRate * json.TransportationSubTotal, 2);
            json.TQSERITA = Math.Round(totalTaxRate * json.TQSETotal, 2);
            json.GHTransportationRITA = Math.Round(totalTaxRate * json.GHTransportationTotal, 2);
            json.MEARITA = Math.Round(totalTaxRate * json.MEASubtotal, 2);
            json.RealEstateLeaseRITA = Math.Round(totalTaxRate * json.RealEstateLeaseTotal, 2);
            json.NTSRITA = Math.Round(totalTaxRate * json.NTSSubtotal, 2);

            json.RITASubtotal = json.HouseHuntingRITA + json.TransportationRITA + json.TQSERITA + json.GHTransportationRITA + json.MEARITA + json.RealEstateLeaseRITA + json.NTSRITA;
        }
        private static void ProcessNTS(ICivPcsNts ntsInput, bool initialState, int calculatedDistance, int amcosVersion, decimal jicInflationRate)
        {
            if (calculatedDistance > 0 && ntsInput.IsIsolatedDutyStation)
                ntsInput.NTSSubtotal = initialState || ntsInput.IsIsolatedDutyStationChanged ?
                    Math.Round(SingleValue.Get("AA", "PCS_NTSDefaultSqFt", amcosVersion) * SingleValue.Get("AA", "PCS_NTSPricePerSqFt", amcosVersion) * 12 * SingleValue.Get("AA", "PCS_NTSDefaultYears", amcosVersion) * jicInflationRate, 2) :
                    Math.Round(ntsInput.NTSSubtotal, 2);
            else
                ntsInput.NTSSubtotal = 0;
        }
        private static void ProcessMileageInput(CivPcsJson json, CivLocationPerDiem origination, CivLocationPerDiem destination)
        {
            //Only update the CalculatedDistance if the location was changed and the calculated miles were not just manually altered.
            if (json.LocationChanged && !json.MileageChanged)
            {
                // Compute the great-circle distance geodesically in PostGIS. Falls back to 0 (manual
                // entry) when either location is missing coordinates.
                json.CalculatedDistance = GetDistanceMiles(json.OriginationId, json.DestinationId) ?? 0;
                //Set the miles changed flag to true.  This will automatically be set back to false after calculations are complete.
                json.MileageChanged = true;
            }
        }
        private static void ProcessHouseHunting(ICivPcsHouseHunting houseHuntingInput, CivLocationPerDiem destination, int amcosVersion, decimal jicInflationRate)
        {
            houseHuntingInput.SpousePerDiemRate = SingleValue.Get("AA", "PCS_SpousePerDiem_Rate", amcosVersion);
            houseHuntingInput.SelfLodgingPerDiem = destination != null && destination.MaxLodgingRate.HasValue ? Math.Round(destination.MaxLodgingRate.Value * jicInflationRate, 2) : 0;
            houseHuntingInput.SelfMIEPerDiem = destination != null && destination.MIERate.HasValue ? Math.Round(destination.MIERate.Value * jicInflationRate, 2) : 0;
            houseHuntingInput.SpouseLodgingPerDiem = houseHuntingInput.HouseHuntingHaveSpouse ? Math.Round(houseHuntingInput.SelfLodgingPerDiem * houseHuntingInput.SpousePerDiemRate, 2) : 0;
            houseHuntingInput.SpouseMIEPerDiem = houseHuntingInput.HouseHuntingHaveSpouse ? Math.Round(houseHuntingInput.SelfMIEPerDiem * houseHuntingInput.SpousePerDiemRate, 2) : 0;
            if (houseHuntingInput.NumberOfDaysHunting > 0)
            {
                var totalDayPerDiem = houseHuntingInput.SelfLodgingPerDiem + houseHuntingInput.SelfMIEPerDiem + houseHuntingInput.SpouseMIEPerDiem + houseHuntingInput.SpouseLodgingPerDiem;
                var totalDayMIE = houseHuntingInput.SelfMIEPerDiem + houseHuntingInput.SpouseMIEPerDiem;
                houseHuntingInput.HouseHuntingTotal = Math.Round(totalDayPerDiem * houseHuntingInput.NumberOfDaysHunting + totalDayMIE * SingleValue.Get("AA", "PCS_HouseHuntingTravelDayRate", amcosVersion) * SingleValue.Get("AA", "PCS_DefaultHouseHuntingTravelDays", amcosVersion), 2);
            }
            else
                houseHuntingInput.HouseHuntingTotal = 0;
        }
        private static void ProcessTransportation(CivPcsJson transportationInput, int calculatedDistance, int amcosVersion)
        {
            if(transportationInput.MileageChanged)
            {
                transportationInput.POVMileage = calculatedDistance;
                transportationInput.POVMileageChanged = true;
            }
           
            transportationInput.PCSMaltRate = SingleValue.Get("AA", "PCS_MALT_Rate", amcosVersion);
            transportationInput.TransportationVersionYear = Convert.ToInt16(amcosVersion.ToString().Substring(0, 4));
            transportationInput.MileageReimbursement = Math.Round(transportationInput.POVMileage * transportationInput.PCSMaltRate, 2);
            //Enforce a min and max for transportation dependents from 0 - 999
            transportationInput.TransportationDependents = Math.Max(Math.Min(transportationInput.TransportationDependents, 999), 0);
            //Multiply the number of dependents by the Mileage reimbursement value to calculate the Dependent mileage reimbursement and round to 2 decimal places
            transportationInput.DependantMileageReimbursement = Math.Round(transportationInput.TransportationDependents * transportationInput.MileageReimbursement, 2);
            transportationInput.TransportationSubTotal = transportationInput.POVMileageChanged || transportationInput.TransDependentsChanged ? transportationInput.DependantMileageReimbursement + transportationInput.MileageReimbursement : Math.Round(transportationInput.TransportationSubTotal, 2);
        }
        private static void ProcessTQSE(ICivPcsTqse tqseInput, CivLocationPerDiem destination, int amcosVersion, decimal jicInflationRate)
        {
            tqseInput.TQSEPerDiemRate = SingleValue.Get("AA", "PCS_TQSEPerDiem_Rate", amcosVersion);
            tqseInput.TQSESpousePerDiemRate = SingleValue.Get("AA", "PCS_TQSESpousePerDiem_Rate", amcosVersion);
            tqseInput.TQSESelfPerDiemLodging = destination != null && destination.MaxLodgingRate.HasValue ? Math.Round(tqseInput.TQSEPerDiemRate * destination.MaxLodgingRate.Value * jicInflationRate, 2) : 0;
            tqseInput.TQSESelfPerDiemMIE = destination != null && destination.MIERate.HasValue ? Math.Round(tqseInput.TQSEPerDiemRate * destination.MIERate.Value * jicInflationRate, 2) : 0;
            //Enforce a min and max for tqse dependents from 0-999
            tqseInput.TQSEDependents = Math.Max(Math.Min(tqseInput.TQSEDependents, 999), 0);
            tqseInput.TQSESpousePerDiemLodging = destination != null && tqseInput.TQSEDependents > 0 && destination.MaxLodgingRate.HasValue ? Math.Round(tqseInput.TQSEDependents * tqseInput.TQSESpousePerDiemRate * destination.MaxLodgingRate.Value * jicInflationRate, 2) : 0;
            tqseInput.TQSESpousePerDiemMIE = destination != null && tqseInput.TQSEDependents > 0 && destination.MIERate.HasValue ? Math.Round(tqseInput.TQSEDependents * tqseInput.TQSESpousePerDiemRate * destination.MIERate.Value * jicInflationRate, 2) : 0;
            if (tqseInput.NumberDaysTQSE > 0)
            {
                var totalTQSEDay = tqseInput.TQSESelfPerDiemLodging + tqseInput.TQSESelfPerDiemMIE + tqseInput.TQSESpousePerDiemLodging + tqseInput.TQSESpousePerDiemMIE;
                var totalDayMIE = tqseInput.TQSESelfPerDiemMIE + tqseInput.TQSESpousePerDiemMIE;
                tqseInput.TQSETotal = Math.Round(totalTQSEDay * tqseInput.NumberDaysTQSE + totalDayMIE * SingleValue.Get("AA", "PCS_TQSETravelDayRate", amcosVersion) * SingleValue.Get("AA", "PCS_DefaultTQSETravelDays", amcosVersion), 2);
            }
            else
                tqseInput.TQSETotal = 0;
        }
        private static void ProcessGoodsHomeTransportation(CivPcsJson json, int amcosVersion, decimal jicInflationRate)
        {
            json.HHGTotalMileage = json.MileageChanged ? json.CalculatedDistance : json.HHGTotalMileage;
            json.MobileHomeTotalMileage = json.MileageChanged ? json.CalculatedDistance : json.MobileHomeTotalMileage;
            json.HHGMaxWeight = Convert.ToInt32(SingleValue.Get("AA", "PCS_HHGMaxWeight", amcosVersion));
            json.HHGEstimatedCostPerMile = Math.Round(json.InitialState ? SingleValue.Get("AA", "PCS_HHGCostPerMile", amcosVersion) * jicInflationRate : json.HHGEstimatedCostPerMile, 2);
            json.HHGEstimatedCostPerPound = Math.Round(json.InitialState ? SingleValue.Get("AA", "PCS_HHGCostPerPound", amcosVersion) * jicInflationRate : json.HHGEstimatedCostPerPound, 2);
            json.HHGTotalWeight = json.InitialState ? json.HHGMaxWeight : json.HHGTotalWeight;
            json.MobileHomeEstCostPerMile = Math.Round(json.InitialState ? SingleValue.Get("AA", "PCS_MobileHomeCostPerMile", amcosVersion) * jicInflationRate : json.MobileHomeEstCostPerMile, 2);
            if (json.TransportationType == "Goods")
            {
                //Goods
                json.HHGCostByTotalMiles = Math.Round(json.HHGEstimatedCostPerMile * json.HHGTotalMileage, 2);
                json.HHGCostByTotalWeight = Math.Round(json.HHGTotalMileage > 0 ? json.HHGEstimatedCostPerPound * Convert.ToDecimal(Math.Min(json.HHGTotalWeight, json.HHGMaxWeight)) : 0, 2);
                json.SubtotalHHG = json.HHGCostByTotalMiles + json.HHGCostByTotalWeight;
                json.GHTransportationTotal = json.SubtotalHHG;
            }
            else
            {
                // Home
                json.MobileHomeSubtotal = Math.Round(json.MobileHomeTotalMileage * json.MobileHomeEstCostPerMile, 2);
                json.GHTransportationTotal = json.MobileHomeSubtotal;
            }
        }
        private static void ProcessMEA(ICivPcsMea meaInput, int calculatedDistance, bool initialState, int amcosVersion)
        {
            meaInput.MEACivilian = Math.Round(SingleValue.Get("AA", "PCS_MEACivilian", amcosVersion), 2);
            meaInput.MEACivilianAndSpouse = Math.Round(SingleValue.Get("AA", "PCS_MEACivilianAndSpouse", amcosVersion), 2);
            if (calculatedDistance > 0)
                meaInput.MEASubtotal = initialState ? (meaInput.MEAHasSpouse ? meaInput.MEACivilianAndSpouse : meaInput.MEACivilian) : meaInput.MEASubtotal;
            else
                meaInput.MEASubtotal = 0;
        }
        private static void ProcessRealEstateLease(CivPcsJson realEstateLease, bool initialState, bool locationChanged, int calculatedDistance, int amcosVersion, decimal jicInflationRate, CivLocationPerDiem origination, CivLocationPerDiem destination)
        {
            //Refund prices come in as percentages but must be calculated as fractions.
            realEstateLease.SalePriceRefund *= .01M;
            realEstateLease.PurchasePriceRefund *= .01M;

            if (calculatedDistance == 0)
            {
                realEstateLease.SalePriceAmount = 0;
                realEstateLease.PurchasePriceAmount = 0;
                realEstateLease.UELAmount = 0;
                realEstateLease.UELTotal = 0;
            }
            else
            {


                if (initialState || locationChanged)
                {
                    if (origination.LocationType.IndexOf("civilian overseas", StringComparison.OrdinalIgnoreCase) > -1 || destination.LocationType.IndexOf("civilian overseas", StringComparison.OrdinalIgnoreCase) > -1)
                    {
                        realEstateLease.SalePriceAmount = 0;
                        realEstateLease.PurchasePriceAmount = 0;
                    }
                    else
                    {
                        //TODO: find a way to make these estimations more accurate to the actual averages by origination / destination
                        var value = Math.Round(SingleValue.Get("AA", "PCS_RealEstateDefaultValue", amcosVersion) * jicInflationRate, 2);
                        realEstateLease.SalePriceAmount = value;
                        realEstateLease.PurchasePriceAmount = value;
                        realEstateLease.SalePriceRefund = SingleValue.Get("AA", "PCS_RealEstateSaleRefund", amcosVersion);
                        realEstateLease.PurchasePriceRefund = SingleValue.Get("AA", "PCS_RealEstatePurchaseRefund", amcosVersion);
                    }
                }

                realEstateLease.UELAmount = initialState ? Math.Round(SingleValue.Get("AA", "PCS_UELDefault", amcosVersion) * jicInflationRate, 2) : realEstateLease.UELAmount;
            }

            if (realEstateLease.RealEstateOrLease == "RealEstate")
            {
                //Make sure we don't go over the maximum values
                var maxSaleRefund = SingleValue.Get("AA", "PCS_RealEstateSaleRefund_Max", amcosVersion);
                var maxPurchaseRefund = SingleValue.Get("AA", "PCS_RealEstatePurchaseRefund_Max", amcosVersion);

                if (realEstateLease.SalePriceRefund > maxSaleRefund) { realEstateLease.SalePriceRefund = maxSaleRefund; }
                else if (realEstateLease.SalePriceRefund < 0) { realEstateLease.SalePriceRefund = 0; }
                else { realEstateLease.SalePriceRefund = Math.Round(realEstateLease.SalePriceRefund, 4); }

                if (realEstateLease.PurchasePriceRefund > maxPurchaseRefund) { realEstateLease.PurchasePriceRefund = maxPurchaseRefund; }
                else if (realEstateLease.PurchasePriceRefund < 0) { realEstateLease.PurchasePriceRefund = 0; }
                else { realEstateLease.PurchasePriceRefund = Math.Round(realEstateLease.PurchasePriceRefund, 4); }

                realEstateLease.RealEstateSubtotal = Math.Round(realEstateLease.SalePriceRefund * realEstateLease.SalePriceAmount, 2) +
                Math.Round(realEstateLease.PurchasePriceRefund * realEstateLease.PurchasePriceAmount, 2);
                realEstateLease.RealEstateLeaseTotal = realEstateLease.RealEstateSubtotal;
            }
            else
            {
                realEstateLease.UELTotal = realEstateLease.UELAmount;
                realEstateLease.RealEstateLeaseTotal = realEstateLease.UELTotal;
            }

            //Reset Refund to percentage values for display
            realEstateLease.PurchasePriceRefund *= 100;
            realEstateLease.SalePriceRefund *= 100;
        }
        private static DataSet ExecuteStoredProcedure(string storedProcedure, params NpgsqlParameter[] parameters)
        {
            // The web.* functions return (result_set_name text, row_data jsonb); StoredFunction
            // unpacks the jsonb into a flat DataTable. The old CommandType.StoredProcedure path
            // produced CALL (invalid on a function) and a two-column result, not the flat shape
            // these callers consume (row["LocationId"], row["CY"], etc.).
            DataSet dataset = new DataSet();
            dataset.Tables.Add(StoredFunction.QueryAsTable(storedProcedure, parameters));
            return dataset;
        }
    }
}
