namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Runs an apply and then fails on purpose, so the database rolls back everything the apply
/// wrote. Commits inside the apply are ignored, so nothing it does survives. Run it with
/// Codeunit.Run from "BJF MN Config Preview".
/// </summary>
codeunit 77711 "BJF MN Config Preview Run"
{
    Access = Internal;

    trigger OnRun()
    begin
        this.RunPreview();
    end;

    procedure SetProvider(NewProviderType: Enum "BJF MN Config Provider")
    begin
        this.ProviderType := NewProviderType;
    end;

    /// <summary>The error text that ends a preview which ran to the end.</summary>
    /// <returns>The marker text.</returns>
    procedure CompletedMarker(): Text
    begin
        exit(this.PreviewCompletedTok);
    end;

    [CommitBehavior(CommitBehavior::Ignore)]
    local procedure RunPreview()
    var
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        Recorder: Codeunit "BJF MN Preview Recorder";
    begin
        ConfigurationApplication.PreviewProvider(this.ProviderType);
        Recorder.Finish();
        Error(this.PreviewCompletedTok);
    end;

    var
        ProviderType: Enum "BJF MN Config Provider";
        PreviewCompletedTok: Label 'BJF MN preview completed. Rolling back.', Locked = true;
}
