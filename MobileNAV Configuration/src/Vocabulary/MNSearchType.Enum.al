namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a saved filter matches a field. The names are MobileNAV's own Search Type members.</summary>
enum 77764 "BJF MN Search Type"
{
    Access = Public;
    Extensible = false;

    value(0; BeginMatch) { Caption = 'Begins With'; }
    value(1; Equal) { Caption = 'Matches Whole Word'; }
    value(2; AnyMatch) { Caption = 'Contains'; }
}
