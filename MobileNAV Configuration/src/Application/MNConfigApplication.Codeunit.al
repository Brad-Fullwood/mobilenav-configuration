namespace BradFullwood.MobileNAV.Configuration;

using System.IO;

/// <summary>
/// Validates and applies one provider definition in deterministic dependency order,
/// then records success with the definition's fingerprint in the configuration transaction.
/// New endpoint publication commits first so MobileNAV's separate WSDL request can see it.
/// </summary>
codeunit 77784 "BJF MN Config Application"
{
    Access = Public;
    Permissions = tabledata "MobileNAV Master Data" = r;

    /// <summary>
    /// Whether MobileNAV has been set up in this company. An install codeunit checks this before
    /// applying: MobileNAV's Setup Wizard has to import the base configuration first, and an apply
    /// against an empty MobileNAV fails the app's installation.
    /// </summary>
    /// <returns>True when MobileNAV holds a configuration in this company.</returns>
    procedure MobileNAVIsConfigured(): Boolean
    var
        ServiceLookup: Codeunit "BJF MN Service Lookup";
    begin
        exit(ServiceLookup.HasConfiguration());
    end;

    /// <summary>Validates the given provider's declared configuration, applies it, and records that it was applied.</summary>
    /// <param name="ProviderType">The configuration provider to validate and apply.</param>
    procedure ApplyProvider(ProviderType: Enum "BJF MN Config Provider")
    begin
        this.ApplyProvider(ProviderType, false);
    end;

    /// <summary>
    /// Applies the given provider. Unattended runs the device handover without a client (the API)
    /// and raises MobileNAV's error when the handover is refused, after recording it as pending.
    /// </summary>
    /// <param name="ProviderType">The configuration provider to validate and apply.</param>
    /// <param name="Unattended">True to hand the configuration over to devices without a client.</param>
    procedure ApplyProvider(ProviderType: Enum "BJF MN Config Provider"; Unattended: Boolean)
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
        ContentHash: Text[64];
        DeviceHandoverCompleted: Boolean;
    begin
        this.ProviderCatalog.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        this.ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
        ContentHash := this.ConfigurationHash.Compute(TempConfigurationLine, TempConfigurationProperty);

        this.ConfigurationValidator.Validate(TempConfigurationLine, TempConfigurationProperty);
        // Publication is an explicit first phase, before construction/configuration writes.
        // MobileNAV resolves option metadata through a separate HTTP request: an endpoint
        // inserted in the current transaction is not visible to that request. An apply
        // failure may therefore leave published endpoints, but never a successful status.
        if this.PageManagement.PublishDeclaredServices(TempConfigurationLine) then
            Commit(); // MobileNAV's WSDL request runs in its own session and sees only committed endpoints.
        DeviceHandoverCompleted := this.Execute(TempConfigurationLine, TempConfigurationProperty, Unattended);
        this.ConfigurationStatus.RecordApplied(
            ProviderId, ProviderName, ContentHash, not DeviceHandoverCompleted);
        if Unattended and not DeviceHandoverCompleted then begin
            Commit(); // Keep the pending-handover status the Doctor reports; the error below would roll it back.
            Error(this.HandoverRefusedErr, ProviderId, this.PageManagement.LastHandoverError());
        end;
    end;

    /// <summary>
    /// Runs the apply without the device handover and without recording the provider as applied.
    /// Only "BJF MN Config Preview Run" calls it, inside a transaction it rolls back.
    /// </summary>
    /// <param name="ProviderType">The configuration provider to preview.</param>
    internal procedure PreviewProvider(ProviderType: Enum "BJF MN Config Provider")
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
    begin
        this.ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
        this.ConfigurationValidator.Validate(TempConfigurationLine, TempConfigurationProperty);
        this.KeepDeclaredPageRows(TempConfigurationLine);
        this.PageManagement.PublishDeclaredServices(TempConfigurationLine);
        this.PreviewMode := true;
        this.Execute(TempConfigurationLine, TempConfigurationProperty, true);
    end;

    /// <summary>
    /// Raised once per supported MobileNAV language for every TranslatedCaptions() target, with the
    /// session language set to that language, so a Label in the subscriber resolves to the
    /// translation from the app's XLIFF file. The session language is restored afterwards.
    /// Set Handled to true to write Caption for the language. Leave it false to write nothing for
    /// that language, and MobileNAV shows the Business Central caption.
    /// </summary>
    /// <param name="PageId">The page the caption is for.</param>
    /// <param name="ControlName">The control the caption is for, or blank for the page itself.</param>
    /// <param name="Caption">The caption in the current session language. Set it from a Label.</param>
    /// <param name="Handled">Set to true when Caption holds the answer.</param>
#pragma warning disable AC0024
    [IntegrationEvent(false, false)]
    procedure OnGetTranslatedCaption(PageId: Integer; ControlName: Text; var Caption: Text; var Handled: Boolean)
    begin
    end;
#pragma warning restore AC0024

    /// <summary>
    /// Replaces each TranslatedCaptions() marker line with one Caption line per MobileNAV language
    /// that a subscriber of OnGetTranslatedCaption answers for. MobileNAV languages are the
    /// SuppLang master data rows. Their Language ID is the Windows language the session switches to.
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    internal procedure ExpandTranslatedCaptions(var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempMarker: Record "BJF MN Config Line" temporary;
        LanguageCodes: List of [Code[20]];
        LanguageIds: List of [Integer];
        NextEntryNo: Integer;
    begin
        TempConfigurationLine.Reset();
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Caption);
        TempConfigurationLine.SetRange("Language Code", this.TranslatedLanguageTok);
        if TempConfigurationLine.IsEmpty() then begin
            TempConfigurationLine.Reset();
            exit;
        end;
        TempMarker.Copy(TempConfigurationLine, true);
        TempConfigurationLine.Reset();
        if TempConfigurationLine.FindLast() then
            NextEntryNo := TempConfigurationLine."Entry No.";
        this.ReadLanguages(LanguageCodes, LanguageIds);
        if TempMarker.FindSet() then
            repeat
                this.AddTranslatedCaptions(TempConfigurationLine, TempMarker, LanguageCodes, LanguageIds, NextEntryNo);
            until TempMarker.Next() = 0;
        TempConfigurationLine.Reset();
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Caption);
        TempConfigurationLine.SetRange("Language Code", this.TranslatedLanguageTok);
        TempConfigurationLine.DeleteAll(false);
        TempConfigurationLine.Reset();
    end;

    /// <summary>The MobileNAV languages (SuppLang master data rows with a Language ID), in master data order.</summary>
    /// <param name="LanguageCodes">Receives each language's code.</param>
    /// <param name="LanguageIds">Receives each language's Windows language id, at the same position.</param>
    local procedure ReadLanguages(var LanguageCodes: List of [Code[20]]; var LanguageIds: List of [Integer])
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        MasterData.SetRange(Type, MasterData.Type::SuppLang);
        MasterData.SetFilter("Language ID", '<>0');
        MasterData.SetLoadFields(Code, "Language ID");
        if MasterData.FindSet() then
            repeat
                LanguageCodes.Add(MasterData.Code);
                LanguageIds.Add(MasterData."Language ID");
            until MasterData.Next() = 0;
    end;

    local procedure AddTranslatedCaptions(var TempConfigurationLine: Record "BJF MN Config Line" temporary; Marker: Record "BJF MN Config Line" temporary; LanguageCodes: List of [Code[20]]; LanguageIds: List of [Integer]; var NextEntryNo: Integer)
    var
        CaptionText: Text;
        Index: Integer;
    begin
        for Index := 1 to LanguageIds.Count() do
            if this.RaiseForLanguage(Marker."Page ID", Marker."Control Name", LanguageIds.Get(Index), CaptionText) then begin
                NextEntryNo += 1;
                TempConfigurationLine.Init();
                TempConfigurationLine.Validate("Entry No.", NextEntryNo);
                TempConfigurationLine.Validate(Operation, Enum::"BJF MN Config Operation"::Caption);
                TempConfigurationLine.Validate("Page ID", Marker."Page ID");
                TempConfigurationLine.Validate("Control Name", Marker."Control Name");
                TempConfigurationLine.Validate("Language Code", CopyStr(LanguageCodes.Get(Index), 1, MaxStrLen(TempConfigurationLine."Language Code")));
                TempConfigurationLine.Validate(Description, CopyStr(CaptionText, 1, MaxStrLen(TempConfigurationLine.Description)));
                TempConfigurationLine.Insert(false);
            end;
    end;

    /// <summary>Raises OnGetTranslatedCaption with the session set to the Windows language, then restores the session.</summary>
    /// <param name="PageId">The page the caption is for.</param>
    /// <param name="ControlName">The control, or blank for the page.</param>
    /// <param name="LanguageId">Windows language id of the MobileNAV language.</param>
    /// <param name="CaptionText">Returns the caption a subscriber gave.</param>
    /// <returns>True when a subscriber answered with a caption.</returns>
    local procedure RaiseForLanguage(PageId: Integer; ControlName: Text; LanguageId: Integer; var CaptionText: Text): Boolean
    var
        TranslationHelper: Codeunit "Translation Helper";
        Handled: Boolean;
        Succeeded: Boolean;
    begin
        CaptionText := '';
        TranslationHelper.SetGlobalLanguageById(LanguageId);
        Succeeded := this.TryRaise(PageId, ControlName, CaptionText, Handled);
        TranslationHelper.RestoreGlobalLanguage();
        // A subscriber error must not leave the session in another language.
        if not Succeeded then
            Error(this.SubscriberFailedErr, GetLastErrorText());
        exit(Handled and (CaptionText <> ''));
    end;

    [TryFunction]
    local procedure TryRaise(PageId: Integer; ControlName: Text; var CaptionText: Text; var Handled: Boolean)
    begin
        this.OnGetTranslatedCaption(PageId, ControlName, CaptionText, Handled);
    end;

    /// <summary>
    /// A published MobileNAV page without ShowInMenu keeps the tiles and profile rows its
    /// administrator gave it. Taking them over would remove its tiles, and MobileNAV then deletes
    /// the root rows of other pages that hang off it.
    /// </summary>
    /// <param name="ConfigurationLine">The Published Page line.</param>
    /// <returns>True when the page keeps its administrator's tiles and profile rows.</returns>
    local procedure KeepsAdministratorProfiles(ConfigurationLine: Record "BJF MN Config Line" temporary): Boolean
    begin
        if ConfigurationLine."Show In Menu" then
            exit(false);
        exit(this.Lookup.IsMobileNAVPage(ConfigurationLine."Page ID"));
    end;

    /// <summary>Hands the preview recorder the current MobileNAV rows of every page the declaration names.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    local procedure KeepDeclaredPageRows(var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        ProfileSetup: Record "MobileNAV Profile Setup";
        CaptionAdmin: Record "MobileNAV CaptionML Admin.";
        SetupMain: Record "MobileNAV Svc. Setup Main";
        LineFormat: Record "MobileNAV Line Format";
        Recorder: Codeunit "BJF MN Preview Recorder";
        PageId: Integer;
        ServiceName: Text[100];
    begin
        foreach PageId in this.DeclaredPageIds(TempConfigurationLine) do begin
            ServiceName := this.Lookup.GetServiceName(PageId);
            Recorder.KeepRows(Database::"MobileNAV CaptionML Admin.", CaptionAdmin.FieldNo("Page ID"), PageId);
            if ServiceName <> '' then begin
                Recorder.KeepRows(Database::"MobileNAV Service Setup", ServiceSetup.FieldNo("Service Name"), ServiceName);
                Recorder.KeepRows(Database::"MobileNAV Profile Setup", ProfileSetup.FieldNo(ID), ServiceName);
                Recorder.KeepRows(Database::"MobileNAV Svc. Setup Main", SetupMain.FieldNo("Service Name"), ServiceName);
                Recorder.KeepRows(Database::"MobileNAV Line Format", LineFormat.FieldNo("Service Name"), ServiceName);
            end;
        end;
    end;

    /// <summary>The distinct page and target page ids the lines name, in line order.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <returns>The page ids, without zero.</returns>
    local procedure DeclaredPageIds(var TempConfigurationLine: Record "BJF MN Config Line" temporary) PageIds: List of [Integer]
    begin
        TempConfigurationLine.Reset();
        if TempConfigurationLine.FindSet() then
            repeat
                this.AddPageId(PageIds, TempConfigurationLine."Page ID");
                this.AddPageId(PageIds, TempConfigurationLine."Target Page ID");
            until TempConfigurationLine.Next() = 0;
        exit(PageIds);
    end;

    /// <summary>Adds a nonzero page id to the list when it is not there yet.</summary>
    /// <param name="PageIds">The list to add to.</param>
    /// <param name="PageId">The page id to add.</param>
    local procedure AddPageId(var PageIds: List of [Integer]; PageId: Integer)
    begin
        if (PageId <> 0) and not PageIds.Contains(PageId) then
            PageIds.Add(PageId);
    end;

    local procedure Execute(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; Unattended: Boolean): Boolean
    var
        PageServices: Dictionary of [Integer, Text];
    begin
        // MobileNAV only carries configuration through to devices for changes made while its
        // construction window is open, so the whole apply runs inside one.
        this.PageManagement.BeginConfigurationChange(Unattended);
        this.FieldManagement.ForgetUpdatablePages();
        this.RelationManagement.ForgetUpdatablePages();
        this.ApplyMasterData(TempConfigurationLine);
        this.PreparePublishedPages(TempConfigurationLine, PageServices);
        this.PrepareReferencedPages(TempConfigurationLine, TempConfigurationProperty, PageServices);
        this.ApplyPageFunctions(TempConfigurationLine, PageServices);
        // Page settings first: a page type change resets list-only field settings.
        this.ApplyProperties(TempConfigurationProperty, PageServices, true);
        this.ApplyFields(TempConfigurationLine, TempConfigurationProperty, PageServices);
        this.ApplyFunctionFields(TempConfigurationLine, TempConfigurationProperty, PageServices);
        this.ApplyScanFields(TempConfigurationLine, TempConfigurationProperty, PageServices);
        this.ApplyRelations(TempConfigurationLine, PageServices);
        this.ApplyProperties(TempConfigurationProperty, PageServices, false);
        this.ApplyUserScopes(TempConfigurationLine, PageServices);
        this.ApplyPageRows(TempConfigurationLine, PageServices);
        // Groups and order last among the field rows: flow filters add rows of their own.
        this.ApplyGroupsAndOrder(TempConfigurationLine, PageServices);
        this.ApplyAppearance(TempConfigurationLine, PageServices);
        // Profile rows override the service-level field rows on the device, so they are written
        // after every field operation and read the Control IDs those operations settled.
        this.ApplyProfilePages(TempConfigurationLine, TempConfigurationProperty, PageServices);
        // After the pages exist in the profiles, and before the field rows: a linked field's
        // target has to be reachable from the page the control sits on or the control is not
        // drawn at all. See "BJF MN Profile Mgt.".LinkPageToParent.
        this.ApplyProfilePageParents(TempConfigurationLine, PageServices);
        // The menu flag lives on the profile Page row; MobileNAV deletes a row that is neither on
        // the menu nor linked, so this follows the parent links.
        this.ApplyProfileMenu(TempConfigurationLine, PageServices);
        this.ApplyProfilePageSettings(TempConfigurationLine, PageServices);
        this.ApplyProfileFields(TempConfigurationLine, PageServices);
        // Staging runs after the fields: the per-field stage masks span every visible field row.
        this.ApplyStaging(TempConfigurationLine, PageServices);
        this.ApplyLayouts(TempConfigurationLine, PageServices);
        this.ApplyLineFormats(TempConfigurationLine, PageServices);
        TempConfigurationLine.Reset();
        if this.PreviewMode then begin
            this.PageManagement.EndConfigurationChangeWithoutHandover();
            exit(true);
        end;
        exit(this.PageManagement.PublishConfigurationToDevices(Unattended));
    end;

    local procedure ApplyMasterData(var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        TempConfigurationLine.SetFilter(Operation, '%1|%2|%3',
            Enum::"BJF MN Config Operation"::Category, Enum::"BJF MN Config Operation"::"Category Translation",
            Enum::"BJF MN Config Operation"::Profile);
        if TempConfigurationLine.FindSet() then
            repeat
                case TempConfigurationLine.Operation of
                    Enum::"BJF MN Config Operation"::Category:
                        this.MasterDataManagement.EnsureCategory(CopyStr(TempConfigurationLine."Control Name", 1, 20), TempConfigurationLine.Description);
                    Enum::"BJF MN Config Operation"::"Category Translation":
                        this.MasterDataManagement.EnsureCategoryTranslation(CopyStr(TempConfigurationLine."Control Name", 1, 20), TempConfigurationLine."Language Code", TempConfigurationLine.Description);
                    Enum::"BJF MN Config Operation"::Profile:
                        this.MasterDataManagement.EnsureProfile(TempConfigurationLine.Profile, TempConfigurationLine.Description);
                end;
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure PreparePublishedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                this.PageManagement.EnsurePage(
                    TempConfigurationLine."Page ID", TempConfigurationLine."Service Name", ServiceName);
                this.PageManagement.PublishPage(TempConfigurationLine."Page ID", ServiceName);
                this.ApplyPublishedPageSettings(TempConfigurationLine, ServiceName);
                this.PublishPageFunctionCodeunit(TempConfigurationLine, ServiceName);
                PageServices.Add(TempConfigurationLine."Page ID", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>Sets the page type, menu flag and main menu action a Published Page line declares.</summary>
    /// <param name="ConfigurationLine">The Published Page line.</param>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    local procedure ApplyPublishedPageSettings(ConfigurationLine: Record "BJF MN Config Line" temporary; ServiceName: Text[100])
    begin
        if ConfigurationLine."Page Type" <> '' then
            this.PageManagement.SetPageType(ServiceName, CopyStr(ConfigurationLine."Page Type", 1, 30));
        if not this.KeepsAdministratorProfiles(ConfigurationLine) then
            this.PageManagement.SetDisplayInMenu(ServiceName, ConfigurationLine."Show In Menu");
        if ConfigurationLine."Main Menu Action" <> '' then
            this.PageManagement.SetMainMenuAction(ServiceName, ConfigurationLine."Main Menu Action");
    end;

    /// <summary>Publishes the function codeunit a Published Page line declares, as a companion or as a report service.</summary>
    /// <param name="ConfigurationLine">The Published Page line.</param>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    local procedure PublishPageFunctionCodeunit(ConfigurationLine: Record "BJF MN Config Line" temporary; ServiceName: Text[100])
    begin
        if ConfigurationLine."Function Codeunit ID" = 0 then
            exit;
        if ConfigurationLine."Report Service Name" = '' then
            this.PageManagement.PublishFunctionCompanion(ServiceName, ConfigurationLine."Function Codeunit ID")
        else begin
            this.PageManagement.PublishFunctionService(
                ConfigurationLine."Function Codeunit ID", ConfigurationLine."Report Service Name");
            this.PageManagement.SetReportService(ServiceName, ConfigurationLine."Report Service Name");
        end;
    end;

    /// <summary>Registers the custom companion declared with PageFunctions() on a page the provider does not publish.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyPageFunctions(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Page Functions");
        if TempConfigurationLine.FindSet() then
            repeat
                this.PageManagement.PublishFunctionCompanion(this.ServiceOf(PageServices, TempConfigurationLine."Page ID"), TempConfigurationLine."Function Codeunit ID");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure PrepareReferencedPages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetFilter(Operation, '<>%1', Enum::"BJF MN Config Operation"::"Published Page");
        TempConfigurationLine.SetFilter("Page ID", '<>%1', 0);
        if TempConfigurationLine.FindSet() then
            repeat
                this.ResolvePage(TempConfigurationLine."Page ID", PageServices);
                if TempConfigurationLine."Target Page ID" <> 0 then
                    this.ResolvePage(TempConfigurationLine."Target Page ID", PageServices);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();

        TempConfigurationProperty.Reset();
        if TempConfigurationProperty.FindSet() then
            repeat
                this.ResolvePage(TempConfigurationProperty."Page ID", PageServices);
            until TempConfigurationProperty.Next() = 0;
    end;

    /// <summary>Writes the declared properties of one level to MobileNAV.</summary>
    /// <param name="TempConfigurationProperty">The provider's declared properties.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    /// <param name="PageLevel">True writes the page (Main row) properties, false the control properties.</param>
    local procedure ApplyProperties(var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text]; PageLevel: Boolean)
    begin
        TempConfigurationProperty.Reset();
        if PageLevel then
            TempConfigurationProperty.SetRange("Control Name", '')
        else
            TempConfigurationProperty.SetFilter("Control Name", '<>%1', '');
        if TempConfigurationProperty.FindSet() then
            repeat
                // Field settings are written with their control's field row, see ApplyFields.
                if not this.PropertyCatalog.IsFieldSetting(TempConfigurationProperty.Property) then
                    this.PropertyManagement.Apply(this.ServiceOf(PageServices, TempConfigurationProperty."Page ID"), TempConfigurationProperty);
            until TempConfigurationProperty.Next() = 0;
        TempConfigurationProperty.Reset();
    end;

    /// <summary>Configures the field row of every plain field, from the field settings its property rows declare.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="TempConfigurationProperty">The provider's property rows. Filtered to the line's page while each control is written.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Field);
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                TempConfigurationProperty.SetRange("Page ID", TempConfigurationLine."Page ID");
                if not this.FieldManagement.ConfigureControl(
                    ServiceName, TempConfigurationLine."Control Name", TempConfigurationProperty,
                    '', TempConfigurationLine.Editable)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationProperty.Reset();
        TempConfigurationLine.Reset();
    end;

    /// <summary>Configures the field row of every function field, its function name included.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="TempConfigurationProperty">The provider's property rows. Filtered to the line's page while each control is written.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyFunctionFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
        FunctionName: Text[50];
        Problem: Text;
        CompanionCodeunitId: Integer;
        UsesFunctionCodeunit: Boolean;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Function Field");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                // A function codeunit runs the button as one of its own procedures: the name is
                // the procedure's, and the page-function companion is not what the device calls.
                UsesFunctionCodeunit := this.HasFunctionCodeunit(TempConfigurationLine, TempConfigurationLine."Page ID");
                if UsesFunctionCodeunit then begin
                    Problem := this.ButtonProcedureNameProblem(TempConfigurationLine, ServiceName, true);
                    if Problem <> '' then
                        Error(ErrorInfo.Create(Problem));
                    FunctionName := TempConfigurationLine."Function Name";
                end else
                    FunctionName := this.ResolveStandardFunction(TempConfigurationLine, ServiceName, CompanionCodeunitId);
                TempConfigurationProperty.SetRange("Page ID", TempConfigurationLine."Page ID");
                if not this.FieldManagement.ConfigureControl(
                    ServiceName, TempConfigurationLine."Control Name", TempConfigurationProperty,
                    FunctionName, TempConfigurationLine.Editable)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
                if not UsesFunctionCodeunit then
                    this.PageManagement.PublishStandardCompanion(ServiceName, CompanionCodeunitId);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationProperty.Reset();
        TempConfigurationLine.Reset();
    end;

    /// <summary>Configures the field row of every scan field, from the field settings its property rows declare.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="TempConfigurationProperty">The provider's property rows. Filtered to the line's page while each control is written.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyScanFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Scan Field");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                TempConfigurationProperty.SetRange("Page ID", TempConfigurationLine."Page ID");
                // A scan field never makes its page updatable: it is filled from the device's scanner.
                if not this.FieldManagement.ConfigureControl(
                    ServiceName, TempConfigurationLine."Control Name", TempConfigurationProperty,
                    '', false)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationProperty.Reset();
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyUserScopes(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"User Scope");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                if not this.FieldManagement.ConfigureUserScope(
                    ServiceName, TempConfigurationLine."Control Name")
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>
    /// Clears the profile exclusion on every page this plan touches.
    ///
    /// A page MobileNAV does not collect for a user is not merely absent: it also force-hides
    /// any control whose job is to open it, because a relation button is only drawn when its
    /// target page is among the collected pages. Running this for every page in the plan means a
    /// declared page and the control that opens it cannot disagree. See "BJF MN Profile Mgt.".
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="TempConfigurationProperty">The provider's declared properties, read for MenuCategory().</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyProfilePages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
        Parents: List of [Text];
    begin
        // Only the pages this plan publishes. A provider that publishes a page is asking for it
        // to be usable, whereas the other pages here are MobileNAV's own and already belong to
        // whichever profiles their administrator chose. A page without a menu tile is reached
        // through its links alone, so it belongs only to the profiles that carry a parent page.
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                if this.KeepsAdministratorProfiles(TempConfigurationLine) then
                    continue;
                if TempConfigurationLine."Show In Menu" then
                    this.ProfileManagement.IncludePageInProfiles(ServiceName, '')
                else begin
                    Parents := this.ParentServices(TempConfigurationLine, TempConfigurationLine."Page ID", PageServices);
                    if Parents.Count() = 0 then
                        Error(this.MenuUnreachableErr, ServiceName);
                    this.ProfileManagement.IncludePageWhereParentExists(ServiceName, Parents);
                end;
                this.ProfileManagement.SetPageCategory(
                    ServiceName, this.ProfileManagement.DeclaredMenuCategory(TempConfigurationProperty, TempConfigurationLine."Page ID"));
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>
    /// The service names of the pages a device reaches this page from: the pages whose declared
    /// linked or lookup fields open it, otherwise the relations MobileNAV itself already has to it
    /// (its own pages link to Bin Content from every bin lookup, for example).
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="PageId">The page to find the parents of.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    /// <returns>The parent service names, without duplicates from the declared links.</returns>
    local procedure ParentServices(var TempConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer; var PageServices: Dictionary of [Integer, Text]) Parents: List of [Text]
    var
        TempLink: Record "BJF MN Config Line" temporary;
        ParentService: Text;
    begin
        TempLink.Copy(TempConfigurationLine, true);
        TempLink.Reset();
        TempLink.SetRelationFilter();
        TempLink.SetRange("Target Page ID", PageId);
        if TempLink.FindSet() then
            repeat
                ParentService := this.ServiceOf(PageServices, TempLink."Page ID");
                if not Parents.Contains(ParentService) then
                    Parents.Add(ParentService);
            until TempLink.Next() = 0;
        if Parents.Count() > 0 then
            exit;

        foreach ParentService in this.Lookup.RelationSources(this.ServiceOf(PageServices, PageId)) do
            Parents.Add(ParentService);
    end;

    /// <summary>
    /// Makes every linked field's target page a child of the page the control sits on.
    ///
    /// Declaring a linked field is a statement that the control opens the target from this
    /// page, and MobileNAV only draws such a control once the target is reachable from that
    /// page in the profile hierarchy. Deriving the hierarchy from the links the provider
    /// already declared keeps the two from disagreeing.
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyProfilePageParents(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetRelationFilter();
        if TempConfigurationLine.FindSet() then
            repeat
                this.ProfileManagement.LinkPageToParent(
                    this.ServiceOf(PageServices, TempConfigurationLine."Target Page ID"), this.ServiceOf(PageServices, TempConfigurationLine."Page ID"), '');
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>Puts a tile on the device home menu only for pages declared ShowInMenu.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyProfileMenu(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                if not this.KeepsAdministratorProfiles(TempConfigurationLine) then
                    if not this.ProfileManagement.SetPageMenuVisibility(ServiceName, '', TempConfigurationLine."Show In Menu") then
                        Error(this.MenuUnreachableErr, ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyProfileFields(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Field");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                if not this.ProfileManagement.ConfigureProfileField(
                    ServiceName, TempConfigurationLine."Control Name",
                    TempConfigurationLine.Profile,
                    TempConfigurationLine.Visible, TempConfigurationLine.Editable)
                then
                    Error(this.FieldMissingErr, TempConfigurationLine."Control Name", ServiceName);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyStaging(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        StagedPageIds: List of [Integer];
        PageId: Integer;
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
        if TempConfigurationLine.FindSet() then
            repeat
                StagedPageIds.Add(TempConfigurationLine."Page ID");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();

        // ApplyPageStaging refilters the shared temporary record, so the page ids are
        // collected first rather than iterated in place.
        foreach PageId in StagedPageIds do
            this.StageManagement.ApplyPageStaging(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
    end;

    local procedure ApplyRelations(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        TempControlLine: Record "BJF MN Config Line" temporary;
        ServiceName: Text[100];
        TargetServiceName: Text[100];
        Configured: Boolean;
    begin
        TempControlLine.Copy(TempConfigurationLine, true);
        TempControlLine.Reset();
        TempControlLine.SetRelationFilter();
        if TempControlLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempControlLine."Page ID");
                TargetServiceName := this.ServiceOf(PageServices, TempControlLine."Target Page ID");
                if TempControlLine.Operation = Enum::"BJF MN Config Operation"::"Linked Field" then
                    Configured := this.RelationManagement.ConfigureLink(ServiceName, TargetServiceName, TempControlLine, TempConfigurationLine)
                else
                    Configured := this.RelationManagement.ConfigureLookup(ServiceName, TargetServiceName, TempControlLine, TempConfigurationLine);
                if not Configured then
                    Error(this.FieldMissingErr, TempControlLine."Control Name", ServiceName);
            until TempControlLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    /// <summary>Page filters, flow filters, saved filters and operations, per page that declares any.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    local procedure ApplyPageRows(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        PageId: Integer;
    begin
        foreach PageId in TempConfigurationLine.PageIdsWith(Enum::"BJF MN Config Operation"::"User Scope", Enum::"BJF MN Config Operation"::"Page Filter") do
            this.FilterManagement.ApplyPageFilters(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Flow Filter");
        if TempConfigurationLine.FindSet() then
            repeat
                this.FilterManagement.ApplyFlowFilter(this.ServiceOf(PageServices, TempConfigurationLine."Page ID"), TempConfigurationLine."Control Name");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
        foreach PageId in TempConfigurationLine.PageIdsWith(Enum::"BJF MN Config Operation"::"Saved Filter") do
            this.FilterManagement.ApplySavedFilters(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
        foreach PageId in TempConfigurationLine.PageIdsWith(Enum::"BJF MN Config Operation"::Operation) do
            this.FilterManagement.ApplyOperations(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
    end;

    local procedure ApplyGroupsAndOrder(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        PageId: Integer;
    begin
        foreach PageId in TempConfigurationLine.PageIdsWith(Enum::"BJF MN Config Operation"::"Field Order") do
            this.GroupManagement.ApplyDeclaredOrder(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
        foreach PageId in TempConfigurationLine.PageIdsWith(Enum::"BJF MN Config Operation"::Group) do
            this.GroupManagement.ApplyGroups(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
    end;

    local procedure ApplyAppearance(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        TempConfigurationLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::Caption, Enum::"BJF MN Config Operation"::"Menu Picture");
        if TempConfigurationLine.FindSet() then
            repeat
                ServiceName := this.ServiceOf(PageServices, TempConfigurationLine."Page ID");
                if TempConfigurationLine.Operation = Enum::"BJF MN Config Operation"::Caption then
                    this.AppearanceManagement.SetCaption(ServiceName, TempConfigurationLine."Control Name", TempConfigurationLine."Language Code", TempConfigurationLine.Description)
                else
                    this.AppearanceManagement.SetMenuPicture(ServiceName, TempConfigurationLine);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyProfilePageSettings(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    begin
        TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Page");
        if TempConfigurationLine.FindSet() then
            repeat
                this.ProfileManagement.ConfigureProfilePage(
                    this.ServiceOf(PageServices, TempConfigurationLine."Page ID"), TempConfigurationLine.Profile,
                    TempConfigurationLine.Disabled, TempConfigurationLine."Auto Refresh On Open", TempConfigurationLine."Multi Select",
                    TempConfigurationLine."Menu Category");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    local procedure ApplyLayouts(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        TempLayoutLine: Record "BJF MN Config Line" temporary;
    begin
        TempLayoutLine.Copy(TempConfigurationLine, true);
        TempLayoutLine.Reset();
        TempLayoutLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Layout);
        if TempLayoutLine.FindSet() then
            repeat
                this.LayoutManagement.ApplyLayout(this.ServiceOf(PageServices, TempLayoutLine."Page ID"), TempLayoutLine, TempConfigurationLine);
            until TempLayoutLine.Next() = 0;
    end;

    local procedure ApplyLineFormats(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var PageServices: Dictionary of [Integer, Text])
    var
        PageId: Integer;
    begin
        foreach PageId in TempConfigurationLine.PageIdsWith(Enum::"BJF MN Config Operation"::"Line Format") do
            this.LineFormatManagement.ApplyLineFormats(this.ServiceOf(PageServices, PageId), TempConfigurationLine, PageId);
    end;

    /// <summary>
    /// The function a button runs when the page has no function codeunit of its own, and the
    /// companion that serves it. The table is only known once the service exists, so the name is
    /// resolved here rather than in the builder. See ResolveButtonFunction.
    /// </summary>
    /// <param name="ConfigurationLine">The Function Field line.</param>
    /// <param name="ServiceName">The page's MobileNAV service name.</param>
    /// <param name="CompanionCodeunitId">Returns the companion codeunit that serves the function.</param>
    /// <returns>The function name the device calls.</returns>
    local procedure ResolveStandardFunction(ConfigurationLine: Record "BJF MN Config Line" temporary; ServiceName: Text[100]; var CompanionCodeunitId: Integer): Text[50]
    var
        Problems: List of [Text];
        TableNo: Integer;
        FunctionName: Text[50];
    begin
        if not this.Lookup.GetServiceTableNo(ServiceName, TableNo) then
            Error(this.PageMissingErr, ConfigurationLine."Page ID");
        FunctionName := this.ResolveButtonFunction(ConfigurationLine, ServiceName, true, TableNo, CompanionCodeunitId, Problems);
        if Problems.Count() > 0 then
            Error(ErrorInfo.Create(Problems.Get(1)));
        exit(FunctionName);
    end;

    /// <summary>The MobileNAV service name of a page the apply has prepared.</summary>
    /// <param name="PageServices">The service name of each page, by page id.</param>
    /// <param name="PageId">The page.</param>
    /// <returns>The service name.</returns>
    local procedure ServiceOf(var PageServices: Dictionary of [Integer, Text]; PageId: Integer): Text[100]
    begin
        exit(CopyStr(PageServices.Get(PageId), 1, 100));
    end;

    /// <summary>Whether the page has a custom function codeunit, published with it or declared with PageFunctions().</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="PageId">The page to check.</param>
    /// <returns>True when the page has a function codeunit of its own.</returns>
    internal procedure HasFunctionCodeunit(var TempConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer): Boolean
    var
        TempPublishedLine: Record "BJF MN Config Line" temporary;
    begin
        TempPublishedLine.Copy(TempConfigurationLine, true);
        TempPublishedLine.Reset();
        TempPublishedLine.SetFilter(Operation, '%1|%2', Enum::"BJF MN Config Operation"::"Published Page", Enum::"BJF MN Config Operation"::"Page Functions");
        TempPublishedLine.SetRange("Page ID", PageId);
        TempPublishedLine.SetFilter("Function Codeunit ID", '<>%1', 0);
        exit(not TempPublishedLine.IsEmpty());
    end;

    /// <summary>
    /// Shared with "BJF MN Metadata Validator": the apply raises the first problem these button
    /// procedures return and names the page by its service name, the validator collects every
    /// problem and names the page by its id. ServiceWording picks the matching message texts.
    ///
    /// The problem with a button on a page that runs its buttons through a function codeunit:
    /// the procedure name cannot be derived, so FunctionName() is required.
    /// </summary>
    /// <param name="ConfigurationLine">The Function Field line.</param>
    /// <param name="PageRef">The page as the message names it: its service name or its page id.</param>
    /// <param name="ServiceWording">True for the apply's wording, false for the validator's.</param>
    /// <returns>The problem, or blank when the line names its procedure.</returns>
    internal procedure ButtonProcedureNameProblem(ConfigurationLine: Record "BJF MN Config Line" temporary; PageRef: Variant; ServiceWording: Boolean): Text
    begin
        if ConfigurationLine."Function Name" <> '' then
            exit('');
        if ServiceWording then
            exit(StrSubstNo(this.ProcedureNameRequiredErr, ConfigurationLine."Control Name", PageRef));
        exit(StrSubstNo(this.ProcedureNameRequiredPageErr, ConfigurationLine."Control Name", PageRef));
    end;

    /// <summary>
    /// The function a button runs when the page has no function codeunit of its own, and the
    /// companion that serves it. A declared FunctionName() must be one that companion has, or
    /// every tap fails on the device with 'Method is invalid'. A button declared without
    /// FunctionName() is served by whichever of MobileNAV's page functions handles the page's
    /// source table.
    /// </summary>
    /// <param name="ConfigurationLine">The Function Field line.</param>
    /// <param name="PageRef">The page as the messages name it: its service name or its page id.</param>
    /// <param name="ServiceWording">True for the apply's wording, false for the validator's.</param>
    /// <param name="TableNo">The page's source table.</param>
    /// <param name="CompanionCodeunitId">Returns the companion codeunit that serves the function.</param>
    /// <param name="Problems">Receives the problems found, in the order the apply checks them.</param>
    /// <returns>The function name the device calls.</returns>
    internal procedure ResolveButtonFunction(ConfigurationLine: Record "BJF MN Config Line" temporary; PageRef: Variant; ServiceWording: Boolean; TableNo: Integer; var CompanionCodeunitId: Integer; var Problems: List of [Text]): Text[50]
    var
        FunctionRouter: Codeunit "BJF MN Function Router";
        DefaultName: Text[50];
    begin
        if not FunctionRouter.TryGetStandardRoute(TableNo, CompanionCodeunitId, DefaultName) then begin
            if ServiceWording then
                Problems.Add(StrSubstNo(this.NoDispatcherErr, ConfigurationLine."Control Name", PageRef, TableNo))
            else
                Problems.Add(StrSubstNo(this.NoDispatcherPageErr, ConfigurationLine."Control Name", PageRef, TableNo));
            exit(DefaultName);
        end;

        if CompanionCodeunitId = Codeunit::"MobileNAV Page Functions" then
            exit(this.ResolvePageFunction(ConfigurationLine, PageRef, ServiceWording, TableNo, DefaultName, Problems));

        this.CheckTableFunction(ConfigurationLine, PageRef, ServiceWording, DefaultName, Problems);
        exit(DefaultName);
    end;

    /// <summary>The MobileNAV Page Functions function a button runs, after checking the declared name exists for the table.</summary>
    /// <param name="ConfigurationLine">The Function Field line.</param>
    /// <param name="PageRef">The page as the message names it.</param>
    /// <param name="ServiceWording">True for the apply's wording, false for the validator's.</param>
    /// <param name="TableNo">The page's source table.</param>
    /// <param name="DefaultName">The function used when the line declares none.</param>
    /// <param name="Problems">Receives the problem found.</param>
    /// <returns>The function name the device calls.</returns>
    local procedure ResolvePageFunction(ConfigurationLine: Record "BJF MN Config Line" temporary; PageRef: Variant; ServiceWording: Boolean; TableNo: Integer; DefaultName: Text[50]; var Problems: List of [Text]): Text[50]
    var
        PageFunctionCatalog: Codeunit "BJF MN Page Function Catalog";
        FunctionNames: Text;
    begin
        if ConfigurationLine."Function Name" = '' then
            exit(DefaultName);
        if not PageFunctionCatalog.Contains(TableNo, ConfigurationLine."Function Name") then begin
            FunctionNames := PageFunctionCatalog.Names(TableNo).Replace('|', ', ');
            if ServiceWording then
                Problems.Add(StrSubstNo(this.UnknownPageFunctionErr, ConfigurationLine."Control Name", PageRef, ConfigurationLine."Function Name", TableNo, FunctionNames))
            else
                Problems.Add(StrSubstNo(this.UnknownPageFunctionPageErr, ConfigurationLine."Control Name", PageRef, ConfigurationLine."Function Name", TableNo, FunctionNames));
        end;
        exit(ConfigurationLine."Function Name");
    end;

    /// <summary>The problems with a button served by "BJF MN Table Functions" that declares a function name or type it does not have.</summary>
    /// <param name="ConfigurationLine">The Function Field line.</param>
    /// <param name="PageRef">The page as the messages name it.</param>
    /// <param name="ServiceWording">True for the apply's wording, false for the validator's.</param>
    /// <param name="DefaultName">The one function the table has.</param>
    /// <param name="Problems">Receives the problems found.</param>
    local procedure CheckTableFunction(ConfigurationLine: Record "BJF MN Config Line" temporary; PageRef: Variant; ServiceWording: Boolean; DefaultName: Text[50]; var Problems: List of [Text])
    var
        Vocabulary: Codeunit "BJF MN Vocabulary";
    begin
        // "BJF MN Table Functions" has one plain function per table.
        if (ConfigurationLine."Function Name" <> '') and (ConfigurationLine."Function Name" <> DefaultName) then
            if ServiceWording then
                Problems.Add(StrSubstNo(this.UnknownTableFunctionErr, ConfigurationLine."Control Name", PageRef, ConfigurationLine."Function Name", DefaultName))
            else
                Problems.Add(StrSubstNo(this.UnknownTableFunctionPageErr, ConfigurationLine."Control Name", PageRef, ConfigurationLine."Function Name", DefaultName));
        if (ConfigurationLine."Function Type" <> '') and
            (ConfigurationLine."Function Type" <> Vocabulary.FunctionTypeName(Enum::"BJF MN Function Type"::Normal))
        then
            if ServiceWording then
                Problems.Add(StrSubstNo(this.TableFunctionTypeErr, ConfigurationLine."Control Name", PageRef, ConfigurationLine."Function Type"))
            else
                Problems.Add(StrSubstNo(this.TableFunctionTypePageErr, ConfigurationLine."Control Name", PageRef, ConfigurationLine."Function Type"));
    end;

    local procedure ResolvePage(PageId: Integer; var PageServices: Dictionary of [Integer, Text])
    var
        ServiceName: Text[100];
    begin
        if PageServices.ContainsKey(PageId) then
            exit;
        if not this.PageManagement.RefreshConfiguredPage(PageId, ServiceName) then
            Error(this.PageMissingErr, PageId);
        PageServices.Add(PageId, ServiceName);
    end;

    var
        ConfigurationStatus: Record "BJF MN Config Status";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationValidator: Codeunit "BJF MN Config Validator";
        ConfigurationHash: Codeunit "BJF MN Config Hash";
        Lookup: Codeunit "BJF MN Service Lookup";
        PageManagement: Codeunit "BJF MN Page Mgt.";
        FieldManagement: Codeunit "BJF MN Field Mgt.";
        ProfileManagement: Codeunit "BJF MN Profile Mgt.";
        PropertyManagement: Codeunit "BJF MN Property Mgt.";
        PropertyCatalog: Codeunit "BJF MN Property Catalog";
        RelationManagement: Codeunit "BJF MN Relation Mgt.";
        FilterManagement: Codeunit "BJF MN Filter Mgt.";
        GroupManagement: Codeunit "BJF MN Group Mgt.";
        AppearanceManagement: Codeunit "BJF MN Appearance Mgt.";
        MasterDataManagement: Codeunit "BJF MN Master Data Mgt.";
        LayoutManagement: Codeunit "BJF MN Layout Mgt.";
        LineFormatManagement: Codeunit "BJF MN Line Format Mgt.";
        StageManagement: Codeunit "BJF MN Stage Mgt.";
        PreviewMode: Boolean;
        TranslatedLanguageTok: Label '*', Locked = true;
        SubscriberFailedErr: Label 'A subscriber of OnGetTranslatedCaption failed: %1', Comment = '%1 = error text';
        HandoverRefusedErr: Label 'Provider %1 was applied to MobileNAV''s tables, but MobileNAV refused the device handover: %2 MobileNAV asks a delegated administrator to confirm the handover, which an API call cannot answer; call the API as a licensed user or a Microsoft Entra application.', Comment = '%1 = provider id, %2 = MobileNAV error text';
        MenuUnreachableErr: Label 'Page %1 is not declared ShowInMenu(), no Link opens it and no MobileNAV page relates to it, so devices could never reach it. Declare ShowInMenu() or a Link from another page. To give buttons on a MobileNAV page a codeunit of yours, declare PageFunctions() without Publish().', Comment = '%1 = service name';
        PageMissingErr: Label 'Page %1 has not been registered in MobileNAV.', Comment = '%1 = page object id';
        FieldMissingErr: Label 'Control %1 was not found on MobileNAV service %2 after metadata refresh.', Comment = '%1 = control name, %2 = MobileNAV service name';
        ProcedureNameRequiredErr: Label 'Button %1 on %2 needs FunctionName(): the page runs its buttons through a function codeunit, so the procedure name cannot be derived.', Comment = '%1 = control name, %2 = service name';
        NoDispatcherErr: Label 'Button %1 on MobileNAV service %2 cannot be served automatically: neither MobileNAV nor this app has a page function for table %3. Declare PageFunctions() with a codeunit of yours and name its procedure with FunctionName().', Comment = '%1 = control name, %2 = MobileNAV service name, %3 = table number';
        UnknownPageFunctionErr: Label 'Button %1 on %2 names function %3, which MobileNAV Page Functions does not have for table %4, so every tap would fail on the device. Leave FunctionName() out, use one of %5, or declare PageFunctions() with the codeunit that has %3.', Comment = '%1 = control name, %2 = service name, %3 = function name, %4 = table number, %5 = list of function names';
        UnknownTableFunctionErr: Label 'Button %1 on %2 names function %3, but the page''s buttons run through "BJF MN Table Functions", which only has %4. Leave FunctionName() out and handle the tap in OnPageFunction, or declare PageFunctions() with the codeunit that has %3.', Comment = '%1 = control name, %2 = service name, %3 = declared function name, %4 = the function name it has';
        TableFunctionTypeErr: Label 'Button %1 on %2 has function type %3. "BJF MN Table Functions" serves Normal buttons only. Declare PageFunctions() with a codeunit that has the %3 function.', Comment = '%1 = control name, %2 = service name, %3 = function type';
        ProcedureNameRequiredPageErr: Label 'Button %1 on page %2 needs FunctionName(): the page runs its buttons through a function codeunit, so the procedure name cannot be derived.', Comment = '%1 = control name, %2 = page id';
        NoDispatcherPageErr: Label 'Button %1 on page %2 cannot be served automatically: neither MobileNAV nor this app has a page function for table %3. Declare PageFunctions() with a codeunit of yours and name its procedure with FunctionName().', Comment = '%1 = control name, %2 = page id, %3 = table number';
        UnknownPageFunctionPageErr: Label 'Button %1 on page %2 names function %3, which MobileNAV Page Functions does not have for table %4, so every tap would fail on the device. Leave FunctionName() out, use one of %5, or declare PageFunctions() with the codeunit that has %3.', Comment = '%1 = control name, %2 = page id, %3 = function name, %4 = table number, %5 = list of function names';
        UnknownTableFunctionPageErr: Label 'Button %1 on page %2 names function %3, but the page''s buttons run through "BJF MN Table Functions", which only has %4. Leave FunctionName() out and handle the tap in OnPageFunction, or declare PageFunctions() with the codeunit that has %3.', Comment = '%1 = control name, %2 = page id, %3 = declared function name, %4 = the function name it has';
        TableFunctionTypePageErr: Label 'Button %1 on page %2 has function type %3. "BJF MN Table Functions" serves Normal buttons only. Declare PageFunctions() with a codeunit that has the %3 function.', Comment = '%1 = control name, %2 = page id, %3 = function type';
}
