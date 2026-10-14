namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// MobileNAV's master data, read-only: profiles, menu categories and the general setup row
/// (device activation, testing mode, configuration version). Filter on type.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/masterData.
/// </summary>
page 77795 "BJF MN Master Data API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Master Data';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Master Data';
    EntityName = 'masterDataEntry';
    EntitySetCaption = 'MobileNAV Master Data';
    EntitySetName = 'masterData';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Master Data" = r;
    SourceTable = "MobileNAV Master Data";

    layout
    {
        area(Content)
        {
            repeater(Entries)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(type; Rec.Type) { }
                field("code"; Rec."Code") { }
                field(description; Rec.Description) { }
                field(order; Rec."Order") { }
                field(autoDeviceActivation; Rec."Auto. Device Activation") { }
                field(testingMode; Rec."Testing Mode") { }
                field(configVersion; Rec.ConfigVersion) { }
                field(lastKnownAddOnVersion; Rec."Last Known AddOn Version") { }
                field(baseConfig; Rec."Base Config") { }
            }
        }
    }
}
