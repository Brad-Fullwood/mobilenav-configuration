namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Which "assigned to me" views a list offers. The names are MobileNAV's own Mine Filter Type members.</summary>
enum 77793 "BJF MN Mine Filter"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; MineAll) { Caption = 'Mine and All'; }
    #pragma warning restore AC0019
    value(1; MineUnassigned) { Caption = 'Mine and Unassigned'; }
    value(2; MineUnassignedAll) { Caption = 'Mine and Unassigned and All'; }
    value(3; MineOnly) { Caption = 'Mine Only'; }
    value(4; MineUnassignedOnly) { Caption = 'Mine and Unassigned Only'; }
}
