namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A prefix the device puts in a page title, which HideTitlePrefix removes.</summary>
enum 77791 "BJF MN Title Prefix"
{
    Access = Public;
    Extensible = false;

    /// <summary>"New" in front of a record being created.</summary>
    value(0; New) { Caption = 'New'; }
    /// <summary>The page name in front of a card's title.</summary>
    value(1; PageNameOnCard) { Caption = 'Page Name on Card'; }
    /// <summary>The parent record in front of a drilled-down page's title.</summary>
    value(2; ParentOnDrillDown) { Caption = 'Parent on Drill-Down'; }
}
