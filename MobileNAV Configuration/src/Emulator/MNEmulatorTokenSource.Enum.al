namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Where the emulator gets the delegated token its page service calls are sent with.</summary>
enum 77701 "BJF MN Emulator Token Source"
{
    Access = Internal;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 is the default token source.
    value(0; AppRegistration) { Caption = 'App Registration'; }
    #pragma warning restore AC0019
    value(1; MobileNAVToken) { Caption = 'MobileNAV Token'; }
    value(2; SuppliedToken) { Caption = 'Supplied Token'; }
}
