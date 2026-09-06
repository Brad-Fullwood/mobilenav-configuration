namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A standard toolbar button the device draws on a card or list, which HideButton removes.</summary>
enum 77790 "BJF MN Toolbar Button"
{
    Access = Public;
    Extensible = false;

    value(0; CardRefresh) { Caption = 'Card: Refresh'; }
    value(1; CardHideFields) { Caption = 'Card: Hide Fields'; }
    value(2; CardFlowFilters) { Caption = 'Card: Flow Filters'; }
    value(3; CardNavigate) { Caption = 'Card: Navigate'; }
    value(4; ListSort) { Caption = 'List: Sort'; }
    value(5; ListRefresh) { Caption = 'List: Refresh'; }
    value(6; ListFilter) { Caption = 'List: Filter'; }
    value(7; ListFlowFilters) { Caption = 'List: Flow Filters'; }
    value(8; ListFullScreen) { Caption = 'List: Full Screen'; }
    value(9; ListMultiSelect) { Caption = 'List: Multi-Select'; }
    value(10; ListHideFilters) { Caption = 'List: Hide Filters'; }
    value(11; LongerToolbarCaption) { Caption = 'Longer Toolbar Caption'; }
}
