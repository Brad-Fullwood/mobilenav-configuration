namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The contract a configuration provider implements. A provider names itself and declares what
/// MobileNAV devices should show through the fluent builder; the framework validates the
/// definition, applies it, and tracks — by fingerprinting the definition — whether what is
/// applied still matches what is declared. Register the implementation with an enumextension
/// of "BJF MN Config Provider".
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
    /// Declares the provider's desired state through the fluent builder. Declare only; the
    /// framework applies. The definition is rebuilt whenever its state is inspected, so it must
    /// be deterministic and free of side effects.
    /// </summary>
    /// <param name="Configuration">The builder that records the provider's desired state.</param>
    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
}
