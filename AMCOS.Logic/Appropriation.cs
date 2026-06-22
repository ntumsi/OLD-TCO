using System.Drawing;

namespace AMCOS.Logic
{
    public class Appropriation
    {
        public const string colorHtmlActiveArmyMPA = "#5D7430";
        public const string colorHtmlActiveArmyOMA = "#6A9303";
        public const string colorHtmlActiveDodOMA = "#7030A0";
        public const string colorHtmlActiveFedOMA = "#00008B";
        public const string colorHtmlARNGOM = "#8BA103";
        public const string colorHtmlARNGPA = "#74B803";
        public const string colorHtmlCCE = "#006D8B";
        public const string colorHtmlCivArmyCivPay = "#1F8802";
        public const string colorHtmlCivArmyOMA = colorHtmlActiveArmyOMA;
        public const string colorHtmlCivFedOMA = colorHtmlActiveFedOMA;
        public const string colorHtmlSumArmy = colorHtmlActiveArmyMPA;
        public const string colorHtmlSumDoD = colorHtmlActiveDodOMA;
        public const string colorHtmlSumFed = colorHtmlActiveFedOMA;
        public const string colorHtmlTotal = "#DEDFDE";
        public const string colorHtmlUSAROM = "#6E8003";
        public const string colorHtmlUSARPA = "#5C9303";

        public Color ColorARNGOM
        {
            get { return ColorTranslator.FromHtml(colorHtmlARNGOM); }
        }
        public Color ColorCCE
        {
            get { return ColorTranslator.FromHtml(colorHtmlCCE); }
        }
        public Color ColorSumArmy
        {
            get { return ColorTranslator.FromHtml(colorHtmlActiveArmyMPA); }
        }
        public Color ColorSumDOD
        {
            get { return ColorTranslator.FromHtml(colorHtmlActiveDodOMA); }
        }
        public Color ColorSumFed
        {
            get { return ColorTranslator.FromHtml(colorHtmlActiveFedOMA); }
        }
        public Color ColorUSAROM
        {
            get { return ColorTranslator.FromHtml(colorHtmlUSAROM); }
        }
        public Color GetAppropriationColor(string appropriation)
        {
            switch (appropriation.Trim())
            {
                case "ARMY CivPay":
                case "Army CivPay":
                case "MPA":
                case "MPA Non-Pay":
                case "OMA":
                case "OMA_1":
                    return ColorTranslator.FromHtml(colorHtmlSumArmy);
                case "DoD OMA":
                case "OMDW":
                    return ColorTranslator.FromHtml(colorHtmlSumDoD);
                case "FEDERAL OMA":
                case "Federal OM":
                    return ColorTranslator.FromHtml(colorHtmlSumFed);
                case "NG OM":
                case "NG OM_1":
                case "NG PA":
                case "NGPA":
                case "OMNG":
                case "OMNG_1":
                    return ColorTranslator.FromHtml(colorHtmlARNGOM);
                case "RES OM":
                case "RES OM_1":
                case "RES PA":
                case "RPA":
                case "OMAR":
                case "OMAR_1":
                    return ColorTranslator.FromHtml(colorHtmlUSAROM);
                case "Contractor":
                    return ColorTranslator.FromHtml(colorHtmlCCE);
                default:
                    return Color.White;
            }
        }
    }
}
