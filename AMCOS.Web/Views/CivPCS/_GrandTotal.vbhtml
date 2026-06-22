@ModelType AMCOS.Logic.ViewModels.CivPcsGrandTotalViewModel

<div class="show-for-medium">
    <h4>@Model.Title</h4>
</div>
<table class="cal-notice-table" style="margin-top: 1.25rem;">
    <tr>
        <td class="header-cell">
            <table class="cal-info-table inner">
                <tr>
                    <td class="header-cell">
                        House Hunting Trip
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="HouseHuntingSummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Transportation Expense
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="TransportationSummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Temporary Quarters Subsistence Expense
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="TQSESummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Goods / Home Transportation
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="GHTransportationSummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Miscellaneous Expense Allowance
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="MEASummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Real Estate / Lease Reimbursement
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="RealEstateLeaseSummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Non-Temporary Storage
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="NTSSummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
                <tr>
                    <td class="header-cell">
                        Relocation Income Tax Allowance
                    </td>
                    <td class="header-cell" style="text-align: right;">
                        <span id="RITASummarySubtotal" name="SummarySubtotal"></span>
                    </td>
                </tr>
            </table>
        </td>
    </tr>
</table>

<table class="cal-subtotal">
    <tr>
        <td>@Model.Title:</td>
        <td id="GrandTotal" name="GrandTotal" class="subtotal-value">$@Model.GrandTotal.ToString("0.00")</td>
    </tr>
</table>

