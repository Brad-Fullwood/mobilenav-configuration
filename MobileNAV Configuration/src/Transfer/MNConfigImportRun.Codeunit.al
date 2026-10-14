namespace BradFullwood.MobileNAV.Configuration;

using System.Utilities;

/// <summary>
/// Runs MobileNAV's configuration import on its own, so "BJF MN Config Transfer" can catch an
/// error through Codeunit.Run and name the backup snapshot in the message. Follows ImportConfig in
/// "MobileNAV Config Handling Func" without its confirmation and file upload: clear the device
/// login cache, import, then save the imported configuration as a new loaded snapshot.
/// </summary>
codeunit 77715 "BJF MN Config Import Run"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = r;

    trigger OnRun()
    var
        GeneralSetup: Record "MobileNAV Master Data";
        ImportedSnapshot: Record "MobileNAV Master Data";
        ConfigHandling: Codeunit "MobileNAV Config Handling Func";
        SnapshotFunctions: Codeunit "MobileNAV Config Snapshot Func";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
        ConfigTransfer: Codeunit "BJF MN Config Transfer";
        InStream: InStream;
        ImportedPartialConfig: Boolean;
    begin
        CoreFunctions.ClearLoginCache();
        this.Configuration.CreateInStream(InStream);
        ConfigHandling.ImportConfigFromStream(false, InStream, ImportedPartialConfig);
        // MobileNAV keeps a snapshot of a full import only. A partial or skin import changes the loaded configuration in place.
        if not this.FullConfiguration then
            exit;
        GeneralSetup.SetRange(Type, GeneralSetup.Type::General);
        if not GeneralSetup.FindFirst() then
            Error(this.NoGeneralSetupErr);
        GeneralSetup.CalcFields("Last Imported Config. XML");
        ConfigTransfer.WaitForFreeSnapshotCode();
        SnapshotFunctions.TakeSnapshotFromLastImported(ImportedSnapshot, GeneralSetup);
        SnapshotFunctions.ReorderSnapshots();
    end;

    /// <summary>Sets the configuration XML the next run imports.</summary>
    /// <param name="ConfigurationXml">The configuration XML.</param>
    /// <param name="IsFullConfiguration">True when the XML is a full configuration, false for a partial or skin configuration.</param>
    procedure SetConfiguration(var ConfigurationXml: Codeunit "Temp Blob"; IsFullConfiguration: Boolean)
    var
        InStream: InStream;
        OutStream: OutStream;
    begin
        ConfigurationXml.CreateInStream(InStream);
        this.Configuration.CreateOutStream(OutStream);
        CopyStream(OutStream, InStream);
        this.FullConfiguration := IsFullConfiguration;
    end;

    var
        Configuration: Codeunit "Temp Blob";
        FullConfiguration: Boolean;
        NoGeneralSetupErr: Label 'The import left no MobileNAV general setup row, so no snapshot of the imported configuration was taken.';
}
