namespace BradFullwood.MobileNAV.Configuration;

using System.Environment;
using System.Utilities;

/// <summary>
/// The one row of emulator setup: the Entra app registration, the token source and the write switches.
/// The client secret is not a field. It is kept in isolated storage, and only the setup procedures read it.
/// </summary>
table 77701 "BJF MN Emulator Setup"
{
    Access = Internal;
    Caption = 'MobileNAV Emulator Setup';
    DataClassification = CustomerContent;
    Permissions = tabledata "BJF MN Emulator Setup" = ri;

    fields
    {
        field(1; "Primary Key"; Code[10])
        {
            AllowInCustomizations = Never;
            Caption = 'Primary Key';
            DataClassification = SystemMetadata;
            NotBlank = true;
        }
        field(2; "Client ID"; Text[100])
        {
            Caption = 'Client ID';
            ToolTip = 'Specifies the application (client) ID of the Microsoft Entra app registration.';
        }
        field(3; "Token Source"; Enum "BJF MN Emulator Token Source")
        {
            Caption = 'Token Source';
            ToolTip = 'Specifies whether the emulator signs in with the app registration below, or reuses the token MobileNAV stored for the signed-in user.';
        }
        field(4; "Allow Writes"; Boolean)
        {
            Caption = 'Allow Writes';
            ToolTip = 'Specifies whether the emulator may change data through the real page services. Outside a sandbox, turn on Allow Writes in Production first.';

            trigger OnValidate()
            var
                EnvironmentInformation: Codeunit "Environment Information";
            begin
                if not Rec."Allow Writes" then
                    exit;
                if EnvironmentInformation.IsSandbox() or Rec."Allow Writes in Production" then
                    exit;
                Error(this.WritesNeedProductionFlagErr);
            end;
        }
        field(5; "Allow Writes in Production"; Boolean)
        {
            Caption = 'Allow Writes in Production';
            ToolTip = 'Specifies whether writes may run in a production environment. Writes post real documents.';

            trigger OnValidate()
            var
                EnvironmentInformation: Codeunit "Environment Information";
                ConfirmManagement: Codeunit "Confirm Management";
            begin
                if not Rec."Allow Writes in Production" then
                    exit;
                if EnvironmentInformation.IsSandbox() then
                    exit;
                if not ConfirmManagement.GetResponseOrDefault(this.ConfirmProductionWritesQst, false) then
                    Rec."Allow Writes in Production" := false;
            end;
        }
        field(6; "Device ID"; Text[50])
        {
            Caption = 'Device ID';
            InitValue = 'BJF-EMULATOR';
            ToolTip = 'Specifies the device ID the emulator reports to MobileNAV. Its default is BJF-EMULATOR.';
        }
    }

    keys
    {
        key(PK; "Primary Key")
        {
            Clustered = true;
        }
    }

    var
        SecretKeyTok: Label 'BJF-MN-EMU-SECRET', Locked = true;
        SetupKeyTok: Label 'SETUP', Locked = true;
        WritesNeedProductionFlagErr: Label 'Writes post real documents, and this environment is not a sandbox. Turn on Allow Writes in Production first, then turn on Allow Writes.';
        ConfirmProductionWritesQst: Label 'Writes from the emulator change real data in this production environment. Do you want to continue?';

    /// <summary>Gets the setup row. Creates it with the default device ID when it does not exist yet.</summary>
    procedure GetSetup()
    begin
        if Rec.Get(this.SetupKeyTok) then
            exit;
        Rec.Init();
        Rec.Validate("Primary Key", this.SetupKeyTok);
        Rec.Insert(false);
    end;

    /// <summary>Stores the client secret in isolated storage, scoped to this extension.</summary>
    /// <param name="Secret">The client secret of the Entra app registration.</param>
    [NonDebuggable]
    procedure SetClientSecret(Secret: SecretText)
    begin
        IsolatedStorage.Set(this.SecretKeyTok, Secret, DataScope::Module);
    end;

    /// <summary>Reads the client secret from isolated storage.</summary>
    /// <returns>The client secret, or an empty secret when none is stored.</returns>
    [NonDebuggable]
    procedure GetClientSecret(): SecretText
    var
        Secret: SecretText;
    begin
        IsolatedStorage.Get(this.SecretKeyTok, DataScope::Module, Secret);
        exit(Secret);
    end;

    /// <summary>Tells whether a client secret is stored. The secret itself is not read.</summary>
    /// <returns>True when a client secret is stored.</returns>
    procedure HasClientSecret(): Boolean
    begin
        exit(IsolatedStorage.Contains(this.SecretKeyTok, DataScope::Module));
    end;

    /// <summary>Tells whether emulated writes may run now: writes are switched on and this is a sandbox, or production writes are allowed.</summary>
    /// <returns>True when a write may be sent to the tenant's page services.</returns>
    procedure WritesAllowed(): Boolean
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        exit(Rec."Allow Writes" and (EnvironmentInformation.IsSandbox() or Rec."Allow Writes in Production"));
    end;
}
