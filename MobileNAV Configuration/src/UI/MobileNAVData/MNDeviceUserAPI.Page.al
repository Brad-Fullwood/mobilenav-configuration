namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Warehouse.Setup;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// Creates a MobileNAV device user from the API: the MobileNAV User Setup row and, when profileCode
/// is given, the user's profile row. A test device (the harness or the emulator) signs in as an
/// administrator who has no device user in a copied sandbox, and MobileNAV refuses the logon with
/// "There is no user setup defined". MobileNAV's User Setup and User Profile pages do the same insert
/// from the web client. A user that exists already is kept, and only a missing profile row is added.
/// When locationCode is given, the user also becomes a warehouse employee for that location (the
/// standard Warehouse Employee row), because MobileNAV lists a warehouse document only for a location
/// the user may view (WMS Management.LocationIsAllowedToView).
/// </summary>
page 77835 "BJF MN Device User API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Device User';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Device User';
    EntityName = 'deviceUser';
    EntitySetCaption = 'MobileNAV Device Users';
    EntitySetName = 'deviceUsers';
    Extensible = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    Permissions = tabledata "MobileNAV Profile Setup" = ri,
        tabledata "MobileNAV User Setup" = ri,
        tabledata "Warehouse Employee" = ri;
    SourceTable = "MobileNAV User Setup";

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { }
                field(userId; Rec."User ID") { }
                field(profileCode; this.ProfileCode) { }
                field(locationCode; this.LocationCode) { }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        UserSetup: Record "MobileNAV User Setup";
    begin
        if not UserSetup.Get(Rec."User ID") then begin
            UserSetup.Init();
            UserSetup.Validate("User ID", Rec."User ID");
            UserSetup.Insert(true);
        end;
        if this.ProfileCode <> '' then
            this.EnsureUserProfile(UserSetup."User ID", this.ProfileCode);
        if this.LocationCode <> '' then
            this.EnsureWarehouseEmployee(UserSetup."User ID", this.LocationCode);
        Rec := UserSetup;
        exit(false);
    end;

    local procedure EnsureUserProfile(DeviceUserId: Code[50]; Profile: Code[30])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
    begin
        ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
        ProfileSetup.SetRange(ID, DeviceUserId);
        ProfileSetup.SetRange(Profile, Profile);
        if not ProfileSetup.IsEmpty() then
            exit;
        ProfileSetup.Init();
        ProfileSetup.Validate("Profile Type", ProfileSetup."Profile Type"::User);
        ProfileSetup.Validate(ID, DeviceUserId);
        ProfileSetup.Validate(Profile, Profile);
        ProfileSetup.Insert(true);
    end;

    local procedure EnsureWarehouseEmployee(DeviceUserId: Code[50]; Location: Code[10])
    var
        WarehouseEmployee: Record "Warehouse Employee";
    begin
        if WarehouseEmployee.Get(DeviceUserId, Location) then
            exit;
        WarehouseEmployee.Init();
        WarehouseEmployee.Validate("User ID", DeviceUserId);
        WarehouseEmployee.Validate("Location Code", Location);
        WarehouseEmployee.Insert(true);
    end;

    var
        LocationCode: Code[10];
        ProfileCode: Code[30];
}
#pragma warning restore LC0063
