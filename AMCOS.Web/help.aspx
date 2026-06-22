<%@ Page Language="VB" MasterPageFile="~/Site.master" AutoEventWireup="false" Inherits="AMCOS.Web.help" Title="Help" Codebehind="help.aspx.vb" %>

<asp:Content ID="Content1" ContentPlaceHolderID="ContentPlaceHolder1" runat="Server">
   
    <div class="amcos-page">

        <h1>Help &amp; Support</h1>

        <p>
            For questions or suggestions, please click <a href="https://www.aesmp.army.mil/csm?id=sc_cat_item&sys_id=faac2dbe9775d69440c7b8021153afee" target="_blank">here</a> to contact us. 
        </p>
        <p>
            For more information on how to submit a request, please click <a href='<%= ResolveClientUrl("~/Public/AESMP User Primer.pdf") %>' target='_blank'>here.</a>
        </p>

    </div>

</asp:Content>
