Imports System.Configuration.ConfigurationManager
Imports System.Web.Services
Imports System.ComponentModel
Imports AMCOS.Data.ViewModels
Imports AMCOS.Logic

' To allow this Web Service to be called from script, using ASP.NET AJAX, uncomment the following line.
<System.Web.Script.Services.ScriptService()>
<System.Web.Services.WebService(Namespace:="http://tempuri.org/")>
<System.Web.Services.WebServiceBinding(ConformsTo:=WsiProfiles.BasicProfile1_1)>
<ToolboxItem(False)>
Public Class LiteService
    Inherits System.Web.Services.WebService

    <WebMethod()>
    Public Sub LogChoices(userId As String, pageElement As String, payPlan As String, costSummaryName As String, categoryGroupCode As String, categorySubgroupCode As String, careerProgramNumber As String, locationId As Integer, locationText As String, scienceTechnologyReinventionLaboratory As String, dependentStatus As String, numberOfDependents As Integer, overheadPercent As String, inflationConversionType As String, inflationYear As String)

        Dim Logging As Boolean = False
        Dim customSetting As String = AppSettings("AmcosLiteLogging")
        If Not (customSetting = Nothing) Then
            If (customSetting = "Both") Or (customSetting = "FilterValue") Then
                Logging = True
            Else
                Logging = False
            End If
        Else
            Logging = False
        End If

        If Logging = False Then
            Exit Sub
        End If

        Dim amcosLiteViewModel As AmcosLiteViewModel = New AmcosLiteViewModel With {
            .UserId = userId,
            .PayPlan = payPlan,
            .CostSummaryName = costSummaryName,
            .CategoryGroupCode = categoryGroupCode,
            .CategorySubgroupCode = categorySubgroupCode,
            .CareerProgramNumber = careerProgramNumber,
            .LocationId = locationId,
            .LocationText = locationText,
            .ScienceTechnologyReinventionLaboratory = scienceTechnologyReinventionLaboratory,
            .DependentStatus = dependentStatus,
            .NumberOfDependents = numberOfDependents,
            .OverheadPercent = CSng(overheadPercent),
            .InflationConversionType = inflationConversionType,
            .InflationYear = inflationYear
        }

        Try
            Dim amcosLite As Lite = New Lite()
            amcosLite.LogSelections("Filter", pageElement, amcosLiteViewModel)
        Catch ex As Exception
            'do nothing
        End Try

    End Sub

End Class