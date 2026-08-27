namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Declarative contract for one independently versioned MobileNAV configuration provider.
/// The framework validates the provider metadata and complete definition before applying it.
/// </summary>
interface "BJF MN Config Provider"
{
    /// <summary>Returns a stable, non-localized identifier used to persist application state.</summary>
    /// <returns>The stable, non-localized provider identifier.</returns>
    procedure GetId(): Code[50]

    /// <summary>Returns the provider name shown to administrators.</summary>
    /// <returns>The provider name shown to administrators.</returns>
    procedure GetName(): Text[100]

    /// <summary>Returns a concise explanation of the configuration owned by the provider.</summary>
    /// <returns>A concise explanation of the configuration owned by the provider.</returns>
    procedure GetDescription(): Text[250]

    /// <summary>
    /// Returns a positive schema version. Increment it whenever the declared configuration
    /// changes; previously applied versions then become outdated automatically.
    /// </summary>
    /// <returns>The positive schema version currently declared by the provider.</returns>
    procedure GetVersion(): Integer

    /// <summary>
    /// Describes the provider's desired state through the constrained configuration builder.
    /// Providers do not execute MobileNAV configuration themselves.
    /// </summary>
    /// <param name="Configuration">The configuration builder that records the provider's desired state.</param>
    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
}
