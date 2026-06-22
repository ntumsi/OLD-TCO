Imports System.Web.Http
Imports AMCOS.Data.DataTransferObjects
Imports AMCOS.Logic

Namespace Controllers
    Public Class CategoriesController
        Inherits ApiController
        <HttpGet>
        <Route("api/categories/{payplan}")>
        Public Function GetCategories(PayPlan As String) As List(Of CategoryDto)
            Dim amcosLite As New Lite()
            Return amcosLite.GetOptionListCategory(PayPlan)
        End Function
    End Class
End Namespace