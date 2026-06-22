Imports System.Web.Http
Imports AMCOS.Logic
Imports AMCOS.Data.Entities
Imports AMCOS.Data.DataTransferObjects

Namespace Controllers
    Public Class UnitsController
        Inherits ApiController
        <HttpGet>
        <Route("api/units")>
        Public Function GetUnits() As List(Of UnitDto)
            Dim results As List(Of UnitDto) = New List(Of UnitDto)
            results = OptionList.GetUnitList()
            Return results
        End Function
        <HttpGet>
        <Route("api/units/{unitIdentificationCode}/location/")>
        Public Function GetUnitLocations(UnitIdentificationCode As String) As List(Of UnitLocationDto)
            Dim project As Project = New Project()
            Return project.GetUnitLocations(UnitIdentificationCode)
        End Function
        '<HttpGet>
        '<Route("api/units/{unitIdentificationCode}/personnel")>
        'Public Function GetUnitPersonnel(UnitIdentificationCode As String) As List(Of UnitPersonnel)
        '    Dim project As New Project()
        '    Return project.GetUnitPersonnel(UnitIdentificationCode)
        'End Function
        <HttpGet>
        <Route("api/units/{unitIdentificationCode}/{projectStartYear}/personnel")>
        Public Function GetUnitPersonnel(UnitIdentificationCode As String, ProjectStartYear As Integer) As List(Of UnitPersonnelAndLocationDto)
            Dim project As New Project()
            Return project.GetUnitPersonnelAndLocation(UnitIdentificationCode, ProjectStartYear)
        End Function
        <HttpGet>
        <Route("api/units/{unitIdentificationCode}/mtoeyears")>
        Public Function GetMtoeUnitYears(UnitIdentificationCode As String) As List(Of MtoeUnitYearDto)
            Dim project As Project = New Project()
            Return project.GetMtoeUnitYears(UnitIdentificationCode)
        End Function
    End Class
End Namespace