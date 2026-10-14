namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// MobileNAV's profile rows, read-only: which user has which profile (profileType User), the
/// pages a profile carries and their menu tiles and categories (Page), how child pages hang off
/// their parents (Parent Page, Root Page), and per-profile field overrides (Field).
/// Filter on profileCode, profileType and pageId.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/profileSetupLines.
/// </summary>
page 77794 "BJF MN Profile Setup API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Profile Setup Line';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Profile Setup Line';
    EntityName = 'profileSetupLine';
    EntitySetCaption = 'MobileNAV Profile Setup Lines';
    EntitySetName = 'profileSetupLines';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Profile Setup" = r;
    SourceTable = "MobileNAV Profile Setup";

    layout
    {
        area(Content)
        {
            repeater(Lines)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(profileType; Rec."Profile Type") { }
                field(pageId; Rec.ID) { }
                field(profileCode; Rec.Profile) { }
                field(description; Rec.Description) { }
                field(controlId; Rec."Control ID") { }
                field(fieldName; Rec."Field Name") { }
                field(parent; Rec.Parent) { }
                field(visible; Rec.Visible) { }
                field(visibleInherited; Rec."Visible Inherited") { }
                field(editable; Rec.Editable) { }
                field(editableInherited; Rec."Editable Inherited") { }
                field(displayInMenu; Rec."Display in Menu") { }
                field(category; Rec.Category) { }
                field(order; Rec."Order") { }
                field(excludeFromProfile; Rec."Exclude from Profile") { }
                field(excludeByParent; Rec."Exclude by Parent") { }
                field(addedByRelation; Rec."Added by Relation") { }
                field(stagingEnabled; Rec."Staging Enabled") { }
                field(useAsOnline; Rec."Use as Online") { }
                field(lookupOnly; Rec."Lookup Only") { }
                field(pageNo; Rec."Page No.") { }
                field(tableNo; Rec."Table No.") { }
                field(pageType; Rec."Page Type") { }
                field(pageInsert; Rec."Page Insert") { }
                field(pageUpdate; Rec."Page Update") { }
                field(pageDelete; Rec."Page Delete") { }
            }
        }
    }
}
