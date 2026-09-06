namespace BradFullwood.MobileNAV.Showcase;

using BradFullwood.MobileNAV.Configuration;

/// <summary>Registers the provider so the framework lists and applies it.</summary>
enumextension 50100 "Showcase MN Providers" extends "BJF MN Config Provider"
{
    value(50100; Showcase)
    {
        Caption = 'MobileNAV Configuration Showcase';
        Implementation = "BJF MN Config Provider" = "Showcase MN Provider";
    }
}
