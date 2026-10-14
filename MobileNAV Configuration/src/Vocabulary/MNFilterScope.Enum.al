namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Where a page filter applies. The names are MobileNAV's own Filter Scope members.</summary>
enum 77798 "BJF MN Filter Scope"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; Online) { Caption = 'Online'; }
    #pragma warning restore AC0019
    value(1; Offline) { Caption = 'Offline'; }
    value(2; Both) { Caption = 'Both'; }
}
