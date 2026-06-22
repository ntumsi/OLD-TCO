Imports System.Configuration.ConfigurationManager
Imports AMCOS.Logic

Partial Class ProjectDefault
    Inherits BasePage

    Protected Sub SqlProject_Inserting(ByVal sender As Object, ByVal e As SqlDataSourceCommandEventArgs) Handles SqlProject.Inserting
        e.Command.Parameters("@UserId").Value = currentUser.UserId
        e.Command.Parameters("@YearStart").Value = SingleValue.Get("ALL", "ProjectManager_StartYear", CInt(AppSettings("AmcosVersionId")))
    End Sub
    Protected Sub dvProject_ItemCommand(ByVal sender As Object, ByVal e As CommandEventArgs) Handles dvProject.ItemCommand
        Select Case e.CommandName
            Case "Copy"
                Dim project As New Project()
                Dim projectId As Integer = CInt(DirectCast(Me.dvProject.FindControl("ddlExistingProjects"), DropDownList).SelectedValue)
                Dim projectName As String = DirectCast(Me.dvProject.FindControl("tbName"), TextBox).Text
                Dim projectDescription As String = DirectCast(Me.dvProject.FindControl("tbDescription"), TextBox).Text
                project.Copy(projectId, projectName, projectDescription)

        End Select
        Me.projectList.DataBind()
    End Sub
    Protected Sub dvProject_ItemInserted(ByVal sender As Object, ByVal e As DetailsViewInsertedEventArgs) Handles dvProject.ItemInserted
        Me.projectList.DataBind()
    End Sub
    Protected Sub projectList_SelectedIndexChanged(ByVal sender As Object, ByVal e As EventArgs) Handles projectList.SelectedIndexChanged
        Response.Redirect("details.aspx?ProjectId=" & Me.projectList.SelectedDataKey.Item("ProjectId").ToString)
    End Sub

    Private Sub ObjectDataSourceProjects_Selecting(sender As Object, e As ObjectDataSourceSelectingEventArgs) Handles ObjectDataSourceProjects.Selecting
        e.InputParameters("UserId") = currentUser.UserId
    End Sub

End Class
