using System;

namespace System.Web.UI.WebControls
{
    public class ListItem : IEquatable<ListItem>
    {
        public ListItem()
        {
        }

        public ListItem(string text, string value)
        {
            Text = text;
            Value = value;
        }

        public string Text { get; set; }
        public string Value { get; set; }
        public bool Selected { get; set; }

        public bool Equals(ListItem other)
        {
            if (other is null)
            {
                return false;
            }

            return string.Equals(Text, other.Text, StringComparison.Ordinal)
                && string.Equals(Value, other.Value, StringComparison.Ordinal)
                && Selected == other.Selected;
        }

        public override bool Equals(object obj)
        {
            return Equals(obj as ListItem);
        }

        public override int GetHashCode()
        {
            return HashCode.Combine(Text, Value, Selected);
        }
    }
}
