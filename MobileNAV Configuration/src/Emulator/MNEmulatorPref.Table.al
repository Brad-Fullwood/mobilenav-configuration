namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The device emulator choices of one signed-in Business Central user: the user whose screens were drawn last, the
/// language and the profile. The emulator page restores them when it opens. One row per signed-in user.
/// </summary>
table 77830 "BJF MN Emulator Pref"
{
    Access = Internal;
    Caption = 'MobileNAV Emulator Preference';
    DataClassification = EndUserIdentifiableInformation;
    Permissions = tabledata "BJF MN Emulator Pref" = rim;

    fields
    {
        field(1; "Signed-in User ID"; Code[50])
        {
            Caption = 'Signed-in User ID';
            NotBlank = true;
        }
        field(2; "Emulated User ID"; Code[50])
        {
            Caption = 'Emulated User ID';
            ToolTip = 'Specifies the Business Central user whose MobileNAV main menu the emulator drew last.';
        }
        field(3; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
            ToolTip = 'Specifies the MobileNAV language code the emulator drew the captions in last.';
        }
        field(4; "Profile Code"; Code[30])
        {
            Caption = 'Profile Code';
            ToolTip = 'Specifies the MobileNAV profile the emulator drew last. Blank means the profiles of the user.';
        }
    }

    keys
    {
        key(PK; "Signed-in User ID")
        {
            Clustered = true;
        }
    }

    /// <summary>Stores the choices of the signed-in user. Creates the row on the first save.</summary>
    /// <param name="EmulatedUserId">The Business Central user whose screens the emulator draws.</param>
    /// <param name="LanguageValue">The MobileNAV language code of the captions.</param>
    /// <param name="ProfileValue">The MobileNAV profile, or blank.</param>
    procedure Remember(EmulatedUserId: Code[50]; LanguageValue: Code[10]; ProfileValue: Code[30])
    var
        SignedInUserId: Code[50];
    begin
        SignedInUserId := CopyStr(UserId(), 1, MaxStrLen(SignedInUserId));
        if not Rec.Get(SignedInUserId) then begin
            Rec.Init();
            Rec.Validate("Signed-in User ID", SignedInUserId);
            Rec.Insert(false);
        end;
        Rec.Validate("Emulated User ID", EmulatedUserId);
        Rec.Validate("Language Code", LanguageValue);
        Rec.Validate("Profile Code", ProfileValue);
        Rec.Modify(false);
    end;

    /// <summary>Reads the choices stored for the signed-in user.</summary>
    /// <returns>True when the signed-in user has stored choices.</returns>
    procedure Restore(): Boolean
    var
        SignedInUserId: Code[50];
    begin
        SignedInUserId := CopyStr(UserId(), 1, MaxStrLen(SignedInUserId));
        exit(Rec.Get(SignedInUserId));
    end;
}
