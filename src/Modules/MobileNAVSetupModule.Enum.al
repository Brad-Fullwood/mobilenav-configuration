namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Extensible registry of MobileNAV setup modules supplied by consuming extensions.
/// </summary>
enum 77780 "BJF MobileNAV Setup Module" implements "BJF MobileNAV Setup Module"
{
    Caption = 'MobileNAV Setup Module';
    Extensible = true;
    DefaultImplementation = "BJF MobileNAV Setup Module" = "BJF Empty MN Setup Module";
    UnknownValueImplementation = "BJF MobileNAV Setup Module" = "BJF Empty MN Setup Module";

    value(0; None)
    {
        Caption = 'None';
        Implementation = "BJF MobileNAV Setup Module" = "BJF Empty MN Setup Module";
    }
}
