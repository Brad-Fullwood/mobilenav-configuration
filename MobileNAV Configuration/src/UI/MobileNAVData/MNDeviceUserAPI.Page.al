namespace BradFullwood.MobileNAV.Configuration;

#pragma warning disable LC0063 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// Creates a MobileNAV device user from the API: the MobileNAV User Setup row and, when profileCode
/// is given, the user's profile row. A test device (the harness or the emulator) signs in as an
/// administrator who has no device user in a copied sandbox, and MobileNAV refuses the logon with
/// "There is no user setup defined". MobileNAV's User Setup and User Profile pages do the same insert
/// from the web client. A user that exists already is kept, and only a missing profile row is added.
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
        tabledata "MobileNAV User Setup" = ri;
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

    var
        ProfileCode: Code[30];
}
#pragma warning restore LC0063
