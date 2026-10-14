namespace BradFullwood.MobileNAV.Configuration;

/// <summary>What a published page's home tile does when tapped.</summary>
enum 77787 "BJF MN Main Menu Action"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    /// <summary>Opens the page straight onto a new record.</summary>
    value(0; Create) { Caption = 'Create'; }
    #pragma warning restore AC0019
    /// <summary>Opens the single existing record.</summary>
    value(1; Open) { Caption = 'Open'; }
}
