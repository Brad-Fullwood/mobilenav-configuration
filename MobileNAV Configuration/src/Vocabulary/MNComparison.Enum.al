namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a filter or condition compares. The names are MobileNAV's own comparison members.</summary>
enum 77797 "BJF MN Comparison"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; Equal) { Caption = 'Equal'; }
    #pragma warning restore AC0019
    value(1; NotEqual) { Caption = 'Not Equal'; }
    value(2; Less) { Caption = 'Less'; }
    value(3; LessOrEqual) { Caption = 'Less or Equal'; }
    value(4; Greater) { Caption = 'Greater'; }
    value(5; GreaterOrEqual) { Caption = 'Greater or Equal'; }
}
