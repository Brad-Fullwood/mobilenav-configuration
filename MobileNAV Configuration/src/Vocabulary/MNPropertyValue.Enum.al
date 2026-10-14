namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a property's Value text is resolved before it is written.</summary>
enum 77796 "BJF MN Property Value"
{
    Access = Internal;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    /// <summary>Written as given.</summary>
    value(0; Literal) { Caption = 'Literal'; }
    #pragma warning restore AC0019
    /// <summary>A page control name, written as the name MobileNAV stores the control under.</summary>
    value(1; "Control Name") { Caption = 'Control Name'; }
    /// <summary>A page control name, written as that control's Page Line No.</summary>
    value(2; "Control Line No.") { Caption = 'Control Line No.'; }
}
