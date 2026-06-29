namespace BradFullwood.MobileNAV.Configuration;

enum 77782 "BJF MN Config State"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration State';
    Extensible = false;

    value(0; "Not Applied")
    {
        Caption = 'Not Applied';
    }
    value(1; Applied)
    {
        Caption = 'Applied';
    }
    value(2; Outdated)
    {
        Caption = 'Outdated';
    }
}
