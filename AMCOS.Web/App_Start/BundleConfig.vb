Imports System.Web.Optimization

Public Class BundleConfig
    Public Shared Sub RegisterBundles(ByVal bundles As BundleCollection)
        bundles.Add(New ScriptBundle("~/bundles/jquery") _
        .Include("~/dist/js/jquery.min.js") _
        .Include("~/dist/js/foundation.min.js"))

        bundles.Add(New ScriptBundle("~/bundles/civilian-pcs") _
        .Include("~/dist/js/pcs-common.js") _
        .Include("~/dist/js/pcs-civilian.js"))

        bundles.Add(New ScriptBundle("~/bundles/selectize").Include("~/dist/js/selectize.min.js"))

        bundles.Add(New StyleBundle("~/bundles/css").Include("~/dist/css/foundation.min.css").Include("~/dist/css/AMCOS.css"))
    End Sub
End Class


