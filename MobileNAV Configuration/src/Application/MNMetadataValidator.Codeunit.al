namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// Checks a provider's definition against Business Central metadata only, so it runs in a
/// container without MobileNAV data: page ids against AllObjWithCaption, control names against
/// the page's controls and its source table's fields, button functions against the function
/// catalogs, and whether a published page can be reached on the device. The builder's modifier
/// rules and the validator's whole-definition rules are reported as the first problem when they
/// stop the definition. The apply path does not call this codeunit.
/// </summary>
codeunit 77736 "BJF MN Metadata Validator"
{
    Access = Internal;

    /// <summary>Builds the provider's definition and returns every problem the metadata reveals.</summary>
    /// <param name="ProviderType">The provider to check.</param>
    /// <param name="Problems">Returns the problems, empty when the provider is valid.</param>
    procedure Collect(ProviderType: Enum "BJF MN Config Provider"; var Problems: List of [Text])
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
    begin
        Clear(this.Found);
        Clear(this.PageControls);
        Clear(this.PageExistence);
        Clear(this.RelationTargets);
        this.ControlsReadable := this.CanReadControls();
        if not this.TryBuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty) then
            this.AddProblem(GetLastErrorText())
        else begin
            if not this.TryValidate(TempConfigurationLine, TempConfigurationProperty) then
                this.AddProblem(GetLastErrorText());
            this.CheckDefinition(TempConfigurationLine, TempConfigurationProperty);
        end;
        Problems := this.Found;
    end;

    [TryFunction]
    local procedure TryBuildDefinition(ProviderType: Enum "BJF MN Config Provider"; var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    var
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ProviderId: Code[50];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
    begin
        ProviderCatalog.GetMetadata(ProviderType, ProviderId, ProviderName, ProviderDescription);
        ProviderCatalog.BuildDefinition(ProviderType, TempConfigurationLine, TempConfigurationProperty);
    end;

    [TryFunction]
    local procedure TryValidate(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    var
        ConfigurationValidator: Codeunit "BJF MN Config Validator";
    begin
        ConfigurationValidator.Validate(TempConfigurationLine, TempConfigurationProperty);
    end;

    local procedure CheckDefinition(var TempConfigurationLine: Record "BJF MN Config Line" temporary; var TempConfigurationProperty: Record "BJF MN Config Property" temporary)
    begin
        this.CollectRelationTargets(TempConfigurationLine);
        TempConfigurationLine.Reset();
        if TempConfigurationLine.FindSet() then
            repeat
                this.CheckLine(TempConfigurationLine);
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();

        TempConfigurationProperty.Reset();
        if TempConfigurationProperty.FindSet() then
            repeat
                this.CheckProperty(TempConfigurationLine, TempConfigurationProperty);
            until TempConfigurationProperty.Next() = 0;
        TempConfigurationProperty.Reset();
    end;

    /// <summary>Runs every check that applies to the current line.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines, positioned on the line to check.</param>
    local procedure CheckLine(var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        this.CheckLinePages(TempConfigurationLine, TempConfigurationLine);
        this.CheckLineControls(TempConfigurationLine);
        case TempConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::"Function Field":
                this.CheckButton(TempConfigurationLine, TempConfigurationLine);
            Enum::"BJF MN Config Operation"::"Layout Action":
                this.CheckLayoutAction(TempConfigurationLine, TempConfigurationLine);
            Enum::"BJF MN Config Operation"::"Published Page":
                this.CheckReachable(TempConfigurationLine, TempConfigurationLine);
        end;
    end;

    /// <summary>The target page of each declared link and lookup, by page and control, for the relation detail lines.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    local procedure CollectRelationTargets(var TempConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        TempConfigurationLine.Reset();
        TempConfigurationLine.SetRelationFilter();
        if TempConfigurationLine.FindSet() then
            repeat
                this.RelationTargets.Set(this.RelationKey(TempConfigurationLine), TempConfigurationLine."Target Page ID");
            until TempConfigurationLine.Next() = 0;
        TempConfigurationLine.Reset();
    end;

    // ---- Pages and codeunits ------------------------------------------------------------

    /// <summary>
    /// Reports a page or codeunit id that is not an object, and a page the provider uses without
    /// publishing it that is not one of MobileNAV's pages: the apply finds such a page only when
    /// MobileNAV already has a service for it, which depends on data outside the provider.
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="ConfigurationLine">The line to check.</param>
    local procedure CheckLinePages(var TempConfigurationLine: Record "BJF MN Config Line" temporary; ConfigurationLine: Record "BJF MN Config Line" temporary)
    begin
        if ConfigurationLine.Operation = Enum::"BJF MN Config Operation"::"Published Page" then
            this.CheckPageExists(ConfigurationLine."Page ID")
        else
            this.CheckUsedPage(TempConfigurationLine, ConfigurationLine."Page ID");
        this.CheckUsedPage(TempConfigurationLine, ConfigurationLine."Target Page ID");
        if ConfigurationLine."Function Codeunit ID" <> 0 then
            if not this.CodeunitExists(ConfigurationLine."Function Codeunit ID") then
                this.AddProblem(StrSubstNo(this.CodeunitMissingErr, ConfigurationLine."Function Codeunit ID", ConfigurationLine."Page ID"));
    end;

    local procedure CheckUsedPage(var TempConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer)
    var
        TempPublishedLine: Record "BJF MN Config Line" temporary;
        Lookup: Codeunit "BJF MN Service Lookup";
    begin
        if PageId = 0 then
            exit;
        if not this.CheckPageExists(PageId) then
            exit;
        TempPublishedLine.Copy(TempConfigurationLine, true);
        TempPublishedLine.Reset();
        TempPublishedLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        TempPublishedLine.SetRange("Page ID", PageId);
        if TempPublishedLine.IsEmpty() and not Lookup.IsMobileNAVPage(PageId) then
            this.AddProblem(StrSubstNo(this.PageNotPublishedErr, PageId, this.PageName(PageId)));
    end;

    local procedure CheckPageExists(PageId: Integer): Boolean
    begin
        if this.PageExists(PageId) then
            exit(true);
        this.AddProblem(StrSubstNo(this.PageMissingErr, PageId));
        exit(false);
    end;

    local procedure PageExists(PageId: Integer): Boolean
    var
        Exists: Boolean;
    begin
        if PageId <= 0 then
            exit(false);
        if not this.PageExistence.Get(PageId, Exists) then begin
            Exists := this.PageObjectExists(PageId);
            this.PageExistence.Add(PageId, Exists);
        end;
        exit(Exists);
    end;

    local procedure PageObjectExists(PageId: Integer): Boolean
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Page);
        AllObjWithCaption.SetRange("Object ID", PageId);
        exit(not AllObjWithCaption.IsEmpty());
    end;

    local procedure CodeunitExists(CodeunitId: Integer): Boolean
    var
        AllObjWithCaption: Record AllObjWithCaption;
    begin
        AllObjWithCaption.SetRange("Object Type", AllObjWithCaption."Object Type"::Codeunit);
        AllObjWithCaption.SetRange("Object ID", CodeunitId);
        exit(not AllObjWithCaption.IsEmpty());
    end;

    local procedure PageName(PageId: Integer): Text
    var
        AllObjWithCaption: Record AllObjWithCaption;
        Lookup: Codeunit "BJF MN Service Lookup";
    begin
        exit(Lookup.ObjectNameOf(AllObjWithCaption."Object Type"::Page, PageId));
    end;

    local procedure SourceTableNo(PageId: Integer): Integer
    var
        PageMetadata: Record "Page Metadata";
    begin
        PageMetadata.SetLoadFields(SourceTable);
        if PageMetadata.Get(PageId) then
            exit(PageMetadata.SourceTable);
        exit(0);
    end;

    // ---- Control names ------------------------------------------------------------------

    /// <summary>Checks every control name a line refers to, on the page it refers to.</summary>
    /// <param name="ConfigurationLine">The line to check.</param>
    local procedure CheckLineControls(ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        PageId: Integer;
    begin
        PageId := ConfigurationLine."Page ID";
        case ConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::Field,
            Enum::"BJF MN Config Operation"::"Function Field",
            Enum::"BJF MN Config Operation"::"Scan Field",
            Enum::"BJF MN Config Operation"::"Profile Field",
            Enum::"BJF MN Config Operation"::"User Scope",
            Enum::"BJF MN Config Operation"::"Stage Field",
            Enum::"BJF MN Config Operation"::"Page Filter",
            Enum::"BJF MN Config Operation"::"Flow Filter",
            Enum::"BJF MN Config Operation"::Caption:
                this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Control Name");
            Enum::"BJF MN Config Operation"::"Linked Field":
                begin
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Control Name");
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Source Field");
                    this.CheckControl(ConfigurationLine, ConfigurationLine."Target Page ID", ConfigurationLine."Target Filter Field");
                end;
            Enum::"BJF MN Config Operation"::"Lookup Field":
                begin
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Control Name");
                    this.CheckControl(ConfigurationLine, ConfigurationLine."Target Page ID", ConfigurationLine."Related Code Field");
                    this.CheckControl(ConfigurationLine, ConfigurationLine."Target Page ID", ConfigurationLine."Related Description Field");
                end;
            else
                this.CheckDetailControls(ConfigurationLine);
        end;
    end;

    /// <summary>Checks the control names of relation detail, filter, operation and layout lines.</summary>
    /// <param name="ConfigurationLine">The line to check.</param>
    local procedure CheckDetailControls(ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        PageId: Integer;
    begin
        PageId := ConfigurationLine."Page ID";
        case ConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::"Relation Filter":
                begin
                    this.CheckControl(ConfigurationLine, this.RelationTarget(ConfigurationLine), ConfigurationLine."Target Filter Field");
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Source Field");
                end;
            Enum::"BJF MN Config Operation"::"Additional Code Field":
                begin
                    this.CheckControl(ConfigurationLine, this.RelationTarget(ConfigurationLine), ConfigurationLine."Source Field");
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Target Filter Field");
                end;
            Enum::"BJF MN Config Operation"::"Relation Condition",
            Enum::"BJF MN Config Operation"::"Parent Action",
            Enum::"BJF MN Config Operation"::"Propagated Field",
            Enum::"BJF MN Config Operation"::"Saved Filter Field",
            Enum::"BJF MN Config Operation"::Operation,
            Enum::"BJF MN Config Operation"::"Layout Condition":
                begin
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Source Field");
                    this.CheckControl(ConfigurationLine, PageId, ConfigurationLine."Target Filter Field");
                end;
        end;
    end;

    /// <summary>A stage action names a stage of the page, every other action with a name names a control.</summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="ConfigurationLine">The Layout Action line.</param>
    local procedure CheckLayoutAction(var TempConfigurationLine: Record "BJF MN Config Line" temporary; ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempStageLine: Record "BJF MN Config Line" temporary;
    begin
        if not (ConfigurationLine."Action Type" in [this.HideStageActionTok, this.StageValidatedActionTok]) then begin
            this.CheckControl(ConfigurationLine, ConfigurationLine."Page ID", ConfigurationLine."Target Filter Field");
            exit;
        end;
        TempStageLine.Copy(TempConfigurationLine, true);
        TempStageLine.Reset();
        TempStageLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Stage);
        TempStageLine.SetRange("Page ID", ConfigurationLine."Page ID");
        TempStageLine.SetRange("Stage Id", UpperCase(ConfigurationLine."Target Filter Field"));
        if TempStageLine.IsEmpty() then
            this.AddProblem(StrSubstNo(this.StageMissingErr, ConfigurationLine."Control Name", ConfigurationLine."Target Filter Field", ConfigurationLine."Page ID"));
    end;

    local procedure CheckProperty(var TempConfigurationLine: Record "BJF MN Config Line" temporary; ConfigurationProperty: Record "BJF MN Config Property" temporary)
    begin
        this.CheckUsedPage(TempConfigurationLine, ConfigurationProperty."Page ID");
        this.CheckPropertyControl(ConfigurationProperty, ConfigurationProperty."Control Name");
        if ConfigurationProperty."Value Kind" <> Enum::"BJF MN Property Value"::Literal then
            this.CheckPropertyControl(ConfigurationProperty, CopyStr(ConfigurationProperty.Value, 1, 100));
    end;

    local procedure CheckPropertyControl(ConfigurationProperty: Record "BJF MN Config Property" temporary; ControlName: Text[100])
    begin
        if (ControlName = '') or not this.ControlsReadable or not this.PageExists(ConfigurationProperty."Page ID") then
            exit;
        if not this.ControlNames(ConfigurationProperty."Page ID").Contains(this.Normalized(ControlName)) then
            this.AddProblem(
                StrSubstNo(
                    this.PropertyControlMissingErr, ConfigurationProperty.Setting, ControlName, ConfigurationProperty."Page ID",
                    this.PageName(ConfigurationProperty."Page ID"), this.SourceTableNo(ConfigurationProperty."Page ID")));
    end;

    local procedure CheckControl(ConfigurationLine: Record "BJF MN Config Line" temporary; PageId: Integer; ControlName: Text[100])
    begin
        if (ControlName = '') or not this.ControlsReadable or not this.PageExists(PageId) then
            exit;
        if not this.ControlNames(PageId).Contains(this.Normalized(ControlName)) then
            this.AddProblem(
                StrSubstNo(
                    this.ControlMissingErr, ConfigurationLine.Operation, ControlName, PageId, this.PageName(PageId),
                    this.SourceTableNo(PageId)));
    end;

    /// <summary>
    /// The names a declaration can use on the page, in the form MobileNAV stores them: the page's
    /// controls, page extension controls included, and the fields of its source table (flow
    /// filters and fields MobileNAV adds to the service are table fields, not page controls).
    /// </summary>
    /// <param name="PageId">The page.</param>
    /// <returns>The normalized names.</returns>
    local procedure ControlNames(PageId: Integer) Names: List of [Text]
    var
        PageControlField: Record "Page Control Field";
        TableField: Record Field;
        TableNo: Integer;
    begin
        if this.PageControls.Get(PageId, Names) then
            exit(Names);
        PageControlField.SetRange(PageNo, PageId);
        PageControlField.SetLoadFields(ControlName);
        if PageControlField.FindSet() then
            repeat
                Names.Add(this.Normalized(PageControlField.ControlName));
            until PageControlField.Next() = 0;
        TableNo := this.SourceTableNo(PageId);
        if TableNo <> 0 then begin
            TableField.SetRange(TableNo, TableNo);
            TableField.SetLoadFields(FieldName);
            if TableField.FindSet() then
                repeat
                    Names.Add(this.Normalized(TableField.FieldName));
                until TableField.Next() = 0;
        end;
        this.PageControls.Add(PageId, Names);
        exit(Names);
    end;

    /// <summary>
    /// Whether the session can read Page Control Field. A Business Central online license does
    /// not grant it to every user (a delegated administrator gets a license error), and without
    /// the page's controls an unbound control such as a button placeholder cannot be told from a
    /// typing error, so the control name checks are skipped.
    /// </summary>
    /// <returns>True when the control name checks can run.</returns>
    local procedure CanReadControls(): Boolean
    var
        PageControlField: Record "Page Control Field";
    begin
        exit(PageControlField.ReadPermission());
    end;

    local procedure Normalized(ControlName: Text): Text
    var
        Lookup: Codeunit "BJF MN Service Lookup";
    begin
        exit(LowerCase(Lookup.StoredFieldName(ControlName)));
    end;

    local procedure RelationTarget(ConfigurationLine: Record "BJF MN Config Line" temporary): Integer
    var
        TargetPageId: Integer;
    begin
        if this.RelationTargets.Get(this.RelationKey(ConfigurationLine), TargetPageId) then
            exit(TargetPageId);
        exit(0);
    end;

    local procedure RelationKey(ConfigurationLine: Record "BJF MN Config Line" temporary): Text
    begin
        exit(StrSubstNo(this.RelationKeyTok, ConfigurationLine."Page ID", LowerCase(ConfigurationLine."Control Name")));
    end;

    // ---- Buttons ------------------------------------------------------------------------

    /// <summary>
    /// The function checks the apply makes, run by the same "BJF MN Config Application"
    /// procedures, with the page's source table taken from page metadata instead of MobileNAV's
    /// service row.
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="ConfigurationLine">The Function Field line.</param>
    local procedure CheckButton(var TempConfigurationLine: Record "BJF MN Config Line" temporary; ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        Problems: List of [Text];
        Problem: Text;
        CompanionCodeunitId: Integer;
    begin
        if ConfigurationApplication.HasFunctionCodeunit(TempConfigurationLine, ConfigurationLine."Page ID") then begin
            Problem := ConfigurationApplication.ButtonProcedureNameProblem(ConfigurationLine, ConfigurationLine."Page ID", false);
            if Problem <> '' then
                this.AddProblem(Problem);
            exit;
        end;
        if not this.PageExists(ConfigurationLine."Page ID") then
            exit;
        ConfigurationApplication.ResolveButtonFunction(
            ConfigurationLine, ConfigurationLine."Page ID", false, this.SourceTableNo(ConfigurationLine."Page ID"), CompanionCodeunitId, Problems);
        foreach Problem in Problems do
            this.AddProblem(Problem);
    end;

    // ---- Reachability -------------------------------------------------------------------

    /// <summary>
    /// A published page needs a menu tile or a declared Link or Lookup that opens it. A MobileNAV
    /// page keeps its administrator's tiles, so it needs neither. The apply also accepts a
    /// relation MobileNAV already has to the page, which only MobileNAV's data shows.
    /// </summary>
    /// <param name="TempConfigurationLine">The provider's declared lines.</param>
    /// <param name="ConfigurationLine">The Published Page line.</param>
    local procedure CheckReachable(var TempConfigurationLine: Record "BJF MN Config Line" temporary; ConfigurationLine: Record "BJF MN Config Line" temporary)
    var
        TempLinkLine: Record "BJF MN Config Line" temporary;
        Lookup: Codeunit "BJF MN Service Lookup";
    begin
        if ConfigurationLine."Show In Menu" then
            exit;
        if not this.PageExists(ConfigurationLine."Page ID") then
            exit;
        if Lookup.IsMobileNAVPage(ConfigurationLine."Page ID") then
            exit;
        TempLinkLine.Copy(TempConfigurationLine, true);
        TempLinkLine.Reset();
        TempLinkLine.SetRelationFilter();
        TempLinkLine.SetRange("Target Page ID", ConfigurationLine."Page ID");
        if TempLinkLine.IsEmpty() then
            this.AddProblem(StrSubstNo(this.UnreachableErr, ConfigurationLine."Page ID", this.PageName(ConfigurationLine."Page ID")));
    end;

    local procedure AddProblem(Problem: Text)
    begin
        if not this.Found.Contains(Problem) then
            this.Found.Add(Problem);
    end;

    var
        Found: List of [Text];
        ControlsReadable: Boolean;
        PageControls: Dictionary of [Integer, List of [Text]];
        PageExistence: Dictionary of [Integer, Boolean];
        RelationTargets: Dictionary of [Text, Integer];
        RelationKeyTok: Label '%1|%2', Locked = true;
        HideStageActionTok: Label 'HideStage', Locked = true;
        StageValidatedActionTok: Label 'StageValidated', Locked = true;
        PageMissingErr: Label 'Page %1 does not exist.', Comment = '%1 = page id';
        CodeunitMissingErr: Label 'Codeunit %1, declared as the function codeunit of page %2, does not exist.', Comment = '%1 = codeunit id, %2 = page id';
        PageNotPublishedErr: Label 'Page %1 %2 is used but not published by this provider and is not one of MobileNAV''s pages. Declare Publish() on it, or the apply works only where another provider or an administrator has published it.', Comment = '%1 = page id, %2 = page name';
        ControlMissingErr: Label '%1 names %2, which page %3 %4 does not have as a control and table %5 does not have as a field.', Comment = '%1 = declaration kind, %2 = control name, %3 = page id, %4 = page name, %5 = source table number';
        PropertyControlMissingErr: Label '%1 names %2, which page %3 %4 does not have as a control and table %5 does not have as a field.', Comment = '%1 = setting name, %2 = control name, %3 = page id, %4 = page name, %5 = source table number';
        StageMissingErr: Label 'Layout %1 names stage %2, which page %3 does not declare.', Comment = '%1 = layout code, %2 = stage id, %3 = page id';
        UnreachableErr: Label 'Page %1 %2 is not declared ShowInMenu() and no Link or Lookup in this provider opens it, so devices reach it only if MobileNAV already relates another page to it. Declare ShowInMenu() or a Link from another page.', Comment = '%1 = page id, %2 = page name';
}
