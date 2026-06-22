
Partial Class PublicNote
    Inherits System.Web.UI.Page
    Private _noteid As Integer = 0

    Public ReadOnly Property NoteId() As Integer
        Get
            If Not Integer.TryParse(Request("noteid"), _noteid) Then

                Response.Redirect("rss.xml")
            End If
            Return Me._noteid
        End Get
    End Property

    Protected Sub Page_Load(ByVal sender As Object, ByVal e As System.EventArgs) Handles Me.Load
        If Not IsPostBack Then
            Me.XmlDataSource1.XPath = "rss/channel/item[contains(guid,'" & NoteId & "')]"
        End If
    End Sub
End Class
