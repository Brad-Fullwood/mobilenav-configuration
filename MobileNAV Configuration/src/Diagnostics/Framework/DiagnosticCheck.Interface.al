namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// A single diagnostic check. To add a check: create a codeunit implementing this interface,
/// then register it as a value of enum "BJF Diagnostic Check Type". The enum is extensible,
/// so other apps can contribute checks through an enumextension without touching this app.
/// </summary>
interface "BJF Diagnostic Check"
{
    /// <summary>Runs the check and records any findings via Finding.Add() / Finding.AddWithFix().</summary>
    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")

    /// <summary>
    /// Applies the automatic fix for a finding this check recorded with AddWithFix().
    /// Called per selected finding from the findings list; only invoked when Finding.Fixable is true.
    /// Checks without automatic fixes should raise an error.
    /// </summary>
    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
}
