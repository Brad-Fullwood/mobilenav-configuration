namespace BradFullwood.MobileNAV.Configuration;

using System.IO;
using System.Reflection;
using System.Utilities;

/// <summary>
/// Writes the files of a new MobileNAV Configuration provider for a customer app: the provider
/// codeunit, the enum extension, one page extension per MobileNAV page, a handler codeunit when a
/// button is declared, an install codeunit, a permission set, the app.json dependencies and a
/// README.txt. The files follow the Example app. The New provider wizard collects the input and
/// downloads them as a zip file.
/// </summary>
codeunit 77720 "BJF MN Scaffold Writer"
{
    /// <summary>Sets the facts of the app that receives the provider.</summary>
    /// <param name="NewPrefix">The object name prefix, such as ABC. Control names start with it too.</param>
    /// <param name="NewNamespace">The namespace of the generated files. Blank gives Publisher.AppName.</param>
    /// <param name="NewPublisher">The app's publisher.</param>
    /// <param name="NewAppName">The app's name.</param>
    /// <param name="NewFirstObjectId">The first object ID to use. Each object type counts up from it.</param>
    procedure SetAppDetails(NewPrefix: Text; NewNamespace: Text; NewPublisher: Text; NewAppName: Text; NewFirstObjectId: Integer)
    begin
        this.Prefix := NewPrefix.Trim();
        this.Namespace := NewNamespace.Trim();
        this.Publisher := NewPublisher.Trim();
        this.AppName := NewAppName.Trim();
        this.FirstObjectId := NewFirstObjectId;
    end;

    /// <summary>Sets the provider's identity. Blank values get the defaults the command line scaffolder uses.</summary>
    /// <param name="NewProviderId">The provider ID. Blank gives the prefix in upper case.</param>
    /// <param name="NewProviderName">The name the MobileNAV Configuration page shows. Blank gives the app name.</param>
    /// <param name="NewDescription">The description. Blank gives "Device configuration for" and the app name.</param>
    procedure SetProvider(NewProviderId: Text; NewProviderName: Text; NewDescription: Text)
    begin
        this.ProviderId := NewProviderId.Trim();
        this.ProviderName := NewProviderName.Trim();
        this.ProviderDescription := NewDescription.Trim();
    end;

    /// <summary>Returns the namespace the files get when none is given: the publisher and the app name as identifiers.</summary>
    /// <param name="ForPublisher">The app's publisher.</param>
    /// <param name="ForAppName">The app's name.</param>
    /// <returns>The namespace text.</returns>
    procedure DefaultNamespace(ForPublisher: Text; ForAppName: Text): Text
    begin
        exit(this.ALSource.LettersAndDigits(ForPublisher) + '.' + this.ALSource.LettersAndDigits(ForAppName));
    end;

    /// <summary>Returns the provider ID used when none is given: the prefix as an identifier, in upper case.</summary>
    /// <param name="ForPrefix">The object name prefix.</param>
    /// <returns>The provider ID.</returns>
    procedure DefaultProviderId(ForPrefix: Text): Text
    begin
        exit(UpperCase(this.ALSource.LettersAndDigits(ForPrefix)));
    end;

    /// <summary>Returns the control name of a new control: the prefix and the name, letters and digits only.</summary>
    /// <param name="ForPrefix">The object name prefix.</param>
    /// <param name="Name">The field name or the button caption.</param>
    /// <returns>The control name.</returns>
    procedure NewControlName(ForPrefix: Text; Name: Text): Text
    begin
        exit(this.ALSource.LettersAndDigits(ForPrefix) + this.ALSource.LettersAndDigits(Name));
    end;

    /// <summary>Fills the list of MobileNAV pages: every page whose name starts with MobileNAV and that has a source table.</summary>
    /// <param name="TempScaffoldPage">Receives one row per page. Existing rows are kept.</param>
    procedure LoadMobileNAVPages(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary)
    var
        AllObjWithCaption: Record AllObjWithCaption;
        PageMetadata: Record "Page Metadata";
        ServiceLookup: Codeunit "BJF MN Service Lookup";
    begin
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Page);
        AllObjWithCaption.SetFilter("Object Name", this.MobileNAVPageFilterTok);
        AllObjWithCaption.SetLoadFields("Object ID", "Object Name");
        PageMetadata.SetLoadFields(SourceTable);
        if AllObjWithCaption.FindSet() then
            repeat
                if PageMetadata.Get(AllObjWithCaption."Object ID") then
                    if (PageMetadata.SourceTable <> 0) and not TempScaffoldPage.Get(AllObjWithCaption."Object ID") then begin
                        TempScaffoldPage.Init();
                        TempScaffoldPage.Validate("Page ID", AllObjWithCaption."Object ID");
                        TempScaffoldPage.Validate("Page Name", AllObjWithCaption."Object Name");
                        TempScaffoldPage.Validate("Source Table ID", PageMetadata.SourceTable);
                        TempScaffoldPage.Validate("Source Table Name", CopyStr(ServiceLookup.ObjectNameOf(AllObjWithCaption."Object Type"::Table, PageMetadata.SourceTable), 1, MaxStrLen(TempScaffoldPage."Source Table Name")));
                        TempScaffoldPage.Validate("Add Controls To", CopyStr(this.DefaultPageGroup(AllObjWithCaption."Object ID"), 1, MaxStrLen(TempScaffoldPage."Add Controls To")));
                        TempScaffoldPage.Insert(false);
                    end;
            until AllObjWithCaption.Next() = 0;
    end;

    /// <summary>
    /// Returns the layout groups of a MobileNAV page from the page group list the app ships, in layout order.
    /// The list is the file Resources/MobileNAV/PageGroups.csv, one row per group.
    /// </summary>
    /// <param name="PageId">The page ID.</param>
    /// <param name="GroupNames">Receives the group names, the page's first group first. Cleared first.</param>
    /// <param name="Captions">Receives the caption of each group, blank when the group has none. Cleared first.</param>
    /// <returns>True when the list has the page. False when it does not, and both lists are empty.</returns>
    procedure PageGroups(PageId: Integer; var GroupNames: List of [Text]; var Captions: List of [Text]): Boolean
    var
        Fields: List of [Text];
        Remaining: Text;
        CsvLine: Text;
        LineEnd: Integer;
        PageIdText: Text;
    begin
        Clear(GroupNames);
        Clear(Captions);
        PageIdText := Format(PageId);
        Remaining := NavApp.GetResourceAsText(this.PageGroupsPathTok, TextEncoding::UTF8);
        while Remaining <> '' do begin
            LineEnd := StrPos(Remaining, this.Lf());
            if LineEnd = 0 then begin
                CsvLine := Remaining;
                Remaining := '';
            end else begin
                CsvLine := CopyStr(Remaining, 1, LineEnd - 1);
                Remaining := CopyStr(Remaining, LineEnd + 1);
            end;
            this.SplitCsvLine(CsvLine, Fields);
            if (Fields.Count() = 5) and (Fields.Get(1) = PageIdText) then begin
                GroupNames.Add(Fields.Get(2));
                Captions.Add(Fields.Get(3));
            end;
        end;
        exit(GroupNames.Count() > 0);
    end;

    /// <summary>
    /// Returns the group a new page extension adds its controls to: the page's first group in the page group list,
    /// or Group when the list does not have the page.
    /// </summary>
    /// <param name="PageId">The page ID.</param>
    /// <returns>The group name.</returns>
    procedure DefaultPageGroup(PageId: Integer): Text
    var
        GroupNames: List of [Text];
        Captions: List of [Text];
    begin
        if this.PageGroups(PageId, GroupNames, Captions) then
            exit(GroupNames.Get(1));
        exit(this.DefaultAnchorTok);
    end;

    /// <summary>Splits one line of the page group list at its commas. The list has no quoted fields.</summary>
    /// <param name="CsvLine">The line.</param>
    /// <param name="Fields">Receives the fields. Cleared first.</param>
    local procedure SplitCsvLine(CsvLine: Text; var Fields: List of [Text])
    var
        Rest: Text;
        Comma: Integer;
    begin
        Clear(Fields);
        Rest := CsvLine;
        Comma := StrPos(Rest, ',');
        while Comma > 0 do begin
            Fields.Add(CopyStr(Rest, 1, Comma - 1));
            Rest := CopyStr(Rest, Comma + 1);
            Comma := StrPos(Rest, ',');
        end;
        Fields.Add(Rest);
    end;

    /// <summary>
    /// Fills the field rows for every selected page that has none yet: first the page's own controls
    /// in page order, then the source table fields that are not on the page. Rows of pages that are no
    /// longer selected are deleted, buttons included.
    /// </summary>
    /// <param name="TempScaffoldPage">The pages, with Selected set.</param>
    /// <param name="TempFieldPick">The field and button rows.</param>
    procedure LoadFieldPicks(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        TempScaffoldPage.Reset();
        if TempScaffoldPage.FindSet() then
            repeat
                TempFieldPick.Reset();
                TempFieldPick.SetRange("Page ID", TempScaffoldPage."Page ID");
                if not TempScaffoldPage.Selected then
                    TempFieldPick.DeleteAll(false)
                else begin
                    TempFieldPick.SetRange("Is Button", false);
                    if TempFieldPick.IsEmpty() then
                        this.AddFieldRows(TempScaffoldPage, TempFieldPick);
                end;
            until TempScaffoldPage.Next() = 0;
        TempFieldPick.Reset();
    end;

    /// <summary>
    /// Fails when a new control would clash with a control the page already has, as the command
    /// line scaffolder does. Skipped when the session cannot read Page Control Field.
    /// </summary>
    /// <param name="TempScaffoldPage">The pages, with Selected set.</param>
    /// <param name="TempFieldPick">The field and button rows.</param>
    procedure CheckNewControlNames(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    var
        PageControlField: Record "Page Control Field";
    begin
        if not PageControlField.ReadPermission() then
            exit;
        TempScaffoldPage.Reset();
        TempScaffoldPage.SetCurrentKey(Selected, "Page Name");
        TempScaffoldPage.SetRange(Selected, true);
        if TempScaffoldPage.FindSet() then
            repeat
                this.CheckPageNewControlNames(TempScaffoldPage, TempFieldPick);
            until TempScaffoldPage.Next() = 0;
        TempScaffoldPage.Reset();
        TempFieldPick.Reset();
    end;

    local procedure CheckPageNewControlNames(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    var
        PageControlField: Record "Page Control Field";
        ControlName: Text;
    begin
        TempFieldPick.Reset();
        TempFieldPick.SetRange("Page ID", TempScaffoldPage."Page ID");
        if TempFieldPick.FindSet() then
            repeat
                if this.IsNewControl(TempFieldPick) then begin
                    ControlName := this.ControlNameOf(TempFieldPick);
                    PageControlField.SetRange(PageNo, TempScaffoldPage."Page ID");
                    PageControlField.SetRange(ControlName, ControlName);
                    if not PageControlField.IsEmpty() then
                        Error(this.ControlExistsErr, ControlName, TempScaffoldPage."Page Name");
                end;
            until TempFieldPick.Next() = 0;
    end;

    /// <summary>
    /// Renders every file. The selected pages each get a page extension. A page's field rows with
    /// Selected set become fields, its button rows become buttons.
    /// </summary>
    /// <param name="TempScaffoldPage">The pages, with Selected set.</param>
    /// <param name="TempFieldPick">The field and button rows.</param>
    /// <param name="FilePaths">Receives the path of each file inside the zip file.</param>
    /// <param name="FileTexts">Receives the text of each file, in the order of FilePaths.</param>
    procedure Render(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary; var FilePaths: List of [Text]; var FileTexts: List of [Text])
    var
        PageExtensionId: Integer;
        PrefixIdent: Text;
    begin
        Clear(FilePaths);
        Clear(FileTexts);
        this.CheckInput(TempScaffoldPage, TempFieldPick);
        PrefixIdent := this.ALSource.LettersAndDigits(this.Prefix);
        this.AddFile(FilePaths, FileTexts, StrSubstNo(this.ProviderPathTok, PrefixIdent), this.RenderProvider(TempScaffoldPage, TempFieldPick));
        this.AddFile(FilePaths, FileTexts, StrSubstNo(this.EnumExtPathTok, PrefixIdent), this.RenderEnumExtension());
        PageExtensionId := this.FirstObjectId;
        TempScaffoldPage.FindSet();
        repeat
            this.AddFile(FilePaths, FileTexts,
                StrSubstNo(this.PageExtPathTok, this.ShortPage(TempScaffoldPage."Page Name"), PrefixIdent, this.ALSource.LettersAndDigits(TempScaffoldPage."Page Name")),
                this.RenderPageExtension(PageExtensionId, TempScaffoldPage, TempFieldPick));
            PageExtensionId += 1;
        until TempScaffoldPage.Next() = 0;
        if this.HasButtons(TempScaffoldPage, TempFieldPick) then
            this.AddFile(FilePaths, FileTexts, StrSubstNo(this.HandlerPathTok, PrefixIdent), this.RenderHandler(TempScaffoldPage, TempFieldPick));
        this.AddFile(FilePaths, FileTexts, StrSubstNo(this.InstallPathTok, PrefixIdent), this.RenderInstall());
        this.AddFile(FilePaths, FileTexts, StrSubstNo(this.PermissionSetPathTok, PrefixIdent), this.RenderPermissionSet(TempScaffoldPage, TempFieldPick));
        this.AddFile(FilePaths, FileTexts, this.DependenciesPathTok, this.RenderDependencies());
        this.AddFile(FilePaths, FileTexts, this.ReadmePathTok, this.RenderReadme(TempScaffoldPage, TempFieldPick, FilePaths));
        TempScaffoldPage.Reset();
        TempFieldPick.Reset();
    end;

    /// <summary>Renders every file, packs them in a zip file and downloads it.</summary>
    /// <param name="TempScaffoldPage">The pages, with Selected set.</param>
    /// <param name="TempFieldPick">The field and button rows.</param>
    procedure DownloadZip(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    var
        DataCompression: Codeunit "Data Compression";
        ZipBlob: Codeunit "Temp Blob";
        FilePaths: List of [Text];
        FileTexts: List of [Text];
        ZipInStream: InStream;
        ZipFileName: Text;
        FileIndex: Integer;
    begin
        this.Render(TempScaffoldPage, TempFieldPick, FilePaths, FileTexts);
        DataCompression.CreateZipArchive();
        for FileIndex := 1 to FilePaths.Count() do
            this.AddZipEntry(DataCompression, FilePaths.Get(FileIndex), FileTexts.Get(FileIndex));
        DataCompression.SaveZipArchive(ZipBlob);
        DataCompression.CloseZipArchive();
        ZipBlob.CreateInStream(ZipInStream);
        ZipFileName := StrSubstNo(this.ZipFileNameTok, this.ALSource.LettersAndDigits(this.Prefix));
        DownloadFromStream(ZipInStream, '', '', '', ZipFileName);
    end;

    local procedure AddZipEntry(var DataCompression: Codeunit "Data Compression"; PathInArchive: Text; FileText: Text)
    var
        EntryBlob: Codeunit "Temp Blob";
        EntryOutStream: OutStream;
        EntryInStream: InStream;
    begin
        EntryBlob.CreateOutStream(EntryOutStream, TextEncoding::UTF8);
        EntryOutStream.WriteText(FileText);
        EntryBlob.CreateInStream(EntryInStream, TextEncoding::UTF8);
        DataCompression.AddEntry(EntryInStream, PathInArchive);
    end;

    local procedure AddFile(var FilePaths: List of [Text]; var FileTexts: List of [Text]; FilePath: Text; FileText: Text)
    begin
        FilePaths.Add(FilePath);
        FileTexts.Add(FileText);
    end;

    local procedure AddFieldRows(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    var
        TableField: Record Field;
        FieldsOnPage: List of [Integer];
    begin
        FieldsOnPage := this.AddPageControlRows(TempScaffoldPage, TempFieldPick);
        TableField.SetRange(TableNo, TempScaffoldPage."Source Table ID");
        TableField.SetRange(Class, TableField.Class::Normal);
        TableField.SetRange(Enabled, true);
        TableField.SetFilter(ObsoleteState, '<>%1', TableField.ObsoleteState::Removed);
        TableField.SetFilter("No.", '<%1', this.SystemFieldStart());
        TableField.SetLoadFields("No.", FieldName);
        if TableField.FindSet() then
            repeat
                if not FieldsOnPage.Contains(TableField."No.") then
                    this.InsertFieldRow(TempScaffoldPage, TempFieldPick, TableField."No.", this.NewControlName(this.Prefix, TableField.FieldName), false);
            until TableField.Next() = 0;
    end;

    /// <summary>Adds a row per control on the page, in page order. Adds nothing when the session cannot read Page Control Field.</summary>
    /// <param name="TempScaffoldPage">The page.</param>
    /// <param name="TempFieldPick">The rows.</param>
    /// <returns>The source table fields the page already shows.</returns>
    local procedure AddPageControlRows(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary) FieldsOnPage: List of [Integer]
    var
        PageControlField: Record "Page Control Field";
        FieldNo: Integer;
    begin
        if not PageControlField.ReadPermission() then
            exit(FieldsOnPage);
        PageControlField.SetCurrentKey(PageNo, Sequence);
        PageControlField.SetRange(PageNo, TempScaffoldPage."Page ID");
        PageControlField.SetLoadFields(ControlName, TableNo, FieldNo);
        if PageControlField.FindSet() then
            repeat
                FieldNo := 0;
                if PageControlField.TableNo = TempScaffoldPage."Source Table ID" then
                    FieldNo := PageControlField.FieldNo;
                this.InsertFieldRow(TempScaffoldPage, TempFieldPick, FieldNo, PageControlField.ControlName, true);
                if FieldNo <> 0 then
                    FieldsOnPage.Add(FieldNo);
            until PageControlField.Next() = 0;
        exit(FieldsOnPage);
    end;

    local procedure InsertFieldRow(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary; FieldNo: Integer; ControlName: Text; OnPage: Boolean)
    var
        TableField: Record Field;
        LineNo: Integer;
    begin
        TempFieldPick.Reset();
        if TempFieldPick.FindLast() then
            LineNo := TempFieldPick."Line No.";
        TempFieldPick.Init();
        TempFieldPick.Validate("Line No.", LineNo + 10000);
        TempFieldPick.Validate("Page ID", TempScaffoldPage."Page ID");
        TempFieldPick.Validate("Page Name", TempScaffoldPage."Page Name");
        TempFieldPick.Validate("Field No.", FieldNo);
        TempFieldPick.Validate("Control Name", CopyStr(ControlName, 1, MaxStrLen(TempFieldPick."Control Name")));
        TempFieldPick.Validate("On Page", OnPage);
        TableField.SetLoadFields(FieldName, "Field Caption");
        if (FieldNo <> 0) and TableField.Get(TempScaffoldPage."Source Table ID", FieldNo) then begin
            TempFieldPick.Validate("Field Name", TableField.FieldName);
            TempFieldPick.Validate(Caption, TableField."Field Caption");
        end;
        TempFieldPick.Insert(false);
    end;

    local procedure CheckInput(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    var
        UsedNames: List of [Text];
    begin
        if this.ALSource.LettersAndDigits(this.Prefix) = '' then
            Error(this.PrefixRequiredErr);
        if this.AppName = '' then
            Error(this.AppNameRequiredErr);
        if this.FirstObjectId <= 0 then
            Error(this.FirstObjectIdRequiredErr);
        this.CheckObjectName(this.ObjectNameFor(this.ProviderSuffixTok));
        this.CheckObjectName(this.ObjectNameFor(this.ProvidersSuffixTok));
        this.CheckObjectName(this.ObjectNameFor(this.InstallSuffixTok));
        this.CheckObjectName(this.ObjectNameFor(this.HandlerSuffixTok));
        this.CheckObjectName(this.ObjectNameFor(this.PermissionSetSuffixTok));
        UsedNames.Add(LowerCase(this.ObjectNameFor(this.ProviderSuffixTok)));
        UsedNames.Add(LowerCase(this.ObjectNameFor(this.ProvidersSuffixTok)));
        UsedNames.Add(LowerCase(this.ObjectNameFor(this.InstallSuffixTok)));
        UsedNames.Add(LowerCase(this.ObjectNameFor(this.HandlerSuffixTok)));
        UsedNames.Add(LowerCase(this.ObjectNameFor(this.PermissionSetSuffixTok)));
        Clear(this.PageObjectNames);
        TempScaffoldPage.Reset();
        TempScaffoldPage.SetCurrentKey(Selected, "Page Name");
        TempScaffoldPage.SetRange(Selected, true);
        if not TempScaffoldPage.FindSet() then
            Error(this.PageRequiredErr);
        repeat
            this.AssignPageObjectName(TempScaffoldPage, UsedNames);
            this.CheckPageControlNames(TempScaffoldPage, TempFieldPick);
        until TempScaffoldPage.Next() = 0;
    end;

    /// <summary>
    /// Names the page extension of one page: the prefix, then the page name without the MobileNAV prefix. With
    /// prefix AUK, MobileNAV ItemTrackingEntrySum gives AUK ItemTrackingEntrySum. The name is cut to 30
    /// characters, and numbered when another object already has it.
    /// </summary>
    /// <param name="TempScaffoldPage">The selected page.</param>
    /// <param name="UsedNames">The lower-case object names taken so far. Receives the name of this page.</param>
    local procedure AssignPageObjectName(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var UsedNames: List of [Text])
    var
        PageName: Text;
        Base: Text;
        Candidate: Text;
        Suffix: Integer;
    begin
        PageName := this.ShortPageName(TempScaffoldPage."Page Name");
        Base := this.Prefix + ' ' + PageName;
        if (PageName = '') or (StrLen(this.Prefix) + 2 > this.MaxObjectNameLength()) then
            Error(this.PageObjectNameErr, TempScaffoldPage."Page Name");
        Suffix := 1;
        Candidate := this.PageObjectNameCandidate(Base, Suffix);
        while UsedNames.Contains(LowerCase(Candidate)) do begin
            Suffix += 1;
            Candidate := this.PageObjectNameCandidate(Base, Suffix);
        end;
        UsedNames.Add(LowerCase(Candidate));
        this.PageObjectNames.Set(TempScaffoldPage."Page ID", Candidate);
    end;

    /// <summary>Cuts a base name to fit 30 characters, leaving room for the number when Suffix is above 1.</summary>
    /// <param name="Base">The name before cutting.</param>
    /// <param name="Suffix">1 for no number, otherwise the number appended to the name.</param>
    /// <returns>The name, without a trailing space.</returns>
    local procedure PageObjectNameCandidate(Base: Text; Suffix: Integer): Text
    var
        NumberText: Text;
    begin
        if Suffix > 1 then
            NumberText := Format(Suffix);
        exit(DelChr(CopyStr(Base, 1, this.MaxObjectNameLength() - StrLen(NumberText)), '>', ' ') + NumberText);
    end;

    local procedure CheckPageControlNames(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    var
        ControlNames: List of [Text];
        ControlName: Text;
    begin
        this.FilterControls(TempScaffoldPage, TempFieldPick);
        if TempFieldPick.FindSet() then
            repeat
                ControlName := this.ControlNameOf(TempFieldPick);
                if this.ALSource.LettersAndDigits(ControlName) = '' then
                    Error(this.ControlNameRequiredErr, TempScaffoldPage."Page Name");
                if ControlNames.Contains(LowerCase(ControlName)) then
                    Error(this.DeclaredTwiceErr, ControlName, TempScaffoldPage."Page Name");
                ControlNames.Add(LowerCase(ControlName));
            until TempFieldPick.Next() = 0;
    end;

    local procedure CheckObjectName(Name: Text)
    begin
        if StrLen(Name) > this.MaxObjectNameLength() then
            Error(this.NameTooLongErr, Name, StrLen(Name), this.MaxObjectNameLength());
    end;

    /// <summary>Sets TempFieldPick to the declared rows of one page: its selected fields, then its buttons.</summary>
    /// <param name="TempScaffoldPage">The page.</param>
    /// <param name="TempFieldPick">The rows, filtered on return.</param>
    local procedure FilterControls(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        TempFieldPick.Reset();
        TempFieldPick.SetCurrentKey("Page ID", "Is Button", "Line No.");
        TempFieldPick.SetRange("Page ID", TempScaffoldPage."Page ID");
        this.MarkDeclared(TempFieldPick);
    end;

    /// <summary>Marks the field rows with Selected set and every button row, and filters on the marks.</summary>
    /// <param name="TempFieldPick">The rows of one page.</param>
    local procedure MarkDeclared(var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        TempFieldPick.ClearMarks();
        if TempFieldPick.FindSet() then
            repeat
                TempFieldPick.Mark(TempFieldPick."Is Button" or TempFieldPick.Selected);
            until TempFieldPick.Next() = 0;
        TempFieldPick.MarkedOnly(true);
    end;

    local procedure IsNewControl(var TempFieldPick: Record "BJF MN Field Pick" temporary): Boolean
    begin
        if TempFieldPick."Is Button" then
            exit(true);
        exit(TempFieldPick.Selected and not TempFieldPick."On Page");
    end;

    local procedure ControlNameOf(var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    begin
        if TempFieldPick."Is Button" then begin
            if TempFieldPick."Control Name" <> '' then
                exit(TempFieldPick."Control Name");
            exit(this.NewControlName(this.Prefix, TempFieldPick.Caption));
        end;
        if TempFieldPick."On Page" then
            exit(TempFieldPick."Control Name");
        exit(this.NewControlName(this.Prefix, TempFieldPick."Field Name"));
    end;

    local procedure HasButtons(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Boolean
    begin
        TempScaffoldPage.FindSet();
        repeat
            TempFieldPick.Reset();
            TempFieldPick.SetRange("Page ID", TempScaffoldPage."Page ID");
            TempFieldPick.SetRange("Is Button", true);
            if not TempFieldPick.IsEmpty() then
                exit(true);
        until TempScaffoldPage.Next() = 0;
        exit(false);
    end;

    // ------------------------------------------------------------------ rendering

    local procedure RenderProvider(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Output: TextBuilder;
        First: Boolean;
    begin
        this.AppendHeader(Output, true);
        this.Line(Output, this.SummaryOpenTok);
        this.Line(Output, StrSubstNo(this.ProviderSummary1Tok, this.AppName));
        this.Line(Output, this.ProviderSummary2Tok);
        this.Line(Output, this.SummaryCloseTok);
        this.Line(Output, StrSubstNo(this.ProviderObjectTok, this.FirstObjectId, this.ObjectNameFor(this.ProviderSuffixTok)));
        this.Line(Output, this.OpenBraceTok);
        this.Line(Output, this.AccessInternalTok);
        this.Line(Output, '');
        this.AppendGetter(Output, this.GetIdTok, this.ExitProviderIdTok);
        this.AppendGetter(Output, this.GetNameTok, this.ExitProviderNameTok);
        this.AppendGetter(Output, this.GetDescriptionTok, this.ExitProviderDescriptionTok);
        this.Line(Output, this.DefineConfigurationTok);
        this.Line(Output, this.BeginTok);
        TempScaffoldPage.FindSet();
        repeat
            this.Line(Output, StrSubstNo(this.DeclareCallTok, this.ShortPage(TempScaffoldPage."Page Name")));
        until TempScaffoldPage.Next() = 0;
        this.Line(Output, this.EndTok);
        this.Line(Output, '');
        First := true;
        TempScaffoldPage.FindSet();
        repeat
            if not First then
                this.Line(Output, '');
            First := false;
            this.AppendDeclareProcedure(Output, TempScaffoldPage, TempFieldPick);
        until TempScaffoldPage.Next() = 0;
        this.Line(Output, '');
        this.Line(Output, this.VarTok);
        this.Line(Output, StrSubstNo(this.ProviderIdLabelTok, this.ALSource.Escaped(this.EffectiveProviderId())));
        this.Line(Output, StrSubstNo(this.ProviderNameLabelTok, this.ALSource.Escaped(CopyStr(this.EffectiveProviderName(), 1, 100))));
        this.Line(Output, StrSubstNo(this.ProviderDescriptionLabelTok, this.ALSource.Escaped(CopyStr(this.EffectiveDescription(), 1, 250))));
        this.Line(Output, this.CloseBraceTok);
        exit(Output.ToText());
    end;

    local procedure AppendGetter(var Output: TextBuilder; Signature: Text; ExitLine: Text)
    begin
        this.Line(Output, Signature);
        this.Line(Output, this.BeginTok);
        this.Line(Output, ExitLine);
        this.Line(Output, this.EndTok);
        this.Line(Output, '');
    end;

    local procedure AppendDeclareProcedure(var Output: TextBuilder; var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary)
    begin
        this.Line(Output, this.ProcedureSummaryOpenTok);
        this.Line(Output, StrSubstNo(this.DeclareSummary1Tok, this.ControlSummary(TempScaffoldPage, TempFieldPick), TempScaffoldPage."Page Name"));
        this.Line(Output, this.DeclareSummary2Tok);
        this.Line(Output, this.ProcedureSummaryCloseTok);
        this.Line(Output, this.DeclareParamTok);
        this.Line(Output, StrSubstNo(this.DeclareSignatureTok, this.ShortPage(TempScaffoldPage."Page Name")));
        this.Line(Output, this.BeginTok);
        this.Line(Output, this.Declaration(TempScaffoldPage, TempFieldPick));
        this.Line(Output, this.EndTok);
    end;

    /// <summary>Returns the builder chain for one page: Configuration.Page, then one line per field and button, ending in a semicolon.</summary>
    /// <param name="TempScaffoldPage">The page.</param>
    /// <param name="TempFieldPick">The rows.</param>
    /// <returns>The statement, its lines separated by line feeds.</returns>
    local procedure Declaration(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Statement: Text;
    begin
        Statement := StrSubstNo(this.PageCallTok, TempScaffoldPage."Page Name");
        this.FilterControls(TempScaffoldPage, TempFieldPick);
        if not TempFieldPick.FindSet() then
            exit(Statement + this.Lf() + this.EmptyDeclarationTok);
        repeat
            Statement += this.Lf() + this.ControlCall(TempFieldPick);
        until TempFieldPick.Next() = 0;
        exit(Statement + ';');
    end;

    local procedure ControlCall(var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Modifiers: Text;
    begin
        if TempFieldPick."Is Button" then
            exit(StrSubstNo(this.ButtonCallTok, this.ALSource.Escaped(this.ControlNameOf(TempFieldPick))));
        if TempFieldPick.Filterable then
            Modifiers += this.FilterableCallTok;
        if TempFieldPick.Editable then
            Modifiers += this.EditableCallTok;
        exit(StrSubstNo(this.FieldCallTok, this.ALSource.Escaped(this.ControlNameOf(TempFieldPick)), Modifiers));
    end;

    local procedure ControlSummary(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Summary: Text;
    begin
        this.FilterControls(TempScaffoldPage, TempFieldPick);
        TempFieldPick.SetRange("Is Button", false);
        Summary := this.CountText(TempFieldPick.Count(), this.OneFieldTok, this.FieldsTok);
        TempFieldPick.SetRange("Is Button", true);
        Summary := this.JoinWithAnd(Summary, this.CountText(TempFieldPick.Count(), this.OneButtonTok, this.ButtonsTok));
        TempFieldPick.SetRange("Is Button");
        if Summary = '' then
            exit(this.NoControlsTok);
        exit(Summary);
    end;

    local procedure JoinWithAnd(FirstPart: Text; SecondPart: Text): Text
    begin
        if (FirstPart = '') or (SecondPart = '') then
            exit(FirstPart + SecondPart);
        exit(FirstPart + this.AndTok + SecondPart);
    end;

    local procedure CountText(Count: Integer; SingularText: Text; PluralText: Text): Text
    begin
        if Count = 0 then
            exit('');
        if Count = 1 then
            exit(StrSubstNo(SingularText, Count));
        exit(StrSubstNo(PluralText, Count));
    end;

    local procedure RenderEnumExtension(): Text
    var
        Output: TextBuilder;
    begin
        this.AppendHeader(Output, true);
        this.Line(Output, this.EnumExtSummaryTok);
        this.Line(Output, StrSubstNo(this.EnumExtObjectTok, this.FirstObjectId, this.ObjectNameFor(this.ProvidersSuffixTok)));
        this.Line(Output, this.OpenBraceTok);
        this.Line(Output, StrSubstNo(this.EnumValueTok, this.FirstObjectId, this.ALSource.LettersAndDigits(this.Prefix)));
        this.Line(Output, this.IndentOpenBraceTok);
        this.Line(Output, StrSubstNo(this.EnumCaptionTok, this.ALSource.Escaped(this.EffectiveProviderName())));
        this.Line(Output, StrSubstNo(this.EnumImplementationTok, this.ObjectNameFor(this.ProviderSuffixTok)));
        this.Line(Output, this.IndentCloseBraceTok);
        this.Line(Output, this.CloseBraceTok);
        exit(Output.ToText());
    end;

    /// <summary>Returns the group name a page extension adds its controls to, in quotes when the name has a space.</summary>
    /// <param name="GroupName">The group the user set. Blank gives Group.</param>
    /// <returns>The name as AL writes it after addlast.</returns>
    local procedure AnchorName(GroupName: Text): Text
    begin
        if GroupName = '' then
            GroupName := this.DefaultAnchorTok;
        if (StrPos(GroupName, ' ') > 0) and (StrPos(GroupName, '"') = 0) then
            exit(StrSubstNo(this.QuotedNameTok, GroupName));
        exit(GroupName);
    end;

    local procedure RenderPageExtension(ObjectId: Integer; var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Output: TextBuilder;
        Anchor: Text;
        AnyControl: Boolean;
    begin
        this.AppendHeader(Output, false);
        this.Line(Output, this.SummaryOpenTok);
        this.Line(Output, StrSubstNo(this.PageExtSummary1Tok, TempScaffoldPage."Page Name"));
        this.Line(Output, this.PageExtSummary2Tok);
        this.Line(Output, this.SummaryCloseTok);
        this.Line(Output, StrSubstNo(this.PageExtObjectTok, ObjectId, this.PageObjectNames.Get(TempScaffoldPage."Page ID"), TempScaffoldPage."Page Name"));
        this.Line(Output, this.OpenBraceTok);
        this.Line(Output, this.LayoutTok);
        this.Line(Output, this.IndentOpenBraceTok);
        Anchor := this.AnchorName(TempScaffoldPage."Add Controls To");
        this.Line(Output, StrSubstNo(this.AddLastTok, Anchor));
        this.Line(Output, this.AddLastOpenBraceTok);
        this.FilterControls(TempScaffoldPage, TempFieldPick);
        if TempFieldPick.FindSet() then
            repeat
                if TempFieldPick."Is Button" then begin
                    AnyControl := true;
                    this.Line(Output, this.ButtonCommentTok);
                    this.Line(Output, StrSubstNo(this.ButtonControlTok, this.ControlNameOf(TempFieldPick)));
                    this.Line(Output, this.ControlOpenBraceTok);
                    this.Line(Output, this.ApplicationAreaTok);
                    this.Line(Output, StrSubstNo(this.CaptionTok, this.ALSource.Escaped(TempFieldPick.Caption)));
                    this.Line(Output, StrSubstNo(this.ButtonToolTipTok, this.ALSource.Escaped(TempFieldPick.Caption)));
                    this.Line(Output, this.ControlCloseBraceTok);
                end else
                    if not TempFieldPick."On Page" then begin
                        AnyControl := true;
                        this.Line(Output, StrSubstNo(this.FieldControlTok, this.ControlNameOf(TempFieldPick), TempFieldPick."Field Name"));
                        this.Line(Output, this.ControlOpenBraceTok);
                        this.Line(Output, this.ApplicationAreaTok);
                        this.Line(Output, this.ControlCloseBraceTok);
                    end;
            until TempFieldPick.Next() = 0;
        if not AnyControl then
            this.Line(Output, this.NoNewControlsTok);
        this.Line(Output, this.AddLastCloseBraceTok);
        this.Line(Output, this.IndentCloseBraceTok);
        this.Line(Output, this.CloseBraceTok);
        exit(Output.ToText());
    end;

    local procedure RenderHandler(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Output: TextBuilder;
        Checks: TextBuilder;
        Procedures: TextBuilder;
        Labels: TextBuilder;
        HandlerKey: Text;
    begin
        TempScaffoldPage.FindSet();
        repeat
            TempFieldPick.Reset();
            TempFieldPick.SetCurrentKey("Page ID", "Is Button", "Line No.");
            TempFieldPick.SetRange("Page ID", TempScaffoldPage."Page ID");
            TempFieldPick.SetRange("Is Button", true);
            if TempFieldPick.FindSet() then
                repeat
                    HandlerKey := this.ShortPage(TempScaffoldPage."Page Name") + this.ALSource.LettersAndDigits(TempFieldPick.Caption);
                    this.Line(Checks, StrSubstNo(this.HandlerCheckTok, TempScaffoldPage."Page Name", HandlerKey));
                    this.Line(Checks, StrSubstNo(this.HandlerRunCallTok, HandlerKey));
                    this.Line(Checks, this.HandlerExitTok);
                    this.Line(Checks, this.HandlerEndTok);
                    if Procedures.Length() > 0 then
                        this.Line(Procedures, '');
                    this.Line(Procedures, this.ProcedureSummaryOpenTok);
                    this.Line(Procedures, StrSubstNo(this.HandlerSummaryTok, TempFieldPick.Caption, TempScaffoldPage."Page Name"));
                    this.Line(Procedures, this.ProcedureSummaryCloseTok);
                    this.Line(Procedures, this.HandlerParamRecordTok);
                    this.Line(Procedures, this.HandlerParamFactoryTok);
                    this.Line(Procedures, StrSubstNo(this.HandlerSignatureTok, HandlerKey));
                    this.Line(Procedures, this.BeginTok);
                    this.Line(Procedures, StrSubstNo(this.HandlerToastTok, HandlerKey));
                    this.Line(Procedures, this.HandlerRefreshTok);
                    this.Line(Procedures, this.EndTok);
                    this.Line(Labels, StrSubstNo(this.HandlerTokLabelTok, HandlerKey, this.ALSource.Escaped(this.ControlNameOf(TempFieldPick))));
                    this.Line(Labels, StrSubstNo(this.HandlerMsgLabelTok, HandlerKey, this.ALSource.Escaped(TempFieldPick.Caption)));
                until TempFieldPick.Next() = 0;
        until TempScaffoldPage.Next() = 0;
        this.AppendHeader(Output, true);
        this.Line(Output, this.SummaryOpenTok);
        this.Line(Output, this.HandlerSummary1Tok);
        this.Line(Output, this.HandlerSummary2Tok);
        this.Line(Output, this.SummaryCloseTok);
        this.Line(Output, StrSubstNo(this.CodeunitObjectTok, this.FirstObjectId + 2, this.ObjectNameFor(this.HandlerSuffixTok)));
        this.Line(Output, this.OpenBraceTok);
        this.Line(Output, this.AccessInternalTok);
        this.Line(Output, '');
        this.Line(Output, this.HandlerSubscriberTok);
        this.Line(Output, this.HandlerSubscriberSignatureTok);
        this.Line(Output, this.BeginTok);
        Output.Append(Checks.ToText());
        this.Line(Output, this.EndTok);
        this.Line(Output, '');
        Output.Append(Procedures.ToText());
        this.Line(Output, '');
        this.Line(Output, this.VarTok);
        Output.Append(Labels.ToText());
        this.Line(Output, this.CloseBraceTok);
        exit(Output.ToText());
    end;

    local procedure RenderInstall(): Text
    var
        Output: TextBuilder;
    begin
        this.AppendHeader(Output, true);
        this.Line(Output, this.SummaryOpenTok);
        this.Line(Output, this.InstallSummary1Tok);
        this.Line(Output, this.InstallSummary2Tok);
        this.Line(Output, this.InstallSummary3Tok);
        this.Line(Output, this.InstallSummary4Tok);
        this.Line(Output, this.InstallSummary5Tok);
        this.Line(Output, this.SummaryCloseTok);
        this.Line(Output, StrSubstNo(this.CodeunitObjectTok, this.FirstObjectId + 1, this.ObjectNameFor(this.InstallSuffixTok)));
        this.Line(Output, this.OpenBraceTok);
        this.Line(Output, this.AccessInternalTok);
        this.Line(Output, this.SubtypeInstallTok);
        this.Line(Output, '');
        this.Line(Output, this.InstallTriggerTok);
        this.Line(Output, this.InstallVarTok);
        this.Line(Output, this.InstallVariableTok);
        this.Line(Output, this.BeginTok);
        this.Line(Output, this.InstallGuard1Tok);
        this.Line(Output, this.InstallGuard2Tok);
        this.Line(Output, StrSubstNo(this.InstallApplyTok, this.ALSource.LettersAndDigits(this.Prefix)));
        this.Line(Output, this.EndTok);
        this.Line(Output, this.CloseBraceTok);
        exit(Output.ToText());
    end;

    local procedure RenderPermissionSet(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary): Text
    var
        Output: TextBuilder;
        CodeunitLines: List of [Text];
        PermissionLine: Text;
        LineIndex: Integer;
    begin
        CodeunitLines := this.PermissionLines(this.HasButtons(TempScaffoldPage, TempFieldPick));
        this.AppendHeader(Output, true);
        this.Line(Output, this.SummaryOpenTok);
        this.Line(Output, StrSubstNo(this.PermissionSetSummary1Tok, this.AppName));
        this.Line(Output, this.PermissionSetSummary2Tok);
        this.Line(Output, this.SummaryCloseTok);
        this.Line(Output, StrSubstNo(this.PermissionSetObjectTok, this.FirstObjectId, this.ObjectNameFor(this.PermissionSetSuffixTok)));
        this.Line(Output, this.OpenBraceTok);
        this.Line(Output, this.AssignableTok);
        this.Line(Output, StrSubstNo(this.PermissionSetCaptionTok, CopyStr(this.ALSource.Escaped(this.AppName), 1, 30)));
        this.Line(Output, this.IncludedPermissionSetsTok);
        this.Line(Output, this.PermissionsTok);
        foreach PermissionLine in CodeunitLines do begin
            LineIndex += 1;
            if LineIndex < CodeunitLines.Count() then
                this.Line(Output, this.PermissionIndentTok + PermissionLine + ',')
            else
                this.Line(Output, this.PermissionIndentTok + PermissionLine + ';');
        end;
        this.Line(Output, this.CloseBraceTok);
        exit(Output.ToText());
    end;

    /// <summary>The permission lines for the generated codeunits, sorted by object name as in the Example.</summary>
    /// <param name="WithHandler">Whether a handler codeunit is generated.</param>
    /// <returns>One line per codeunit, without separators.</returns>
    local procedure PermissionLines(WithHandler: Boolean): List of [Text]
    var
        Lines: List of [Text];
    begin
        // The three names share the prefix, so Handler, Install, Provider is the sorted order.
        if WithHandler then
            Lines.Add(StrSubstNo(this.CodeunitPermissionTok, this.ObjectNameFor(this.HandlerSuffixTok)));
        Lines.Add(StrSubstNo(this.CodeunitPermissionTok, this.ObjectNameFor(this.InstallSuffixTok)));
        Lines.Add(StrSubstNo(this.CodeunitPermissionTok, this.ObjectNameFor(this.ProviderSuffixTok)));
        exit(Lines);
    end;

    local procedure RenderDependencies(): Text
    var
        Output: TextBuilder;
        FrameworkInfo: ModuleInfo;
        MobileNAVInfo: ModuleInfo;
        MobileNAVAppId: Guid;
    begin
        NavApp.GetCurrentModuleInfo(FrameworkInfo);
        this.Line(Output, this.DependenciesOpenTok);
        this.AppendDependency(Output, FrameworkInfo.Id(), FrameworkInfo.Name(), FrameworkInfo.Publisher(), Format(FrameworkInfo.AppVersion()));
        Evaluate(MobileNAVAppId, this.MobileNAVAppIdTok);
        if NavApp.GetModuleInfo(MobileNAVAppId, MobileNAVInfo) then begin
            this.Line(Output, this.DependencySeparatorTok);
            this.AppendDependency(Output, MobileNAVInfo.Id(), MobileNAVInfo.Name(), MobileNAVInfo.Publisher(), Format(MobileNAVInfo.AppVersion()));
        end;
        this.Line(Output, '');
        this.Line(Output, this.DependenciesCloseTok);
        exit(Output.ToText());
    end;

    local procedure AppendDependency(var Output: TextBuilder; AppId: Guid; Name: Text; DependencyPublisher: Text; Version: Text)
    begin
        this.Line(Output, this.DependencyOpenTok);
        this.Line(Output, StrSubstNo(this.DependencyIdTok, LowerCase(Format(AppId, 0, 4))));
        this.Line(Output, StrSubstNo(this.DependencyNameTok, Name));
        this.Line(Output, StrSubstNo(this.DependencyPublisherTok, DependencyPublisher));
        this.Line(Output, StrSubstNo(this.DependencyVersionTok, Version));
        Output.Append(this.DependencyCloseTok);
    end;

    local procedure RenderReadme(var TempScaffoldPage: Record "BJF MN Scaffold Page" temporary; var TempFieldPick: Record "BJF MN Field Pick" temporary; FilePaths: List of [Text]): Text
    var
        Output: TextBuilder;
        FilePath: Text;
        PermissionLine: Text;
    begin
        this.Line(Output, StrSubstNo(this.ReadmeTitleTok, this.EffectiveProviderName(), this.AppName));
        this.Line(Output, '');
        this.Line(Output, this.ReadmeFilesTok);
        foreach FilePath in FilePaths do
            this.Line(Output, this.ReadmeIndentTok + FilePath);
        this.Line(Output, this.ReadmeIndentTok + this.ReadmePathTok);
        this.Line(Output, '');
        this.Line(Output, this.ReadmeStepsTok);
        this.Line(Output, this.ReadmeStep1Tok);
        this.Line(Output, this.ReadmeStep2Tok);
        this.Line(Output, this.ReadmeStep3Tok);
        this.Line(Output, this.ReadmeStep4Tok);
        this.Line(Output, this.ReadmeStep5Tok);
        this.Line(Output, this.ReadmeStep6Tok);
        this.Line(Output, '');
        this.Line(Output, this.ReadmePermissionsTok);
        foreach PermissionLine in this.PermissionLines(this.HasButtons(TempScaffoldPage, TempFieldPick)) do
            this.Line(Output, this.ReadmeIndentTok + PermissionLine + ',');
        this.Line(Output, '');
        this.Line(Output, this.ReadmeGroupsTok);
        TempScaffoldPage.FindSet();
        repeat
            this.Line(Output, StrSubstNo(this.ReadmeGroupLineTok, TempScaffoldPage."Page Name", TempScaffoldPage."Add Controls To"));
        until TempScaffoldPage.Next() = 0;
        this.Line(Output, '');
        this.Line(Output, StrSubstNo(this.ReadmeIdsTok, this.FirstObjectId));
        exit(Output.ToText());
    end;

    // ------------------------------------------------------------------ names and text

    local procedure AppendHeader(var Output: TextBuilder; WithUsing: Boolean)
    begin
        this.Line(Output, StrSubstNo(this.NamespaceTok, this.EffectiveNamespace()));
        this.Line(Output, '');
        if WithUsing then begin
            this.Line(Output, this.UsingFrameworkTok);
            this.Line(Output, '');
        end;
    end;

    local procedure Line(var Output: TextBuilder; Value: Text)
    begin
        Output.Append(Value);
        Output.Append(this.Lf());
    end;

    local procedure Lf(): Text
    var
        TypeHelper: Codeunit "Type Helper";
    begin
        exit(TypeHelper.LFSeparator());
    end;

    // Named ObjectNameFor because the codeunit's generated C# class already has a member ObjectName.
    // The local compiler accepts that name, and the service fails on the first call with CS0102.
    local procedure ObjectNameFor(Suffix: Text): Text
    begin
        exit(this.Prefix + ' ' + Suffix);
    end;

    local procedure EffectiveNamespace(): Text
    begin
        if this.Namespace <> '' then
            exit(this.Namespace);
        exit(this.DefaultNamespace(this.Publisher, this.AppName));
    end;

    local procedure EffectiveProviderId(): Text
    begin
        if this.ProviderId <> '' then
            exit(this.ProviderId);
        exit(this.DefaultProviderId(this.Prefix));
    end;

    local procedure EffectiveProviderName(): Text
    begin
        if this.ProviderName <> '' then
            exit(this.ProviderName);
        exit(this.AppName);
    end;

    local procedure EffectiveDescription(): Text
    begin
        if this.ProviderDescription <> '' then
            exit(this.ProviderDescription);
        exit(StrSubstNo(this.DefaultDescriptionTok, this.AppName));
    end;

    /// <summary>Returns the page name without the MobileNAV prefix, as an identifier: MobileNAV WhseShipment gives WhseShipment.</summary>
    /// <param name="PageName">The page name.</param>
    /// <returns>The identifier.</returns>
    local procedure ShortPage(PageName: Text): Text
    begin
        if PageName.StartsWith(this.MobileNAVPrefixTok) then
            exit(this.ALSource.LettersAndDigits(PageName.Substring(StrLen(this.MobileNAVPrefixTok) + 1)));
        exit(this.ALSource.LettersAndDigits(PageName));
    end;

    /// <summary>Returns the page name without the MobileNAV prefix, as it is: MobileNAV Whse Shipment gives Whse Shipment.</summary>
    /// <param name="PageName">The page name.</param>
    /// <returns>The short name, which can hold spaces.</returns>
    local procedure ShortPageName(PageName: Text): Text
    begin
        if PageName.StartsWith(this.MobileNAVPrefixTok) then
            exit(PageName.Substring(StrLen(this.MobileNAVPrefixTok) + 1));
        exit(PageName);
    end;

    local procedure MaxObjectNameLength(): Integer
    begin
        exit(30);
    end;

    local procedure SystemFieldStart(): Integer
    begin
        exit(2000000000);
    end;

    var
        ALSource: Codeunit "BJF MN AL Source";
        PageObjectNames: Dictionary of [Integer, Text];
        Prefix: Text;
        Namespace: Text;
        Publisher: Text;
        AppName: Text;
        FirstObjectId: Integer;
        ProviderId: Text;
        ProviderName: Text;
        ProviderDescription: Text;
        PrefixRequiredErr: Label 'Enter a prefix with at least one letter or digit.';
        AppNameRequiredErr: Label 'Enter the app name.';
        FirstObjectIdRequiredErr: Label 'Enter the first object ID, a number in the app''s ID range.';
        PageRequiredErr: Label 'Select at least one MobileNAV page.';
        NameTooLongErr: Label 'The object name ''%1'' is %2 characters and AL allows %3. Use a shorter prefix.', Comment = '%1 = object name, %2 = its length, %3 = the maximum length';
        DeclaredTwiceErr: Label '%1 is declared twice on %2.', Comment = '%1 = control name, %2 = page name';
        ControlNameRequiredErr: Label 'A button on %1 has no caption and no control name.', Comment = '%1 = page name';
        ControlExistsErr: Label 'The control %1 already exists on %2. Use a different prefix or a different button caption.', Comment = '%1 = control name, %2 = page name';
        PageObjectNameErr: Label 'No object name fits the page %1. Use a shorter prefix.', Comment = '%1 = page name';
        MobileNAVPageFilterTok: Label 'MobileNAV *', Locked = true;
        MobileNAVPrefixTok: Label 'MobileNAV ', Locked = true;
        MobileNAVAppIdTok: Label 'fd09b53c-ff32-4d9c-91ce-6a82a87b8c9c', Locked = true;
        DefaultAnchorTok: Label 'Group', Locked = true;
        PageGroupsPathTok: Label 'MobileNAV/PageGroups.csv', Locked = true;
        QuotedNameTok: Label '"%1"', Locked = true;
        DefaultDescriptionTok: Label 'Device configuration for %1.', Locked = true;
        ProviderSuffixTok: Label 'MN Provider', Locked = true;
        ProvidersSuffixTok: Label 'MN Providers', Locked = true;
        InstallSuffixTok: Label 'MN Install', Locked = true;
        HandlerSuffixTok: Label 'MN Handler', Locked = true;
        PermissionSetSuffixTok: Label 'MN Config', Locked = true;
        ProviderPathTok: Label 'src/Provider/%1MNProvider.Codeunit.al', Locked = true;
        EnumExtPathTok: Label 'src/Provider/%1MNProviders.EnumExt.al', Locked = true;
        PageExtPathTok: Label 'src/%1/%2%3.PageExt.al', Locked = true;
        HandlerPathTok: Label 'src/Provider/%1MNHandler.Codeunit.al', Locked = true;
        InstallPathTok: Label 'src/Provider/%1MNInstall.Codeunit.al', Locked = true;
        PermissionSetPathTok: Label 'permissions/%1MNConfig.PermissionSet.al', Locked = true;
        DependenciesPathTok: Label 'app.json.dependencies.txt', Locked = true;
        ReadmePathTok: Label 'README.txt', Locked = true;
        ZipFileNameTok: Label '%1-mobilenav-provider.zip', Locked = true;
        NamespaceTok: Label 'namespace %1;', Locked = true;
        UsingFrameworkTok: Label 'using BradFullwood.MobileNAV.Configuration;', Locked = true;
        SummaryOpenTok: Label '/// <summary>', Locked = true;
        SummaryCloseTok: Label '/// </summary>', Locked = true;
        ProcedureSummaryOpenTok: Label '    /// <summary>', Locked = true;
        ProcedureSummaryCloseTok: Label '    /// </summary>', Locked = true;
        OpenBraceTok: Label '{', Locked = true;
        CloseBraceTok: Label '}', Locked = true;
        IndentOpenBraceTok: Label '    {', Locked = true;
        IndentCloseBraceTok: Label '    }', Locked = true;
        AccessInternalTok: Label '    Access = Internal;', Locked = true;
        BeginTok: Label '    begin', Locked = true;
        EndTok: Label '    end;', Locked = true;
        VarTok: Label '    var', Locked = true;
        ProviderSummary1Tok: Label '/// The %1 provider: everything the device shows for this app, declared in one place.', Locked = true;
        ProviderSummary2Tok: Label '/// The framework applies the declaration. The MobileNAV Doctor checks it afterwards and repairs it.', Locked = true;
        ProviderObjectTok: Label 'codeunit %1 "%2" implements "BJF MN Config Provider"', Locked = true;
        GetIdTok: Label '    procedure GetId(): Code[50]', Locked = true;
        GetNameTok: Label '    procedure GetName(): Text[100]', Locked = true;
        GetDescriptionTok: Label '    procedure GetDescription(): Text[250]', Locked = true;
        ExitProviderIdTok: Label '        exit(this.ProviderIdTok);', Locked = true;
        ExitProviderNameTok: Label '        exit(this.ProviderNameLbl);', Locked = true;
        ExitProviderDescriptionTok: Label '        exit(this.ProviderDescriptionLbl);', Locked = true;
        DefineConfigurationTok: Label '    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")', Locked = true;
        DeclareCallTok: Label '        this.Declare%1(Configuration);', Locked = true;
        DeclareSummary1Tok: Label '    /// The device gets %1 on the %2 page. Add more with .Field, .Button,', Locked = true;
        DeclareSummary2Tok: Label '    /// .Lookup and the other builder verbs. The page extension holds the matching controls.', Locked = true;
        DeclareParamTok: Label '    /// <param name="Configuration">The builder that collects the declarations.</param>', Locked = true;
        DeclareSignatureTok: Label '    local procedure Declare%1(var Configuration: Codeunit "BJF MN Config Builder")', Locked = true;
        PageCallTok: Label '        Configuration.Page(Page::"%1")', Locked = true;
        EmptyDeclarationTok: Label '            ;', Locked = true;
        ButtonCallTok: Label '            .Button(''%1'')', Locked = true;
        FieldCallTok: Label '            .Field(''%1'')%2', Locked = true;
        FilterableCallTok: Label '.Filterable()', Locked = true;
        EditableCallTok: Label '.Editable()', Locked = true;
        OneFieldTok: Label '%1 field', Locked = true;
        FieldsTok: Label '%1 fields', Locked = true;
        OneButtonTok: Label '%1 button', Locked = true;
        ButtonsTok: Label '%1 buttons', Locked = true;
        AndTok: Label ' and ', Locked = true;
        NoControlsTok: Label 'no controls yet', Locked = true;
        ProviderIdLabelTok: Label '        ProviderIdTok: Label ''%1'', Locked = true;', Locked = true;
        ProviderNameLabelTok: Label '        ProviderNameLbl: Label ''%1'', MaxLength = 100;', Locked = true;
        ProviderDescriptionLabelTok: Label '        ProviderDescriptionLbl: Label ''%1'', MaxLength = 250;', Locked = true;
        EnumExtSummaryTok: Label '/// <summary>Registers the provider so the framework lists and applies it.</summary>', Locked = true;
        EnumExtObjectTok: Label 'enumextension %1 "%2" extends "BJF MN Config Provider"', Locked = true;
        EnumValueTok: Label '    value(%1; %2)', Locked = true;
        EnumCaptionTok: Label '        Caption = ''%1'';', Locked = true;
        EnumImplementationTok: Label '        Implementation = "BJF MN Config Provider" = "%1";', Locked = true;
        PageExtSummary1Tok: Label '/// Adds the controls the provider declares to the %1 page: the fields that', Locked = true;
        PageExtSummary2Tok: Label '/// are not on it yet, and a placeholder control for each button.', Locked = true;
        PageExtObjectTok: Label 'pageextension %1 "%2" extends "%3"', Locked = true;
        LayoutTok: Label '    layout', Locked = true;
        AddLastTok: Label '        addlast(%1)', Locked = true;
        AddLastOpenBraceTok: Label '        {', Locked = true;
        AddLastCloseBraceTok: Label '        }', Locked = true;
        ButtonCommentTok: Label '            // A button is a placeholder control. The provider turns it into a device button.', Locked = true;
        ButtonControlTok: Label '            field(%1; '''')', Locked = true;
        FieldControlTok: Label '            field(%1; Rec."%2")', Locked = true;
        ControlOpenBraceTok: Label '            {', Locked = true;
        ControlCloseBraceTok: Label '            }', Locked = true;
        ApplicationAreaTok: Label '                ApplicationArea = All;', Locked = true;
        CaptionTok: Label '                Caption = ''%1'';', Locked = true;
        ButtonToolTipTok: Label '                ToolTip = ''Specifies the device button %1. The provider declares it.'';', Locked = true;
        NoNewControlsTok: Label '            // Every declared field is already a control on the page.', Locked = true;
        HandlerSummary1Tok: Label '/// Answers the buttons the provider declares. The framework raises one event for every tap on', Locked = true;
        HandlerSummary2Tok: Label '/// every page, with the tapped record as a RecordRef. Filter on the page and the control, then do the work.', Locked = true;
        CodeunitObjectTok: Label 'codeunit %1 "%2"', Locked = true;
        HandlerSubscriberTok: Label '    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Function Router", OnPageFunction, '''', false, false)]', Locked = true;
        HandlerSubscriberSignatureTok: Label '    local procedure "BJF MN Function Router_OnPageFunction"(PageId: Integer; ControlName: Text[75]; FunctionRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")', Locked = true;
        HandlerCheckTok: Label '        if (PageId = Page::"%1") and (ControlName = this.%2Tok) then begin', Locked = true;
        HandlerRunCallTok: Label '            this.Run%1(FunctionRecord, FieldControlFactory);', Locked = true;
        HandlerExitTok: Label '            exit;', Locked = true;
        HandlerEndTok: Label '        end;', Locked = true;
        HandlerSummaryTok: Label '    /// Runs when the device user taps %1 on the %2 page. Replace the toast with the work.', Locked = true;
        HandlerParamRecordTok: Label '    /// <param name="FunctionRecord">The record that was tapped.</param>', Locked = true;
        HandlerParamFactoryTok: Label '    /// <param name="FieldControlFactory">The factory that answers the device.</param>', Locked = true;
        HandlerSignatureTok: Label '    local procedure Run%1(FunctionRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")', Locked = true;
        HandlerToastTok: Label '        FieldControlFactory.FcSetToastMessage(FunctionRecord, this.%1Msg);', Locked = true;
        HandlerRefreshTok: Label '        FieldControlFactory.FcRefreshCurrent(FunctionRecord);', Locked = true;
        HandlerTokLabelTok: Label '        %1Tok: Label ''%2'', Locked = true;', Locked = true;
        HandlerMsgLabelTok: Label '        %1Msg: Label ''%2 ran.'';', Locked = true;
        InstallSummary1Tok: Label '/// Applies the provider on install. Install has no client to answer MobileNAV''s dialogs, so', Locked = true;
        InstallSummary2Tok: Label '/// the configuration is written but the handover to devices waits for an administrator to', Locked = true;
        InstallSummary3Tok: Label '/// apply once more from the MobileNAV Configuration page. When MobileNAV has not been set up', Locked = true;
        InstallSummary4Tok: Label '/// in the company yet, nothing is applied: the provider stays Not Applied until the administrator', Locked = true;
        InstallSummary5Tok: Label '/// runs MobileNAV''s Setup Wizard and applies it.', Locked = true;
        InstallGuard1Tok: Label '        if not ConfigurationApplication.MobileNAVIsConfigured() then', Locked = true;
        InstallGuard2Tok: Label '            exit;', Locked = true;
        SubtypeInstallTok: Label '    Subtype = Install;', Locked = true;
        InstallTriggerTok: Label '    trigger OnInstallAppPerCompany()', Locked = true;
        InstallVarTok: Label '    var', Locked = true;
        InstallVariableTok: Label '        ConfigurationApplication: Codeunit "BJF MN Config Application";', Locked = true;
        InstallApplyTok: Label '        ConfigurationApplication.ApplyProvider(Enum::"BJF MN Config Provider"::%1);', Locked = true;
        PermissionSetSummary1Tok: Label '/// Everything %1 needs: its own objects, and "BJF MN Configuration" so the user can', Locked = true;
        PermissionSetSummary2Tok: Label '/// open MobileNAV Configuration and MobileNAV Doctor. Assign it to device users and administrators.', Locked = true;
        PermissionSetObjectTok: Label 'permissionset %1 "%2"', Locked = true;
        AssignableTok: Label '    Assignable = true;', Locked = true;
        PermissionSetCaptionTok: Label '    Caption = ''%1'', MaxLength = 30;', Locked = true;
        IncludedPermissionSetsTok: Label '    IncludedPermissionSets = "BJF MN Configuration";', Locked = true;
        PermissionsTok: Label '    Permissions =', Locked = true;
        PermissionIndentTok: Label '        ', Locked = true;
        CodeunitPermissionTok: Label 'codeunit "%1" = X', Locked = true;
        DependenciesOpenTok: Label '"dependencies": [', Locked = true;
        DependenciesCloseTok: Label ']', Locked = true;
        DependencyOpenTok: Label '  {', Locked = true;
        DependencyCloseTok: Label '  }', Locked = true;
        DependencySeparatorTok: Label ',', Locked = true;
        DependencyIdTok: Label '    "id": "%1",', Locked = true;
        DependencyNameTok: Label '    "name": "%1",', Locked = true;
        DependencyPublisherTok: Label '    "publisher": "%1",', Locked = true;
        DependencyVersionTok: Label '    "version": "%1"', Locked = true;
        ReadmeTitleTok: Label 'MobileNAV provider %1 for %2', Locked = true;
        ReadmeFilesTok: Label 'Files:', Locked = true;
        ReadmeIndentTok: Label '    ', Locked = true;
        ReadmeStepsTok: Label 'Steps:', Locked = true;
        ReadmeStep1Tok: Label '1. Copy the src and permissions folders into the app folder, next to app.json.', Locked = true;
        ReadmeStep2Tok: Label '2. Add the entries in app.json.dependencies.txt to the dependencies in app.json, then download symbols.', Locked = true;
        ReadmeStep3Tok: Label '3. Check each page extension''s addlast group (listed below) against the MobileNAV page, and the object IDs against the app''s idRanges.', Locked = true;
        ReadmeStep4Tok: Label '4. Build, then publish the app. The install codeunit applies the provider once.', Locked = true;
        ReadmeStep5Tok: Label '5. Open MobileNAV Configuration, select the provider and choose Apply selected, so devices get the configuration.', Locked = true;
        ReadmeStep6Tok: Label '6. Replace the toast in each Run procedure of the handler codeunit with the button''s work.', Locked = true;
        ReadmePermissionsTok: Label 'If the app already has a permission set, delete the generated one and add these lines to the existing set:', Locked = true;
        ReadmeGroupsTok: Label 'Page extensions add their controls to these groups:', Locked = true;
        ReadmeGroupLineTok: Label '    %1: %2', Locked = true;
        ReadmeIdsTok: Label 'Object IDs start at %1 for each object type: provider, enum extension, first page extension and permission set use it, the install codeunit uses the next ID and the handler the one after.', Locked = true;
}
