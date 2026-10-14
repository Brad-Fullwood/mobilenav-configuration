namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Where the device places the "assign to me" control. The names are MobileNAV's own members.</summary>
enum 77794 "BJF MN Assign To Me"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; Hide) { Caption = 'Hidden'; }
    #pragma warning restore AC0019
    value(1; ViewSettings) { Caption = 'View Settings'; }
    value(2; ToolbarAdditional) { Caption = 'Additional Toolbar'; }
    value(3; ToolbarStandard) { Caption = 'Standard Toolbar'; }
}
