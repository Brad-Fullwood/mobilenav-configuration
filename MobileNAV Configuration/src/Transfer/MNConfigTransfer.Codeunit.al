namespace BradFullwood.MobileNAV.Configuration;

using System.Text;
using System.Utilities;

/// <summary>
/// Takes, reads and imports MobileNAV configuration snapshots without a client, for the
/// configSnapshots, configSnapshotContents and configImports API pages. It calls MobileNAV's own
/// snapshot and import routines and avoids the ones that ask the user something: the Config
/// Snapshot List page's Export Snapshot asks for a description, and its Import Custom
/// Configuration confirms the change and opens a file dialog.
/// </summary>
codeunit 77714 "BJF MN Config Transfer"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = rm;

    /// <summary>
    /// Takes a snapshot of the current configuration, as Take Snapshot on the Config Snapshot List
    /// page does, and gives it the description.
    /// </summary>
    /// <param name="Description">The snapshot's description; empty keeps MobileNAV's default, the creation time.</param>
    /// <param name="Snapshot">Returns the new snapshot.</param>
    procedure TakeSnapshot(Description: Text; var Snapshot: Record "MobileNAV Master Data")
    var
        SnapshotFunctions: Codeunit "MobileNAV Config Snapshot Func";
    begin
        this.WaitForFreeSnapshotCode();
        // Without a client MobileNAV skips its description prompt and always inserts a new snapshot,
        // which becomes the loaded one.
        SnapshotFunctions.TakeSnapshot(Snapshot);
        if not SnapshotFunctions.GetLoadedSnapshot(Snapshot) then
            Error(this.SnapshotNotTakenErr);
        if Description <> '' then
            this.SetDescription(Snapshot, Description);
        SnapshotFunctions.ReorderSnapshots();
        if not Snapshot.Find() then
            Error(this.SnapshotNotTakenErr);
    end;

    /// <summary>The snapshot's configuration XML, base64 encoded, exactly as MobileNAV stored it.</summary>
    /// <param name="Snapshot">The snapshot to read.</param>
    /// <returns>The base64 text, or empty when the snapshot has no XML.</returns>
    procedure SnapshotXmlBase64(var Snapshot: Record "MobileNAV Master Data"): Text
    var
        Base64Convert: Codeunit "Base64 Convert";
        InStream: InStream;
    begin
        Snapshot.CalcFields("Last Imported Config. XML");
        if not Snapshot."Last Imported Config. XML".HasValue() then
            exit('');
        Snapshot."Last Imported Config. XML".CreateInStream(InStream);
        exit(Base64Convert.ToBase64(InStream));
    end;

    /// <summary>
    /// Imports a configuration XML as a custom configuration, with the effect of Import Custom
    /// Configuration on the Config Snapshot List page. A snapshot of the current configuration is
    /// taken and committed first, so a failed or unwanted import can be undone with Load Snapshot.
    /// </summary>
    /// <param name="ConfigXmlBase64">The configuration XML, base64 encoded, as MobileNAV exports it.</param>
    /// <param name="ConfigImport">Returns the backup snapshot, the snapshot of the imported configuration and the XML's kind and description.</param>
    procedure ImportConfiguration(ConfigXmlBase64: Text; var ConfigImport: Record "BJF MN Config Import" temporary)
    var
        BackupSnapshot: Record "MobileNAV Master Data";
        ImportedSnapshot: Record "MobileNAV Master Data";
        SnapshotFunctions: Codeunit "MobileNAV Config Snapshot Func";
        ImportRun: Codeunit "BJF MN Config Import Run";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        OutStream: OutStream;
    begin
        if ConfigXmlBase64 = '' then
            Error(this.NoConfigurationErr);
        TempBlob.CreateOutStream(OutStream);
        Base64Convert.FromBase64(ConfigXmlBase64, OutStream);
        this.ReadConfigInfo(TempBlob, ConfigImport);
        this.CheckImportAllowed();

        this.TakeSnapshot(StrSubstNo(this.BackupDescriptionLbl, Format(CurrentDateTime())), BackupSnapshot);
        ConfigImport.Validate("Backup Snapshot Code", BackupSnapshot.Code);
        Commit(); // Keeps the backup when the import fails. MobileNAV commits partway through an import as well.

        ImportRun.SetConfiguration(TempBlob, ConfigImport."Config Kind" = this.FullKindTok);
        if not ImportRun.Run() then
            Error(this.ImportFailedErr, GetLastErrorText(), BackupSnapshot.Code);

        if (ConfigImport."Config Kind" = this.FullKindTok) and SnapshotFunctions.GetLoadedSnapshot(ImportedSnapshot) then
            ConfigImport.Validate("Imported Snapshot Code", ImportedSnapshot.Code);
        ConfigImport.Validate("Imported At", CurrentDateTime());
        ConfigImport.Validate("Imported By", CopyStr(UserId(), 1, MaxStrLen(ConfigImport."Imported By")));
    end;

    /// <summary>
    /// MobileNAV names a snapshot after the second it was taken, so a second snapshot in the same
    /// second fails on a duplicate key. Waits for the next second when the current name is taken.
    /// </summary>
    procedure WaitForFreeSnapshotCode()
    var
        Snapshot: Record "MobileNAV Master Data";
        Attempt: Integer;
    begin
        Snapshot.SetRange(Type, Snapshot.Type::ConfigSnapshot);
        for Attempt := 1 to 20 do begin
            Snapshot.SetRange(Code, this.SnapshotCodeAt(CurrentDateTime()));
            if Snapshot.IsEmpty() then
                exit;
            Sleep(100);
        end;
    end;

    /// <summary>The code MobileNAV's InitializeNewSnapshot gives a snapshot taken at the given time.</summary>
    /// <param name="TakenAt">The time the snapshot is taken.</param>
    /// <returns>The snapshot code: the time to the second, digits only.</returns>
    local procedure SnapshotCodeAt(TakenAt: DateTime): Code[20]
    begin
        exit(CopyStr(DelChr(Format(RoundDateTime(TakenAt, 1000, '<'), 0, 9), '=', '-T:.Z'), 1, 20));
    end;

    /// <summary>
    /// Writes the description into the snapshot row and into the XML's ConfigInfo element, which is
    /// where an import in another company reads it from. The configuration hash leaves the
    /// description out, so it stays valid.
    /// </summary>
    /// <param name="Snapshot">The snapshot to describe.</param>
    /// <param name="Description">The description.</param>
    local procedure SetDescription(var Snapshot: Record "MobileNAV Master Data"; Description: Text)
    var
        Xml: Codeunit "MobileNAV XML Wrapper";
        InStream: InStream;
        OutStream: OutStream;
    begin
        Snapshot.CalcFields("Last Imported Config. XML");
        Snapshot."Last Imported Config. XML".CreateInStream(InStream);
        Xml.Initialize(true, '1.0', 'utf-8');
        Xml.LoadFromStream(InStream);
        if Xml.SelectSingleNode('root', 'config_info', './ConfigInfo') then begin
            Xml.SetAttribute('config_info', 'Desc', Description);
            Clear(Snapshot."Last Imported Config. XML");
            Snapshot."Last Imported Config. XML".CreateOutStream(OutStream);
            Xml.SaveToStream(OutStream);
        end;
        Snapshot.Validate(Description, CopyStr(Description, 1, MaxStrLen(Snapshot.Description)));
        Snapshot.Modify(false);
    end;

    /// <summary>Checks the XML is a MobileNAV configuration and reads its kind and description.</summary>
    /// <param name="TempBlob">The configuration XML.</param>
    /// <param name="ConfigImport">Returns the kind, description and base configuration version.</param>
    local procedure ReadConfigInfo(var TempBlob: Codeunit "Temp Blob"; var ConfigImport: Record "BJF MN Config Import" temporary)
    var
        Document: XmlDocument;
        Root: XmlElement;
        ConfigInfoNode: XmlNode;
        ConfigInfo: XmlElement;
        InStream: InStream;
    begin
        TempBlob.CreateInStream(InStream);
        if not XmlDocument.ReadFrom(InStream, Document) then
            Error(this.NotXmlErr);
        if not Document.GetRoot(Root) then
            Error(this.NotConfigurationErr);
        if (Root.LocalName() <> this.RootElementTok) or not Root.SelectSingleNode(this.ConfigInfoTok, ConfigInfoNode) then
            Error(this.NotConfigurationErr);
        ConfigInfo := ConfigInfoNode.AsXmlElement();

        ConfigImport.Validate("Config Kind", this.FullKindTok);
        if this.AttributeValue(ConfigInfo, 'PartialConfig') = 'true' then
            ConfigImport.Validate("Config Kind", this.PartialKindTok);
        if this.AttributeValue(ConfigInfo, 'OnlySkin') = 'true' then
            ConfigImport.Validate("Config Kind", this.SkinKindTok);
        ConfigImport.Validate("Config Description", CopyStr(this.AttributeValue(ConfigInfo, 'Desc'), 1, MaxStrLen(ConfigImport."Config Description")));
        ConfigImport.Validate("Base Config Version", CopyStr(this.AttributeValue(ConfigInfo, 'Ver'), 1, MaxStrLen(ConfigImport."Base Config Version")));
    end;

    local procedure AttributeValue(Element: XmlElement; Name: Text): Text
    var
        Attribute: XmlAttribute;
    begin
        if Element.Attributes().Get(Name, Attribute) then
            exit(Attribute.Value());
        exit('');
    end;

    /// <summary>
    /// Stops before the backup is taken when MobileNAV would refuse the import: it asks a delegated
    /// administrator to confirm (InitializeImport calls CheckUserDelegatedAdmin), which a session
    /// without a client cannot answer, and it rejects any configuration change while a device user
    /// is frozen.
    /// </summary>
    local procedure CheckImportAllowed()
    var
        PlatformSpecific: Codeunit "MobileNAV Platform Specific";
        CoreFunctions: Codeunit "MobileNAV Core Functions";
    begin
        if not GuiAllowed() and PlatformSpecific.IsUserDelegatedAdmin() then
            Error(this.DelegatedAdminErr);
        if CoreFunctions.IsConfigFreezed() then
            Error(this.ConfigFrozenErr);
    end;

    var
        FullKindTok: Label 'Full', Locked = true;
        PartialKindTok: Label 'Partial', Locked = true;
        SkinKindTok: Label 'Skin', Locked = true;
        RootElementTok: Label 'MobileNAVConfiguration', Locked = true;
        ConfigInfoTok: Label 'ConfigInfo', Locked = true;
        BackupDescriptionLbl: Label 'Backup before configuration import %1', Comment = '%1 = date and time';
        SnapshotNotTakenErr: Label 'MobileNAV did not create a configuration snapshot.';
        NoConfigurationErr: Label 'No configuration XML was given. Send it base64 encoded in configXmlBase64.';
        NotXmlErr: Label 'The configuration is not valid XML. Send the XML file base64 encoded.';
        NotConfigurationErr: Label 'The XML is not a MobileNAV configuration: it needs a MobileNAVConfiguration root element with a ConfigInfo element.';
        DelegatedAdminErr: Label 'MobileNAV asks a delegated administrator to confirm a configuration import, which an API call cannot answer. Nothing was changed. Call the API as a licensed user of the tenant or as a Microsoft Entra application.';
        ConfigFrozenErr: Label 'MobileNAV does not allow configuration changes while a device user is frozen. Nothing was changed. Unfreeze the users on the MobileNAV User Setup page first.';
        ImportFailedErr: Label 'The MobileNAV configuration import stopped with: %1 MobileNAV commits partway through an import, so the configuration may be partly replaced. Snapshot %2 holds the configuration from before the import: load it with Load Snapshot on the MobileNAV Configuration Handling page to go back.', Comment = '%1 = MobileNAV error text, %2 = backup snapshot code';
}
