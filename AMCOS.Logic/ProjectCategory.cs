using AMCOS.Data;
using AMCOS.Data.DataTransferObjects;
using System.Collections.Generic;
using System.Linq;

namespace AMCOS.Logic
{
    public class ProjectCategory
    {
        public List<ListItemDto> GetCategoryList(int projectId, int categoryId)
        {
            IEnumerable<ListItemDto> listItems = null;

            using (var context = new ApplicationDbContext())
            {
                listItems = context.PMCategory.AsNoTracking()
                    .Where(c => c.ProjectId == projectId)
                    .Where(c => c.CategoryId != categoryId)
                    .OrderBy(c => c.CategoryName)
                    .Select(c => new ListItemDto()
                    {
                        Value = c.CategoryId.ToString(),
                        Text = c.CategoryName
                    })
                    .Distinct();
                return listItems?.ToList();
            }
        }
    }
}
