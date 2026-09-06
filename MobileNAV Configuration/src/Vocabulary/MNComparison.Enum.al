namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a filter or condition compares. The names are MobileNAV's own comparison members.</summary>
enum 77797 "BJF MN Comparison"
{
    Access = Public;
    Extensible = false;

    value(0; Equal) { Caption = 'Equal'; }
    value(1; NotEqual) { Caption = 'Not Equal'; }
    value(2; Less) { Caption = 'Less'; }
    value(3; LessOrEqual) { Caption = 'Less or Equal'; }
    value(4; Greater) { Caption = 'Greater'; }
    value(5; GreaterOrEqual) { Caption = 'Greater or Equal'; }
}
