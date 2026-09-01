
namespace BradFullwood.MobileNAV.Configuration;

enum 77781 "BJF MN Config Operation"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Operation';
    Extensible = false;

    // Ordinal 0 carries meaning here: the enum is Access = Internal and
    // Extensible = false, so no external code or table extension can land on it
    // by accident, and the value is shown to administrators.
#pragma warning disable AC0019
    value(0; "Published Page")
    {
        Caption = 'Published Page';
    }
#pragma warning restore AC0019
    value(1; Field)
    {
        Caption = 'Field';
    }
    value(2; "Linked Field")
    {
        Caption = 'Linked Field';
    }
    value(3; "Function Field")
    {
        Caption = 'Function Field';
    }
    value(4; "Scan Field")
    {
        Caption = 'Scan Field';
    }
    value(5; Staging)
    {
        Caption = 'Staging';
    }
    value(6; Stage)
    {
        Caption = 'Stage';
    }
    value(7; "Stage Field")
    {
        Caption = 'Stage Field';
    }
    value(8; "Profile Field")
    {
        Caption = 'Profile Field';
    }
    value(9; "User Scope")
    {
        Caption = 'User Scope';
    }
}
