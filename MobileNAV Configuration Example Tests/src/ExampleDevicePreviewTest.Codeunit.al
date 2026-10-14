namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Draws the example provider's device pages through "BJF MN Screen Renderer" and checks the
/// drawing holds the item page's note and reorder button and the stock count's two wizard
/// stages. The renderer reads MobileNAV's live rows when they exist and draws from the
/// definition alone when they do not, so the test needs no MobileNAV data.
/// </summary>
codeunit 50153 "Example Device Preview Test"
{
    Subtype = Test;
    Access = Internal;

    /// <summary>The drawing of the example provider names its controls and its wizard stages.</summary>
    [Test]
    procedure ExampleProviderDrawsControlsAndStages()
    var
        ScreenRenderer: Codeunit "BJF MN Screen Renderer";
        Html: Text;
    begin
        Html := ScreenRenderer.Render(Enum::"BJF MN Config Provider"::Example, this.EnglishTok);

        this.AssertContains(Html, this.NotesControlTok);
        this.AssertContains(Html, this.ReorderButtonTok);
        this.AssertContains(Html, this.ScanStageCaptionTok);
        this.AssertContains(Html, this.CountStageCaptionTok);
    end;

    local procedure AssertContains(Html: Text; Expected: Text)
    begin
        if not Html.Contains(Expected) then
            Error(this.MissingErr, Expected);
    end;

    var
        EnglishTok: Label 'ENU', Locked = true;
        NotesControlTok: Label 'ExampleNotes', Locked = true;
        ReorderButtonTok: Label 'ExampleFlagReorder', Locked = true;
        // The stage captions of the example provider in English; the test runs in an English session.
        ScanStageCaptionTok: Label 'Scan the item', Locked = true;
        CountStageCaptionTok: Label 'Count it', Locked = true;
        MissingErr: Label 'The device preview does not contain "%1".', Comment = '%1 = expected text';
}
