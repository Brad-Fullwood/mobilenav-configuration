namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Shows what applying a provider would change, without changing it. The apply runs in full,
/// including MobileNAV's own triggers, and is then rolled back. The changes it made to MobileNAV's
/// tables and web services are kept in "BJF MN Preview Line". The device handover is skipped.
/// While it runs, the preview locks the MobileNAV rows it changes, as an apply does.
/// </summary>
codeunit 77710 "BJF MN Config Preview"
{
    Access = Internal;

    /// <summary>Previews the provider and stores the result, replacing its previous preview.</summary>
    /// <param name="ProviderType">The provider to preview.</param>
    /// <returns>The number of preview lines stored.</returns>
    procedure Preview(ProviderType: Enum "BJF MN Config Provider"): Integer
    var
        Recorder: Codeunit "BJF MN Preview Recorder";
        Subscribers: Codeunit "BJF MN Preview Subscribers";
        PreviewRun: Codeunit "BJF MN Config Preview Run";
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ErrorText: Text;
    begin
        this.ProviderCatalog.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        Recorder.Start();
        BindSubscription(Subscribers);
        PreviewRun.SetProvider(ProviderType);
        Commit(); // Codeunit.Run with a return value needs a committed transaction.
        ClearLastError();
        if PreviewRun.Run() then
            ErrorText := this.NotRolledBackErr
        else
            ErrorText := GetLastErrorText();
        UnbindSubscription(Subscribers);
        Recorder.Stop();
        if ErrorText <> PreviewRun.CompletedMarker() then
            Recorder.AddError(ErrorText);
        exit(Recorder.SaveAs(ProviderId));
    end;

    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        NotRolledBackErr: Label 'The preview finished without rolling back. Check the provider''s rows with the Doctor.';
}
