Imports AMCOS.Logic

Partial Class download
    Inherits BasePage

    Public ReadOnly Property DownloadData() As String
        Get
            If Session("DownloadData") Is Nothing Then
                Session("DownloadData") = ""
            End If
            Return CType(Session("DownloadData"), String)
        End Get
    End Property

    Public ReadOnly Property DownloadType() As String
        Get
            Dim sType As String = String.Empty
            If Not Request("Type") Is Nothing Then
                sType = Request("Type")
            End If
            Return sType
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        Response.Clear()
    End Sub

End Class
