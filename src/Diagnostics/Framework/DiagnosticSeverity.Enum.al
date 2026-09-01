namespace BradFullwood.MobileNAV.Configuration;

enum 77763 "BJF Diagnostic Severity"
{
    Access = Public;
    Caption = 'Diagnostic Severity';
    Extensible = false;

    value(0; Blocker)
    {
        Caption = 'Blocker';
    }
    value(1; Warning)
    {
        Caption = 'Warning';
    }
    value(2; Info)
    {
        Caption = 'Info';
    }
}
