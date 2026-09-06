namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Where a page filter applies. The names are MobileNAV's own Filter Scope members.</summary>
enum 77798 "BJF MN Filter Scope"
{
    Access = Public;
    Extensible = false;

    value(0; Online) { Caption = 'Online'; }
    value(1; Offline) { Caption = 'Offline'; }
    value(2; Both) { Caption = 'Both'; }
}
