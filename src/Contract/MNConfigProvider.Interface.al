namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Declarative contract for one independently versioned MobileNAV configuration provider.
/// The framework validates the provider metadata and complete definition before applying it.
/// </summary>
interface "BJF MN Config Provider"
{
    /// <summary>Returns a stable, non-localized identifier used to persist application state.</summary>
    procedure GetId(): Code[50]

    /// <summary>Returns the provider name shown to administrators.</summary>
    procedure GetName(): Text[100]

    /// <summary>Returns a concise explanation of the configuration owned by the provider.</summary>
    procedure GetDescription(): Text[250]

    /// <summary>
    /// Returns a positive schema version. Increment it whenever the declared configuration
    /// changes; previously applied versions then become outdated automatically.
    /// </summary>
    procedure GetVersion(): Integer

    /// <summary>
    /// Describes the provider's desired state through the constrained configuration builder.
    /// Providers do not execute MobileNAV configuration themselves.
    /// </summary>
    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
}
