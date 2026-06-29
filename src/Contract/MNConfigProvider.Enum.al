namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Extensible registry of declarative MobileNAV configuration providers.</summary>
enum 77780 "BJF MN Config Provider" implements "BJF MN Config Provider"
{
    Caption = 'MobileNAV Configuration Provider';
    Extensible = true;
    DefaultImplementation = "BJF MN Config Provider" = "BJF Empty MN Provider";
    UnknownValueImplementation = "BJF MN Config Provider" = "BJF Empty MN Provider";

    value(0; None)
    {
        Caption = 'None';
        Implementation = "BJF MN Config Provider" = "BJF Empty MN Provider";
    }
}
