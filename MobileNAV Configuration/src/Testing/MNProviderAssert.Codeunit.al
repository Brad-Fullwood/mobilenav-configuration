namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Checks a provider in a unit test. The check builds the provider's definition and compares it
/// with Business Central metadata: every page and codeunit id exists, every control name is a
/// control of its page or a field of the page's source table, every button function exists, the
/// builder's modifier rules hold, and every published page can be reached on the device. It reads
/// no MobileNAV table, so the test runs in a container without MobileNAV data. Control names are
/// checked only where the session can read Page Control Field, which a Business Central online
/// license does not grant to every user.
///
///   [Test]
///   procedure ProviderIsValid()
///   var
///       ProviderAssert: Codeunit "BJF MN Provider Assert";
///   begin
///       ProviderAssert.AssertProviderIsValid(Enum::"BJF MN Config Provider"::"Your Provider");
///   end;
/// </summary>
codeunit 77737 "BJF MN Provider Assert"
{
    Access = Public;

    /// <summary>Whether the provider's declaration matches the Business Central metadata.</summary>
    /// <param name="ProviderType">The provider to check.</param>
    /// <returns>True when no problem was found.</returns>
    procedure ProviderIsValid(ProviderType: Enum "BJF MN Config Provider"): Boolean
    var
        Problems: List of [Text];
    begin
        exit(this.ProviderIsValid(ProviderType, Problems));
    end;

    /// <summary>Whether the provider's declaration matches the Business Central metadata, with the problems found.</summary>
    /// <param name="ProviderType">The provider to check.</param>
    /// <param name="Errors">Returns one message per problem, empty when the provider is valid.</param>
    /// <returns>True when no problem was found.</returns>
    procedure ProviderIsValid(ProviderType: Enum "BJF MN Config Provider"; var Errors: List of [Text]): Boolean
    var
        MetadataValidator: Codeunit "BJF MN Metadata Validator";
    begin
        MetadataValidator.Collect(ProviderType, Errors);
        exit(Errors.Count() = 0);
    end;

    /// <summary>Raises an error that lists every problem found in the provider's declaration.</summary>
    /// <param name="ProviderType">The provider to check.</param>
    procedure AssertProviderIsValid(ProviderType: Enum "BJF MN Config Provider")
    var
        Errors: List of [Text];
        Message: TextBuilder;
        Problem: Text;
    begin
        if this.ProviderIsValid(ProviderType, Errors) then
            exit;
        Message.AppendLine(StrSubstNo(this.ProviderInvalidErr, ProviderType, Errors.Count()));
        foreach Problem in Errors do
            Message.AppendLine(StrSubstNo(this.ProblemLineTok, Problem));
        Error(ErrorInfo.Create(Message.ToText().TrimEnd()));
    end;

    var
        ProviderInvalidErr: Label 'Provider %1 has %2 problem(s):', Comment = '%1 = provider enum value, %2 = number of problems';
        ProblemLineTok: Label '- %1', Locked = true;
}
