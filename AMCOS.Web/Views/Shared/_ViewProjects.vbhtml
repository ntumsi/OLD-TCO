@ModelType List(Of Tuple(Of String, DateTime))

    <table class="table-view-project" >
        <thead>
            <tr>
                <th class="text-left" style="width: 250px; padding: 5px;">
                    <a onclick="ViewProjectSort('ProjectName');">Project Name <span data-column="ProjectName"></span></a>
                </th>
                <th class="text-left" colspan="2" style="width: 316px; padding: 5px;">
                    <a onclick="ViewProjectSort('ProjectSaveDate');">Save Date <span data-column="ProjectSaveDate">&#9660;</span></a>
                </th>
            </tr>
        </thead>
        <tbody name="ViewProjectBody">
            @For Each val As Tuple(Of String, DateTime) In Model
                @<tr class="selectable-row" >
                    <td class="selectable-project" >
                        @val.Item1
                    </td>
                    <td class="selectable-project" >
                        @val.Item2
                    </td>
                    <td class="selectable-project-icon">
                        <a class="cal-row-delete" data-tooltip data-click-open="false" title="Delete" value="@val.Item1">&#x1F5D1;</a>
                    </td>
                </tr>
            Next
        </tbody>
    </table>