namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// A stored build of one user's MobileNAV configuration for the device emulator. The payload holds the
/// rows that "BJF MN Emulator Config" built. The fingerprint names the MobileNAV and app state the rows
/// were built from, and the rows are reused only while the fingerprint still matches.
/// </summary>
table 77820 "BJF MN Emulator Cache"
{
    Access = Internal;
    Caption = 'MobileNAV Emulator Cache';
    DataClassification = CustomerContent;

    fields
    {
        field(1; "User ID"; Code[50])
        {
            Caption = 'User ID';
        }
        field(2; "Language Code"; Code[10])
        {
            Caption = 'Language Code';
        }
        field(3; "Profile Code"; Code[30])
        {
            Caption = 'Profile Code';
        }
        field(4; Fingerprint; Text[2048])
        {
            Caption = 'Fingerprint';
        }
        field(5; "Built At"; DateTime)
        {
            Caption = 'Built At';
        }
        field(6; "Build Duration (ms)"; Integer)
        {
            Caption = 'Build Duration (ms)';
        }
        /// <summary>The built rows as JSON, one array per row kind.</summary>
        field(7; Payload; Blob)
        {
            Caption = 'Payload';
        }
    }

    keys
    {
        key(PK; "User ID", "Language Code", "Profile Code")
        {
            Clustered = true;
        }
    }
}
