namespace BradFullwood.MobileNAV.Configuration;

/// <summary>What a published page's home tile does when tapped.</summary>
enum 77787 "BJF MN Main Menu Action"
{
    Access = Public;
    Extensible = false;

    /// <summary>Opens the page straight onto a new record.</summary>
    value(0; Create) { Caption = 'Create'; }
    /// <summary>Opens the single existing record.</summary>
    value(1; Open) { Caption = 'Open'; }
}
