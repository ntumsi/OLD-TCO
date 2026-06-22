using System;
using System.Data;
using System.Web.UI.WebControls;

namespace AMCOS.Logic
{
    public class WebControlUtil
    {
        public static void PopulateDropDownList(ref DropDownList dropDownList,ref DataView dvDataSource,string valueField, string textField = "",string selectedValue = "",bool addBlankSelect = false)
        {

            dropDownList.DataSource = dvDataSource;
            dropDownList.DataValueField = valueField;
            if (textField == "")
            {
                dropDownList.DataTextField = valueField;
            }
            else
            {
                dropDownList.DataTextField = textField;
            }
            dropDownList.DataBind();

            if (addBlankSelect) {
                dropDownList.Items.Insert(0, new ListItem("(Select)", ""));
                selectedValue = "";
            }

            if (dvDataSource.Table.Columns[valueField].DataType == Type.GetType("System.String")) {
                for (int i = 0; i < dropDownList.Items.Count - 1; i++) {
                    if (dropDownList.Items[i].Value.Trim() == selectedValue.Trim()) {
                        dropDownList.Items[i].Selected = true;
                        break;
                    }
                }
            }
            else{
                ListItem lstItem = dropDownList.Items.FindByValue(selectedValue);
                if (!(lstItem == null)) {
                    lstItem.Selected = true;
                }
            }       
    }

        public static void PopulateDropDownList(ref DropDownList dropDownList,ref string[] sa,string selectedValue = "")
        {
            dropDownList.DataSource = sa;
            dropDownList.DataBind();
            ListItem lstItem = dropDownList.Items.FindByValue(selectedValue);
            if (!(lstItem == null)) {
                lstItem.Selected = true;
            }
        }
    }
}
