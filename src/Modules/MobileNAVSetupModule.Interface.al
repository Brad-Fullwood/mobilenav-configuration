namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// One independently registered unit of MobileNAV configuration.
/// Implement this interface and register the codeunit through an enumextension of
/// "BJF MobileNAV Setup Module".
/// </summary>
interface "BJF MobileNAV Setup Module"
{
    procedure ApplySetup()
}
