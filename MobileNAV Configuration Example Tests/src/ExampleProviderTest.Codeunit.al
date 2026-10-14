namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Fails when the example provider names a page, control or button function that does not
/// exist. The check reads only Business Central metadata, so it needs no MobileNAV data.
/// </summary>
codeunit 50150 "Example Provider Test"
{
    Subtype = Test;
    Access = Internal;

    /// <summary>Every declaration of the example provider resolves against the metadata.</summary>
    [Test]
    procedure ExampleProviderIsValid()
    var
        ProviderAssert: Codeunit "BJF MN Provider Assert";
    begin
        ProviderAssert.AssertProviderIsValid(Enum::"BJF MN Config Provider"::Example);
    end;
}
