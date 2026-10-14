namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How serious a diagnostic finding is. Blocker breaks a device flow, Warning needs attention, Info is for the record.</summary>
enum 77763 "BJF Diagnostic Severity"
{
    Access = Public;
    Caption = 'Diagnostic Severity';
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 is Blocker. Renumbering would change the stored value of existing findings.
    value(0; Blocker)
    {
        Caption = 'Blocker';
    }
    #pragma warning restore AC0019
    value(1; Warning)
    {
        Caption = 'Warning';
    }
    value(2; Info)
    {
        Caption = 'Info';
    }
}
