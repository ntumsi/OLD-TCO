Imports System.Net.Mail
Imports System.Configuration.ConfigurationManager
Imports Aspose.Cells

Public Module CommonModule
    Public C As String = AppSettings("OsmiswebLink")
    Public AmcosDatabase As String = ConnectionStrings("AmcosAdo").ConnectionString
    Public _RootPath As String = AppSettings("RootPath")
    Public AmcosAdminEmail As String = AppSettings("AmcosAdminEmail")
    Public AmcosUrl As String = AppSettings("AmcosUrl")
    Public AmcosUserLoginGuideFile As String = AppSettings("AmcosUserLoginGuideFile")
    Public Function GetFiscalYear(ByVal inDate As Date) As Integer
        If Month(inDate) < 10 Then
            GetFiscalYear = Year(inDate)
        Else
            GetFiscalYear = Year(inDate) + 1
        End If
    End Function
    Function GetCommaDelimitedValues(ByRef list As ListItemCollection) As String
        Dim Values As String = String.Empty
        For Each oListItem As ListItem In list
            If Not oListItem Is Nothing AndAlso oListItem.Selected Then
                If Values.Length > 0 Then
                    Values = Values & "," & oListItem.Value
                Else
                    Values = oListItem.Value
                End If
            End If
        Next
        GetCommaDelimitedValues = Values
    End Function
    Function GetCommaDelimitedText(ByRef list As ListItemCollection) As String
        Dim Values As String = String.Empty
        For Each oListItem As ListItem In list
            If Not oListItem Is Nothing AndAlso oListItem.Selected Then
                If Values.Length > 0 Then
                    Values = Values & "," & oListItem.Text.ToString
                Else
                    Values = oListItem.Text.ToString
                End If
            End If
        Next
        GetCommaDelimitedText = Values
    End Function

    <Obsolete("Use AMCOS.Logic.Helpers.EmailHelper.SendEmail instead")>
    Sub SendEmail(ByVal FromAddress As String, ByVal ToAddresses() As String, ByVal Subject As String, ByVal Body As String, Optional FilesToAttach() As String = Nothing, Optional ByVal CCEmailAddresses() As String = Nothing, Optional ByVal BCCEmailAddresses() As String = Nothing)

        Dim SmtpHost As String = AppSettings("SmtpHost")
        Dim SmtpPort As Integer = CInt(AppSettings("SmtpPort"))
        Dim SmtpCredentialsUserName As String = AppSettings("SmtpCredentialsUserName")
        Dim SmtpCredentialsPassword As String = AppSettings("SmtpCredentialsPassword")
        Dim emailFrom As MailAddress = New MailAddress(FromAddress)
        Dim mailMessage As MailMessage = New MailMessage()

        mailMessage.From = emailFrom
        mailMessage.IsBodyHtml = True
        mailMessage.Subject = Subject
        mailMessage.Body = Body

        For Each emailAddress As String In ToAddresses
            mailMessage.To.Add(New MailAddress(emailAddress))
        Next

        If Not FilesToAttach Is Nothing Then
            For Each file As String In FilesToAttach
                mailMessage.Attachments.Add(New Attachment(file))
            Next
        End If

        If Not CCEmailAddresses Is Nothing Then
            For Each emailAddress As String In CCEmailAddresses
                mailMessage.CC.Add(New MailAddress(emailAddress))
            Next
        End If

        If Not BCCEmailAddresses Is Nothing Then
            For Each emailAddress As String In BCCEmailAddresses
                mailMessage.Bcc.Add(New MailAddress(emailAddress))
            Next
        End If

        Dim client As New SmtpClient(SmtpHost, SmtpPort)
        client.Credentials = New Net.NetworkCredential(SmtpCredentialsUserName, SmtpCredentialsPassword)
        client.Send(mailMessage)
    End Sub
    Sub AddClassification(ByRef sheet As Aspose.Cells.Worksheet)
        Dim maxRow As Integer = sheet.Cells.MaxRow
        sheet.Cells.Merge((maxRow + 4), 0, 1, 10)
        sheet.Cells(maxRow + 4, 0).PutValue("UNCLASSIFIED//FOR OFFICIAL USE ONLY")
        Dim style As Aspose.Cells.Style = sheet.Cells(maxRow + 4, 0).GetStyle()
        style.Font.IsBold = True
        style.HorizontalAlignment = Aspose.Cells.TextAlignmentType.Center
        sheet.Cells(maxRow + 4, 0).SetStyle(style)
    End Sub

End Module
