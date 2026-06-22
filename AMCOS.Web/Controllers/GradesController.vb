Imports System.Configuration.ConfigurationManager
Imports System.Web.Http
Imports AMCOS.Data.DataTransferObjects
Imports AMCOS.Logic

Namespace Controllers
    Public Class GradesController
        Inherits ApiController
        <HttpGet>
        <Route("api/grades/{payPlan}/{categoryGroupCode}/{categorySubgroupCode}/{careerProgramNumber}/{locationId}")>
        Public Function GetGradesByCategory(PayPlan As String, CategoryGroupCode As String, CategorySubgroupCode As String, CareerProgramNumber As String, LocationId As Integer) As List(Of GradeLevelDto)

            Dim amcosLite As New Lite()
            Dim results As List(Of GradeLevelDto) = New List(Of GradeLevelDto)
            results = amcosLite.GetOptionListGradeLevel(PayPlan, CategoryGroupCode, CategorySubgroupCode, CareerProgramNumber, LocationId, CInt(AppSettings("AmcosVersionId")))
            Return results

        End Function
    End Class
End Namespace