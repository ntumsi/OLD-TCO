Imports System.Web.Http
Imports AMCOS.Data.DataTransferObjects
Imports AMCOS.Logic

Namespace Controllers
    Public Class LocationsController
        Inherits ApiController
        <HttpGet>
        <Route("api/locations/{payplan}/{categorygroupcode}/{categorysubgroupcode}/{careerProgramNumber}")>
        Public Function GetLocationsByCategory(PayPlan As String, CategoryGroupCode As String, CategorySubgroupCode As String, CareerProgramNumber As String) As List(Of LocationDto)
            Dim amcosLite As New Lite()
            Dim results As List(Of LocationDto) = New List(Of LocationDto)
            results = amcosLite.GetOptionListLocation(PayPlan, CategoryGroupCode, CategorySubgroupCode, CareerProgramNumber)
            Return results
        End Function
        <HttpGet>
        <Route("api/locations/installations")>
        Public Function GetMilitaryInstallations() As List(Of LocationDto)
            Dim amcosLite As New Lite()
            Dim results As List(Of LocationDto) = New List(Of LocationDto)
            results = amcosLite.GetMilitaryInstallations()
            Return results
        End Function
    End Class
End Namespace