namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a property's Value text is resolved before it is written.</summary>
enum 77796 "BJF MN Property Value"
{
    Access = Internal;
    Extensible = false;

    /// <summary>Written as given.</summary>
    value(0; Literal) { Caption = 'Literal'; }
    /// <summary>A page control name, written as the name MobileNAV stores the control under.</summary>
    value(1; "Control Name") { Caption = 'Control Name'; }
    /// <summary>A page control name, written as that control's Page Line No.</summary>
    value(2; "Control Line No.") { Caption = 'Control Line No.'; }
}
