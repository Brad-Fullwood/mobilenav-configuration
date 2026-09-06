namespace BradFullwood.MobileNAV.Configuration;

/// <summary>When the device reloads a page's data on its own.</summary>
enum 77792 "BJF MN Auto Refresh"
{
    Access = Public;
    Extensible = false;

    value(0; OnOpen) { Caption = 'On Open'; }
    value(1; CardOnChildUpdate) { Caption = 'Card on Child Update'; }
    value(2; ListOnChildUpdate) { Caption = 'List on Child Update'; }
    value(3; ListOnUpdate) { Caption = 'List on Update'; }
}
