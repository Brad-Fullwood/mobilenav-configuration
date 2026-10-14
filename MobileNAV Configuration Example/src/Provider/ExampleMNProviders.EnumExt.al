namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;

/// <summary>Registers the provider so the framework lists and applies it.</summary>
enumextension 50100 "Example MN Providers" extends "BJF MN Config Provider"
{
    value(50100; Example)
    {
        Caption = 'MobileNAV Configuration Example';
        Implementation = "BJF MN Config Provider" = "Example MN Provider";
    }
}
