Imports System.Web.Http
Imports AMCOS.Data.DataTransferObjects
Imports AMCOS.Logic

Namespace Controllers
    Public Class StrlsController
        Inherits ApiController
        <HttpGet>
        <Route("api/strls/{payplan}/{categorygroupcode}/{categorysubgroupcode}/{careerProgramNumber}/{locationId}")>
        Public Function GetStrls(PayPlan As String, CategoryGroupCode As String, CategorySubgroupCode As String, CareerProgramNumber As String, LocationId As Integer) As List(Of ScienceAndTechnologyReinventionLaboratoryDto)

            Dim amcosLite As New Lite()
            Dim results As List(Of ScienceAndTechnologyReinventionLaboratoryDto) = New List(Of ScienceAndTechnologyReinventionLaboratoryDto)
            results = amcosLite.GetOptionListScienceTechnologyReinventionLaboratory(PayPlan, CategoryGroupCode, CategorySubgroupCode, CareerProgramNumber, LocationId)
            Return results

        End Function
    End Class
End Namespace