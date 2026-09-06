namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Where the device places the "assign to me" control. The names are MobileNAV's own members.</summary>
enum 77794 "BJF MN Assign To Me"
{
    Access = Public;
    Extensible = false;

    value(0; Hide) { Caption = 'Hidden'; }
    value(1; ViewSettings) { Caption = 'View Settings'; }
    value(2; ToolbarAdditional) { Caption = 'Additional Toolbar'; }
    value(3; ToolbarStandard) { Caption = 'Standard Toolbar'; }
}
