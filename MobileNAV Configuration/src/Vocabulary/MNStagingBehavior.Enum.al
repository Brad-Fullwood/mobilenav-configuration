namespace BradFullwood.MobileNAV.Configuration;

/// <summary>How a wizard page restarts between records.</summary>
enum 77788 "BJF MN Staging Behavior"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    /// <summary>Restarts the wizard on every record.</summary>
    value(0; Always) { Caption = 'Always'; }
    #pragma warning restore AC0019
    /// <summary>Stages only while a record is being created.</summary>
    value(1; CreationOnly) { Caption = 'Creation Only'; }
    /// <summary>Resumes a part-finished wizard.</summary>
    value(2; PersistState) { Caption = 'Persist State'; }
}
