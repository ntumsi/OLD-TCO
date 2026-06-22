Imports System.Web.Http
Imports AMCOS.Data.DataTransferObjects
Imports AMCOS.Logic

Namespace Controllers
    Public Class PayPlansController
        Inherits ApiController
        Public Function GetAll() As List(Of PayPlanDto)
            Dim amcosLite As New Lite()
            Return amcosLite.GetOptionListPayPlan()
        End Function
    End Class
End Namespace