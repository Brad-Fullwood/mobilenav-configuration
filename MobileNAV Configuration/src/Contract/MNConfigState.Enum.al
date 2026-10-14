
namespace BradFullwood.MobileNAV.Configuration;

enum 77782 "BJF MN Config State"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration State';
    Extensible = false;

    // Ordinal 0 carries meaning here: the enum is Access = Internal and
    // Extensible = false, so no external code or table extension can land on it
    // by accident, and the value is shown to administrators.
#pragma warning disable AC0019
    value(0; "Not Applied")
    {
        Caption = 'Not Applied';
    }
#pragma warning restore AC0019
    value(1; Applied)
    {
        Caption = 'Applied';
    }
    value(2; Outdated)
    {
        Caption = 'Outdated';
    }
}
