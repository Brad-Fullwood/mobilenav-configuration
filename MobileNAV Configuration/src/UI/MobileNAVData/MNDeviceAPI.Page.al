namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// MobileNAV's licence rows, read-only: every registered device and user licence with its
/// status (Standby, Active, Rejected, Support) and last login, which is where to look when a
/// device cannot log in because the licence is full. Filter on type eq 'Device' and status.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/devices.
/// </summary>
page 77796 "BJF MN Device API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Device';
    DataAccessIntent = ReadOnly;
    Editable = false;
    EntityCaption = 'MobileNAV Device';
    EntityName = 'device';
    EntitySetCaption = 'MobileNAV Devices';
    EntitySetName = 'devices';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV License Setup" = r;
    SourceTable = "MobileNAV License Setup";

    layout
    {
        area(Content)
        {
            repeater(Devices)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(deviceId; Rec."Device ID") { }
                field(userId; Rec."User ID") { }
                field(type; Rec.Type) { }
                field(status; Rec.Status) { }
                field(description; Rec.Description) { }
                field(company; Rec.Company) { }
                field(creationDate; Rec."Creation Date") { }
                field(lastLoginDate; Rec."Last Login Date") { }
                field(lastLogoutDate; Rec."Last Logout Date") { }
                field(configurationChanged; Rec."Configuration Changed") { }
                field(currentLanguageCode; Rec."Current Language Code") { }
            }
        }
    }
}
