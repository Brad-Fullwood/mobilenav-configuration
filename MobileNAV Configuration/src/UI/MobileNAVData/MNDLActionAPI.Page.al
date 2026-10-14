namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The actions of MobileNAV's dynamic layouts, read-only: one row per action type, with the
/// caption, color and icon of a page-wide action. Filter on serviceName.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/dynamicLayoutActions.
/// </summary>
page 77736 "BJF MN D. L. Action API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV D. L. Action';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV D. L. Action';
    EntityName = 'dynamicLayoutAction';
    EntitySetCaption = 'MobileNAV D. L. Action';
    EntitySetName = 'dynamicLayoutActions';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV D. L. Action" = r;
    SourceTable = "MobileNAV D. L. Action";

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
                field(type; Rec.Type) { }
                field(caption; Rec.Caption) { }
                field(color; Rec.Color) { }
                field(icon; Rec.Icon) { }
            }
        }
    }
}
