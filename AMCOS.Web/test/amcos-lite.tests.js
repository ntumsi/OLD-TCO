var { AMCOSCommon }= require("../dist/js/amcos-common.js");
var assert = require("assert");
describe("amcos-lite", function () {
    var amcos = new AMCOSCommon();
    it("should parse the category group code for Active Duty pay plans", function () {
        const expectedResult = {
            categoryGroupCode: '11',
            categorySubgroupCode: '-1',
            armyCareerProgramNumber: '-1'
        };
        var result = amcos.parseCategory('AE', '11');
        assert.equal(result.categoryGroupCode, expectedResult.categoryGroupCode);
        assert.equal(result.categorySubgroupCode, expectedResult.categorySubgroupCode);
        assert.equal(result.armyCareerProgramNumber, expectedResult.armyCareerProgramNumber);
    });
    it("should parse a valid category for the GS pay plan", function () {
        const expectedResult = {
            categoryGroupCode: '0300',
            categorySubgroupCode: '-1',
            armyCareerProgramNumber: '-1'
        };
        var result = amcos.parseCategory('GS', '0300');
        assert.equal(result.categoryGroupCode, expectedResult.categoryGroupCode);
        assert.equal(result.categorySubgroupCode, expectedResult.categorySubgroupCode);
        assert.equal(result.armyCareerProgramNumber, expectedResult.armyCareerProgramNumber);
    });
    it("should not parse a valid category for the GS pay plan", function () {
        const expectedResult = {
            categoryGroupCode: '0600',
            categorySubgroupCode: '0602',
            armyCareerProgramNumber: '-1'
        };
        var result = amcos.parseCategory('GP', '0602');
        assert.equal(result.categoryGroupCode, expectedResult.categoryGroupCode);
        assert.equal(result.categorySubgroupCode, expectedResult.categorySubgroupCode);
        assert.equal(result.armyCareerProgramNumber, expectedResult.armyCareerProgramNumber);
    });
});