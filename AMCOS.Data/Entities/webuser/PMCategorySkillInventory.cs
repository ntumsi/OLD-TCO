namespace AMCOS.Data.Entities
{
    public class PMCategorySkillInventory
    {
        public int InventoryId { get; set; }
        public int SkillId { get; set; }
        public int Year { get; set; }
        public int Amount { get; set; }
        public virtual PMCategorySkill PMCategorySkillRecord { get; set; }
    }
}
