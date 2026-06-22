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
Public Class ProjectService
    Inherits System.Web.Services.WebService

    <WebMethod()>
    Public Sub LogAddUnit(userId As String, categoryId As String, uic As String, excludedPayPlans As String, dataAction As String, newSubprojectName As String, unitLocation As String, mtoeProjectInventoryYear As String, projectExtendsSacsYears As String, contractorOverheadPercent As String)
        Dim customSetting As String = AppSettings("AmcosLiteLogging")

        Dim Logging As Boolean
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

        Dim projectAddUnitViewModel As ProjectAddUnitViewModel = New ProjectAddUnitViewModel With {
            .UserId = userId,
            .CategoryId = categoryId,
            .UIC = uic,
            .ExcludedPayPlans = excludedPayPlans,
            .DataAction = dataAction,
            .NewSubprojectName = newSubprojectName,
            .UnitLocation = unitLocation,
            .MtoeProjectInventoryYear = mtoeProjectInventoryYear,
            .ProjectExtendsSacsYears = projectExtendsSacsYears,
            .ContractorOverheadPercent = contractorOverheadPercent
        }

        Try
            Dim project As Project = New Project()
            project.LogAddUnit(projectAddUnitViewModel)
        Catch ex As Exception
            'do nothing
        End Try

    End Sub

End Class