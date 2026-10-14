namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The conditions of MobileNAV's dynamic layouts, read-only: the control compared, the
/// comparison and the value, other control or filter. Filter on serviceName.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/dynamicLayoutConditions.
/// </summary>
page 77735 "BJF MN D. L. Condition API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV D. L. Condition';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV D. L. Condition';
    EntityName = 'dynamicLayoutCondition';
    EntitySetCaption = 'MobileNAV D. L. Condition';
    EntitySetName = 'dynamicLayoutConditions';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV D. L. Condition" = r;
    SourceTable = "MobileNAV D. L. Condition";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(serviceName; Rec."Service Name") { }
                field(layoutCode; Rec."Layout Code") { }
                field(lineNo; Rec."Line No.") { }
                field(sourceFieldName; Rec.SourceFieldName) { }
                field(destFieldName; Rec.DestFieldName) { }
                field(conditionType; Rec.ConditionType) { }
                field(comparisonType; Rec."Comparsion Type") { }
                field(conditionValue; Rec.ConditionValue) { }
            }
        }
    }
}
