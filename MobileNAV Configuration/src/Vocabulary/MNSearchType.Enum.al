namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a saved filter matches a field. The names are MobileNAV's own Search Type members.</summary>
enum 77764 "BJF MN Search Type"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; BeginMatch) { Caption = 'Begins With'; }
    #pragma warning restore AC0019
    value(1; Equal) { Caption = 'Matches Whole Word'; }
    value(2; AnyMatch) { Caption = 'Contains'; }
}
