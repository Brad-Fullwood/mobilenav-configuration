namespace BradFullwood.MobileNAV.Configuration;

using System.Environment;
using System.IO;
using System.Reflection;
using System.Utilities;

/// <summary>
/// Writes the AL text of a provider codeunit and its enum extension that restate the live MobileNAV
/// setup of chosen services as builder calls: pages, fields, buttons, scan inputs, field controls,
/// links and lookups with their detail rows, page filters, flow filters, saved filters, operations,
/// dynamic layouts, wizards, groups, captions, menu categories, master data and, when asked, the
/// per-profile overrides. A row the builder cannot write becomes a comment where it belongs.
/// The mapping follows mnconfig.py reverse, which reads the same rows through the API pages.
/// </summary>
codeunit 77718 "BJF MN Provider Writer"
{
    Permissions = tabledata "MobileNAV CaptionML Admin." = r,
        tabledata "MobileNAV Category Transl." = r,
        tabledata "MobileNAV D. L. Action" = r,
        tabledata "MobileNAV D. L. Action Line" = r,
        tabledata "MobileNAV D. L. Condition" = r,
        tabledata "MobileNAV Dynamic Layout" = r,
        tabledata "MobileNAV Master Data" = r,
        tabledata "MobileNAV Profile Setup" = r,
        tabledata "MobileNAV Service Setup" = r;

    /// <summary>Sets the identity of the generated provider. Call before Generate or Download.</summary>
    /// <param name="NewProviderId">The provider id GetId() returns, for example AUK-WAREHOUSE.</param>
    /// <param name="NewObjectId">The id of the codeunit and the enum extension. 0 means 50100.</param>
    /// <param name="NewObjectName">The codeunit name. Empty means the provider id followed by MN Provider.</param>
    /// <param name="NewNamespaceName">The namespace of the generated file. Empty writes no namespace line.</param>
    procedure SetProvider(NewProviderId: Text[50]; NewObjectId: Integer; NewObjectName: Text[30]; NewNamespaceName: Text)
    begin
        this.ProviderId := NewProviderId;
        this.ObjectId := NewObjectId;
        this.ObjectName := NewObjectName;
        this.NamespaceName := NewNamespaceName;
    end;

    /// <summary>Sets which rows beyond the page setup the generated provider restates.</summary>
    /// <param name="NewIncludeProfiles">Read profile rows and declare the per-profile overrides.</param>
    /// <param name="NewIncludeHidden">Declare the hidden fields of MobileNAV's own pages as well.</param>
    /// <param name="NewIncludeAllCaptions">Declare control captions too. MobileNAV regenerates them from page metadata.</param>
    procedure SetScope(NewIncludeProfiles: Boolean; NewIncludeHidden: Boolean; NewIncludeAllCaptions: Boolean)
    begin
        this.IncludeProfiles := NewIncludeProfiles;
        this.IncludeHidden := NewIncludeHidden;
        this.IncludeAllCaptions := NewIncludeAllCaptions;
    end;

    /// <summary>Tells whether MobileNAV has a page set up under a service name.</summary>
    /// <param name="ServiceName">The MobileNAV service name, for example MNItem.</param>
    /// <returns>True when the service has a Main row.</returns>
    procedure HasService(ServiceName: Text): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        exit(not ServiceSetup.IsEmpty());
    end;

    /// <summary>Tells whether a service has a field row with a control name.</summary>
    /// <param name="ServiceName">The MobileNAV service name.</param>
    /// <param name="ControlName">MobileNAV's stored control name, for example ExampleNotes.</param>
    /// <returns>True when the field row exists.</returns>
    procedure HasControl(ServiceName: Text; ControlName: Text): Boolean
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::"Field");
        ServiceSetup.SetRange(FieldName, ControlName);
        exit(not ServiceSetup.IsEmpty());
    end;

    /// <summary>Downloads a zip file with one .al file per object the provider writes, named after the codeunit.</summary>
    /// <param name="ServiceNames">The MobileNAV service names to restate, in the order the provider defines them.</param>
    procedure Download(ServiceNames: List of [Text])
    var
        DataCompression: Codeunit "Data Compression";
        ZipBlob: Codeunit "Temp Blob";
        ZipInStream: InStream;
        ZipFileName: Text;
        FilePaths: List of [Text];
        FileTexts: List of [Text];
        FileIndex: Integer;
    begin
        this.GenerateFiles(ServiceNames, FilePaths, FileTexts);
        DataCompression.CreateZipArchive();
        for FileIndex := 1 to FilePaths.Count() do
            this.AddZipEntry(DataCompression, FilePaths.Get(FileIndex), FileTexts.Get(FileIndex));
        DataCompression.SaveZipArchive(ZipBlob);
        DataCompression.CloseZipArchive();
        ZipBlob.CreateInStream(ZipInStream);
        ZipFileName := this.EffectiveObjectName() + '.zip';
        DownloadFromStream(ZipInStream, '', '', '', ZipFileName);
    end;

    /// <summary>The provider codeunit and enum extension as one .al text, for the given services.</summary>
    /// <param name="ServiceNames">The MobileNAV service names to restate, in the order the provider defines them.</param>
    /// <returns>The text of one .al file.</returns>
    procedure Generate(ServiceNames: List of [Text]): Text
    var
        Services: List of [Text];
    begin
        this.ReadServices(ServiceNames, Services);
        exit(this.BuildText(Services));
    end;

    /// <summary>The files of the provider: the provider codeunit and the enum extension, each as its own .al file.</summary>
    /// <param name="ServiceNames">The MobileNAV service names to restate, in the order the provider defines them.</param>
    /// <param name="FilePaths">Receives the file name of each file: the object name, the object type, then .al.</param>
    /// <param name="FileTexts">Receives the text of each file, in the order of FilePaths.</param>
    procedure GenerateFiles(ServiceNames: List of [Text]; var FilePaths: List of [Text]; var FileTexts: List of [Text])
    var
        Services: List of [Text];
    begin
        Clear(FilePaths);
        Clear(FileTexts);
        this.ReadServices(ServiceNames, Services);
        this.BuildFiles(Services, FilePaths, FileTexts);
    end;

    local procedure ReadServices(ServiceNames: List of [Text]; var Services: List of [Text])
    var
        ServiceName: Text;
    begin
        if this.ProviderId = '' then
            Error(this.ProviderIdMissingErr);
        foreach ServiceName in ServiceNames do
            if (ServiceName <> '') and not Services.Contains(ServiceName) then
                Services.Add(ServiceName);
        if Services.Count() = 0 then
            Error(this.NoServicesErr);
        this.ResetState();
        this.LoadRows(Services);
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

    // ---- reading -------------------------------------------------------------------------------

    local procedure ResetState()
    begin
        this.TempServiceSetup.Reset();
        this.TempServiceSetup.DeleteAll(false);
        this.TempProfileSetup.Reset();
        this.TempProfileSetup.DeleteAll(false);
        this.TempDynamicLayout.Reset();
        this.TempDynamicLayout.DeleteAll(false);
        this.TempLayoutCondition.Reset();
        this.TempLayoutCondition.DeleteAll(false);
        this.TempLayoutAction.Reset();
        this.TempLayoutAction.DeleteAll(false);
        this.TempLayoutActionLine.Reset();
        this.TempLayoutActionLine.DeleteAll(false);
        this.TempCaptionAdmin.Reset();
        this.TempCaptionAdmin.DeleteAll(false);
        this.TempCategoryTransl.Reset();
        this.TempCategoryTransl.DeleteAll(false);
        Clear(this.CategoryDescriptions);
        Clear(this.ProfileDescriptions);
        Clear(this.UsedCategories);
        Clear(this.UsedProfiles);
        Clear(this.StageIds);
        Clear(this.LabelLines);
        Clear(this.LabelNameByKey);
        Clear(this.LabelNames);
    end;

    local procedure LoadRows(Services: List of [Text])
    var
        ProfileSetup: Record "MobileNAV Profile Setup";
        ServiceName: Text;
    begin
        foreach ServiceName in Services do begin
            if not this.HasService(ServiceName) then
                Error(this.ServiceNotFoundErr, ServiceName);
            this.LoadServiceRows(ServiceName, false);
            this.LoadLayouts(ServiceName);
            this.LoadLayoutActions(ServiceName);
            this.LoadCaptionRows(ServiceName);
            if this.IncludeProfiles then begin
                ProfileSetup.SetRange(ID, ServiceName);
                this.LoadProfileRows(ProfileSetup);
            end;
        end;
        this.LoadRelationTargets(Services);
        this.LoadMasterData();
        this.LoadCategoryTranslations();
        if this.IncludeProfiles then begin
            ProfileSetup.Reset();
            ProfileSetup.SetRange("Profile Type", ProfileSetup."Profile Type"::User);
            this.LoadProfileRows(ProfileSetup);
        end;
    end;

    local procedure LoadServiceRows(ServiceName: Text; MainOnly: Boolean)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Service Name", ServiceName);
        if MainOnly then
            ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if ServiceSetup.FindSet() then
            repeat
                this.TempServiceSetup := ServiceSetup;
                if this.TempServiceSetup.Insert(false) then; // A row read twice is kept once.
            until ServiceSetup.Next() = 0;
    end;

    // The Main rows of the pages the selected pages link to, so a Link or Lookup can name them.
    local procedure LoadRelationTargets(Services: List of [Text])
    var
        TempRelationLine: Record "MobileNAV Service Setup" temporary;
        Targets: List of [Text];
        Target: Text;
    begin
        TempRelationLine.Copy(this.TempServiceSetup, true);
        TempRelationLine.Reset();
        TempRelationLine.SetRange("Line Type", TempRelationLine."Line Type"::Relation);
        TempRelationLine.SetFilter(RelatedPageName, '<>%1', '');
        if TempRelationLine.FindSet() then
            repeat
                Target := TempRelationLine.RelatedPageName;
                if not Services.Contains(Target) and not Targets.Contains(Target) then
                    Targets.Add(Target);
            until TempRelationLine.Next() = 0;
        foreach Target in Targets do
            this.LoadServiceRows(Target, true);
    end;

    local procedure LoadMasterData()
    var
        MobileNAVMasterData: Record "MobileNAV Master Data";
    begin
        MobileNAVMasterData.SetLoadFields(Type, "Code", Description);
        MobileNAVMasterData.SetFilter(Type, '%1|%2', MobileNAVMasterData.Type::Category, MobileNAVMasterData.Type::Profile);
        if MobileNAVMasterData.FindSet() then
            repeat
                if MobileNAVMasterData.Type = MobileNAVMasterData.Type::Category then
                    this.CategoryDescriptions.Set(MobileNAVMasterData."Code", MobileNAVMasterData.Description)
                else
                    this.ProfileDescriptions.Set(MobileNAVMasterData."Code", MobileNAVMasterData.Description);
            until MobileNAVMasterData.Next() = 0;
    end;

    local procedure LoadCategoryTranslations()
    var
        CategoryTransl: Record "MobileNAV Category Transl.";
    begin
        if CategoryTransl.FindSet() then
            repeat
                this.TempCategoryTransl := CategoryTransl;
                this.TempCategoryTransl.Insert(false);
            until CategoryTransl.Next() = 0;
    end;

    // Copies the profile rows within the caller's filter.
    local procedure LoadProfileRows(var ProfileSetup: Record "MobileNAV Profile Setup")
    begin
        if ProfileSetup.FindSet() then
            repeat
                this.TempProfileSetup := ProfileSetup;
                if this.TempProfileSetup.Insert(false) then; // A row read twice is kept once.
            until ProfileSetup.Next() = 0;
    end;

    local procedure LoadLayouts(ServiceName: Text)
    var
        DynamicLayout: Record "MobileNAV Dynamic Layout";
        LayoutCondition: Record "MobileNAV D. L. Condition";
    begin
        DynamicLayout.SetRange("Service Name", ServiceName);
        if DynamicLayout.FindSet() then
            repeat
                this.TempDynamicLayout := DynamicLayout;
                this.TempDynamicLayout.Insert(false);
            until DynamicLayout.Next() = 0;
        LayoutCondition.SetRange("Service Name", ServiceName);
        if LayoutCondition.FindSet() then
            repeat
                this.TempLayoutCondition := LayoutCondition;
                this.TempLayoutCondition.Insert(false);
            until LayoutCondition.Next() = 0;
    end;

    local procedure LoadLayoutActions(ServiceName: Text)
    var
        LayoutAction: Record "MobileNAV D. L. Action";
        LayoutActionLine: Record "MobileNAV D. L. Action Line";
    begin
        LayoutAction.SetRange("Service Name", ServiceName);
        if LayoutAction.FindSet() then
            repeat
                this.TempLayoutAction := LayoutAction;
                this.TempLayoutAction.Insert(false);
            until LayoutAction.Next() = 0;
        LayoutActionLine.SetRange("Service Name", ServiceName);
        if LayoutActionLine.FindSet() then
            repeat
                this.TempLayoutActionLine := LayoutActionLine;
                this.TempLayoutActionLine.Insert(false);
            until LayoutActionLine.Next() = 0;
    end;

    local procedure LoadCaptionRows(ServiceName: Text)
    var
        CaptionAdmin: Record "MobileNAV CaptionML Admin.";
        TempMainLine: Record "MobileNAV Service Setup" temporary;
    begin
        if not this.FindMain(ServiceName, TempMainLine) then
            exit;
        CaptionAdmin.SetRange("Page ID", TempMainLine."Object ID");
        if CaptionAdmin.FindSet() then
            repeat
                this.TempCaptionAdmin := CaptionAdmin;
                if this.TempCaptionAdmin.Insert(false) then; // Two services on one page share its captions.
            until CaptionAdmin.Next() = 0;
    end;

    // ---- row access ------------------------------------------------------------------------------

    local procedure ShareLines(var TempServiceLine: Record "MobileNAV Service Setup" temporary; ServiceName: Text)
    begin
        TempServiceLine.Copy(this.TempServiceSetup, true);
        TempServiceLine.Reset();
        TempServiceLine.SetRange("Service Name", ServiceName);
    end;

    // The field rows of a service in display order, as MobileNAV sorts them.
    local procedure ShareFields(var TempFieldLine: Record "MobileNAV Service Setup" temporary; ServiceName: Text)
    begin
        this.ShareLines(TempFieldLine, ServiceName);
        TempFieldLine.SetCurrentKey("Service Name", "Line Type", "Order");
        TempFieldLine.SetRange("Line Type", TempFieldLine."Line Type"::"Field");
    end;

    local procedure FindMain(ServiceName: Text; var TempMainLine: Record "MobileNAV Service Setup" temporary): Boolean
    begin
        this.ShareLines(TempMainLine, ServiceName);
        TempMainLine.SetRange("Line Type", TempMainLine."Line Type"::Main);
        exit(TempMainLine.FindFirst());
    end;

    local procedure FindFieldByLine(ServiceName: Text; PageLineNo: Integer; var TempFieldLine: Record "MobileNAV Service Setup" temporary): Boolean
    begin
        this.ShareFields(TempFieldLine, ServiceName);
        TempFieldLine.SetRange("Page Line No.", PageLineNo);
        exit(TempFieldLine.FindFirst());
    end;

    local procedure FindRelation(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary): Boolean
    begin
        this.ShareDetails(TempRelationLine, TempFieldLine);
        TempRelationLine.SetRange("Line Type", TempRelationLine."Line Type"::Relation);
        exit(TempRelationLine.FindFirst());
    end;

    // The first filter of a relation, when it is a FIELD filter: a Link's own filter.
    local procedure FindLinkFilter(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempFilterLine: Record "MobileNAV Service Setup" temporary): Boolean
    begin
        this.ShareDetails(TempFilterLine, TempFieldLine);
        TempFilterLine.SetRange("Line Type", TempFilterLine."Line Type"::"Filter");
        if not TempFilterLine.FindFirst() then
            exit(false);
        exit(TempFilterLine.FilterType = TempFilterLine.FilterType::"FIELD");
    end;

    local procedure PageRef(ServiceName: Text): Text
    var
        TempMainLine: Record "MobileNAV Service Setup" temporary;
    begin
        if this.FindMain(ServiceName, TempMainLine) then
            exit('Page::"' + TempMainLine.Name + '"');
        // The target page is not set up: the service name makes the compiler point at it.
        exit('Page::"' + ServiceName + '"');
    end;

    local procedure IsOwn(var TempMainLine: Record "MobileNAV Service Setup" temporary): Boolean
    begin
        exit(this.ServiceLookup.IsOwnServicePage(TempMainLine.Name, TempMainLine."Object ID"));
    end;

    // ---- one page --------------------------------------------------------------------------------

    local procedure DefinePage(ServiceName: Text; var Output: List of [Text])
    var
        TempMainLine: Record "MobileNAV Service Setup" temporary;
        Head: List of [Text];
        Body: List of [Text];
        Tail: List of [Text];
        Notes: List of [Text];
        MineCalls: List of [Text];
        FilterCalls: List of [Text];
        MineFields: List of [Text];
        Emitted: List of [Integer];
        IsDialog: Boolean;
        PageFunctions: Boolean;
    begin
        this.FindMain(ServiceName, TempMainLine);
        IsDialog := TempMainLine."Page Type" = TempMainLine."Page Type"::Report;
        if this.IsOwn(TempMainLine) then
            this.PublishCalls(TempMainLine, IsDialog, Head, Notes);
        PageFunctions := this.PageShapeCalls(TempMainLine, IsDialog, Head);
        this.PageSettings(TempMainLine, Head);
        this.FunctionSettings(TempMainLine, Head);
        this.MenuAndCaptions(TempMainLine, Head);
        this.PageFiltersAndScope(ServiceName, MineCalls, FilterCalls, MineFields);
        Head.AddRange(MineCalls);
        this.Operations(ServiceName, 0, Head);
        this.Controls(TempMainLine, PageFunctions or IsDialog, MineFields, Notes, Body, Emitted);
        if (Emitted.Count() > 0) and not this.IncludeHidden and this.OrdersFirst(ServiceName, Emitted) then
            Head.Add('.OrderAsDeclared()');
        this.FlowFilters(ServiceName, Tail);
        Tail.AddRange(FilterCalls);
        this.SavedFilters(ServiceName, Tail);
        this.Layouts(ServiceName, Tail);
        this.Wizard(TempMainLine, Tail);
        this.RelationNotes(ServiceName, Emitted, Notes);
        Head.AddRange(Body);
        Head.AddRange(Tail);
        this.WriteProcedure(TempMainLine, Head, Notes, Output);
    end;

    local procedure MenuAndCaptions(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Head: List of [Text])
    begin
        if TempMainLine.Category <> '' then
            Head.Add('.MenuCategory(' + this.Category(TempMainLine.Category) + ')');
        this.Captions(TempMainLine, 0, '', Head);
        if this.IncludeProfiles then
            this.ProfilePages(TempMainLine."Service Name", TempMainLine.Category, Head);
    end;

    local procedure PublishCalls(var TempMainLine: Record "MobileNAV Service Setup" temporary; IsDialog: Boolean; var Head: List of [Text]; var Notes: List of [Text])
    var
        FunctionCodeunit: Text;
        ServiceRef: Text;
    begin
        ServiceRef := this.Tok(TempMainLine."Service Name", TempMainLine."Service Name" + ' Service');
        if IsDialog then
            Head.Add('.PublishAsDialog(' + ServiceRef + ')')
        else
            Head.Add('.Publish(' + ServiceRef + ')');
        if TempMainLine.DisplayInMenu then
            Head.Add('.ShowInMenu()');
        if IsDialog and (TempMainLine.OptionValues2 <> '') then begin
            FunctionCodeunit := this.ServiceLookup.CodeunitNameOfService(TempMainLine.OptionValues2);
            if FunctionCodeunit <> '' then
                Head.Add('.Functions(Codeunit::"' + FunctionCodeunit + '", ' + this.Tok(TempMainLine.OptionValues2, TempMainLine.OptionValues2 + ' Service') + ')')
            else
                Notes.Add(StrSubstNo(this.DialogCodeunitNoteTok, TempMainLine.OptionValues2));
        end;
        if TempMainLine."Main Menu Action" <> TempMainLine."Main Menu Action"::Create then
            Head.Add('.MainMenuAction(Enum::"BJF MN Main Menu Action"::' + this.ServiceOption(TempMainLine.FieldNo("Main Menu Action"), TempMainLine."Main Menu Action", 'Create') + ')');
    end;

    // Returns true when the page has a page functions codeunit of its own, whose button functions are always named.
    local procedure PageShapeCalls(var TempMainLine: Record "MobileNAV Service Setup" temporary; IsDialog: Boolean; var Head: List of [Text]) PageFunctions: Boolean
    var
        Companion: Text;
    begin
        Companion := this.ServiceLookup.CodeunitNameOfService(TempMainLine."Service Name");
        PageFunctions := not IsDialog and not (Companion in ['', 'MobileNAV Page Functions', 'BJF MN Table Functions']);
        this.AddIf(Head, PageFunctions, '.PageFunctions(Codeunit::"' + Companion + '")');
        this.AddIf(Head, not (TempMainLine."Page Type" in [TempMainLine."Page Type"::ListCard, TempMainLine."Page Type"::Report]),
            '.PageType(Enum::"BJF MN Page Type"::' + this.ServiceOption(TempMainLine.FieldNo("Page Type"), TempMainLine."Page Type", 'ListCard') + ')');
        this.AddIf(Head, TempMainLine."Page Insert", '.Insertable()');
        this.AddIf(Head, TempMainLine."Page Delete", '.Deletable()');
        this.AddIf(Head, TempMainLine."Page Update" and not this.HasEditableVisibleField(TempMainLine."Service Name"), '.Updatable()');
        exit(PageFunctions);
    end;

    local procedure WriteProcedure(var TempMainLine: Record "MobileNAV Service Setup" temporary; Calls: List of [Text]; Notes: List of [Text]; var Output: List of [Text])
    var
        Lines: List of [Text];
        Call: Text;
        Kind: Text;
    begin
        if this.IsOwn(TempMainLine) then
            Kind := 'a page of its own'
        else
            Kind := 'MobileNAV''s own page';
        Lines.Add('    /// <summary>Service ' + TempMainLine."Service Name" + ', page "' + TempMainLine.Name + '" (' + Kind + ').</summary>');
        Lines.Add('    /// <param name="Configuration">The builder that collects the declarations.</param>');
        Lines.Add('    local procedure Define' + this.ALSource.Identifier(TempMainLine."Service Name") + '(var Configuration: Codeunit "BJF MN Config Builder")');
        Lines.Add('    begin');
        foreach Call in Notes do
            Lines.Add('        // ' + Call);
        Lines.Add('        Configuration.Page(' + this.PageRef(TempMainLine."Service Name") + ')');
        foreach Call in Calls do
            if Call.Trim().StartsWith('//') then
                Lines.Add('            ' + Call.Trim())
            else
                Lines.Add('            ' + Call);
        this.EndStatement(Lines);
        Lines.Add('    end;');
        Output.AddRange(Lines);
    end;

    // The statement ends on the last call, which may carry a trailing comment.
    local procedure EndStatement(var Lines: List of [Text])
    var
        Line: Text;
        Index: Integer;
        Position: Integer;
    begin
        Index := Lines.Count();
        while (Index > 0) and Lines.Get(Index).Trim().StartsWith('//') do
            Index -= 1;
        if Index = 0 then
            exit;
        Line := Lines.Get(Index);
        Position := Line.IndexOf('  //');
        if Position > 0 then
            Line := Line.Substring(1, Position - 1) + ';' + Line.Substring(Position)
        else
            Line += ';';
        Lines.Set(Index, Line);
    end;

    local procedure HasEditableVisibleField(ServiceName: Text): Boolean
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
    begin
        this.ShareFields(TempFieldLine, ServiceName);
        TempFieldLine.SetRange(Editable, true);
        TempFieldLine.SetRange(Visible, true);
        exit(not TempFieldLine.IsEmpty());
    end;

    local procedure PageSettings(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    begin
        this.TitlePrefixCalls(TempMainLine, Calls);
        this.ToolbarCalls(TempMainLine, Calls);
        this.AutoRefreshCalls(TempMainLine, Calls);
        this.AddIf(Calls, TempMainLine.AutoOpenSingleListItemOnOpen, '.AutoOpenSingleRecord()');
        this.AddIf(Calls, TempMainLine.ShowFilterPanelAutomatically, '.ShowFilterPanel()');
        this.AddIf(Calls, TempMainLine."Show Unread Record Count", '.ShowUnreadCount()');
        this.AddIf(Calls, TempMainLine."Filter By Parent Enabled", '.FilterByParent()');
        this.AddIf(Calls, TempMainLine."List Display Limit" <> 0, '.ListLimit(' + this.Num(TempMainLine."List Display Limit") + ')');
        this.AddIf(Calls, TempMainLine."Chunk Size" <> 0, '.ChunkSize(' + this.Num(TempMainLine."Chunk Size") + ')');
        this.AddIf(Calls, TempMainLine."Check for Changes Period" <> 0, '.CheckForChanges(' + this.Num(TempMainLine."Check for Changes Period") + ')');
        this.AddIf(Calls, TempMainLine."Default DrillDown" <> '', '.DefaultDrillDown(' + this.ALSource.Quoted(TempMainLine."Default DrillDown") + ')');
    end;

    local procedure TitlePrefixCalls(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    var
        Prefix: Enum "BJF MN Title Prefix";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        Names := Prefix.Names();
        Ordinals := Prefix.Ordinals();
        for Index := 1 to Ordinals.Count() do begin
            Prefix := Enum::"BJF MN Title Prefix".FromInteger(Ordinals.Get(Index));
            this.AddIf(Calls, this.FlagValue(TempMainLine, this.Vocabulary.TitlePrefixFieldNo(Prefix)),
                '.HideTitlePrefix(Enum::"BJF MN Title Prefix"::' + Names.Get(Index) + ')');
        end;
    end;

    local procedure ToolbarCalls(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    var
        ToolbarButton: Enum "BJF MN Toolbar Button";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        Names := ToolbarButton.Names();
        Ordinals := ToolbarButton.Ordinals();
        for Index := 1 to Ordinals.Count() do begin
            ToolbarButton := Enum::"BJF MN Toolbar Button".FromInteger(Ordinals.Get(Index));
            this.AddIf(Calls, this.FlagValue(TempMainLine, this.Vocabulary.ToolbarButtonFieldNo(ToolbarButton)),
                '.HideButton(Enum::"BJF MN Toolbar Button"::' + Names.Get(Index) + ')');
        end;
    end;

    local procedure AutoRefreshCalls(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    var
        Moment: Enum "BJF MN Auto Refresh";
        Names: List of [Text];
        Ordinals: List of [Integer];
        Index: Integer;
    begin
        Names := Moment.Names();
        Ordinals := Moment.Ordinals();
        for Index := 1 to Ordinals.Count() do begin
            Moment := Enum::"BJF MN Auto Refresh".FromInteger(Ordinals.Get(Index));
            this.AddIf(Calls, this.FlagValue(TempMainLine, this.Vocabulary.AutoRefreshFieldNo(Moment)),
                '.AutoRefresh(Enum::"BJF MN Auto Refresh"::' + Names.Get(Index) + ')');
        end;
    end;

    // A Boolean field of a MobileNAV Service Setup record, read by the field number the Vocabulary gives.
    local procedure FlagValue(var TempMainLine: Record "MobileNAV Service Setup" temporary; FieldNo: Integer): Boolean
    var
        RecRef: RecordRef;
        Current: FieldRef;
    begin
        RecRef.GetTable(TempMainLine);
        Current := RecRef.Field(FieldNo);
        exit(Current.Value());
    end;

    // The page settings that name a function or a style, which become Labels, and the mine and assign settings.
    local procedure FunctionSettings(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    begin
        if TempMainLine."OnOpen Function Name" <> '' then
            Calls.Add('.OnOpen(' + this.Tok(TempMainLine."OnOpen Function Name", TempMainLine."OnOpen Function Name") + ')');
        if TempMainLine."OnClose Function Name" <> '' then
            Calls.Add('.OnClose(' + this.Tok(TempMainLine."OnClose Function Name", TempMainLine."OnClose Function Name") + ')');
        this.AddIf(Calls, TempMainLine."Mine Filter Type" <> TempMainLine."Mine Filter Type"::MineAll,
            '.MineFilter(Enum::"BJF MN Mine Filter"::' + this.ServiceOption(TempMainLine.FieldNo("Mine Filter Type"), TempMainLine."Mine Filter Type", 'MineAll') + ')');
        this.AssignToMe(TempMainLine, Calls);
        if TempMainLine."Page Style" <> '' then
            Calls.Add('.Style(' + this.Tok(TempMainLine."Page Style", TempMainLine."Page Style" + ' Style') + ')');
    end;

    local procedure AssignToMe(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    var
        CardAssign: Text;
        ListAssign: Text;
        AssignCall: Text;
    begin
        CardAssign := this.ServiceOption(TempMainLine.FieldNo("Card Assign to me"), TempMainLine."Card Assign to me", 'Hide');
        ListAssign := this.ServiceOption(TempMainLine.FieldNo("List Assign to me"), TempMainLine."List Assign to me", 'Hide');
        if (CardAssign = 'Hide') and (ListAssign = 'Hide') then
            exit;
        if CardAssign <> 'Hide' then
            AssignCall := '.AssignToMe(Enum::"BJF MN Assign To Me"::' + CardAssign + ')'
        else
            AssignCall := '.AssignToMe(Enum::"BJF MN Assign To Me"::' + ListAssign + ')';
        if CardAssign <> ListAssign then
            AssignCall += '  // ' + StrSubstNo(this.AssignToMeCommentTok, CardAssign, ListAssign);
        Calls.Add(AssignCall);
    end;

    local procedure Captions(var TempMainLine: Record "MobileNAV Service Setup" temporary; ControlId: Integer; ControlHint: Text; var Calls: List of [Text])
    var
        TempCaption: Record "MobileNAV CaptionML Admin." temporary;
    begin
        TempCaption.Copy(this.TempCaptionAdmin, true);
        TempCaption.Reset();
        TempCaption.SetRange("Page ID", TempMainLine."Object ID");
        TempCaption.SetRange("Control ID", ControlId);
        if TempCaption.FindSet() then
            repeat
                Calls.Add('.Caption(' + this.Tok(TempCaption."Language Code", TempCaption."Language Code" + ' Language') + ', ' +
                    this.Lbl(TempCaption."Caption ML", this.ALSource.Identifier(TempMainLine."Service Name") + this.ALSource.Identifier(ControlHint) + TempCaption."Language Code" + 'Caption', 250) + ')');
            until TempCaption.Next() = 0;
    end;

    local procedure ProfilePages(ServiceName: Text; ServiceCategory: Code[20]; var Calls: List of [Text])
    var
        TempProfileLine: Record "MobileNAV Profile Setup" temporary;
    begin
        TempProfileLine.Copy(this.TempProfileSetup, true);
        TempProfileLine.Reset();
        TempProfileLine.SetRange("Profile Type", TempProfileLine."Profile Type"::"Page");
        TempProfileLine.SetRange(ID, ServiceName);
        TempProfileLine.SetRange("Control ID", 0);
        if TempProfileLine.FindSet() then
            repeat
                this.ProfilePage(TempProfileLine, ServiceCategory, Calls);
            until TempProfileLine.Next() = 0;
    end;

    local procedure ProfilePage(var TempProfileLine: Record "MobileNAV Profile Setup" temporary; ServiceCategory: Code[20]; var Calls: List of [Text])
    begin
        if TempProfileLine."Exclude from Profile" then
            Calls.Add('.ExcludeFromProfile(' + this.ProfileRef(TempProfileLine."Profile") + ')');
        if TempProfileLine."Use as Online" then
            Calls.Add('.OnlineInProfile(' + this.ProfileRef(TempProfileLine."Profile") + ')');
        if TempProfileLine."Lookup Only" then
            Calls.Add('.LookupOnlyInProfile(' + this.ProfileRef(TempProfileLine."Profile") + ')');
        if (TempProfileLine.Category <> '') and (TempProfileLine.Category <> ServiceCategory) then
            Calls.Add('.MenuCategoryInProfile(' + this.ProfileRef(TempProfileLine."Profile") + ', ' + this.Category(TempProfileLine.Category) + ')');
    end;

    // The page's filters: a filter on the user's own records becomes a MineOnly() call and names a mine field, any other a page filter call.
    local procedure PageFiltersAndScope(ServiceName: Text; var MineCalls: List of [Text]; var FilterCalls: List of [Text]; var MineFields: List of [Text])
    var
        TempFilterLine: Record "MobileNAV Service Setup" temporary;
    begin
        this.ShareLines(TempFilterLine, ServiceName);
        TempFilterLine.SetRange("Line Type", TempFilterLine."Line Type"::"Filter");
        TempFilterLine.SetRange("Page Line No.", 0);
        TempFilterLine.SetRange("Relation No.", 0);
        if TempFilterLine.FindSet() then
            repeat
                if TempFilterLine."Filter Comparsion Type" = TempFilterLine."Filter Comparsion Type"::Own then begin
                    MineCalls.Add('.MineOnly(' + this.ALSource.Quoted(TempFilterLine.SourceFieldName) + ')');
                    MineFields.Add(TempFilterLine.SourceFieldName);
                end else
                    FilterCalls.Add(this.PageFilterCall(TempFilterLine));
            until TempFilterLine.Next() = 0;
    end;

    local procedure PageFilterCall(var TempFilterLine: Record "MobileNAV Service Setup" temporary): Text
    var
        Comparison: Text;
        Call: Text;
        Target: Text;
    begin
        Comparison := this.ServiceOption(TempFilterLine.FieldNo("Filter Comparsion Type"), TempFilterLine."Filter Comparsion Type", 'Equal');
        case true of
            (TempFilterLine.FilterType = TempFilterLine.FilterType::"CONST") and this.IsComparison(Comparison):
                Call := '.PageFilter(' + this.ALSource.Quoted(TempFilterLine.SourceFieldName) + ', Enum::"BJF MN Comparison"::' + Comparison + ', ' + this.ALSource.Quoted(TempFilterLine.FilterValue) + ')';
            TempFilterLine.FilterType = TempFilterLine.FilterType::"FILTER":
                Call := '.PageFilterExpression(' + this.ALSource.Quoted(TempFilterLine.SourceFieldName) + ', ' + this.ALSource.Quoted(TempFilterLine.FilterValue) + ')';
            else begin
                Target := TempFilterLine.DestFieldName;
                if Target = '' then
                    Target := TempFilterLine.FilterValue;
                exit(StrSubstNo(this.PageFilterCommentTok, TempFilterLine.SourceFieldName,
                    this.ServiceOption(TempFilterLine.FieldNo(FilterType), TempFilterLine.FilterType, 'CONST'), Comparison, Target));
            end;
        end;
        if TempFilterLine."Filter Scope" <> TempFilterLine."Filter Scope"::Both then
            Call += '.Scope(Enum::"BJF MN Filter Scope"::' + this.ServiceOption(TempFilterLine.FieldNo("Filter Scope"), TempFilterLine."Filter Scope", 'Both') + ')';
        exit(Call);
    end;

    local procedure Operations(ServiceName: Text; PageLineNo: Integer; var Calls: List of [Text])
    var
        TempOperationLine: Record "MobileNAV Service Setup" temporary;
        Kind: Text;
    begin
        this.ShareLines(TempOperationLine, ServiceName);
        TempOperationLine.SetRange("Line Type", TempOperationLine."Line Type"::Operation);
        TempOperationLine.SetRange("Page Line No.", PageLineNo);
        TempOperationLine.SetRange("Relation No.", 0);
        if TempOperationLine.FindSet() then
            repeat
                Kind := this.ServiceOption(TempOperationLine.FieldNo("Operation Type"), TempOperationLine."Operation Type", '');
                if TempOperationLine.FilterType = TempOperationLine.FilterType::"FIELD" then
                    Calls.Add('.Operation(Enum::"BJF MN Operation Type"::' + Kind + ', ' + this.ALSource.Quoted(TempOperationLine.SourceFieldName) + ', ' + this.ALSource.Quoted(TempOperationLine.DestFieldName) + ')')
                else
                    Calls.Add('.OperationValue(Enum::"BJF MN Operation Type"::' + Kind + ', ' + this.ALSource.Quoted(TempOperationLine.SourceFieldName) + ', ' + this.ALSource.Quoted(TempOperationLine.FilterValue) + ')');
            until TempOperationLine.Next() = 0;
    end;

    // ---- controls --------------------------------------------------------------------------------

    // Page lines of the field rows inside a group: declared even when hidden, or the group would lose them.
    local procedure InGroups(ServiceName: Text): List of [Integer]
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
        Inside: List of [Integer];
        OpenGroup: Boolean;
    begin
        this.ShareFields(TempFieldLine, ServiceName);
        if TempFieldLine.FindSet() then
            repeat
                case TempFieldLine.FieldClass of
                    TempFieldLine.FieldClass::GroupStart:
                        OpenGroup := true;
                    TempFieldLine.FieldClass::GroupEnd:
                        OpenGroup := false;
                    else
                        if OpenGroup then
                            Inside.Add(TempFieldLine."Page Line No.");
                end;
            until TempFieldLine.Next() = 0;
        exit(Inside);
    end;

    // Page lines of fields a wizard stage shows: declared even when hidden, so the stage keeps them.
    local procedure Staged(ServiceName: Text): List of [Integer]
    var
        TempStageLine: Record "MobileNAV Service Setup" temporary;
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
        Shown: List of [Integer];
    begin
        this.ShareLines(TempStageLine, ServiceName);
        TempStageLine.SetRange("Line Type", TempStageLine."Line Type"::Stage);
        if TempStageLine.IsEmpty() then
            exit(Shown);
        this.ShareFields(TempFieldLine, ServiceName);
        TempFieldLine.SetFilter(Stage, '<>%1', '');
        if TempFieldLine.FindSet() then
            repeat
                if this.ShownInAnyStage(TempFieldLine.Stage) then
                    Shown.Add(TempFieldLine."Page Line No.");
            until TempFieldLine.Next() = 0;
        exit(Shown);
    end;

    local procedure ShownInAnyStage(StageStates: Text): Boolean
    var
        StageToken: Text;
    begin
        foreach StageToken in StageStates.Split(',') do
            if StageToken <> this.StageManagement.HiddenToken() then
                exit(true);
        exit(false);
    end;

    local procedure Controls(var TempMainLine: Record "MobileNAV Service Setup" temporary; NamesOwnFunctions: Boolean; Mine: List of [Text]; var Notes: List of [Text]; var Body: List of [Text]; var Emitted: List of [Integer])
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
        Forced: List of [Integer];
        Skipped: Integer;
    begin
        Forced := this.InGroups(TempMainLine."Service Name");
        Forced.AddRange(this.Staged(TempMainLine."Service Name"));
        this.ShareFields(TempFieldLine, TempMainLine."Service Name");
        if TempFieldLine.FindSet() then
            repeat
                if not this.ControlRow(TempMainLine, TempFieldLine, NamesOwnFunctions, Forced, Mine, Body, Emitted) then
                    Skipped += 1;
            until TempFieldLine.Next() = 0;
        if Skipped > 0 then
            Notes.Add(StrSubstNo(this.HiddenLeftOutNoteTok, Skipped));
    end;

    // One field row: a group start or end, a control, or a flow filter, which FlowFilters() declares. False when a control is left out.
    local procedure ControlRow(var TempMainLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary; NamesOwnFunctions: Boolean; Forced: List of [Integer]; Mine: List of [Text]; var Body: List of [Text]; var Emitted: List of [Integer]): Boolean
    begin
        case TempFieldLine.FieldClass of
            TempFieldLine.FieldClass::GroupStart:
                Body.Add('.Group(' + this.Category(TempFieldLine.Category) + ')');
            TempFieldLine.FieldClass::GroupEnd:
                Body.Add('.EndGroup()');
            TempFieldLine.FieldClass::FlowFilter:
                exit(true);
            else begin
                if not this.Control(TempMainLine, TempFieldLine, NamesOwnFunctions, Forced.Contains(TempFieldLine."Page Line No."), Mine.Contains(TempFieldLine.FieldName), Body) then
                    exit(false);
                Emitted.Add(TempFieldLine."Page Line No.");
            end;
        end;
        exit(true);
    end;

    // The builder calls for one control row. False when the row is left out.
    local procedure Control(var TempMainLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary; NamesOwnFunctions: Boolean; Forced: Boolean; UserScope: Boolean; var Calls: List of [Text]): Boolean
    var
        TempRelationLine: Record "MobileNAV Service Setup" temporary;
        Comments: List of [Text];
        Kind: Text;
        Verb: Text;
        Mods: Text;
    begin
        if (TempFieldLine."Function Name" <> '') and not TempFieldLine.Visible then
            exit(this.HiddenButton(TempFieldLine, Forced, Calls));
        Kind := this.ControlKind(TempFieldLine, TempRelationLine);
        if this.IsLeftOut(TempMainLine, TempFieldLine, Kind, Forced) then
            exit(false);
        Verb := this.ControlVerb(TempMainLine, TempFieldLine, TempRelationLine, Kind, NamesOwnFunctions, UserScope, Mods, Comments);
        Mods += this.BehaviorMods(TempFieldLine, Kind);
        if Kind in ['Lookup', 'Link'] then
            Mods += this.RelationDetails(TempFieldLine, TempRelationLine, Kind);
        Mods += this.ControlSettings(TempFieldLine, Kind, Comments);
        if this.IncludeProfiles and (Kind <> 'FieldControl') then
            Mods += this.ProfileScope(TempFieldLine, Comments);
        this.AddControlCall(TempMainLine, TempFieldLine, Verb + Mods, Comments, Calls);
        exit(true);
    end;

    // The control's call with its comments, then its captions and its operations.
    local procedure AddControlCall(var TempMainLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary; Call: Text; Comments: List of [Text]; var Calls: List of [Text])
    begin
        if Comments.Count() > 0 then
            Call += '  // ' + this.Join(Comments, '; ');
        Calls.Add(Call);
        if this.IncludeAllCaptions then
            this.Captions(TempMainLine, TempFieldLine.ControlID, TempFieldLine.FieldName, Calls);
        this.Operations(TempFieldLine."Service Name", TempFieldLine."Page Line No.", Calls);
    end;

    // A hidden field of MobileNAV's own page is left out unless hidden fields are included or a group or stage needs it.
    local procedure IsLeftOut(var TempMainLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary; Kind: Text; Forced: Boolean): Boolean
    begin
        if (Kind <> 'Field') or TempFieldLine.Visible then
            exit(false);
        exit(not (this.IncludeHidden or Forced or this.IsOwn(TempMainLine)));
    end;

    local procedure ControlVerb(var TempMainLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary; Kind: Text; NamesOwnFunctions: Boolean; UserScope: Boolean; var Mods: Text; var Comments: List of [Text]): Text
    begin
        case Kind of
            'Button':
                exit(this.ButtonVerb(TempMainLine, TempFieldLine, NamesOwnFunctions, Mods));
            'FieldControl':
                exit(this.FieldControlVerb(TempFieldLine, Comments));
            'Lookup', 'Link':
                exit(this.RelationVerb(TempFieldLine, TempRelationLine, Kind));
            'Scan':
                exit('.Scan(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ')');
        end;
        exit(this.FieldVerb(TempFieldLine, UserScope, Mods, Comments));
    end;

    // Button() makes a button visible, so a hidden one is left as MobileNAV has it, with a comment when it is declared.
    local procedure HiddenButton(var TempFieldLine: Record "MobileNAV Service Setup" temporary; Forced: Boolean; var Calls: List of [Text]): Boolean
    begin
        if not (this.IncludeHidden or Forced) then
            exit(false);
        Calls.Add(StrSubstNo(this.HiddenButtonCommentTok, TempFieldLine.FieldName, TempFieldLine."Function Name"));
        exit(true);
    end;

    // Button, FieldControl, Lookup, Link, Scan or Field, in that order of precedence.
    local procedure ControlKind(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary): Text
    var
        Shape: Text;
    begin
        if TempFieldLine."Function Name" <> '' then
            exit('Button');
        if this.Vocabulary.IsMobileType(this.MobileTypeName(TempFieldLine), Enum::"BJF MN Mobile Type"::FieldControl) then
            exit('FieldControl');
        Shape := this.VisibleRelationShape(TempFieldLine, TempRelationLine);
        if Shape <> '' then
            exit(Shape);
        if this.Vocabulary.IsMobileType(this.MobileTypeName(TempFieldLine), Enum::"BJF MN Mobile Type"::Barcode) and TempFieldLine.Visible and TempFieldLine.Editable then
            exit('Scan');
        exit('Field');
    end;

    // Lookup or Link for a visible control with a relation the builder can write, empty otherwise.
    local procedure VisibleRelationShape(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary): Text
    begin
        if not this.FindRelation(TempFieldLine, TempRelationLine) then
            exit('');
        if not TempFieldLine.Visible then
            exit('');
        exit(this.RelationShape(TempFieldLine, TempRelationLine));
    end;

    local procedure ButtonVerb(var TempMainLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary; NamesOwnFunctions: Boolean; var Mods: Text): Text
    var
        FunctionName: Text;
    begin
        FunctionName := TempFieldLine."Function Name";
        this.AddModIf(Mods, not TempFieldLine.Editable, '.ReadOnly()');
        this.AddModIf(Mods, not this.Vocabulary.IsMobileType(this.MobileTypeName(TempFieldLine), Enum::"BJF MN Mobile Type"::Normal), '.MobileType(Enum::"BJF MN Mobile Type"::' + this.MobileTypeName(TempFieldLine) + ')');
        this.AddModIf(Mods, TempFieldLine."Function Type" <> TempFieldLine."Function Type"::Normal,
            '.FunctionType(Enum::"BJF MN Function Type"::"' + this.ServiceOption(TempFieldLine.FieldNo("Function Type"), TempFieldLine."Function Type", 'Normal') + '")');
        if NamesOwnFunctions or not this.IsDefaultFunction(TempMainLine."Table No.", FunctionName) then
            Mods += '.FunctionName(' + this.Tok(FunctionName, FunctionName + ' Function') + ')';
        exit('.Button(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ')');
    end;

    local procedure FieldControlVerb(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var Comments: List of [Text]): Text
    begin
        if TempFieldLine.Visible or not TempFieldLine.Editable then
            Comments.Add(StrSubstNo(this.FieldControlCommentTok, this.PyBool(TempFieldLine.Visible), this.PyBool(TempFieldLine.Editable)));
        exit('.FieldControl(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ')');
    end;

    local procedure RelationVerb(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary; Kind: Text): Text
    var
        TempLinkFilter: Record "MobileNAV Service Setup" temporary;
    begin
        if Kind = 'Lookup' then
            exit('.Lookup(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ', ' + this.PageRef(TempRelationLine.RelatedPageName) + ', ' +
                this.ALSource.Quoted(TempRelationLine.RelatedPgCodeFldName) + ', ' + this.ALSource.Quoted(TempRelationLine.RelatedPgDescFldName) + ')');
        this.FindLinkFilter(TempFieldLine, TempLinkFilter);
        exit('.Link(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ', ' + this.PageRef(TempRelationLine.RelatedPageName) + ', ' +
            this.ALSource.Quoted(TempLinkFilter.DestFieldName) + ', ' + this.ALSource.Quoted(TempLinkFilter.SourceFieldName) + ')');
    end;

    local procedure FieldVerb(var TempFieldLine: Record "MobileNAV Service Setup" temporary; UserScope: Boolean; var Mods: Text; var Comments: List of [Text]): Text
    var
        MobileType: Text;
    begin
        this.AddModIf(Mods, TempFieldLine.Editable, '.Editable()');
        this.AddModIf(Mods, not TempFieldLine.Visible, '.Hidden()');
        this.AddModIf(Mods, TempFieldLine."Visible as Filter", '.Filterable()');
        this.AddModIf(Mods, TempFieldLine.DisplayInMenu, '.InMenu()');
        MobileType := this.MobileTypeName(TempFieldLine);
        // Quantity() writes a Quantity mobile type and MineOnly() writes a UserID one.
        if not (this.Vocabulary.IsMobileType(MobileType, Enum::"BJF MN Mobile Type"::Quantity) or
            (this.Vocabulary.IsMobileType(MobileType, Enum::"BJF MN Mobile Type"::UserID) and UserScope) or
            this.Vocabulary.IsMobileType(MobileType, Enum::"BJF MN Mobile Type"::Normal)) then
            if not this.Vocabulary.IsMobileType(MobileType, Enum::"BJF MN Mobile Type"::Barcode) then
                Comments.Add(StrSubstNo(this.MobileTypeCommentTok, MobileType))
            else
                if TempFieldLine.Visible then
                    Comments.Add(StrSubstNo(this.BarcodeCommentTok, 'read-only'))
                else
                    Comments.Add(StrSubstNo(this.BarcodeCommentTok, 'hidden'));
        exit('.Field(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ')');
    end;

    local procedure BehaviorMods(var TempFieldLine: Record "MobileNAV Service Setup" temporary; Kind: Text) Mods: Text
    var
        Behavior: Text;
        Importance: Text;
    begin
        Behavior := this.ServiceOption(TempFieldLine.FieldNo("Validation Behavior"), TempFieldLine."Validation Behavior", '');
        this.AddModIf(Mods, (Behavior <> '') and (Kind in ['Button', 'Scan', 'Lookup']), '.Validation(Enum::"BJF MN Validation Behavior"::' + Behavior + ')');
        // A Button states its mobile type in ButtonVerb.
        this.AddModIf(Mods, (Kind = 'Lookup') and not this.Vocabulary.IsMobileType(this.MobileTypeName(TempFieldLine), Enum::"BJF MN Mobile Type"::Normal),
            '.MobileType(Enum::"BJF MN Mobile Type"::' + this.MobileTypeName(TempFieldLine) + ')');
        Importance := this.ServiceOption(TempFieldLine.FieldNo(Mandatory), TempFieldLine.Mandatory, '');
        this.AddModIf(Mods, TempFieldLine.Mandatory <> TempFieldLine.Mandatory::None, '.Importance(Enum::"BJF MN Importance"::' + Importance + ')');
        exit(Mods);
    end;

    local procedure MobileTypeName(var TempFieldLine: Record "MobileNAV Service Setup" temporary): Text
    begin
        exit(this.ServiceOption(TempFieldLine.FieldNo(MobileType), TempFieldLine.MobileType, 'Normal'));
    end;

    /// <summary>
    /// Tells whether a button's function is the one MobileNAV Page Functions dispatches for the page's
    /// table, as "BJF MN Function Router" lists them, so the button needs no FunctionName(). Tables
    /// it does not list run through "BJF MN Table Functions", whose procedures are named BJF Table Func.
    /// </summary>
    /// <param name="TableNo">The page's source table.</param>
    /// <param name="FunctionName">The button's function name.</param>
    /// <returns>True when the button needs no FunctionName().</returns>
    local procedure IsDefaultFunction(TableNo: Integer; FunctionName: Text): Boolean
    var
        Dispatcher: Text[50];
    begin
        if this.FunctionRouter.TryGetDispatcher(TableNo, Dispatcher) then
            exit(FunctionName = Dispatcher);
        exit(FunctionName.EndsWith('ExtFunc') or this.IsTableFunctionName(FunctionName));
    end;

    local procedure IsTableFunctionName(FunctionName: Text): Boolean
    var
        Letter: Text;
        Index: Integer;
    begin
        if (StrLen(FunctionName) < 8) or not FunctionName.StartsWith('BJF') or not FunctionName.EndsWith('Func') then
            exit(false);
        for Index := 1 to StrLen(FunctionName) do begin
            Letter := CopyStr(FunctionName, Index, 1);
            if (Letter <> '_') and (StrPos(this.AlphanumericTok, Letter) = 0) then
                exit(false);
        end;
        exit(true);
    end;

    // Lookup when the relation names a code field on an editable control, Link when it is a drill down with a FIELD filter.
    local procedure RelationShape(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary): Text
    var
        TempLinkFilter: Record "MobileNAV Service Setup" temporary;
    begin
        if TempRelationLine.RelatedPgCodeFldName <> '' then begin
            if TempFieldLine.Editable and not TempFieldLine.DisplayInMenu then
                exit('Lookup');
            exit('');
        end;
        if TempFieldLine.DisplayInMenu and this.FindLinkFilter(TempFieldLine, TempLinkFilter) then
            exit('Link');
        exit('');
    end;

    local procedure RelationDetails(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempRelationLine: Record "MobileNAV Service Setup" temporary; Kind: Text) Mods: Text
    begin
        Mods := this.RelationFilters(TempFieldLine, Kind = 'Link');
        Mods += this.RelationConditions(TempFieldLine);
        this.AddModIf(Mods, TempRelationLine.MultiSelect and (Kind = 'Lookup'), '.MultiSelect()');
        this.AddModIf(Mods, TempRelationLine.AutoRefreshOnOpen, '.RefreshOnOpen()');
        if Kind = 'Lookup' then
            Mods += this.LookupExtras(TempFieldLine);
        Mods += this.ParentActions(TempFieldLine);
        exit(Mods);
    end;

    local procedure ShareDetails(var TempDetailLine: Record "MobileNAV Service Setup" temporary; var TempFieldLine: Record "MobileNAV Service Setup" temporary)
    begin
        this.ShareLines(TempDetailLine, TempFieldLine."Service Name");
        TempDetailLine.SetRange("Page Line No.", TempFieldLine."Page Line No.");
        TempDetailLine.SetRange("Relation No.", 1);
    end;

    // A Link's first filter is in the Link() call itself.
    local procedure RelationFilters(var TempFieldLine: Record "MobileNAV Service Setup" temporary; SkipFirst: Boolean) Mods: Text
    var
        TempDetailLine: Record "MobileNAV Service Setup" temporary;
        Skip: Boolean;
    begin
        this.ShareDetails(TempDetailLine, TempFieldLine);
        TempDetailLine.SetRange("Line Type", TempDetailLine."Line Type"::"Filter");
        Skip := SkipFirst;
        if TempDetailLine.FindSet() then
            repeat
                if not Skip then
                    Mods += this.RelationFilter(TempDetailLine);
                Skip := false;
            until TempDetailLine.Next() = 0;
        exit(Mods);
    end;

    local procedure RelationFilter(var TempDetailLine: Record "MobileNAV Service Setup" temporary): Text
    begin
        case TempDetailLine.FilterType of
            TempDetailLine.FilterType::"FIELD":
                exit('.Filter(' + this.ALSource.Quoted(TempDetailLine.DestFieldName) + ', ' + this.ALSource.Quoted(TempDetailLine.SourceFieldName) + ')');
            TempDetailLine.FilterType::"FILTER":
                exit('.FilterExpression(' + this.ALSource.Quoted(TempDetailLine.DestFieldName) + ', ' + this.ALSource.Quoted(TempDetailLine.FilterValue) + ')');
        end;
        exit('.FilterValue(' + this.ALSource.Quoted(TempDetailLine.DestFieldName) + ', ' + this.ALSource.Quoted(TempDetailLine.FilterValue) + ')');
    end;

    local procedure RelationConditions(var TempFieldLine: Record "MobileNAV Service Setup" temporary) Mods: Text
    var
        TempDetailLine: Record "MobileNAV Service Setup" temporary;
    begin
        this.ShareDetails(TempDetailLine, TempFieldLine);
        TempDetailLine.SetRange("Line Type", TempDetailLine."Line Type"::Condition);
        if TempDetailLine.FindSet() then
            repeat
                Mods += '.OnlyWhen(' + this.ALSource.Quoted(TempDetailLine.SourceFieldName) + ', ' + this.ALSource.Quoted(TempDetailLine.FilterValue) + ')';
            until TempDetailLine.Next() = 0;
        exit(Mods);
    end;

    local procedure LookupExtras(var TempFieldLine: Record "MobileNAV Service Setup" temporary) Mods: Text
    var
        TempDetailLine: Record "MobileNAV Service Setup" temporary;
    begin
        this.ShareDetails(TempDetailLine, TempFieldLine);
        TempDetailLine.SetRange("Line Type", TempDetailLine."Line Type"::AdditionalCodeField);
        if TempDetailLine.FindSet() then
            repeat
                Mods += '.AdditionalCode(' + this.ALSource.Quoted(TempDetailLine.SourceFieldName) + ', ' + this.ALSource.Quoted(TempDetailLine.DestFieldName) + ')';
            until TempDetailLine.Next() = 0;
        TempDetailLine.SetRange("Line Type", TempDetailLine."Line Type"::PropagatedField);
        if TempDetailLine.FindSet() then
            repeat
                Mods += '.Propagate(Enum::"BJF MN Propagation"::' + this.ServiceOption(TempDetailLine.FieldNo("Propagation Type"), TempDetailLine."Propagation Type", '') + ', ' + this.ALSource.Quoted(TempDetailLine.DestFieldName) + ')';
            until TempDetailLine.Next() = 0;
        exit(Mods);
    end;

    local procedure ParentActions(var TempFieldLine: Record "MobileNAV Service Setup" temporary) Mods: Text
    var
        TempDetailLine: Record "MobileNAV Service Setup" temporary;
    begin
        this.ShareDetails(TempDetailLine, TempFieldLine);
        TempDetailLine.SetRange("Line Type", TempDetailLine."Line Type"::ParentAction);
        if TempDetailLine.FindSet() then
            repeat
                Mods += '.ParentAction(' + this.ALSource.Quoted(TempDetailLine.Name) + ')';
            until TempDetailLine.Next() = 0;
        exit(Mods);
    end;

    local procedure ControlSettings(var TempFieldLine: Record "MobileNAV Service Setup" temporary; Kind: Text; var Comments: List of [Text]) Mods: Text
    begin
        this.AddSetting(TempFieldLine."Decimal Places" <> '', '.DecimalPlaces(' + this.ALSource.Quoted(TempFieldLine."Decimal Places") + ')', Kind, Enum::"BJF MN Property"::DecimalPlaces, Mods, Comments);
        this.AddSetting(TempFieldLine."Quantity Increment" <> 0, '.Quantity(' + this.Num(TempFieldLine."Quantity Increment") + ')', Kind, Enum::"BJF MN Property"::Quantity, Mods, Comments);
        if (TempFieldLine."Quantity Increment" = 0) and this.Vocabulary.IsMobileType(this.MobileTypeName(TempFieldLine), Enum::"BJF MN Mobile Type"::Quantity) then
            Comments.Add(this.QuantityCommentTok);
        this.Increases(TempFieldLine, Kind, Mods, Comments);
        this.AddSetting((TempFieldLine."Min. Value Dec" <> 0) or (TempFieldLine."Max. Value Dec" <> 0),
            '.Range(' + this.Num(TempFieldLine."Min. Value Dec") + ', ' + this.Num(TempFieldLine."Max. Value Dec") + ')', Kind, Enum::"BJF MN Property"::RangeMin, Mods, Comments);
        this.AddSetting(TempFieldLine."Quick Edit/Action", '.QuickEdit()', Kind, Enum::"BJF MN Property"::QuickEdit, Mods, Comments);
        this.AddSetting(TempFieldLine.PromotedOnGroupHeader, '.PromotedOnGroupHeader()', Kind, Enum::"BJF MN Property"::PromotedOnGroupHeader, Mods, Comments);
        this.AddSetting(TempFieldLine."Allow Skip", '.AllowSkip()', Kind, Enum::"BJF MN Property"::AllowSkip, Mods, Comments);
        this.AddSetting((TempFieldLine.RegExText <> '') and not TempFieldLine."RegEx Inherited",
            '.RegEx(' + this.ALSource.Quoted(TempFieldLine.RegExText) + ', ' + this.ALSource.Quoted(TempFieldLine.RegExResults) + ')', Kind, Enum::"BJF MN Property"::RegExPattern, Mods, Comments);
        if (TempFieldLine.RegExResults <> '') and TempFieldLine."RegEx Inherited" then
            Comments.Add(StrSubstNo(this.RegExInheritedCommentTok, TempFieldLine.RegExResults));
        this.AddSetting(TempFieldLine."Field Category" <> TempFieldLine."Field Category"::Other,
            '.FieldCategory(Enum::"BJF MN Field Category"::' + this.ServiceOption(TempFieldLine.FieldNo("Field Category"), TempFieldLine."Field Category", 'Other') + ')', Kind, Enum::"BJF MN Property"::FieldCategory, Mods, Comments);
        this.AddSetting(TempFieldLine."Hide Card DrillDown", '.HideDrillDown()', Kind, Enum::"BJF MN Property"::HideDrillDown, Mods, Comments);
        this.AddSetting(TempFieldLine."Validate if not Changed", '.ValidateAlways()', Kind, Enum::"BJF MN Property"::ValidateAlways, Mods, Comments);
        exit(Mods);
    end;

    local procedure Increases(var TempFieldLine: Record "MobileNAV Service Setup" temporary; Kind: Text; var Mods: Text; var Comments: List of [Text])
    var
        TempTargetLine: Record "MobileNAV Service Setup" temporary;
    begin
        if TempFieldLine."Field to Increase" = 0 then
            exit;
        if this.FindFieldByLine(TempFieldLine."Service Name", TempFieldLine."Field to Increase", TempTargetLine) then
            this.AddSetting(true, '.Increases(' + this.ALSource.Quoted(TempTargetLine.FieldName) + ')', Kind, Enum::"BJF MN Property"::Increases, Mods, Comments)
        else
            Comments.Add(StrSubstNo(this.TargetNotFoundCommentTok, 'Increases'));
    end;

    // Adds a control setting when it is set: the call when the builder allows it on this kind of control, a comment otherwise.
    local procedure AddSetting(IsSet: Boolean; Call: Text; Kind: Text; Property: Enum "BJF MN Property"; var Mods: Text; var Comments: List of [Text])
    var
        AllowedKinds: Text;
    begin
        if not IsSet then
            exit;
        AllowedKinds := this.PropertyCatalog.WriterKinds(Property);
        if AllowedKinds.Split(',').Contains(Kind) then
            Mods += Call
        else
            Comments.Add(StrSubstNo(this.WrongKindCommentTok, Call.Substring(2), AllowedKinds.Replace(',', ' or ')));
    end;

    local procedure AllProfiles(): List of [Text]
    var
        TempProfileLine: Record "MobileNAV Profile Setup" temporary;
        Codes: List of [Text];
    begin
        TempProfileLine.Copy(this.TempProfileSetup, true);
        TempProfileLine.Reset();
        TempProfileLine.SetRange("Profile Type", TempProfileLine."Profile Type"::User);
        if TempProfileLine.FindSet() then
            repeat
                if not Codes.Contains(TempProfileLine."Profile") then
                    Codes.Add(TempProfileLine."Profile");
            until TempProfileLine.Next() = 0;
        if Codes.Count() = 0 then
            Codes := this.ProfileDescriptions.Keys();
        exit(Codes);
    end;

    local procedure ProfileScope(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var Comments: List of [Text]): Text
    var
        Everyone: List of [Text];
        Found: List of [Text];
        Shown: List of [Text];
        Hidden: List of [Text];
    begin
        Everyone := this.AllProfiles();
        this.ReadFieldProfiles(TempFieldLine, Found, Shown, Hidden, Comments);
        if Found.Count() = 0 then
            exit(this.NoProfileRows(Everyone));
        if not TempFieldLine.Visible then
            exit(this.HiddenControlProfiles(Shown, Comments));
        if not this.AnyMissing(Everyone, Found) then
            exit(this.ProfileCalls('.ExceptInProfile', Hidden));
        if Hidden.Count() > 0 then
            Comments.Add(StrSubstNo(this.HiddenNextToOnlyCommentTok, this.Join(Hidden, ', ')));
        exit(this.ProfileCalls('.OnlyInProfile', Shown));
    end;

    // A control without profile rows is in no profile, when there are profiles.
    local procedure NoProfileRows(Everyone: List of [Text]): Text
    begin
        if Everyone.Count() > 0 then
            exit('.NotInProfiles()');
        exit('');
    end;

    local procedure AnyMissing(Everyone: List of [Text]; Found: List of [Text]): Boolean
    var
        ProfileCode: Text;
    begin
        foreach ProfileCode in Everyone do
            if not Found.Contains(ProfileCode) then
                exit(true);
        exit(false);
    end;

    // A hidden control gets no profile calls. A profile that shows it is noted, since no verb writes that.
    local procedure HiddenControlProfiles(Shown: List of [Text]; var Comments: List of [Text]): Text
    begin
        if Shown.Count() > 0 then
            Comments.Add(StrSubstNo(this.VisibleInProfilesCommentTok, this.Join(Shown, ', ')));
        exit('');
    end;

    local procedure ReadFieldProfiles(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var Found: List of [Text]; var Shown: List of [Text]; var Hidden: List of [Text]; var Comments: List of [Text])
    var
        TempProfileLine: Record "MobileNAV Profile Setup" temporary;
    begin
        TempProfileLine.Copy(this.TempProfileSetup, true);
        TempProfileLine.Reset();
        TempProfileLine.SetRange("Profile Type", TempProfileLine."Profile Type"::"Field");
        TempProfileLine.SetRange(ID, TempFieldLine."Service Name");
        TempProfileLine.SetRange("Control ID", TempFieldLine.ControlID);
        if TempProfileLine.FindSet() then
            repeat
                Found.Add(TempProfileLine."Profile");
                if TempProfileLine.Visible then
                    Shown.Add(TempProfileLine."Profile")
                else
                    Hidden.Add(TempProfileLine."Profile");
                this.CompareProfileEditable(TempFieldLine, TempProfileLine, Comments);
            until TempProfileLine.Next() = 0;
        this.SortTexts(Shown);
        this.SortTexts(Hidden);
    end;

    local procedure CompareProfileEditable(var TempFieldLine: Record "MobileNAV Service Setup" temporary; var TempProfileLine: Record "MobileNAV Profile Setup" temporary; var Comments: List of [Text])
    begin
        if not TempProfileLine.Visible then
            exit;
        if TempProfileLine.Editable <> (TempFieldLine.Editable and TempFieldLine.Visible) then
            Comments.Add(StrSubstNo(this.ProfileEditableCommentTok, TempProfileLine."Profile", this.PyBool(TempProfileLine.Editable), this.PyBool(TempFieldLine.Editable)));
    end;

    local procedure ProfileCalls(Verb: Text; ProfileCodes: List of [Text]) Mods: Text
    var
        ProfileCode: Text;
    begin
        foreach ProfileCode in ProfileCodes do
            Mods += Verb + '(' + this.ProfileRef(ProfileCode) + ')';
        exit(Mods);
    end;

    // True when the declared controls hold the first display positions, which OrderAsDeclared() produces.
    local procedure OrdersFirst(ServiceName: Text; Emitted: List of [Integer]): Boolean
    var
        Normal: List of [Integer];
        Position: Integer;
    begin
        Normal := this.ControlLines(ServiceName);
        if Emitted.Count() = Normal.Count() then
            exit(false);
        for Position := 1 to Emitted.Count() do
            if not Emitted.Contains(Normal.Get(Position)) then
                exit(false);
        exit(true);
    end;

    // Page lines of the rows that are controls, as opposed to group starts, group ends and flow filters.
    local procedure ControlLines(ServiceName: Text): List of [Integer]
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
        Normal: List of [Integer];
    begin
        this.ShareFields(TempFieldLine, ServiceName);
        TempFieldLine.SetFilter(FieldClass, '<>%1&<>%2&<>%3', TempFieldLine.FieldClass::GroupStart, TempFieldLine.FieldClass::GroupEnd, TempFieldLine.FieldClass::FlowFilter);
        if TempFieldLine.FindSet() then
            repeat
                Normal.Add(TempFieldLine."Page Line No.");
            until TempFieldLine.Next() = 0;
        exit(Normal);
    end;

    local procedure FlowFilters(ServiceName: Text; var Calls: List of [Text])
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
        FlowFilterName: Text;
    begin
        this.ShareFields(TempFieldLine, ServiceName);
        TempFieldLine.SetRange(FieldClass, TempFieldLine.FieldClass::FlowFilter);
        TempFieldLine.SetRange(Visible, true);
        TempFieldLine.SetRange("Visible as Filter", true);
        if TempFieldLine.FindSet() then
            repeat
                // A flow filter is declared by its table field name, which the stored control name does not keep.
                FlowFilterName := this.ServiceLookup.FieldNameOf(TempFieldLine."Table No.", TempFieldLine."Field No.");
                if FlowFilterName = '' then
                    FlowFilterName := TempFieldLine.FieldName;
                Calls.Add('.FlowFilter(' + this.ALSource.Quoted(FlowFilterName) + ')');
            until TempFieldLine.Next() = 0;
    end;

    local procedure SavedFilters(ServiceName: Text; var Calls: List of [Text])
    var
        TempHeadLine: Record "MobileNAV Service Setup" temporary;
        FilterName: Text;
    begin
        this.ShareLines(TempHeadLine, ServiceName);
        TempHeadLine.SetRange("Line Type", TempHeadLine."Line Type"::SavedFilter);
        TempHeadLine.SetRange("Line No.", 0);
        if TempHeadLine.FindSet() then
            repeat
                FilterName := TempHeadLine.Name;
                if FilterName = '' then
                    FilterName := 'Saved';
                Calls.Add('.SavedFilter(' + this.Lbl(TempHeadLine.Name, FilterName + ' Filter', 100) + ')');
                this.AddIf(Calls, TempHeadLine."Own Filter Set", '.Mine()');
                this.AddIf(Calls, TempHeadLine."View Type" = TempHeadLine."View Type"::Map, '.AsMap()');
                this.SavedFilterWheres(ServiceName, TempHeadLine."Page Line No.", Calls);
            until TempHeadLine.Next() = 0;
    end;

    local procedure SavedFilterWheres(ServiceName: Text; PageLineNo: Integer; var Calls: List of [Text])
    var
        TempWhereLine: Record "MobileNAV Service Setup" temporary;
    begin
        this.ShareLines(TempWhereLine, ServiceName);
        TempWhereLine.SetRange("Line Type", TempWhereLine."Line Type"::SavedFilter);
        TempWhereLine.SetRange("Page Line No.", PageLineNo);
        TempWhereLine.SetFilter("Line No.", '<>0');
        if TempWhereLine.FindSet() then
            repeat
                Calls.Add('.Where(' + this.ALSource.Quoted(TempWhereLine.FieldName) + ', Enum::"BJF MN Search Type"::' +
                    this.ServiceOption(TempWhereLine.FieldNo("Search Type"), TempWhereLine."Search Type", 'BeginMatch') + ', ' + this.ALSource.Quoted(TempWhereLine.FilterValue) + ')');
            until TempWhereLine.Next() = 0;
    end;

    // ---- layouts and wizard ------------------------------------------------------------------------

    local procedure Layouts(ServiceName: Text; var Calls: List of [Text])
    var
        TempLayout: Record "MobileNAV Dynamic Layout" temporary;
    begin
        TempLayout.Copy(this.TempDynamicLayout, true);
        TempLayout.Reset();
        TempLayout.SetCurrentKey("Service Name", "Order");
        TempLayout.SetRange("Service Name", ServiceName);
        if TempLayout.FindSet() then
            repeat
                // Declared without a condition the builder cannot write, the layout would run always. An undeclared layout is left as it is.
                if not this.UnwritableCondition(TempLayout, Calls) then begin
                    Calls.Add('.Layout(' + this.Tok(TempLayout."Code", TempLayout."Code" + ' Layout') + ', ' + this.Lbl(TempLayout.Description, TempLayout."Code" + ' Layout', 100) + ')');
                    this.AddIf(Calls, TempLayout.Disabled, '.Disabled()');
                    this.LayoutConditions(TempLayout, Calls);
                    this.LayoutActions(TempLayout, Calls);
                end;
            until TempLayout.Next() = 0;
    end;

    local procedure ShareConditions(var TempCondition: Record "MobileNAV D. L. Condition" temporary; var TempLayout: Record "MobileNAV Dynamic Layout" temporary)
    begin
        TempCondition.Copy(this.TempLayoutCondition, true);
        TempCondition.Reset();
        TempCondition.SetRange("Service Name", TempLayout."Service Name");
        TempCondition.SetRange("Layout Code", TempLayout."Code");
    end;

    // True, with a comment, when a condition compares with Own or NotOwn, for which the builder has no value.
    local procedure UnwritableCondition(var TempLayout: Record "MobileNAV Dynamic Layout" temporary; var Calls: List of [Text]): Boolean
    var
        TempCondition: Record "MobileNAV D. L. Condition" temporary;
    begin
        this.ShareConditions(TempCondition, TempLayout);
        TempCondition.SetFilter(ConditionType, '<>%1', TempCondition.ConditionType::"FILTER");
        TempCondition.SetFilter("Comparsion Type", '%1|%2', TempCondition."Comparsion Type"::Own, TempCondition."Comparsion Type"::NotOwn);
        if not TempCondition.FindFirst() then
            exit(false);
        Calls.Add(StrSubstNo(this.LayoutConditionCommentTok, TempLayout."Code", TempCondition.DestFieldName,
            this.OptionName(Database::"MobileNAV D. L. Condition", TempCondition.FieldNo("Comparsion Type"), TempCondition."Comparsion Type", 'Equal')));
        exit(true);
    end;

    local procedure LayoutConditions(var TempLayout: Record "MobileNAV Dynamic Layout" temporary; var Calls: List of [Text])
    var
        TempCondition: Record "MobileNAV D. L. Condition" temporary;
        Comparison: Text;
    begin
        this.ShareConditions(TempCondition, TempLayout);
        if TempCondition.FindSet() then
            repeat
                Comparison := this.OptionName(Database::"MobileNAV D. L. Condition", TempCondition.FieldNo("Comparsion Type"), TempCondition."Comparsion Type", 'Equal');
                case TempCondition.ConditionType of
                    TempCondition.ConditionType::"FILTER":
                        Calls.Add('.WhenFilter(' + this.ALSource.Quoted(TempCondition.DestFieldName) + ', ' + this.ALSource.Quoted(TempCondition.ConditionValue) + ')');
                    TempCondition.ConditionType::"FIELD":
                        Calls.Add('.WhenField(' + this.ALSource.Quoted(TempCondition.DestFieldName) + ', Enum::"BJF MN Comparison"::' + Comparison + ', ' + this.ALSource.Quoted(TempCondition.SourceFieldName) + ')');
                    else
                        Calls.Add('.WhenValue(' + this.ALSource.Quoted(TempCondition.DestFieldName) + ', Enum::"BJF MN Comparison"::' + Comparison + ', ' + this.ALSource.Quoted(TempCondition.ConditionValue) + ')');
                end;
            until TempCondition.Next() = 0;
    end;

    local procedure LayoutActions(var TempLayout: Record "MobileNAV Dynamic Layout" temporary; var Calls: List of [Text])
    var
        TempAction: Record "MobileNAV D. L. Action" temporary;
    begin
        TempAction.Copy(this.TempLayoutAction, true);
        TempAction.Reset();
        TempAction.SetRange("Service Name", TempLayout."Service Name");
        TempAction.SetRange("Layout Code", TempLayout."Code");
        if TempAction.FindSet() then
            repeat
                if not this.PageLevelAction(TempAction, Calls) then
                    this.ActionLines(TempLayout, TempAction, Calls);
            until TempAction.Next() = 0;
    end;

    local procedure ActionTypeName(var TempAction: Record "MobileNAV D. L. Action" temporary): Text
    begin
        exit(this.OptionName(Database::"MobileNAV D. L. Action", TempAction.FieldNo(Type), TempAction.Type, ''));
    end;

    // The actions that apply to the whole page: read-only, icons and area colours. True when the action was one of them.
    local procedure PageLevelAction(var TempAction: Record "MobileNAV D. L. Action" temporary; var Calls: List of [Text]): Boolean
    var
        ActionType: Text;
        AreaName: Text;
    begin
        ActionType := this.ActionTypeName(TempAction);
        if ActionType = 'PageReadOnly' then begin
            Calls.Add('.LocksPage()');
            exit(true);
        end;
        if ActionType in ['RowIcon', 'ToolbarIcon'] then begin
            Calls.Add('.' + ActionType + '(' + this.Tok(TempAction.Icon, TempAction.Icon + ' Icon') + ')');
            exit(true);
        end;
        if not ActionType.EndsWith('Color') then
            exit(false);
        AreaName := ActionType.Substring(1, StrLen(ActionType) - 5);
        if not (AreaName in ['FirstLine', 'SecondLine', 'TopLeft', 'MiddleLeft', 'BottomLeft', 'TopRight', 'MiddleRight', 'BottomRight', 'Background']) then
            exit(false);
        Calls.Add('.AreaColor(Enum::"BJF MN Layout Area"::' + AreaName + ', ' + this.ColorRef(Database::"MobileNAV D. L. Action", TempAction.FieldNo(Color), TempAction.Color) + ')');
        exit(true);
    end;

    local procedure ActionLines(var TempLayout: Record "MobileNAV Dynamic Layout" temporary; var TempAction: Record "MobileNAV D. L. Action" temporary; var Calls: List of [Text])
    var
        TempActionLine: Record "MobileNAV D. L. Action Line" temporary;
        ActionType: Text;
    begin
        ActionType := this.ActionTypeName(TempAction);
        TempActionLine.Copy(this.TempLayoutActionLine, true);
        TempActionLine.Reset();
        TempActionLine.SetRange("Service Name", TempLayout."Service Name");
        TempActionLine.SetRange("Layout Code", TempLayout."Code");
        TempActionLine.SetRange("Action Type", TempAction.Type);
        if not TempActionLine.FindSet() then begin
            if ActionType <> '' then
                Calls.Add(StrSubstNo(this.LayoutNoLinesCommentTok, TempLayout."Code", ActionType));
            exit;
        end;
        repeat
            Calls.Add(this.ActionLineCall(TempLayout."Code", ActionType, TempActionLine));
        until TempActionLine.Next() = 0;
    end;

    local procedure ActionLineCall(LayoutCode: Text; ActionType: Text; var TempActionLine: Record "MobileNAV D. L. Action Line" temporary): Text
    var
        LineName: Text;
    begin
        LineName := this.ALSource.Quoted(TempActionLine.Name);
        if TempActionLine."Related Page Name" <> '' then
            exit(StrSubstNo(this.LayoutRelatedCommentTok, LayoutCode, ActionType, TempActionLine.Name, TempActionLine."Related Page Name"));
        if this.FieldActionVerb(ActionType) <> '' then
            exit('.' + this.FieldActionVerb(ActionType) + '(' + LineName + ')');
        case ActionType of
            'FieldCaption':
                exit('.CaptionsField(' + LineName + ', ' + this.Category(TempActionLine.Caption) + ')');
            'FieldCaptionColor':
                exit('.CaptionColor(' + LineName + ', ' + this.ColorRef(Database::"MobileNAV D. L. Action Line", TempActionLine.FieldNo(Color), TempActionLine.Color) + ')');
            'FieldValueColor':
                exit('.ValueColor(' + LineName + ', ' + this.ColorRef(Database::"MobileNAV D. L. Action Line", TempActionLine.FieldNo(Color), TempActionLine.Color) + ')');
        end;
        exit(StrSubstNo(this.LayoutActionCommentTok, LayoutCode, ActionType, TempActionLine.Name));
    end;

    local procedure FieldActionVerb(ActionType: Text): Text
    begin
        case ActionType of
            'HideField':
                exit('HidesField');
            'FieldReadOnly':
                exit('LocksField');
            'FieldValidated':
                exit('ValidatesField');
            'HideStage':
                exit('HidesStage');
            'StageValidated':
                exit('ValidatesStage');
        end;
        exit('');
    end;

    local procedure ColorRef(TableNo: Integer; FieldNo: Integer; Ordinal: Integer): Text
    begin
        exit('Enum::"BJF MN Color"::' + this.OptionName(TableNo, FieldNo, Ordinal, 'Normal'));
    end;

    local procedure Wizard(var TempMainLine: Record "MobileNAV Service Setup" temporary; var Calls: List of [Text])
    var
        TempStageLine: Record "MobileNAV Service Setup" temporary;
        StageIndex: Integer;
    begin
        this.ShareLines(TempStageLine, TempMainLine."Service Name");
        TempStageLine.SetRange("Line Type", TempStageLine."Line Type"::Stage);
        if not TempMainLine."Enable Staging" or not TempStageLine.FindSet() then
            exit;
        Calls.Add('.Wizard()');
        this.AddIf(Calls, TempMainLine."Auto Next Stage", '.AutoNext()');
        this.AddIf(Calls, not TempMainLine."Back-Next Visible", '.HideBackNext()');
        this.AddIf(Calls, TempMainLine."Staging Behavior" <> TempMainLine."Staging Behavior"::Always,
            '.Behavior(Enum::"BJF MN Staging Behavior"::' + this.ServiceOption(TempMainLine.FieldNo("Staging Behavior"), TempMainLine."Staging Behavior", 'Always') + ')');
        repeat
            StageIndex += 1;
            this.WizardStage(TempMainLine."Service Name", TempStageLine, StageIndex, Calls);
        until TempStageLine.Next() = 0;
    end;

    local procedure WizardStage(ServiceName: Text; var TempStageLine: Record "MobileNAV Service Setup" temporary; StageIndex: Integer; var Calls: List of [Text])
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
        Tokens: List of [Text];
        StageId: Text;
        StageDescription: Text;
    begin
        StageId := TempStageLine.Stage;
        if not this.StageIds.Contains(StageId) then
            this.StageIds.Add(StageId);
        if not this.CategoryDescriptions.Get(StageId, StageDescription) then
            StageDescription := '';
        Calls.Add('.Stage(' + this.Tok(StageId, StageId + ' Stage') + ', ' + this.Lbl(StageDescription, StageId + ' Stage', 250) + ')');
        this.AddIf(Calls, TempStageLine."Staging Restart From", '.RestartsHere()');
        this.ShareFields(TempFieldLine, ServiceName);
        TempFieldLine.SetFilter(Stage, '<>%1', '');
        if TempFieldLine.FindSet() then
            repeat
                Tokens := Format(TempFieldLine.Stage).Split(',');
                if StageIndex <= Tokens.Count() then begin
                    this.AddIf(Calls, Tokens.Get(StageIndex) = '', '.Show(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ')');
                    this.AddIf(Calls, Tokens.Get(StageIndex) = 'R', '.ShowReadOnly(' + this.ALSource.Quoted(TempFieldLine.FieldName) + ')');
                end;
            until TempFieldLine.Next() = 0;
    end;

    local procedure RelationNotes(ServiceName: Text; Emitted: List of [Integer]; var Notes: List of [Text])
    var
        TempRelationLine: Record "MobileNAV Service Setup" temporary;
        Left: List of [Text];
        Entry: Text;
    begin
        this.ShareLines(TempRelationLine, ServiceName);
        TempRelationLine.SetRange("Line Type", TempRelationLine."Line Type"::Relation);
        TempRelationLine.SetRange("Relation No.", 1);
        if TempRelationLine.FindSet() then
            repeat
                Entry := TempRelationLine.FieldName + ' -> ' + TempRelationLine.RelatedPageName;
                if not this.IsTakenOver(ServiceName, Emitted, TempRelationLine) and not Left.Contains(Entry) then
                    Left.Add(Entry);
            until TempRelationLine.Next() = 0;
        if Left.Count() = 0 then
            exit;
        this.SortTexts(Left);
        Notes.Add(StrSubstNo(this.RelationsNoteTok, this.Join(Left, ', ')));
    end;

    // True when a declared Link or Lookup takes the relation over.
    local procedure IsTakenOver(ServiceName: Text; Emitted: List of [Integer]; var TempRelationLine: Record "MobileNAV Service Setup" temporary): Boolean
    var
        TempFieldLine: Record "MobileNAV Service Setup" temporary;
    begin
        if not Emitted.Contains(TempRelationLine."Page Line No.") then
            exit(false);
        if not this.FindFieldByLine(ServiceName, TempRelationLine."Page Line No.", TempFieldLine) then
            exit(false);
        exit(TempFieldLine.Visible and (this.RelationShape(TempFieldLine, TempRelationLine) <> ''));
    end;

    // ---- the whole file ----------------------------------------------------------------------------

    local procedure DefineMasterData(var Output: List of [Text])
    var
        Calls: List of [Text];
        Line: Text;
    begin
        this.CategoryCalls(Calls);
        this.ProfileDefinitionCalls(Calls);
        if Calls.Count() = 0 then
            exit;
        Output.Add('    /// <summary>The categories and profiles the pages below refer to.</summary>');
        Output.Add('    /// <param name="Configuration">The builder that collects the declarations.</param>');
        Output.Add('    local procedure DefineMasterData(var Configuration: Codeunit "BJF MN Config Builder")');
        Output.Add('    begin');
        Output.Add('        Configuration');
        foreach Line in Calls do
            Output.Add('            ' + Line);
        Output.Set(Output.Count(), Output.Get(Output.Count()) + ';');
        Output.Add('    end;');
    end;

    // The categories the pages use, except wizard stages, whose descriptions the Stage() calls carry.
    local procedure CategoryCalls(var Calls: List of [Text])
    var
        TempTranslation: Record "MobileNAV Category Transl." temporary;
        CategoryCode: Text;
        Description: Text;
    begin
        foreach CategoryCode in this.UsedCategories do
            if not this.StageIds.Contains(CategoryCode) then begin
                if not this.CategoryDescriptions.Get(CategoryCode, Description) then
                    Description := '';
                Calls.Add('.Category(' + this.Tok(CategoryCode, CategoryCode + ' Category') + ', ' + this.Lbl(Description, CategoryCode + ' Category', 250) + ')');
                TempTranslation.Copy(this.TempCategoryTransl, true);
                TempTranslation.Reset();
                TempTranslation.SetRange(Category, CategoryCode);
                if TempTranslation.FindSet() then
                    repeat
                        Calls.Add('.CategoryTranslation(' + this.Tok(CategoryCode, CategoryCode + ' Category') + ', ' +
                            this.Tok(TempTranslation."Language Code", TempTranslation."Language Code" + ' Language') + ', ' +
                            this.Lbl(TempTranslation.Description, CategoryCode + TempTranslation."Language Code" + ' Category', 250) + ')');
                    until TempTranslation.Next() = 0;
            end;
    end;

    local procedure ProfileDefinitionCalls(var Calls: List of [Text])
    var
        ProfileCode: Text;
        Description: Text;
    begin
        foreach ProfileCode in this.UsedProfiles do begin
            if not this.ProfileDescriptions.Get(ProfileCode, Description) then
                Description := '';
            Calls.Add('.Profile(' + this.Tok(ProfileCode, ProfileCode + ' Profile') + ', ' + this.Lbl(Description, ProfileCode + ' Profile', 250) + ')');
        end;
    end;

    local procedure BuildText(Services: List of [Text]): Text
    var
        Output: List of [Text];
    begin
        this.AddCodeunitLines(Services, Output);
        this.EnumExtension(Output);
        exit(this.ToText(Output));
    end;

    local procedure BuildFiles(Services: List of [Text]; var FilePaths: List of [Text]; var FileTexts: List of [Text])
    var
        CodeunitLines: List of [Text];
        EnumLines: List of [Text];
    begin
        this.AddCodeunitLines(Services, CodeunitLines);
        FilePaths.Add(this.EffectiveObjectName() + '.Codeunit.al');
        FileTexts.Add(this.ToText(CodeunitLines));
        this.AddUsingLines(EnumLines);
        this.EnumExtension(EnumLines);
        FilePaths.Add(this.EnumName() + '.EnumExt.al');
        FileTexts.Add(this.ToText(EnumLines));
    end;

    local procedure AddCodeunitLines(Services: List of [Text]; var Output: List of [Text])
    var
        PageLines: List of [Text];
        MasterLines: List of [Text];
        ServiceName: Text;
    begin
        // Pages first: they create the labels and record the categories and profiles the master data declares.
        foreach ServiceName in Services do begin
            if PageLines.Count() > 0 then
                PageLines.Add('');
            this.DefinePage(ServiceName, PageLines);
        end;
        this.DefineMasterData(MasterLines);
        this.FileHeader(Services, Output);
        this.CodeunitHead(Services, MasterLines.Count() > 0, Output);
        if MasterLines.Count() > 0 then begin
            Output.Add('');
            Output.AddRange(MasterLines);
        end;
        Output.Add('');
        Output.AddRange(PageLines);
        Output.Add('');
        Output.Add('    var');
        Output.AddRange(this.LabelLines);
        Output.Add('}');
        Output.Add('');
    end;

    local procedure ToText(Lines: List of [Text]): Text
    var
        TypeHelper: Codeunit "Type Helper";
        Result: TextBuilder;
        Line: Text;
    begin
        foreach Line in Lines do begin
            Result.Append(Line);
            Result.Append(TypeHelper.LFSeparator());
        end;
        exit(Result.ToText());
    end;

    local procedure AddUsingLines(var Output: List of [Text])
    begin
        if this.NamespaceName <> '' then begin
            Output.Add('namespace ' + this.NamespaceName + ';');
            Output.Add('');
        end;
        Output.Add('using BradFullwood.MobileNAV.Configuration;');
        Output.Add('');
    end;

    local procedure FileHeader(Services: List of [Text]; var Output: List of [Text])
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        this.AddUsingLines(Output);
        Output.Add('/// <summary>');
        Output.Add(StrSubstNo(this.HeaderGeneratedTok, Format(Today(), 0, 9), EnvironmentInformation.GetEnvironmentName(), CompanyName()));
        Output.Add(StrSubstNo(this.HeaderRestatesTok, this.Join(Services, ', ')));
        Output.Add(this.HeaderOwnsTok);
        Output.Add(this.HeaderNamesTok);
        Output.Add('/// </summary>');
        if not this.IncludeProfiles then
            Output.Add(this.HeaderProfilesTok);
        Output.Add(this.HeaderNotRestatedTok);
    end;

    local procedure CodeunitHead(Services: List of [Text]; HasMasterData: Boolean; var Output: List of [Text])
    var
        ServiceName: Text;
        IdRef: Text;
        NameRef: Text;
        DescriptionRef: Text;
    begin
        IdRef := this.Tok(this.ProviderId, 'Provider Id');
        NameRef := this.Lbl(this.ProviderId + ' MobileNAV', 'Provider Name', 100);
        DescriptionRef := this.Lbl(StrSubstNo(this.ProviderDescriptionTok, this.Join(Services, ', ')), 'Provider Description', 250);
        Output.Add('codeunit ' + this.Num(this.EffectiveObjectId()) + ' "' + this.EffectiveObjectName() + '" implements "BJF MN Config Provider"');
        Output.Add('{');
        Output.Add('    Access = Internal;');
        Output.Add('');
        this.AddGetter('GetId(): Code[50]', IdRef, Output);
        this.AddGetter('GetName(): Text[100]', NameRef, Output);
        this.AddGetter('GetDescription(): Text[250]', DescriptionRef, Output);
        Output.Add('    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")');
        Output.Add('    begin');
        if HasMasterData then
            Output.Add('        this.DefineMasterData(Configuration);');
        foreach ServiceName in Services do
            Output.Add('        this.Define' + this.ALSource.Identifier(ServiceName) + '(Configuration);');
        Output.Add('    end;');
    end;

    local procedure AddGetter(Signature: Text; Value: Text; var Output: List of [Text])
    begin
        Output.Add('    procedure ' + Signature);
        Output.Add('    begin');
        Output.Add('        exit(' + Value + ');');
        Output.Add('    end;');
        Output.Add('');
    end;

    local procedure EnumExtension(var Output: List of [Text])
    begin
        Output.Add('/// <summary>Registers the provider so the framework lists and applies it.</summary>');
        Output.Add('enumextension ' + this.Num(this.EffectiveObjectId()) + ' "' + this.EnumName() + '" extends "BJF MN Config Provider"');
        Output.Add('{');
        Output.Add('    value(' + this.Num(this.EffectiveObjectId()) + '; ' + this.ALSource.Identifier(this.ProviderId) + ')');
        Output.Add('    {');
        Output.Add('        Caption = ' + this.ALSource.Quoted(this.ProviderId + ' MobileNAV') + ';');
        Output.Add('        Implementation = "BJF MN Config Provider" = "' + this.EffectiveObjectName() + '";');
        Output.Add('    }');
        Output.Add('}');
    end;

    /// <summary>The enum extension's name: the codeunit name without its Provider suffix, then Providers.</summary>
    /// <returns>The enum extension name, at most 30 characters.</returns>
    local procedure EnumName(): Text
    var
        Name: Text;
    begin
        Name := this.EffectiveObjectName();
        if Name.EndsWith(' Provider') then
            Name := CopyStr(Name, 1, StrLen(Name) - StrLen(' Provider'));
        exit(CopyStr(Name, 1, 20) + ' Providers');
    end;

    local procedure EffectiveObjectName(): Text
    var
        Title: Text;
        Word: Text;
    begin
        if this.ObjectName <> '' then
            exit(this.ObjectName);
        foreach Word in this.ALSource.Words(this.ProviderId) do begin
            if Title <> '' then
                Title += ' ';
            Title += UpperCase(CopyStr(Word, 1, 1)) + LowerCase(CopyStr(Word, 2));
        end;
        exit(CopyStr(Title + ' MN Provider', 1, 30));
    end;

    local procedure EffectiveObjectId(): Integer
    begin
        if this.ObjectId = 0 then
            exit(50100);
        exit(this.ObjectId);
    end;

    // ---- names and text ----------------------------------------------------------------------------

    local procedure Category(CategoryCode: Text): Text
    begin
        if (CategoryCode <> '') and not this.UsedCategories.Contains(CategoryCode) then
            this.UsedCategories.Add(CategoryCode);
        exit(this.Tok(CategoryCode, CategoryCode + ' Category'));
    end;

    local procedure ProfileRef(ProfileCode: Text): Text
    begin
        if not this.UsedProfiles.Contains(ProfileCode) then
            this.UsedProfiles.Add(ProfileCode);
        exit(this.Tok(ProfileCode, ProfileCode + ' Profile'));
    end;

    // A Locked Label for a value the generated code compares or stores, such as a code or a service name.
    local procedure Tok(Value: Text; Hint: Text): Text
    begin
        exit(this.AddLabel(Value, Hint, 'Tok', 'Locked = true'));
    end;

    // A translatable Label for a caption or description.
    local procedure Lbl(Value: Text; Hint: Text; MaxLength: Integer): Text
    begin
        exit(this.AddLabel(Value, Hint, 'Lbl', 'MaxLength = ' + this.Num(MaxLength)));
    end;

    /// <summary>
    /// The codeunit's Label variable for a value: one per value and meaning, so a profile and a
    /// category can share a code.
    /// </summary>
    /// <param name="Value">The label's text.</param>
    /// <param name="Hint">Words the variable name is made of.</param>
    /// <param name="Suffix">Tok or Lbl.</param>
    /// <param name="LabelProperties">The label's properties, Locked or MaxLength.</param>
    /// <returns>The reference to the label, with this. in front.</returns>
    local procedure AddLabel(Value: Text; Hint: Text; Suffix: Text; LabelProperties: Text): Text
    var
        LabelKey: Text;
        Base: Text;
        LabelName: Text;
        Counter: Integer;
    begin
        LabelKey := Suffix + '|' + LabelProperties + '|' + this.ALSource.Identifier(Hint) + '|' + Value;
        if this.LabelNameByKey.Get(LabelKey, LabelName) then
            exit('this.' + LabelName);
        Base := CopyStr(this.ALSource.Identifier(Hint), 1, 30 - StrLen(Suffix));
        LabelName := Base + Suffix;
        Counter := 1;
        while this.LabelNames.Contains(LabelName) do begin
            Counter += 1;
            LabelName := CopyStr(Base, 1, 30 - StrLen(Suffix) - StrLen(this.Num(Counter))) + this.Num(Counter) + Suffix;
        end;
        this.LabelNames.Add(LabelName);
        this.LabelNameByKey.Add(LabelKey, LabelName);
        this.LabelLines.Add('        ' + LabelName + ': Label ' + this.ALSource.Quoted(Value) + ', ' + LabelProperties + ';');
        exit('this.' + LabelName);
    end;


    // A number as AL writes it: 1 rather than 1.0, and no thousands separator.
    local procedure Num(Value: Decimal): Text
    begin
        exit(Format(Value, 0, 9));
    end;

    local procedure PyBool(Value: Boolean): Text
    begin
        if Value then
            exit('True');
        exit('False');
    end;

    local procedure IsComparison(Comparison: Text): Boolean
    begin
        exit(Comparison in ['Equal', 'NotEqual', 'Less', 'LessOrEqual', 'Greater', 'GreaterOrEqual']);
    end;

    local procedure Join(Values: List of [Text]; Separator: Text): Text
    var
        Result: Text;
        Value: Text;
    begin
        foreach Value in Values do begin
            if Result <> '' then
                Result += Separator;
            Result += Value;
        end;
        exit(Result);
    end;

    local procedure SortTexts(var Values: List of [Text])
    var
        Current: Text;
        Index: Integer;
        Position: Integer;
    begin
        for Index := 2 to Values.Count() do begin
            Current := Values.Get(Index);
            Position := Index - 1;
            // AL evaluates both sides of an and, so Get(0) must not sit in the loop condition.
            while Position > 0 do
                if Values.Get(Position) > Current then
                    Position -= 1
                else
                    break;
            Values.RemoveAt(Index);
            Values.Insert(Position + 1, Current);
        end;
    end;

    local procedure AddIf(var Calls: List of [Text]; Condition: Boolean; Call: Text)
    begin
        if Condition then
            Calls.Add(Call);
    end;

    local procedure AddModIf(var Mods: Text; Condition: Boolean; Call: Text)
    begin
        if Condition then
            Mods += Call;
    end;

    // The option member name of a MobileNAV Service Setup field, as the API returns it.
    local procedure ServiceOption(FieldNo: Integer; Ordinal: Integer; DefaultName: Text): Text
    begin
        exit(this.OptionName(Database::"MobileNAV Service Setup", FieldNo, Ordinal, DefaultName));
    end;

    /// <summary>An option member name, which the builder's enums use as their value names.</summary>
    /// <param name="TableNo">The MobileNAV table.</param>
    /// <param name="FieldNo">The option field.</param>
    /// <param name="Ordinal">The field's value.</param>
    /// <param name="DefaultName">The name to return when the member is blank.</param>
    /// <returns>The member name.</returns>
    local procedure OptionName(TableNo: Integer; FieldNo: Integer; Ordinal: Integer; DefaultName: Text): Text
    var
        RecRef: RecordRef;
        Members: List of [Text];
        CacheKey: Text;
        MemberName: Text;
    begin
        CacheKey := this.Num(TableNo) + ':' + this.Num(FieldNo);
        if not this.OptionMembersCache.Get(CacheKey, MemberName) then begin
            RecRef.Open(TableNo, true);
            MemberName := RecRef.Field(FieldNo).OptionMembers();
            RecRef.Close();
            this.OptionMembersCache.Add(CacheKey, MemberName);
        end;
        Members := MemberName.Split(',');
        if (Ordinal < 0) or (Ordinal >= Members.Count()) then
            exit(DefaultName);
        MemberName := Members.Get(Ordinal + 1).Trim();
        if MemberName = '' then
            exit(DefaultName);
        exit(MemberName);
    end;

    var
        TempServiceSetup: Record "MobileNAV Service Setup" temporary;
        TempProfileSetup: Record "MobileNAV Profile Setup" temporary;
        TempDynamicLayout: Record "MobileNAV Dynamic Layout" temporary;
        TempLayoutCondition: Record "MobileNAV D. L. Condition" temporary;
        TempLayoutAction: Record "MobileNAV D. L. Action" temporary;
        TempLayoutActionLine: Record "MobileNAV D. L. Action Line" temporary;
        TempCaptionAdmin: Record "MobileNAV CaptionML Admin." temporary;
        TempCategoryTransl: Record "MobileNAV Category Transl." temporary;
        FunctionRouter: Codeunit "BJF MN Function Router";
        ServiceLookup: Codeunit "BJF MN Service Lookup";
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        Vocabulary: Codeunit "BJF MN Vocabulary";
        ALSource: Codeunit "BJF MN AL Source";
        PropertyCatalog: Codeunit "BJF MN Property Catalog";
        CategoryDescriptions: Dictionary of [Text, Text];
        ProfileDescriptions: Dictionary of [Text, Text];
        LabelNameByKey: Dictionary of [Text, Text];
        OptionMembersCache: Dictionary of [Text, Text];
        LabelLines: List of [Text];
        LabelNames: List of [Text];
        StageIds: List of [Text];
        UsedCategories: List of [Text];
        UsedProfiles: List of [Text];
        ProviderId: Text[50];
        ObjectName: Text[30];
        NamespaceName: Text;
        ObjectId: Integer;
        IncludeAllCaptions: Boolean;
        IncludeHidden: Boolean;
        IncludeProfiles: Boolean;
        AlphanumericTok: Label 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789', Locked = true;
        ProviderIdMissingErr: Label 'Enter a provider id.';
        NoServicesErr: Label 'Select at least one MobileNAV page.';
        ServiceNotFoundErr: Label 'MobileNAV has no page set up under service name %1.', Comment = '%1 = MobileNAV service name';
        ProviderDescriptionTok: Label 'Restates the MobileNAV setup of %1.', Locked = true;
        HeaderGeneratedTok: Label '/// Generated by BJF MN Provider Writer on %1 from %2 / %3.', Locked = true;
        HeaderRestatesTok: Label '/// It restates the MobileNAV setup of %1. Keep what this app owns and delete the rest:', Locked = true;
        HeaderOwnsTok: Label '/// a provider owns what it declares, and the Doctor reports later drift. Control names are', Locked = true;
        HeaderNamesTok: Label '/// MobileNAV''s stored names, which the framework matches the same way as the page''s own.', Locked = true;
        HeaderProfilesTok: Label '// Profile rows were not read (Include Profiles reads them): every control is declared for every profile.', Locked = true;
        HeaderNotRestatedTok: Label '// Not restated: line formats and menu pictures.', Locked = true;
        HiddenLeftOutNoteTok: Label 'Hidden fields of MobileNAV''s own left out: %1. Include Hidden Fields declares them.', Locked = true;
        DialogCodeunitNoteTok: Label 'The dialog runs its buttons through web service %1, whose codeunit was not found: declare .Functions(Codeunit::"...", ''%1'').', Locked = true;
        RelationsNoteTok: Label 'Relations left as MobileNAV has them (a Link or Lookup would take them over): %1.', Locked = true;
        PageFilterCommentTok: Label '// page filter on %1 (%2 %3 %4): no builder verb writes it', Locked = true;
        HiddenButtonCommentTok: Label '// %1: hidden button (function %2). Button() makes it visible, so it is left as MobileNAV has it', Locked = true;
        FieldControlCommentTok: Label 'visible %1, editable %2 now: FieldControl() writes hidden and editable', Locked = true;
        MobileTypeCommentTok: Label 'mobile type %1: a Field leaves it as MobileNAV has it', Locked = true;
        BarcodeCommentTok: Label 'mobile type Barcode on a field that is %1: Scan() would make it visible and editable', Locked = true;
        AssignToMeCommentTok: Label 'card %1, list %2: AssignToMe sets both', Locked = true;
        QuantityCommentTok: Label 'mobile type Quantity with no increment: add .Quantity(...)', Locked = true;
        TargetNotFoundCommentTok: Label '%1: the control it points at was not found', Locked = true;
        RegExInheritedCommentTok: Label 'RegEx results %1 come from another control''s pattern: .NoRegEx() clears them', Locked = true;
        WrongKindCommentTok: Label '%1 is set, which the builder allows on %2 only', Locked = true;
        ProfileEditableCommentTok: Label 'profile %1 has editable %2, the control %3', Locked = true;
        VisibleInProfilesCommentTok: Label 'hidden, but visible in profiles %1: no builder verb writes that', Locked = true;
        HiddenNextToOnlyCommentTok: Label 'hidden rows in profiles %1 next to OnlyInProfile: no builder verb writes both', Locked = true;
        LayoutConditionCommentTok: Label '// layout %1 is left as MobileNAV has it: its condition on %2 compares with %3, which the builder has no value for', Locked = true;
        LayoutRelatedCommentTok: Label '// layout %1: %2 on %3 of related page %4: no builder verb writes it', Locked = true;
        LayoutActionCommentTok: Label '// layout %1: action %2 on %3: no builder verb writes it', Locked = true;
        LayoutNoLinesCommentTok: Label '// layout %1: action %2 has no lines', Locked = true;
}
