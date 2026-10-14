namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's dynamic layouts, read-only: one row per rule on a page, with its description,
/// order and disabled flag. Filter on serviceName.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/dynamicLayouts.
/// </summary>
page 77734 "BJF MN Dynamic Layout API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Dynamic Layout';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Dynamic Layout';
    EntityName = 'dynamicLayout';
    EntitySetCaption = 'MobileNAV Dynamic Layout';
    EntitySetName = 'dynamicLayouts';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Dynamic Layout" = r;
    SourceTable = "MobileNAV Dynamic Layout";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(serviceName; Rec."Service Name") { }
                field(code; Rec."Code") { }
                field(description; Rec.Description) { }
                field(disabled; Rec.Disabled) { }
                field(order; Rec."Order") { }
            }
        }
    }
}
