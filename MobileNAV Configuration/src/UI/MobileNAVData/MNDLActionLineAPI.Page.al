namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The action lines of MobileNAV's dynamic layouts, read-only: the control or stage an action
/// targets, with its caption, color and icon. Filter on serviceName.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/dynamicLayoutActionLines.
/// </summary>
page 77737 "BJF MN D. L. Action Line API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV D. L. Action Line';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV D. L. Action Line';
    EntityName = 'dynamicLayoutActionLine';
    EntitySetCaption = 'MobileNAV D. L. Action Line';
    EntitySetName = 'dynamicLayoutActionLines';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV D. L. Action Line" = r;
    SourceTable = "MobileNAV D. L. Action Line";

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
                field(actionType; Rec."Action Type") { }
                field(relatedPageName; Rec."Related Page Name") { }
                field(name; Rec.Name) { }
                field(caption; Rec.Caption) { }
                field(color; Rec.Color) { }
                field(icon; Rec.Icon) { }
            }
        }
    }
}
