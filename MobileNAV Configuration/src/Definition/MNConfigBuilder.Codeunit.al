namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The fluent surface a provider declares its MobileNAV configuration through. Every method
/// returns the builder, so a page reads as one sentence:
///
///   Configuration.Page(Page::"MobileNAV WhseShipment")
///       .Field('AUKPackingInstructions')
///       .Field('Shipment Date').Filterable()
///       .Button('AUKPrintDespatch');
///
/// A declared control is visible, in the card's standard section, and present in every
/// MobileNAV profile — the framework writes the profile rows, the page's Page Update flag, the
/// companion function service and the rest of what MobileNAV needs; the provider only says what
/// the device should show. Modifiers refine the control declared last; Wizard, Stage and Show
/// build a staged page the same way.
///
/// The builder records intent only. It cannot apply anything, and a misuse (a modifier with no
/// control to modify, Filterable on a button) fails immediately with a message naming the fix.
/// </summary>
codeunit 77781 "BJF MN Config Builder"
{
    Access = Public;

    // ---- Page context -------------------------------------------------------------------

    /// <summary>
    /// Makes a page the context for the declarations that follow. Calling it again for the same
    /// page continues that page. A page that MobileNAV already knows (any of its own pages)
    /// needs nothing more; a page of your own must be published with Publish or PublishAsDialog.
    /// </summary>
    /// <param name="PageId">Object id of the page, for example Page::"MobileNAV WhseShipment".</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Page(PageId: Integer): Codeunit "BJF MN Config Builder"
    begin
        if PageId <= 0 then
            Error(this.PageIdRequiredErr);
        this.CurrentPageId := PageId;
        this.CurrentControlEntryNo := 0;
        this.CurrentStageEntryNo := 0;
        this.CurrentStageId := '';
        exit(this);
    end;

    /// <summary>
    /// Publishes the current page as a MobileNAV web service so devices can open it. The page
    /// is added to every profile's menu and gets its own tile. If MobileNAV already has a service
    /// for the page object, that service is reused under its existing name.
    /// </summary>
    /// <param name="PreferredServiceName">Web service name to register the page under.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Publish(PreferredServiceName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if PreferredServiceName = '' then
            Error(this.ServiceNameRequiredErr);
        this.AddLine(Enum::"BJF MN Config Operation"::"Published Page", this.CurrentPageId);
        this.TempConfigurationLine."Service Name" := PreferredServiceName;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Publishes the current page as an action dialog: a few inputs and a button that runs
    /// something, like a serial-number generator. Use this instead of Publish when the page
    /// exists to collect parameters rather than to browse records.
    /// </summary>
    /// <param name="PreferredServiceName">Web service name to register the page under.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure PublishAsDialog(PreferredServiceName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.Publish(PreferredServiceName);
        this.TempConfigurationLine."Page Type" := this.Vocabulary.ReportPageTypeName();
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Gives a dialog page its own function codeunit. MobileNAV runs a dialog's buttons through
    /// a codeunit web service rather than through the page's functions, and by default that is
    /// MobileNAV's own report-function codeunit, which knows nothing of your buttons: a tap then
    /// fails on the device with 'Method "..." is invalid!'. Declare the codeunit here and name
    /// each Button's procedure with FunctionName. The codeunit is published as a web service
    /// under ServiceName; its procedure parameters are filled from the dialog's controls of the
    /// same name and it returns MobileNAV's function result text.
    /// </summary>
    /// <param name="CodeunitId">Object id of the codeunit holding the button procedures.</param>
    /// <param name="ServiceName">Web service name to publish the codeunit under.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Functions(CodeunitId: Integer; ServiceName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePublishedPageLine();
        if this.TempConfigurationLine."Page Type" <> this.Vocabulary.ReportPageTypeName() then
            Error(this.FunctionsRequiresDialogErr, this.CurrentPageId);
        if CodeunitId <= 0 then
            Error(this.FunctionCodeunitRequiredErr, this.CurrentPageId);
        if ServiceName = '' then
            Error(this.FunctionServiceRequiredErr, this.CurrentPageId);
        this.TempConfigurationLine."Function Codeunit ID" := CodeunitId;
        this.TempConfigurationLine."Report Service Name" := ServiceName;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets what the published page's home tile does when tapped.</summary>
    /// <param name="Action">Create opens a new record; Open opens the single existing one.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MainMenuAction(Action: Enum "BJF MN Main Menu Action"): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePublishedPageLine();
        this.TempConfigurationLine."Main Menu Action" := this.Vocabulary.MainMenuActionName(Action);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Shows each device user only their own rows. Use it on a page over a per-user table (one
    /// parameter row per user): without it every device lists every user's rows and a card over
    /// the page cannot resolve a record at all. The named control carries the user id and can
    /// stay hidden; it exists for the filter.
    /// </summary>
    /// <param name="UserIdControlName">Control on the page bound to the row's user id.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MineOnly(UserIdControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        this.RequireControlName(UserIdControlName);
        this.AddLine(Enum::"BJF MN Config Operation"::"User Scope", this.CurrentPageId);
        this.TempConfigurationLine."Control Name" := UserIdControlName;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Controls -----------------------------------------------------------------------

    /// <summary>
    /// Shows a field on the current page: visible, read-only, in the standard section, in every
    /// profile. Chain Editable, Filterable, Hidden, Importance or a profile modifier to refine it.
    /// </summary>
    /// <param name="ControlName">Name of the page control (the name after `field(`).</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Field(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::Field, ControlName);
        this.TempConfigurationLine.Visible := true;
        this.TempConfigurationLine.Editable := false;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Shows a button on the current page that runs code in Business Central when tapped. The
    /// framework works out which MobileNAV function serves the page's table and registers what
    /// the device needs to call it; handle the tap by subscribing to
    /// "BJF MN Function Router".OnPageFunction. A page of your own also needs the one-line
    /// web-service wrapper described in the README.
    /// </summary>
    /// <param name="ControlName">Name of the page control (typically a `field(Name; '')` placeholder).</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Button(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::"Function Field", ControlName);
        this.TempConfigurationLine.Visible := true;
        this.TempConfigurationLine.Editable := true;
        this.TempConfigurationLine."Mobile Type" := this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::Normal);
        this.TempConfigurationLine."Function Type" := this.Vocabulary.FunctionTypeName(Enum::"BJF MN Function Type"::Normal);
        this.TempConfigurationLine."Function Name" := '';
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Shows a button that opens another page filtered to the current record. The target is
    /// made reachable from this page in every profile, so the button is drawn. A page of your
    /// own as the target must be published on its own Page(...) declaration.
    /// </summary>
    /// <param name="ControlName">Name of the page control the button renders as.</param>
    /// <param name="TargetPageId">Object id of the page to open.</param>
    /// <param name="TargetFilterField">Field on the target page to filter.</param>
    /// <param name="SourceField">Field on this page whose value becomes the filter.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Link(ControlName: Text[100]; TargetPageId: Integer; TargetFilterField: Text[100]; SourceField: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::"Linked Field", ControlName);
        if TargetPageId <= 0 then
            Error(this.TargetPageRequiredErr, ControlName);
        if (TargetFilterField = '') or (SourceField = '') then
            Error(this.LinkFilterRequiredErr, ControlName);
        this.TempConfigurationLine.Visible := true;
        this.TempConfigurationLine.Editable := false;
        this.TempConfigurationLine."Target Page ID" := TargetPageId;
        this.TempConfigurationLine."Target Filter Field" := TargetFilterField;
        this.TempConfigurationLine."Source Field" := SourceField;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows an editable input the device fills from its barcode scanner.</summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Scan(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::"Scan Field", ControlName);
        this.TempConfigurationLine.Visible := true;
        this.TempConfigurationLine.Editable := true;
        this.TempConfigurationLine."Mobile Type" := this.Vocabulary.BarcodeMobileTypeName();
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Modifiers ----------------------------------------------------------------------

    /// <summary>Lets the device user change the control declared last. The page becomes updatable as a whole.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Editable(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.EditableTok, this.FieldKinds());
        this.TempConfigurationLine.Editable := true;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows the control declared last read-only (the default for fields).</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure ReadOnly(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ReadOnlyTok, this.FieldKinds());
        this.TempConfigurationLine.Editable := false;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Keeps the field declared last off the device, at service level and in every profile.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Hidden(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.HiddenTok, this.PlainFieldKind());
        this.TempConfigurationLine.Visible := false;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Offers the field declared last in the device's filter pane.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Filterable(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.FilterableTok, this.PlainFieldKind());
        this.TempConfigurationLine.Filterable := true;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Draws the field declared last as an entry in the page's menu rather than a value on the
    /// card. Rarely needed: Button and Link already produce menu entries.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure InMenu(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.InMenuTok, this.PlainFieldKind());
        this.TempConfigurationLine."Display In Menu" := true;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Places the control declared last somewhere other than the card's standard section.</summary>
    /// <param name="Level">Where the device draws the control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Importance(Level: Enum "BJF MN Importance"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ImportanceTok, this.AllControlKinds());
        this.TempConfigurationLine.Importance := this.Vocabulary.ImportanceName(Level);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets how the device validates the button or scan declared last.</summary>
    /// <param name="ValidationBehavior">Validation behavior; Default keeps MobileNAV's own.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Validation(ValidationBehavior: Enum "BJF MN Validation Behavior"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ValidationTok, this.ButtonAndScanKinds());
        this.TempConfigurationLine."Validation Behavior" := this.Vocabulary.ValidationBehaviorName(ValidationBehavior);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Renders the button declared last as a special control, for example a signature pad or image capture.</summary>
    /// <param name="ControlType">How the device renders the button.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MobileType(ControlType: Enum "BJF MN Mobile Type"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.MobileTypeTok, this.ButtonKind());
        this.TempConfigurationLine."Mobile Type" := this.Vocabulary.MobileTypeName(ControlType);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets what the button declared last returns — a field-control result, a file, with or without the device position.</summary>
    /// <param name="FunctionKind">Result shape of the function behind the button.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FunctionType(FunctionKind: Enum "BJF MN Function Type"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.FunctionTypeTok, this.ButtonKind());
        this.TempConfigurationLine."Function Type" := this.Vocabulary.FunctionTypeName(FunctionKind);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Names the MobileNAV web-service function the button declared last calls, overriding the
    /// one the framework derives from the page's table. Only needed for a table MobileNAV's page
    /// functions do not cover, or for a function of your own.
    /// </summary>
    /// <param name="DispatcherName">Function name as MobileNAV's Page Functions expose it, for example 'WhseShpmtHdrExtFunc'.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FunctionName(DispatcherName: Text[50]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.FunctionNameTok, this.ButtonKind());
        if DispatcherName = '' then
            Error(this.FunctionNameRequiredErr, this.TempConfigurationLine."Control Name");
        this.TempConfigurationLine."Function Name" := DispatcherName;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Limits the control declared last to one MobileNAV profile instead of every profile.
    /// Repeat for several profiles.
    /// </summary>
    /// <param name="Profile">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OnlyInProfile(Profile: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.OnlyInProfileTok, this.AllControlKinds());
        this.RequireProfile(Profile);
        this.AddProfileScope(this.OnlyProfiles, Profile);
        exit(this);
    end;

    /// <summary>Keeps the control declared last out of one MobileNAV profile while showing it in every other. Repeat for several profiles.</summary>
    /// <param name="Profile">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ExceptInProfile(Profile: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ExceptInProfileTok, this.AllControlKinds());
        this.RequireProfile(Profile);
        this.AddProfileScope(this.ExceptProfiles, Profile);
        exit(this);
    end;

    /// <summary>
    /// Writes no profile rows for the control declared last, leaving profile visibility to
    /// whatever MobileNAV's administrator has configured. The advanced escape hatch; a control
    /// declared this way is not drawn until a profile row exists for it.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure NotInProfiles(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.NotInProfilesTok, this.AllControlKinds());
        if not this.UnprofiledControls.Contains(this.CurrentControlEntryNo) then
            this.UnprofiledControls.Add(this.CurrentControlEntryNo);
        exit(this);
    end;

    // ---- Wizard -------------------------------------------------------------------------

    /// <summary>
    /// Turns the current page into a staged wizard. Declare the stages with Stage and the
    /// fields each stage shows with Show or ShowReadOnly; fields not shown by a stage stay
    /// hidden while that stage is active. Back/Next navigation is shown and the wizard restarts
    /// on every record unless AutoNext, ShowBackNext or Behavior say otherwise.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Wizard(): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        this.AddLine(Enum::"BJF MN Config Operation"::Staging, this.CurrentPageId);
        this.TempConfigurationLine."Back-Next Visible" := true;
        this.TempConfigurationLine."Staging Behavior" := this.Vocabulary.StagingBehaviorName(Enum::"BJF MN Staging Behavior"::Always);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Advances the wizard to the next stage automatically once a stage is complete.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure AutoNext(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStagingLine(this.AutoNextTok);
        this.TempConfigurationLine."Auto Next Stage" := true;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Hides the wizard's Back/Next controls; use with AutoNext for a scan-driven flow.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure HideBackNext(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStagingLine(this.HideBackNextTok);
        this.TempConfigurationLine."Back-Next Visible" := false;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets how the wizard restarts between records.</summary>
    /// <param name="StagingBehavior">Always, CreationOnly or PersistState.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Behavior(StagingBehavior: Enum "BJF MN Staging Behavior"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStagingLine(this.BehaviorTok);
        this.TempConfigurationLine."Staging Behavior" := this.Vocabulary.StagingBehaviorName(StagingBehavior);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Adds the next wizard stage. Stages render in the order they are declared.</summary>
    /// <param name="StageId">Short code identifying the stage (at most 20 characters).</param>
    /// <param name="Description">Caption the device shows for the stage.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Stage(StageId: Code[100]; Description: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if not this.HasLine(Enum::"BJF MN Config Operation"::Staging, this.CurrentPageId) then
            Error(this.WizardRequiredErr, StageId);
        if StageId = '' then
            Error(this.StageIdRequiredErr);
        this.AddLine(Enum::"BJF MN Config Operation"::Stage, this.CurrentPageId);
        this.TempConfigurationLine."Stage Id" := StageId;
        this.TempConfigurationLine."Stage Description" := Description;
        this.TempConfigurationLine.Modify(false);
        this.CurrentStageEntryNo := this.TempConfigurationLine."Entry No.";
        this.CurrentStageId := StageId;
        exit(this);
    end;

    /// <summary>
    /// Makes the stage declared last the one the wizard re-enters on a later record, keeping
    /// what earlier stages captured — a scanned bin retained while its items are counted one
    /// after another. One stage per page, and never the first.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure RestartsHere(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStageLine(this.RestartsHereTok);
        this.TempConfigurationLine."Stage Restart From" := true;
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows a field, editable, while the stage declared last is active.</summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Show(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddStageField(ControlName, true);
        exit(this);
    end;

    /// <summary>Shows a field read-only, for context, while the stage declared last is active.</summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ShowReadOnly(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddStageField(ControlName, false);
        exit(this);
    end;

    // ---- Framework side -----------------------------------------------------------------

    /// <summary>
    /// Returns the declared lines with the profile rows the declarations imply appended: one
    /// all-profiles row per control carrying the control's own visibility and editability,
    /// reshaped by OnlyInProfile, ExceptInProfile and NotInProfiles.
    /// </summary>
    internal procedure GetLines(var Target: Record "BJF MN Config Line" temporary)
    begin
        Target.Reset();
        Target.DeleteAll(false);
        this.TempConfigurationLine.Reset();
        if this.TempConfigurationLine.FindSet() then
            repeat
                Target := this.TempConfigurationLine;
                Target.Insert(false);
            until this.TempConfigurationLine.Next() = 0;
        this.ExpandProfileLines(Target);
        Target.Reset();
    end;

    local procedure ExpandProfileLines(var Target: Record "BJF MN Config Line" temporary)
    var
        ProfileEntryNo: Integer;
    begin
        ProfileEntryNo := this.NextEntryNo;
        this.TempConfigurationLine.SetFilter(Operation, '%1|%2|%3|%4',
            Enum::"BJF MN Config Operation"::Field, Enum::"BJF MN Config Operation"::"Function Field",
            Enum::"BJF MN Config Operation"::"Linked Field", Enum::"BJF MN Config Operation"::"Scan Field");
        if this.TempConfigurationLine.FindSet() then
            repeat
                if not this.UnprofiledControls.Contains(this.TempConfigurationLine."Entry No.") then
                    this.AddProfileLinesForControl(Target, this.TempConfigurationLine, ProfileEntryNo);
            until this.TempConfigurationLine.Next() = 0;
        this.TempConfigurationLine.Reset();
    end;

    /// <summary>
    /// OnlyInProfile writes one visible row per named profile. Otherwise one all-profiles row
    /// carries the control's own visibility, followed by a hidden row per ExceptInProfile:
    /// profile rows are written in entry order, so the specific row wins over the general one.
    /// </summary>
    local procedure AddProfileLinesForControl(var Target: Record "BJF MN Config Line" temporary; ControlLine: Record "BJF MN Config Line" temporary; var ProfileEntryNo: Integer)
    var
        Profile: Code[30];
    begin
        if this.OnlyProfiles.ContainsKey(ControlLine."Entry No.") then begin
            foreach Profile in this.OnlyProfiles.Get(ControlLine."Entry No.") do
                this.AddProfileLine(Target, ControlLine, ProfileEntryNo, Profile, ControlLine.Visible);
            exit;
        end;
        this.AddProfileLine(Target, ControlLine, ProfileEntryNo, '', ControlLine.Visible);
        if this.ExceptProfiles.ContainsKey(ControlLine."Entry No.") then
            foreach Profile in this.ExceptProfiles.Get(ControlLine."Entry No.") do
                this.AddProfileLine(Target, ControlLine, ProfileEntryNo, Profile, false);
    end;

    local procedure AddProfileLine(var Target: Record "BJF MN Config Line" temporary; ControlLine: Record "BJF MN Config Line" temporary; var ProfileEntryNo: Integer; Profile: Code[30]; Visible: Boolean)
    begin
        ProfileEntryNo += 1;
        Target.Init();
        Target."Entry No." := ProfileEntryNo;
        Target.Operation := Enum::"BJF MN Config Operation"::"Profile Field";
        Target."Page ID" := ControlLine."Page ID";
        Target."Control Name" := ControlLine."Control Name";
        Target.Profile := Profile;
        Target.Visible := Visible;
        Target.Editable := ControlLine.Editable and Visible;
        Target.Insert(false);
    end;

    local procedure BeginControl(Operation: Enum "BJF MN Config Operation"; ControlName: Text[100])
    begin
        this.RequirePage();
        this.RequireControlName(ControlName);
        this.AddLine(Operation, this.CurrentPageId);
        this.TempConfigurationLine."Control Name" := ControlName;
        // Standard placement: MobileNAV's own default is Additional, which hides the control
        // behind the card's "show more" section — for a button, somewhere nobody looks.
        this.TempConfigurationLine.Importance := this.Vocabulary.ImportanceName(Enum::"BJF MN Importance"::Standard);
        this.TempConfigurationLine.Modify(false);
        this.CurrentControlEntryNo := this.TempConfigurationLine."Entry No.";
    end;

    local procedure AddStageField(ControlName: Text[100]; FieldEnabled: Boolean)
    begin
        this.RequireStageLine(this.ShowTok);
        this.RequireControlName(ControlName);
        this.AddLine(Enum::"BJF MN Config Operation"::"Stage Field", this.CurrentPageId);
        this.TempConfigurationLine."Stage Id" := this.CurrentStageId;
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine."Stage Enabled" := FieldEnabled;
        this.TempConfigurationLine.Modify(false);
    end;

    local procedure AddLine(Operation: Enum "BJF MN Config Operation"; PageId: Integer)
    begin
        this.NextEntryNo += 1;
        this.TempConfigurationLine.Init();
        this.TempConfigurationLine."Entry No." := this.NextEntryNo;
        this.TempConfigurationLine.Operation := Operation;
        this.TempConfigurationLine."Page ID" := PageId;
        this.TempConfigurationLine.Insert(false);
    end;

    local procedure AddProfileScope(var Scopes: Dictionary of [Integer, List of [Code[30]]]; Profile: Code[30])
    var
        Profiles: List of [Code[30]];
    begin
        if Scopes.ContainsKey(this.CurrentControlEntryNo) then
            Profiles := Scopes.Get(this.CurrentControlEntryNo);
        if not Profiles.Contains(Profile) then
            Profiles.Add(Profile);
        Scopes.Set(this.CurrentControlEntryNo, Profiles);
    end;

    local procedure HasLine(Operation: Enum "BJF MN Config Operation"; PageId: Integer): Boolean
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        TempLine.Copy(this.TempConfigurationLine, true);
        TempLine.SetRange(Operation, Operation);
        TempLine.SetRange("Page ID", PageId);
        exit(not TempLine.IsEmpty());
    end;

    local procedure RequirePage()
    begin
        if this.CurrentPageId = 0 then
            Error(this.PageRequiredErr);
    end;

    local procedure RequireControlName(ControlName: Text[100])
    begin
        if ControlName = '' then
            Error(this.ControlNameRequiredErr);
    end;

    local procedure RequireProfile(Profile: Code[30])
    begin
        if Profile = '' then
            Error(this.ProfileRequiredErr, this.TempConfigurationLine."Control Name");
    end;

    /// <summary>Positions the shared record on the control declared last, or errors naming the modifier and what it applies to.</summary>
    local procedure RequireControl(Modifier: Text; ApplicableKinds: List of [Enum "BJF MN Config Operation"])
    begin
        if this.CurrentControlEntryNo = 0 then
            Error(this.NoControlErr, Modifier);
        this.TempConfigurationLine.Get(this.CurrentControlEntryNo);
        if not ApplicableKinds.Contains(this.TempConfigurationLine.Operation) then
            Error(this.ModifierNotApplicableErr, Modifier, this.TempConfigurationLine."Control Name", this.KindName(this.TempConfigurationLine.Operation));
    end;

    local procedure RequirePublishedPageLine()
    begin
        this.RequirePage();
        this.TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Published Page");
        this.TempConfigurationLine.SetRange("Page ID", this.CurrentPageId);
        if not this.TempConfigurationLine.FindFirst() then begin
            this.TempConfigurationLine.Reset();
            Error(this.PublishRequiredErr, this.CurrentPageId);
        end;
        this.TempConfigurationLine.Reset();
    end;

    local procedure RequireStagingLine(Modifier: Text)
    begin
        this.RequirePage();
        this.TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::Staging);
        this.TempConfigurationLine.SetRange("Page ID", this.CurrentPageId);
        if not this.TempConfigurationLine.FindFirst() then begin
            this.TempConfigurationLine.Reset();
            Error(this.WizardRequiredForModifierErr, Modifier);
        end;
        this.TempConfigurationLine.Reset();
    end;

    local procedure RequireStageLine(Modifier: Text)
    begin
        if this.CurrentStageEntryNo = 0 then
            Error(this.NoStageErr, Modifier);
        this.TempConfigurationLine.Get(this.CurrentStageEntryNo);
    end;

    local procedure KindName(Operation: Enum "BJF MN Config Operation"): Text
    begin
        case Operation of
            Enum::"BJF MN Config Operation"::Field:
                exit(this.FieldKindTok);
            Enum::"BJF MN Config Operation"::"Function Field":
                exit(this.ButtonKindTok);
            Enum::"BJF MN Config Operation"::"Linked Field":
                exit(this.LinkKindTok);
            Enum::"BJF MN Config Operation"::"Scan Field":
                exit(this.ScanKindTok);
        end;
        exit(Format(Operation));
    end;

    local procedure AllControlKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::Field);
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Linked Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
    end;

    local procedure FieldKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::Field);
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
    end;

    local procedure PlainFieldKind() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::Field);
    end;

    local procedure ButtonKind() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
    end;

    local procedure ButtonAndScanKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
    end;

    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        Vocabulary: Codeunit "BJF MN Vocabulary";
        OnlyProfiles: Dictionary of [Integer, List of [Code[30]]];
        ExceptProfiles: Dictionary of [Integer, List of [Code[30]]];
        UnprofiledControls: List of [Integer];
        NextEntryNo: Integer;
        CurrentPageId: Integer;
        CurrentControlEntryNo: Integer;
        CurrentStageEntryNo: Integer;
        CurrentStageId: Code[100];
        PageIdRequiredErr: Label 'Page() needs a page object id, for example Page::"MobileNAV WhseShipment".';
        PageRequiredErr: Label 'Declare the page first: Configuration.Page(Page::"...") before Field, Button, Link, Scan, Publish, MineOnly or Wizard.';
        ServiceNameRequiredErr: Label 'Publish() needs the web service name to register the page under.';
        ControlNameRequiredErr: Label 'A control declaration needs the name of the page control.';
        ProfileRequiredErr: Label 'OnlyInProfile/ExceptInProfile on %1 needs a MobileNAV profile code.', Comment = '%1 = control name';
        TargetPageRequiredErr: Label 'Link %1 needs the object id of the page it opens.', Comment = '%1 = control name';
        LinkFilterRequiredErr: Label 'Link %1 needs both the target filter field and the source field.', Comment = '%1 = control name';
        FunctionNameRequiredErr: Label 'FunctionName() on button %1 needs a MobileNAV function name.', Comment = '%1 = control name';
        NoControlErr: Label '%1() modifies the control declared last, but no Field, Button, Link or Scan has been declared yet.', Comment = '%1 = modifier name';
        ModifierNotApplicableErr: Label '%1() does not apply to %2, which is a %3.', Comment = '%1 = modifier name, %2 = control name, %3 = control kind';
        PublishRequiredErr: Label 'MainMenuAction() needs the page (%1) to be published first with Publish or PublishAsDialog.', Comment = '%1 = page id';
        FunctionsRequiresDialogErr: Label 'Functions() needs the page (%1) to be published with PublishAsDialog: only a dialog page runs its buttons through a function codeunit.', Comment = '%1 = page id';
        FunctionCodeunitRequiredErr: Label 'Functions() on page %1 needs the object id of the codeunit holding the button procedures.', Comment = '%1 = page id';
        FunctionServiceRequiredErr: Label 'Functions() on page %1 needs the web service name to publish the codeunit under.', Comment = '%1 = page id';
        WizardRequiredErr: Label 'Stage %1 needs Wizard() on the page first.', Comment = '%1 = stage id';
        WizardRequiredForModifierErr: Label '%1() needs Wizard() on the page first.', Comment = '%1 = modifier name';
        StageIdRequiredErr: Label 'Stage() needs a stage id.';
        NoStageErr: Label '%1() applies to the stage declared last, but no Stage has been declared yet.', Comment = '%1 = modifier name';
        EditableTok: Label 'Editable', Locked = true;
        ReadOnlyTok: Label 'ReadOnly', Locked = true;
        HiddenTok: Label 'Hidden', Locked = true;
        FilterableTok: Label 'Filterable', Locked = true;
        InMenuTok: Label 'InMenu', Locked = true;
        ImportanceTok: Label 'Importance', Locked = true;
        ValidationTok: Label 'Validation', Locked = true;
        MobileTypeTok: Label 'MobileType', Locked = true;
        FunctionTypeTok: Label 'FunctionType', Locked = true;
        FunctionNameTok: Label 'FunctionName', Locked = true;
        OnlyInProfileTok: Label 'OnlyInProfile', Locked = true;
        ExceptInProfileTok: Label 'ExceptInProfile', Locked = true;
        NotInProfilesTok: Label 'NotInProfiles', Locked = true;
        AutoNextTok: Label 'AutoNext', Locked = true;
        HideBackNextTok: Label 'HideBackNext', Locked = true;
        BehaviorTok: Label 'Behavior', Locked = true;
        RestartsHereTok: Label 'RestartsHere', Locked = true;
        ShowTok: Label 'Show', Locked = true;
        FieldKindTok: Label 'field', Locked = true;
        ButtonKindTok: Label 'button', Locked = true;
        LinkKindTok: Label 'link', Locked = true;
        ScanKindTok: Label 'scan', Locked = true;
}
