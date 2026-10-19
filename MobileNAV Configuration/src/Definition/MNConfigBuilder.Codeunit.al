namespace BradFullwood.MobileNAV.Configuration;

using System.Text;

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
        this.CurrentDetailEntryNo := 0;
        this.CurrentGroupCode := '';
        this.CurrentLineFormatNo := 0;
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
        this.TempConfigurationLine.Validate("Service Name", PreferredServiceName);
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
        this.TempConfigurationLine.Validate("Page Type", this.Vocabulary.ReportPageTypeName());
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
        this.TempConfigurationLine.Validate("Function Codeunit ID", CodeunitId);
        this.TempConfigurationLine.Validate("Report Service Name", ServiceName);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Uses a custom companion codeunit for buttons on a non-dialog page: a page published with
    /// Publish(), or one of MobileNAV's own pages whose table has no dispatcher in MobileNAV Page
    /// Functions. The companion is registered unpublished under the page service name, matching
    /// MobileNAV's standard page-function transport, and replaces the standard companion. Each
    /// Button must name a procedure with FunctionName(). A MobileNAV page keeps its menu and
    /// profile setup, because only a published page is managed there.
    /// </summary>
    /// <param name="CodeunitId">Object id of the codeunit holding record-bound page functions.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure PageFunctions(CodeunitId: Integer): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if CodeunitId <= 0 then
            Error(this.PageFunctionsCodeunitRequiredErr, this.CurrentPageId);
        if not this.HasLine(Enum::"BJF MN Config Operation"::"Published Page", this.CurrentPageId) then begin
            if this.HasLine(Enum::"BJF MN Config Operation"::"Page Functions", this.CurrentPageId) then
                Error(this.PageFunctionsTwiceErr, this.CurrentPageId);
            this.AddLine(Enum::"BJF MN Config Operation"::"Page Functions", this.CurrentPageId);
            this.TempConfigurationLine.Validate("Function Codeunit ID", CodeunitId);
            this.TempConfigurationLine.Modify(false);
            this.CurrentControlEntryNo := 0;
            exit(this);
        end;
        this.RequirePublishedPageLine();
        if this.TempConfigurationLine."Page Type" = this.Vocabulary.ReportPageTypeName() then
            Error(this.PageFunctionsRejectsDialogErr, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Function Codeunit ID", CodeunitId);
        Clear(this.TempConfigurationLine."Report Service Name");
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Gives the published page a tile on the device home menu. Pages without it are reached
    /// only through a Link from another page, which is right for child rows and adapters.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure ShowInMenu(): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePublishedPageLine();
        this.TempConfigurationLine.Validate("Show In Menu", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets what the published page's home tile does when tapped.</summary>
    /// <param name="Action">Create opens a new record; Open opens the single existing one.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MainMenuAction(Action: Enum "BJF MN Main Menu Action"): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePublishedPageLine();
        this.TempConfigurationLine.Validate("Main Menu Action", this.Vocabulary.MainMenuActionName(Action));
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
        this.TempConfigurationLine.Validate("Control Name", UserIdControlName);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;


    // ---- Page settings ------------------------------------------------------------------

    /// <summary>Sets the shape MobileNAV gives the current page: list, card, list and card, dialog or offline.</summary>
    /// <param name="Shape">The shape MobileNAV gives the page.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure PageType(Shape: Enum "BJF MN Page Type"): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::PageType, this.Vocabulary.PageTypeName(Shape));
        exit(this);
    end;

    /// <summary>Lets the device create records on the current page.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Insertable(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::Insertable, this.TrueTok);
        exit(this);
    end;

    /// <summary>Lets the device change records on the current page. Editable() on a control does this on its own.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Updatable(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::Updatable, this.TrueTok);
        exit(this);
    end;

    /// <summary>Lets the device delete records on the current page.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Deletable(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::Deletable, this.TrueTok);
        exit(this);
    end;

    /// <summary>Caps how many records a list fetches.</summary>
    /// <param name="MaxRecords">Most records a list fetches.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ListLimit(MaxRecords: Integer): Codeunit "BJF MN Config Builder"
    begin
        if MaxRecords <= 0 then
            Error(this.PositiveValueRequiredErr, this.ListLimitTok, this.CurrentPageId);
        this.AddPageProperty(Enum::"BJF MN Property"::ListLimit, Format(MaxRecords, 0, 9));
        exit(this);
    end;

    /// <summary>Names the control whose related page opens when a record is tapped.</summary>
    /// <param name="ControlName">Control whose related page opens on tap.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure DefaultDrillDown(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControlName(ControlName);
        this.AddPageProperty(Enum::"BJF MN Property"::DefaultDrillDown, ControlName);
        exit(this);
    end;

    /// <summary>Names the MobileNAV page function the device calls when the page opens.</summary>
    /// <param name="PageFunction">MobileNAV page function the device calls.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OnOpen(PageFunction: Text[50]): Codeunit "BJF MN Config Builder"
    begin
        if PageFunction = '' then
            Error(this.PageFunctionRequiredErr, this.OnOpenTok);
        this.AddPageProperty(Enum::"BJF MN Property"::OnOpen, PageFunction);
        exit(this);
    end;

    /// <summary>Names the MobileNAV page function the device calls when the page closes.</summary>
    /// <param name="PageFunction">MobileNAV page function the device calls.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OnClose(PageFunction: Text[50]): Codeunit "BJF MN Config Builder"
    begin
        if PageFunction = '' then
            Error(this.PageFunctionRequiredErr, this.OnCloseTok);
        this.AddPageProperty(Enum::"BJF MN Property"::OnClose, PageFunction);
        exit(this);
    end;

    /// <summary>Removes one of the standard toolbar buttons from the current page. Repeatable.</summary>
    /// <param name="ToolbarButton">Toolbar button to remove.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure HideButton(ToolbarButton: Enum "BJF MN Toolbar Button"): Codeunit "BJF MN Config Builder"
    begin
        this.AddPagePropertyAt(Enum::"BJF MN Property"::HideButton, this.Vocabulary.ToolbarButtonFieldNo(ToolbarButton), this.TrueTok);
        exit(this);
    end;

    /// <summary>Removes a prefix from the current page's title. Repeatable.</summary>
    /// <param name="Prefix">Title prefix to remove.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure HideTitlePrefix(Prefix: Enum "BJF MN Title Prefix"): Codeunit "BJF MN Config Builder"
    begin
        this.AddPagePropertyAt(Enum::"BJF MN Property"::HideTitlePrefix, this.Vocabulary.TitlePrefixFieldNo(Prefix), this.TrueTok);
        exit(this);
    end;

    /// <summary>Makes the device reload the current page's data on its own. Repeatable.</summary>
    /// <param name="Moment">When the device reloads the page data.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure AutoRefresh(Moment: Enum "BJF MN Auto Refresh"): Codeunit "BJF MN Config Builder"
    begin
        this.AddPagePropertyAt(Enum::"BJF MN Property"::AutoRefresh, this.Vocabulary.AutoRefreshFieldNo(Moment), this.TrueTok);
        exit(this);
    end;

    /// <summary>Opens the record straight away when a list holds exactly one.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure AutoOpenSingleRecord(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::AutoOpenSingleRecord, this.TrueTok);
        exit(this);
    end;

    /// <summary>Shows the filter panel instead of the empty-list placeholder when a list opens.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure ShowFilterPanel(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::ShowFilterPanel, this.TrueTok);
        exit(this);
    end;

    /// <summary>Puts an unread-record badge on the page's tile. Not available on a page with an assign-to-me control.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure ShowUnreadCount(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::ShowUnreadCount, this.TrueTok);
        exit(this);
    end;

    /// <summary>Which "assigned to me" views the list offers, for a page with an assign-to-me control.</summary>
    /// <param name="Views">Assigned-to-me views the list offers.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MineFilter(Views: Enum "BJF MN Mine Filter"): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::MineFilter, this.Vocabulary.MineFilterName(Views));
        exit(this);
    end;

    /// <summary>Where the device places the assign-to-me control, on the card and on the list.</summary>
    /// <param name="Placement">Where the assign-to-me control appears.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure AssignToMe(Placement: Enum "BJF MN Assign To Me"): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::AssignToMeCard, this.Vocabulary.AssignToMeName(Placement));
        this.AddPageProperty(Enum::"BJF MN Property"::AssignToMeList, this.Vocabulary.AssignToMeName(Placement));
        exit(this);
    end;

    /// <summary>Applies a MobileNAV page style (a Page Style code from MobileNAV's master data).</summary>
    /// <param name="PageStyleCode">MobileNAV page style code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Style(PageStyleCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        if PageStyleCode = '' then
            Error(this.CodeRequiredErr, this.StyleTok, this.CurrentPageId);
        this.AddPageProperty(Enum::"BJF MN Property"::Style, PageStyleCode);
        exit(this);
    end;

    /// <summary>Filters a child page to the record that opened it, on top of any declared link filter.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure FilterByParent(): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageProperty(Enum::"BJF MN Property"::FilterByParent, this.TrueTok);
        exit(this);
    end;

    /// <summary>How many records an offline page downloads per request.</summary>
    /// <param name="Records">Records downloaded per request.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ChunkSize(Records: Integer): Codeunit "BJF MN Config Builder"
    begin
        if Records <= 0 then
            Error(this.PositiveValueRequiredErr, this.ChunkSizeTok, this.CurrentPageId);
        this.AddPageProperty(Enum::"BJF MN Property"::ChunkSize, Format(Records, 0, 9));
        exit(this);
    end;

    /// <summary>How often, in hours, an offline page checks the server for changed records.</summary>
    /// <param name="Hours">Hours between checks for changed records.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure CheckForChanges(Hours: Decimal): Codeunit "BJF MN Config Builder"
    begin
        if Hours <= 0 then
            Error(this.PositiveValueRequiredErr, this.CheckForChangesTok, this.CurrentPageId);
        this.AddPageProperty(Enum::"BJF MN Property"::CheckForChanges, Format(Hours, 0, 9));
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
        this.TempConfigurationLine.Validate(Visible, true);
        this.TempConfigurationLine.Validate(Editable, false);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Selects a control that is already declared on the current page (Field, Button, Scan, Lookup,
    /// Link or FieldControl) as the target of the modifiers that follow, without declaring it
    /// again and without adding a configuration line. For example
    /// Configuration.Page(Page::"X").Control('Y').Caption('DEU', 'Text') captions control Y.
    /// The name is matched without regard to case. It errors when the page has no such control.
    /// </summary>
    /// <param name="ControlName">Name of a control declared earlier on the current page.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Control(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        this.RequirePage();
        this.RequireControlName(ControlName);
        TempLine.Copy(this.TempConfigurationLine, true);
        TempLine.SetRange("Page ID", this.CurrentPageId);
        TempLine.SetControlFilter();
        if TempLine.FindSet() then
            repeat
                if TempLine."Control Name" = ControlName then begin
                    this.CurrentControlEntryNo := TempLine."Entry No.";
                    this.CurrentDetailEntryNo := 0;
                    exit(this);
                end;
            until TempLine.Next() = 0;
        Error(this.ControlNotDeclaredErr, this.CurrentPageId, ControlName);
    end;

    /// <summary>
    /// Declares MobileNAV's field-control channel on the current page: a hidden, editable field
    /// of mobile type FieldControl that carries dialogs and refresh directives to the device and
    /// brings the answer back through the field's OnValidate. MobileNAV's own pages ship with
    /// one; a page of your own, or a page extension that adds one, needs it declared.
    /// </summary>
    /// <param name="ControlName">Name of the page control, usually 'FieldControl'.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FieldControl(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::Field, ControlName);
        this.TempConfigurationLine.Validate(Visible, false);
        this.TempConfigurationLine.Validate(Editable, true);
        this.TempConfigurationLine.Validate("Mobile Type", this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::FieldControl));
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
        this.TempConfigurationLine.Validate(Visible, true);
        this.TempConfigurationLine.Validate(Editable, true);
        this.TempConfigurationLine.Validate("Mobile Type", this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::Normal));
        this.TempConfigurationLine.Validate("Function Type", this.Vocabulary.FunctionTypeName(Enum::"BJF MN Function Type"::Normal));
        this.TempConfigurationLine.Validate("Function Name", '');
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
        this.TempConfigurationLine.Validate(Visible, true);
        this.TempConfigurationLine.Validate(Editable, false);
        this.TempConfigurationLine.Validate("Target Page ID", TargetPageId);
        this.TempConfigurationLine.Validate("Target Filter Field", TargetFilterField);
        this.TempConfigurationLine.Validate("Source Field", SourceField);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows an editable input the device fills from its barcode scanner.</summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Scan(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::"Scan Field", ControlName);
        this.TempConfigurationLine.Validate(Visible, true);
        this.TempConfigurationLine.Validate(Editable, true);
        this.TempConfigurationLine.Validate("Mobile Type", this.Vocabulary.BarcodeMobileTypeName());
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Modifiers ----------------------------------------------------------------------

    /// <summary>Lets the device user change the control declared last. The page becomes updatable as a whole.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Editable(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.EditableTok, this.FieldKinds());
        this.TempConfigurationLine.Validate(Editable, true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows the control declared last read-only (the default for fields).</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure ReadOnly(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ReadOnlyTok, this.FieldKinds());
        this.TempConfigurationLine.Validate(Editable, false);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Keeps the field declared last off the device, at service level and in every profile.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Hidden(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.HiddenTok, this.PlainFieldKind());
        this.TempConfigurationLine.Validate(Visible, false);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Offers the field declared last in the device's filter pane.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Filterable(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.FilterableTok, this.PlainFieldKind());
        this.TempConfigurationLine.Validate(Filterable, true);
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
        this.TempConfigurationLine.Validate("Display In Menu", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Places the control declared last somewhere other than the card's standard section.</summary>
    /// <param name="Level">Where the device draws the control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Importance(Level: Enum "BJF MN Importance"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ImportanceTok, this.AllControlKinds());
        this.TempConfigurationLine.Validate(Importance, this.Vocabulary.ImportanceName(Level));
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets how the device validates the button, scan or lookup declared last.</summary>
    /// <param name="ValidationBehavior">Validation behavior; Default keeps MobileNAV's own.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Validation(ValidationBehavior: Enum "BJF MN Validation Behavior"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ValidationTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::FieldValidationBehavior));
        this.TempConfigurationLine.Validate("Validation Behavior", this.Vocabulary.ValidationBehaviorName(ValidationBehavior));
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Renders the button declared last as a special control, for example a signature pad or
    /// image capture, or sets the mobile type of the lookup declared last, for example Barcode
    /// for a lookup the device can also fill from its scanner.
    /// </summary>
    /// <param name="ControlType">How the device renders the control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MobileType(ControlType: Enum "BJF MN Mobile Type"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.MobileTypeTok, this.ButtonAndLookupKinds());
        this.TempConfigurationLine.Validate("Mobile Type", this.Vocabulary.MobileTypeName(ControlType));
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets what the button declared last returns — a field-control result, a file, with or without the device position.</summary>
    /// <param name="FunctionKind">Result shape of the function behind the button.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FunctionType(FunctionKind: Enum "BJF MN Function Type"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.FunctionTypeTok, this.ButtonKind());
        this.TempConfigurationLine.Validate("Function Type", this.Vocabulary.FunctionTypeName(FunctionKind));
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
        this.TempConfigurationLine.Validate("Function Name", DispatcherName);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Limits the control declared last to one MobileNAV profile instead of every profile.
    /// Repeat for several profiles.
    /// </summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OnlyInProfile(ProfileCode: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.OnlyInProfileTok, this.AllControlKinds());
        this.RequireProfile(ProfileCode);
        this.AddProfileScope(this.OnlyProfiles, ProfileCode);
        exit(this);
    end;

    /// <summary>Keeps the control declared last out of one MobileNAV profile while showing it in every other. Repeat for several profiles.</summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ExceptInProfile(ProfileCode: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ExceptInProfileTok, this.AllControlKinds());
        this.RequireProfile(ProfileCode);
        this.AddProfileScope(this.ExceptProfiles, ProfileCode);
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


    // ---- Control settings ---------------------------------------------------------------

    /// <summary>Formats the decimal field declared last, in Business Central's DecimalPlaces notation, for example '2:2'.</summary>
    /// <param name="Places">Decimal places in DecimalPlaces notation, for example 2:2.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure DecimalPlaces(Places: Text[5]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.DecimalPlacesTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::DecimalPlaces));
        this.AddControlProperty(Enum::"BJF MN Property"::DecimalPlaces, Places);
        exit(this);
    end;

    /// <summary>Draws the field declared last as a quantity with plus/minus steppers of the given increment.</summary>
    /// <param name="Increment">Step of the plus and minus buttons.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Quantity(Increment: Decimal): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.QuantityTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::Quantity));
        if Increment <= 0 then
            Error(this.PositiveValueRequiredErr, this.QuantityTok, this.TempConfigurationLine."Control Name");
        this.TempConfigurationLine.Validate("Mobile Type", this.Vocabulary.MobileTypeName(Enum::"BJF MN Mobile Type"::Quantity));
        this.TempConfigurationLine.Modify(false);
        this.AddControlProperty(Enum::"BJF MN Property"::Quantity, Format(Increment, 0, 9));
        exit(this);
    end;

    /// <summary>Makes a scan into the control declared last increase the named quantity field ("scan to add").</summary>
    /// <param name="QuantityControlName">Quantity control that a scan increases.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Increases(QuantityControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.IncreasesTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::Increases));
        this.RequireControlName(QuantityControlName);
        this.AddControlProperty(Enum::"BJF MN Property"::Increases, QuantityControlName);
        exit(this);
    end;

    /// <summary>Bounds the numeric field declared last.</summary>
    /// <param name="MinValue">Lowest allowed value.</param>
    /// <param name="MaxValue">Highest allowed value.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Range(MinValue: Decimal; MaxValue: Decimal): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.RangeTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::RangeMin));
        if MinValue > MaxValue then
            Error(this.RangeOrderErr, this.TempConfigurationLine."Control Name");
        this.AddControlProperty(Enum::"BJF MN Property"::RangeMin, Format(MinValue, 0, 9));
        this.AddControlProperty(Enum::"BJF MN Property"::RangeMax, Format(MaxValue, 0, 9));
        exit(this);
    end;

    /// <summary>Lets the field declared last be edited from the list row without opening the card. One per page.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure QuickEdit(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.QuickEditTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::QuickEdit));
        this.AddControlProperty(Enum::"BJF MN Property"::QuickEdit, this.TrueTok);
        exit(this);
    end;

    /// <summary>Shows the field declared last on a collapsed group header when the list is grouped.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure PromotedOnGroupHeader(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.PromotedOnGroupHeaderTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::PromotedOnGroupHeader));
        this.AddControlProperty(Enum::"BJF MN Property"::PromotedOnGroupHeader, this.TrueTok);
        exit(this);
    end;

    /// <summary>Lets the device user skip the scan the control declared last requires. Needs Validation() first.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure AllowSkip(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.AllowSkipTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::AllowSkip));
        if this.TempConfigurationLine."Validation Behavior" = '' then
            Error(this.ValidationRequiredErr, this.TempConfigurationLine."Control Name");
        this.AddControlProperty(Enum::"BJF MN Property"::AllowSkip, this.TrueTok);
        exit(this);
    end;

    /// <summary>Validates and parses what is scanned or typed into the control declared last with a regular expression.</summary>
    /// <param name="Pattern">The .NET regular expression.</param>
    /// <param name="Results">Comma-separated capture-group indexes that make up the resulting value.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure RegEx(Pattern: Text[250]; Results: Text[50]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.RegExTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::RegExPattern));
        if Pattern = '' then
            Error(this.PatternRequiredErr, this.TempConfigurationLine."Control Name");
        this.AddControlProperty(Enum::"BJF MN Property"::RegExPattern, Pattern);
        this.AddControlProperty(Enum::"BJF MN Property"::RegExResults, Results);
        exit(this);
    end;

    /// <summary>
    /// Takes every regular expression off the control declared last: its own pattern, the capture
    /// groups it is filled from, and the inherited flag. A control filled from another control's
    /// pattern (RegEx Results) reaches the device as Normal even when it is a Barcode control, so
    /// it gets no scan icon; WMS MobileNAV does this to Serial No. on warehouse pick lines. The
    /// values are assigned without validation, because validating RegEx Results asks for
    /// confirmation when the setting was inherited.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure NoRegEx(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.NoRegExTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::NoRegExPattern));
        this.AddControlProperty(Enum::"BJF MN Property"::NoRegExPattern, '');
        this.AddControlProperty(Enum::"BJF MN Property"::NoRegExResults, '');
        this.AddControlProperty(Enum::"BJF MN Property"::NoRegExInherited, this.FalseTok);
        exit(this);
    end;

    /// <summary>Tags the control declared last with the role MobileNAV's warehouse features key on.</summary>
    /// <param name="Role">Role the warehouse features look for.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FieldCategory(Role: Enum "BJF MN Field Category"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.FieldCategoryTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::FieldCategory));
        this.AddControlProperty(Enum::"BJF MN Property"::FieldCategory, this.Vocabulary.FieldCategoryName(Role));
        exit(this);
    end;

    /// <summary>Keeps the field declared last from opening its related page from the card.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure HideDrillDown(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.HideDrillDownTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::HideDrillDown));
        this.AddControlProperty(Enum::"BJF MN Property"::HideDrillDown, this.TrueTok);
        exit(this);
    end;

    /// <summary>Runs the field's Business Central validation even when the value did not change.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure ValidateAlways(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ValidateAlwaysTok, this.PropertyCatalog.ControlKinds(Enum::"BJF MN Property"::ValidateAlways));
        this.AddControlProperty(Enum::"BJF MN Property"::ValidateAlways, this.TrueTok);
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
        this.TempConfigurationLine.Validate("Back-Next Visible", true);
        this.TempConfigurationLine.Validate("Staging Behavior", this.Vocabulary.StagingBehaviorName(Enum::"BJF MN Staging Behavior"::Always));
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Advances the wizard to the next stage automatically once a stage is complete.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure AutoNext(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStagingLine(this.AutoNextTok);
        this.TempConfigurationLine.Validate("Auto Next Stage", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Hides the wizard's Back/Next controls; use with AutoNext for a scan-driven flow.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure HideBackNext(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStagingLine(this.HideBackNextTok);
        this.TempConfigurationLine.Validate("Back-Next Visible", false);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Sets how the wizard restarts between records.</summary>
    /// <param name="StagingBehavior">Always, CreationOnly or PersistState.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Behavior(StagingBehavior: Enum "BJF MN Staging Behavior"): Codeunit "BJF MN Config Builder"
    begin
        this.RequireStagingLine(this.BehaviorTok);
        this.TempConfigurationLine.Validate("Staging Behavior", this.Vocabulary.StagingBehaviorName(StagingBehavior));
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
        this.TempConfigurationLine.Validate("Stage Id", StageId);
        this.TempConfigurationLine.Validate("Stage Description", Description);
        this.TempConfigurationLine.Modify(false);
        this.CurrentStageEntryNo := this.TempConfigurationLine."Entry No.";
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
        this.TempConfigurationLine.Validate("Stage Restart From", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Shows a field, editable, while the stage declared last is active. Between LineFormat and
    /// EndLineFormat it adds the control's value to the line instead.
    /// </summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Show(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        if this.CurrentLineFormatNo <> 0 then
            this.AddLineFormatElement(this.ValueElementTok, ControlName, '')
        else
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


    // ---- Master data --------------------------------------------------------------------

    /// <summary>
    /// Declares a MobileNAV category: a menu heading pages can sit under (MenuCategory) and the
    /// caption of a field group (Group). Needs no page context.
    /// </summary>
    /// <param name="CategoryCode">Category code.</param>
    /// <param name="Description">Category description.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Category(CategoryCode: Code[20]; Description: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        if CategoryCode = '' then
            Error(this.CodeRequiredErr, this.CategoryTok, 0);
        this.AddLine(Enum::"BJF MN Config Operation"::Category, 0);
        this.TempConfigurationLine.Validate("Control Name", CategoryCode);
        this.TempConfigurationLine.Validate(Description, Description);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Translates a declared category's description for one language.</summary>
    /// <param name="CategoryCode">Declared category code.</param>
    /// <param name="LanguageCode">Language of the translation.</param>
    /// <param name="Description">Translated description.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure CategoryTranslation(CategoryCode: Code[20]; LanguageCode: Code[10]; Description: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        if (CategoryCode = '') or (LanguageCode = '') then
            Error(this.CodeRequiredErr, this.CategoryTranslationTok, 0);
        this.AddLine(Enum::"BJF MN Config Operation"::"Category Translation", 0);
        this.TempConfigurationLine.Validate("Control Name", CategoryCode);
        this.TempConfigurationLine.Validate("Language Code", LanguageCode);
        this.TempConfigurationLine.Validate(Description, Description);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Declares a MobileNAV profile, the menu and visibility set a device user logs in against. Needs no page context.</summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <param name="Description">Profile description.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Profile(ProfileCode: Code[30]; Description: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        if ProfileCode = '' then
            Error(this.CodeRequiredErr, this.ProfileTok, 0);
        this.AddLine(Enum::"BJF MN Config Operation"::Profile, 0);
        this.TempConfigurationLine.Validate(Profile, ProfileCode);
        this.TempConfigurationLine.Validate(Description, Description);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Page menu and profiles ---------------------------------------------------------

    /// <summary>Puts the current page's tile under a category heading in the menu.</summary>
    /// <param name="CategoryCode">Category the page tile sits under.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MenuCategory(CategoryCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        if CategoryCode = '' then
            Error(this.CodeRequiredErr, this.MenuCategoryTok, this.CurrentPageId);
        this.AddPageProperty(Enum::"BJF MN Property"::MenuCategory, CategoryCode);
        exit(this);
    end;

    /// <summary>
    /// Files the current page's tile under a category in one profile only, leaving the category
    /// other profiles give it alone. Use it where a MobileNAV page already sits under a category
    /// its own profiles rely on. Repeat for several profiles.
    /// </summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <param name="CategoryCode">MobileNAV category code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MenuCategoryInProfile(ProfileCode: Code[30]; CategoryCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        if CategoryCode = '' then
            Error(this.CodeRequiredErr, this.MenuCategoryInProfileTok, this.CurrentPageId);
        this.ProfilePageLine(this.MenuCategoryInProfileTok, ProfileCode);
        this.TempConfigurationLine.Validate("Menu Category", CategoryCode);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Keeps the current page out of one profile's menu.</summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ExcludeFromProfile(ProfileCode: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.ProfilePageLine(this.ExcludeFromProfileTok, ProfileCode);
        this.TempConfigurationLine.Validate(Disabled, true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Opens the current page online rather than from the device's offline data in one profile.</summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OnlineInProfile(ProfileCode: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.ProfilePageLine(this.OnlineInProfileTok, ProfileCode);
        this.TempConfigurationLine.Validate("Auto Refresh On Open", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Offers the current page only as a lookup, with no tile of its own, in one profile.</summary>
    /// <param name="ProfileCode">MobileNAV profile code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure LookupOnlyInProfile(ProfileCode: Code[30]): Codeunit "BJF MN Config Builder"
    begin
        this.ProfilePageLine(this.LookupOnlyInProfileTok, ProfileCode);
        this.TempConfigurationLine.Validate("Multi Select", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>
    /// Captions the page, or the control declared last, in one language. MobileNAV keeps
    /// captions per language; without one the device shows the Business Central caption.
    /// </summary>
    /// <param name="LanguageCode">Language of the caption.</param>
    /// <param name="CaptionText">Caption text in that language.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Caption(LanguageCode: Code[10]; CaptionText: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if LanguageCode = '' then
            Error(this.CodeRequiredErr, this.CaptionTok, this.CurrentPageId);
        this.AddCaptionLine(LanguageCode, CaptionText);
        exit(this);
    end;

    /// <summary>
    /// Captions the page, or the control declared last, in every language MobileNAV supports,
    /// from your own translations. When the provider is built, each supported language is made the
    /// session language in turn and "BJF MN Config Application" raises OnGetTranslatedCaption, so
    /// a subscriber answers with a Label that your app's XLIFF files translate. Do not also call
    /// Caption for the same target: the languages would then be declared twice.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure TranslatedCaptions(): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        this.AddCaptionLine(this.TranslatedLanguageTok, '');
        exit(this);
    end;

    /// <summary>Gives the current page's tile a picture, from PNG bytes in base64.</summary>
    /// <param name="PngBase64">PNG image as base64 text.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure MenuPicture(PngBase64: Text): Codeunit "BJF MN Config Builder"
    var
        Base64Convert: Codeunit "Base64 Convert";
        PictureStream: OutStream;
    begin
        this.RequirePage();
        if PngBase64 = '' then
            Error(this.CodeRequiredErr, this.MenuPictureTok, this.CurrentPageId);
        this.AddLine(Enum::"BJF MN Config Operation"::"Menu Picture", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Picture Extension", this.PngTok);
        this.TempConfigurationLine.Picture.CreateOutStream(PictureStream);
        Base64Convert.FromBase64(PngBase64, PictureStream);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Groups and order ---------------------------------------------------------------

    /// <summary>
    /// Shows the current page's declared controls first, in the order they are declared;
    /// the page's other controls follow in their existing order.
    /// </summary>
    /// <returns>The builder, for chaining.</returns>
    procedure OrderAsDeclared(): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if not this.HasLine(Enum::"BJF MN Config Operation"::"Field Order", this.CurrentPageId) then
            this.AddLine(Enum::"BJF MN Config Operation"::"Field Order", this.CurrentPageId);
        exit(this);
    end;

    /// <summary>
    /// Opens a group on the card: the controls declared until EndGroup sit together under the
    /// category's description. Declare the category with Category().
    /// </summary>
    /// <param name="CategoryCode">Category whose description captions the group.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Group(CategoryCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if CategoryCode = '' then
            Error(this.CodeRequiredErr, this.GroupTok, this.CurrentPageId);
        if this.CurrentGroupCode <> '' then
            Error(this.GroupOpenErr, this.CurrentGroupCode, CategoryCode);
        this.AddLine(Enum::"BJF MN Config Operation"::Group, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Group Code", CategoryCode);
        this.TempConfigurationLine.Modify(false);
        this.CurrentGroupCode := CategoryCode;
        exit(this);
    end;

    /// <summary>Closes the group opened last.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure EndGroup(): Codeunit "BJF MN Config Builder"
    begin
        if this.CurrentGroupCode = '' then
            Error(this.NoGroupErr);
        this.CurrentGroupCode := '';
        exit(this);
    end;

    // ---- Lookups and relation details ---------------------------------------------------

    /// <summary>
    /// Shows an editable field the device fills by picking a record from another page: the
    /// picked record's code lands in the field and its description is shown beside it. A page
    /// of your own as the target must be published on its own Page(...) declaration.
    /// </summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <param name="TargetPageId">Object id of the page to pick from.</param>
    /// <param name="CodeField">Control on the target page whose value is picked.</param>
    /// <param name="DescriptionField">Control on the target page shown as the description.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Lookup(ControlName: Text[100]; TargetPageId: Integer; CodeField: Text[100]; DescriptionField: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.BeginControl(Enum::"BJF MN Config Operation"::"Lookup Field", ControlName);
        if TargetPageId <= 0 then
            Error(this.TargetPageRequiredErr, ControlName);
        if CodeField = '' then
            Error(this.LookupCodeFieldRequiredErr, ControlName);
        this.TempConfigurationLine.Validate(Visible, true);
        this.TempConfigurationLine.Validate(Editable, true);
        this.TempConfigurationLine.Validate("Target Page ID", TargetPageId);
        this.TempConfigurationLine.Validate("Related Code Field", CodeField);
        this.TempConfigurationLine.Validate("Related Description Field", DescriptionField);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Filters the target of the link or lookup declared last: the target's field must equal this page's field. Repeatable.</summary>
    /// <param name="TargetField">Field on the target record.</param>
    /// <param name="SourceField">Field on this page.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Filter(TargetField: Text[100]; SourceField: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddRelationFilter(this.FilterTok, this.FieldFilterTypeTok, TargetField, SourceField, '');
        exit(this);
    end;

    /// <summary>Filters the target of the link or lookup declared last to a fixed value. Repeatable.</summary>
    /// <param name="TargetField">Field on the target record.</param>
    /// <param name="Value">Fixed value to filter on.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FilterValue(TargetField: Text[100]; Value: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddRelationFilter(this.FilterValueTok, this.ConstFilterTypeTok, TargetField, '', Value);
        exit(this);
    end;

    /// <summary>Filters the target of the link or lookup declared last with a Business Central filter expression, for example '1000..1999'. Repeatable.</summary>
    /// <param name="TargetField">Field on the target record.</param>
    /// <param name="FilterText">Business Central filter expression.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FilterExpression(TargetField: Text[100]; FilterText: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddRelationFilter(this.FilterExpressionTok, this.FilterFilterTypeTok, TargetField, '', FilterText);
        exit(this);
    end;

    /// <summary>Offers the link or lookup declared last only while this page's field holds the value. Repeatable.</summary>
    /// <param name="SourceField">Field on this page.</param>
    /// <param name="Value">Value the field must hold.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OnlyWhen(SourceField: Text[100]; Value: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.OnlyWhenTok, this.RelationKinds());
        this.RequireControlName(SourceField);
        this.AddRelationDetail(Enum::"BJF MN Config Operation"::"Relation Condition");
        this.TempConfigurationLine.Validate("Source Field", SourceField);
        this.TempConfigurationLine.Validate("Filter Value", Value);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Lets the device pick several records at once in the lookup declared last.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure MultiSelect(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.MultiSelectTok, this.LookupKind());
        this.TempConfigurationLine.Validate("Multi Select", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Reloads the target page's data when the link or lookup declared last opens it.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure RefreshOnOpen(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.RefreshOnOpenTok, this.RelationKinds());
        this.TempConfigurationLine.Validate("Auto Refresh On Open", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Copies one more field of the picked record into this page when the lookup declared last is used. Repeatable.</summary>
    /// <param name="SourceField">Field of the picked record.</param>
    /// <param name="DestinationField">Field on this page that receives the value.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure AdditionalCode(SourceField: Text[100]; DestinationField: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.AdditionalCodeTok, this.LookupKind());
        this.RequireControlName(SourceField);
        this.RequireControlName(DestinationField);
        this.AddRelationDetail(Enum::"BJF MN Config Operation"::"Additional Code Field");
        this.TempConfigurationLine.Validate("Source Field", SourceField);
        this.TempConfigurationLine.Validate("Target Filter Field", DestinationField);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows a value of the picked record (its barcode or a cached image) on this page. Repeatable.</summary>
    /// <param name="What">Value to copy from the picked record.</param>
    /// <param name="DestinationField">Field on this page that receives the value.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Propagate(What: Enum "BJF MN Propagation"; DestinationField: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.PropagateTok, this.LookupKind());
        this.RequireControlName(DestinationField);
        this.AddRelationDetail(Enum::"BJF MN Config Operation"::"Propagated Field");
        this.TempConfigurationLine.Validate("Propagation Type", this.Vocabulary.PropagationName(What));
        this.TempConfigurationLine.Validate("Target Filter Field", DestinationField);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows one of this page's buttons on the page the link declared last opens. Repeatable.</summary>
    /// <param name="ButtonControlName">Button on this page to show on the opened page.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ParentAction(ButtonControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControl(this.ParentActionTok, this.RelationKinds());
        this.RequireControlName(ButtonControlName);
        this.AddRelationDetail(Enum::"BJF MN Config Operation"::"Parent Action");
        this.TempConfigurationLine.Validate("Source Field", ButtonControlName);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Page filters and flow filters --------------------------------------------------

    /// <summary>Filters the current page's records: the control's value compared with a fixed value. Applies online and offline unless Scope says otherwise.</summary>
    /// <param name="ControlName">Control to filter on.</param>
    /// <param name="Comparison">Comparison operator.</param>
    /// <param name="Value">Fixed value to compare with.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure PageFilter(ControlName: Text[100]; Comparison: Enum "BJF MN Comparison"; Value: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageFilter(ControlName, this.ConstFilterTypeTok, this.Vocabulary.ComparisonName(Comparison), Value);
        exit(this);
    end;

    /// <summary>Filters the current page's records with a Business Central filter expression on the control, for example '&lt;&gt;0' or 'A*'.</summary>
    /// <param name="ControlName">Control to filter on.</param>
    /// <param name="FilterText">Business Central filter expression.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure PageFilterExpression(ControlName: Text[100]; FilterText: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddPageFilter(ControlName, this.FilterFilterTypeTok, this.Vocabulary.ComparisonName(Enum::"BJF MN Comparison"::Equal), FilterText);
        exit(this);
    end;

    /// <summary>Limits the page filter declared last to online or offline use.</summary>
    /// <param name="FilterScope">Online, offline or both.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Scope(FilterScope: Enum "BJF MN Filter Scope"): Codeunit "BJF MN Config Builder"
    begin
        if not this.GetDetail(Enum::"BJF MN Config Operation"::"Page Filter") then
            Error(this.NoPageFilterErr);
        this.TempConfigurationLine.Validate("Filter Scope", this.Vocabulary.FilterScopeName(FilterScope));
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Offers one of the source table's flow filters (for example 'Date Filter') in the current page's filter pane.</summary>
    /// <param name="FlowFilterFieldName">The field name as the table declares it.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure FlowFilter(FlowFilterFieldName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        this.RequireControlName(FlowFilterFieldName);
        this.AddLine(Enum::"BJF MN Config Operation"::"Flow Filter", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", FlowFilterFieldName);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Saved filters ------------------------------------------------------------------

    /// <summary>Adds a named, ready-made filter the device offers on the current page's list.</summary>
    /// <param name="Name">Name of the saved filter, shown on the device.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure SavedFilter(Name: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        this.RequireControlName(Name);
        this.AddLine(Enum::"BJF MN Config Operation"::"Saved Filter", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", Name);
        this.TempConfigurationLine.Validate("View Type", this.ListViewTok);
        this.TempConfigurationLine.Modify(false);
        this.CurrentDetailEntryNo := this.TempConfigurationLine."Entry No.";
        exit(this);
    end;

    /// <summary>One field the saved filter declared last filters on. Repeatable.</summary>
    /// <param name="ControlName">Control to filter on.</param>
    /// <param name="Match">How the criteria are matched.</param>
    /// <param name="Criteria">Value or filter to match.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Where(ControlName: Text[100]; Match: Enum "BJF MN Search Type"; Criteria: Text[250]): Codeunit "BJF MN Config Builder"
    var
        SavedFilterName: Text[100];
    begin
        this.RequireSavedFilter(this.WhereTok);
        this.RequireControlName(ControlName);
        SavedFilterName := this.TempConfigurationLine."Control Name";
        this.AddLine(Enum::"BJF MN Config Operation"::"Saved Filter Field", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", SavedFilterName);
        this.TempConfigurationLine.Validate("Target Filter Field", ControlName);
        this.TempConfigurationLine.Validate("Search Type", this.Vocabulary.SearchTypeName(Match));
        this.TempConfigurationLine.Validate("Filter Value", Criteria);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Makes the saved filter declared last show only the device user's own records.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Mine(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireSavedFilter(this.MineTok);
        this.TempConfigurationLine.Validate("Own Filter Set", true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>Shows the saved filter declared last on a map instead of a list.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure AsMap(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireSavedFilter(this.AsMapTok);
        this.TempConfigurationLine.Validate("View Type", this.MapViewTok);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    // ---- Offline operations -------------------------------------------------------------

    /// <summary>Runs an operation over an offline page's records, between two fields (for example a transfer or sum).</summary>
    /// <param name="Kind">Operation to run.</param>
    /// <param name="SourceField">Field to read.</param>
    /// <param name="DestinationField">Field to write.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Operation(Kind: Enum "BJF MN Operation Type"; SourceField: Text[100]; DestinationField: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddOperation(Kind, SourceField, this.FieldFilterTypeTok, DestinationField, '');
        exit(this);
    end;

    /// <summary>Runs an operation over an offline page's records with a fixed value.</summary>
    /// <param name="Kind">Operation to run.</param>
    /// <param name="SourceField">Field to write.</param>
    /// <param name="Value">Fixed value for the operation.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure OperationValue(Kind: Enum "BJF MN Operation Type"; SourceField: Text[100]; Value: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddOperation(Kind, SourceField, this.ConstFilterTypeTok, '', Value);
        exit(this);
    end;

    // ---- Dynamic layouts ----------------------------------------------------------------

    /// <summary>
    /// Starts a rule that changes the current page's look while its conditions hold: hide or
    /// lock fields, color parts of a row or card, show icons, skip stages. Add conditions with
    /// WhenValue, WhenField and WhenFilter, effects with the verbs that follow.
    /// </summary>
    /// <param name="LayoutCode">Code of the layout rule.</param>
    /// <param name="Description">Description of the layout rule.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Layout(LayoutCode: Code[50]; Description: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if LayoutCode = '' then
            Error(this.CodeRequiredErr, this.LayoutTok, this.CurrentPageId);
        this.AddLine(Enum::"BJF MN Config Operation"::Layout, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", LayoutCode);
        this.TempConfigurationLine.Validate(Description, Description);
        this.TempConfigurationLine.Modify(false);
        this.CurrentDetailEntryNo := this.TempConfigurationLine."Entry No.";
        exit(this);
    end;

    /// <summary>The layout declared last applies while the control's value compares as given with a fixed value. Repeatable; all conditions must hold.</summary>
    /// <param name="ControlName">Control to compare.</param>
    /// <param name="Comparison">Comparison operator.</param>
    /// <param name="Value">Fixed value to compare with.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure WhenValue(ControlName: Text[100]; Comparison: Enum "BJF MN Comparison"; Value: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutCondition(this.WhenValueTok, ControlName, this.ConstFilterTypeTok, this.Vocabulary.ComparisonName(Comparison), '', Value);
        exit(this);
    end;

    /// <summary>The layout declared last applies while one control compares as given with another. Repeatable.</summary>
    /// <param name="ControlName">Control to compare.</param>
    /// <param name="Comparison">Comparison operator.</param>
    /// <param name="OtherControlName">Control to compare with.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure WhenField(ControlName: Text[100]; Comparison: Enum "BJF MN Comparison"; OtherControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.RequireControlName(OtherControlName);
        this.AddLayoutCondition(this.WhenFieldTok, ControlName, this.FieldFilterTypeTok, this.Vocabulary.ComparisonName(Comparison), OtherControlName, '');
        exit(this);
    end;

    /// <summary>The layout declared last applies while the control's value matches a Business Central filter expression. Repeatable.</summary>
    /// <param name="ControlName">Control to test.</param>
    /// <param name="FilterText">Business Central filter expression.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure WhenFilter(ControlName: Text[100]; FilterText: Text[250]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutCondition(this.WhenFilterTok, ControlName, this.FilterFilterTypeTok, this.Vocabulary.ComparisonName(Enum::"BJF MN Comparison"::Equal), '', FilterText);
        exit(this);
    end;

    /// <summary>Keeps the layout declared last from running, without removing it.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure Disabled(): Codeunit "BJF MN Config Builder"
    begin
        this.RequireLayout(this.DisabledTok);
        this.TempConfigurationLine.Validate(Disabled, true);
        this.TempConfigurationLine.Modify(false);
        exit(this);
    end;

    /// <summary>The layout declared last hides a control. Repeatable.</summary>
    /// <param name="ControlName">Control to hide.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure HidesField(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.HidesFieldTok, this.HideFieldActionTok, ControlName, '', '', '');
        exit(this);
    end;

    /// <summary>The layout declared last makes a control read-only. Repeatable.</summary>
    /// <param name="ControlName">Control to make read-only.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure LocksField(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.LocksFieldTok, this.FieldReadOnlyActionTok, ControlName, '', '', '');
        exit(this);
    end;

    /// <summary>The layout declared last makes the whole page read-only.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure LocksPage(): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.LocksPageTok, this.PageReadOnlyActionTok, '', '', '', '');
        exit(this);
    end;

    /// <summary>The layout declared last captions a control with a category's description. Repeatable.</summary>
    /// <param name="ControlName">Control to caption.</param>
    /// <param name="CategoryCode">Category whose description becomes the caption.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure CaptionsField(ControlName: Text[100]; CategoryCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        if CategoryCode = '' then
            Error(this.CodeRequiredErr, this.CaptionsFieldTok, this.CurrentPageId);
        this.AddLayoutAction(this.CaptionsFieldTok, this.FieldCaptionActionTok, ControlName, CategoryCode, '', '');
        exit(this);
    end;

    /// <summary>The layout declared last colors a control's caption. Repeatable.</summary>
    /// <param name="ControlName">Control whose caption is colored.</param>
    /// <param name="Color">Color to apply.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure CaptionColor(ControlName: Text[100]; Color: Enum "BJF MN Color"): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.CaptionColorTok, this.FieldCaptionColorActionTok, ControlName, '', this.Vocabulary.ColorName(Color), '');
        exit(this);
    end;

    /// <summary>The layout declared last colors a control's value. Repeatable.</summary>
    /// <param name="ControlName">Control whose value is colored.</param>
    /// <param name="Color">Color to apply.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ValueColor(ControlName: Text[100]; Color: Enum "BJF MN Color"): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.ValueColorTok, this.FieldValueColorActionTok, ControlName, '', this.Vocabulary.ColorName(Color), '');
        exit(this);
    end;

    /// <summary>The layout declared last colors a part of the list row or card. Repeatable.</summary>
    /// <param name="LayoutArea">Part of the row or card to color.</param>
    /// <param name="Color">Color to apply.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure AreaColor(LayoutArea: Enum "BJF MN Layout Area"; Color: Enum "BJF MN Color"): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.AreaColorTok, this.Vocabulary.LayoutAreaActionName(LayoutArea), '', '', this.Vocabulary.ColorName(Color), '');
        exit(this);
    end;

    /// <summary>The layout declared last shows an icon (a MobileNAV icon code) on the list row.</summary>
    /// <param name="IconCode">MobileNAV icon code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure RowIcon(IconCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        if IconCode = '' then
            Error(this.CodeRequiredErr, this.RowIconTok, this.CurrentPageId);
        this.AddLayoutAction(this.RowIconTok, this.RowIconActionTok, '', '', '', IconCode);
        exit(this);
    end;

    /// <summary>The layout declared last shows an icon (a MobileNAV icon code) in the toolbar.</summary>
    /// <param name="IconCode">MobileNAV icon code.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ToolbarIcon(IconCode: Code[20]): Codeunit "BJF MN Config Builder"
    begin
        if IconCode = '' then
            Error(this.CodeRequiredErr, this.ToolbarIconTok, this.CurrentPageId);
        this.AddLayoutAction(this.ToolbarIconTok, this.ToolbarIconActionTok, '', '', '', IconCode);
        exit(this);
    end;

    /// <summary>The layout declared last skips a wizard stage. Repeatable.</summary>
    /// <param name="StageId">Wizard stage to skip.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure HidesStage(StageId: Code[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.HidesStageTok, this.HideStageActionTok, StageId, '', '', '');
        exit(this);
    end;

    /// <summary>The layout declared last marks a wizard stage as validated. Repeatable.</summary>
    /// <param name="StageId">Wizard stage to mark as validated.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ValidatesStage(StageId: Code[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.ValidatesStageTok, this.StageValidatedActionTok, StageId, '', '', '');
        exit(this);
    end;

    /// <summary>The layout declared last marks a control as validated. Repeatable.</summary>
    /// <param name="ControlName">Control to mark as validated.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ValidatesField(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLayoutAction(this.ValidatesFieldTok, this.FieldValidatedActionTok, ControlName, '', '', '');
        exit(this);
    end;

    // ---- Line formats -------------------------------------------------------------------

    /// <summary>
    /// Opens a line format: what one line of the current page's list rows shows. Show,
    /// ShowCaption and Separator add to the line in order until EndLineFormat. The declaration
    /// replaces everything MobileNAV has for that line.
    /// </summary>
    /// <param name="LineNo">1 for the first line of a list row (also the card header), 2 for the second line, 3 to 8 for the list cells Top/Left, Middle/Left, Bottom/Left, Top/Right, Middle/Right and Bottom/Right.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure LineFormat(LineNo: Integer): Codeunit "BJF MN Config Builder"
    begin
        this.RequirePage();
        if (LineNo < 1) or (LineNo > 8) then
            Error(this.LineFormatNoErr, LineNo);
        if this.CurrentLineFormatNo <> 0 then
            Error(this.LineFormatOpenErr, this.CurrentLineFormatNo, LineNo);
        if this.HasLineFormat(this.CurrentPageId, LineNo) then
            Error(this.LineFormatTwiceErr, LineNo, this.CurrentPageId);
        this.CurrentLineFormatNo := LineNo;
        this.CurrentLineFormatEntryNo := 0;
        this.CurrentControlEntryNo := 0;
        this.CurrentDetailEntryNo := 0;
        exit(this);
    end;

    /// <summary>Adds the control's caption to the open line format.</summary>
    /// <param name="ControlName">Name of the page control.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure ShowCaption(ControlName: Text[100]): Codeunit "BJF MN Config Builder"
    begin
        this.AddLineFormatElement(this.CaptionElementTok, ControlName, '');
        exit(this);
    end;

    /// <summary>
    /// Adds fixed text to the open line format. Separators declared one after another become
    /// one, as MobileNAV stores them.
    /// </summary>
    /// <param name="SeparatorText">The text, without the brackets [ ] { } that MobileNAV reads as field references.</param>
    /// <returns>The builder, for chaining.</returns>
    procedure Separator(SeparatorText: Text[75]): Codeunit "BJF MN Config Builder"
    var
        Combined: Text;
    begin
        this.RequireLineFormat(this.SeparatorTok);
        if SeparatorText = '' then
            Error(this.SeparatorRequiredErr, this.CurrentLineFormatNo);
        if DelChr(SeparatorText, '=', this.FieldBracketsTok) <> SeparatorText then
            Error(this.SeparatorBracketErr, SeparatorText);
        if (this.CurrentLineFormatEntryNo <> 0) and this.TempConfigurationLine.Get(this.CurrentLineFormatEntryNo) then
            if this.TempConfigurationLine."Filter Type" = this.SeparatorElementTok then begin
                Combined := this.TempConfigurationLine."Filter Value" + SeparatorText;
                if StrLen(Combined) > MaxStrLen(SeparatorText) then
                    Error(this.SeparatorTooLongErr, Combined, MaxStrLen(SeparatorText));
                this.TempConfigurationLine.Validate("Filter Value", CopyStr(Combined, 1, MaxStrLen(SeparatorText)));
                this.TempConfigurationLine.Modify(false);
                exit(this);
            end;
        this.AddLineFormatElement(this.SeparatorElementTok, '', SeparatorText);
        exit(this);
    end;

    /// <summary>Closes the line format opened last.</summary>
    /// <returns>The builder, for chaining.</returns>
    procedure EndLineFormat(): Codeunit "BJF MN Config Builder"
    begin
        if this.CurrentLineFormatNo = 0 then
            Error(this.NoLineFormatErr, this.EndLineFormatTok);
        if this.CurrentLineFormatEntryNo = 0 then
            Error(this.EmptyLineFormatErr, this.CurrentLineFormatNo, this.CurrentPageId);
        this.CurrentLineFormatNo := 0;
        exit(this);
    end;

    // ---- Framework side -----------------------------------------------------------------

    /// <summary>
    /// Returns the declared lines, with the profile rows the declarations imply appended (one
    /// all-profiles row per control carrying its own visibility and editability, reshaped by
    /// OnlyInProfile, ExceptInProfile and NotInProfiles), and the declared properties, with the
    /// field settings of the declared control lines as rows of their own.
    /// </summary>
    /// <param name="TargetLine">Receives the configuration lines.</param>
    /// <param name="TargetProperty">Receives the configuration properties.</param>
    internal procedure GetDefinition(var TargetLine: Record "BJF MN Config Line" temporary; var TargetProperty: Record "BJF MN Config Property" temporary)
    begin
        TargetLine.Reset();
        TargetLine.DeleteAll(false);
        this.TempConfigurationLine.Reset();
        if this.TempConfigurationLine.FindSet() then
            repeat
                TargetLine := this.TempConfigurationLine;
                TargetLine.Insert(false);
            until this.TempConfigurationLine.Next() = 0;
        this.ExpandProfileLines(TargetLine);
        TargetLine.Reset();

        TargetProperty.Reset();
        TargetProperty.DeleteAll(false);
        this.TempConfigurationProperty.Reset();
        if this.TempConfigurationProperty.FindSet() then
            repeat
                TargetProperty := this.TempConfigurationProperty;
                TargetProperty.Insert(false);
            until this.TempConfigurationProperty.Next() = 0;
        this.ExpandFieldSettings(TargetProperty);
        TargetProperty.Reset();
    end;

    local procedure ExpandProfileLines(var Target: Record "BJF MN Config Line" temporary)
    var
        ProfileEntryNo: Integer;
    begin
        ProfileEntryNo := this.NextEntryNo;
        this.TempConfigurationLine.SetControlFilter();
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
    /// <param name="Target">Receives the profile rows.</param>
    /// <param name="ControlLine">Control line the profile rows belong to.</param>
    /// <param name="ProfileEntryNo">Entry number of the last profile row written.</param>
    local procedure AddProfileLinesForControl(var Target: Record "BJF MN Config Line" temporary; ControlLine: Record "BJF MN Config Line" temporary; var ProfileEntryNo: Integer)
    var
        ProfileCode: Code[30];
    begin
        if this.OnlyProfiles.ContainsKey(ControlLine."Entry No.") then begin
            foreach ProfileCode in this.OnlyProfiles.Get(ControlLine."Entry No.") do
                this.AddProfileLine(Target, ControlLine, ProfileEntryNo, ProfileCode, ControlLine.Visible);
            exit;
        end;
        this.AddProfileLine(Target, ControlLine, ProfileEntryNo, '', ControlLine.Visible);
        if this.ExceptProfiles.ContainsKey(ControlLine."Entry No.") then
            foreach ProfileCode in this.ExceptProfiles.Get(ControlLine."Entry No.") do
                this.AddProfileLine(Target, ControlLine, ProfileEntryNo, ProfileCode, false);
    end;

    local procedure AddProfileLine(var Target: Record "BJF MN Config Line" temporary; ControlLine: Record "BJF MN Config Line" temporary; var ProfileEntryNo: Integer; ProfileCode: Code[30]; Visible: Boolean)
    begin
        ProfileEntryNo += 1;
        Target.Init();
        Target.Validate("Entry No.", ProfileEntryNo);
        Target.Validate(Operation, Enum::"BJF MN Config Operation"::"Profile Field");
        Target.Validate("Page ID", ControlLine."Page ID");
        Target.Validate("Control Name", ControlLine."Control Name");
        Target.Validate(Profile, ProfileCode);
        Target.Validate(Visible, Visible);
        Target.Validate(Editable, ControlLine.Editable and Visible);
        Target.Insert(false);
    end;

    local procedure ProfilePageLine(Modifier: Text; ProfileCode: Code[30])
    begin
        this.RequirePage();
        if ProfileCode = '' then
            Error(this.ProfileCodeRequiredErr, Modifier, this.CurrentPageId);
        this.TempConfigurationLine.Reset();
        this.TempConfigurationLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Profile Page");
        this.TempConfigurationLine.SetRange("Page ID", this.CurrentPageId);
        this.TempConfigurationLine.SetRange(Profile, ProfileCode);
        if this.TempConfigurationLine.FindFirst() then begin
            this.TempConfigurationLine.Reset();
            exit;
        end;
        this.TempConfigurationLine.Reset();
        this.AddLine(Enum::"BJF MN Config Operation"::"Profile Page", this.CurrentPageId);
        this.TempConfigurationLine.Validate(Profile, ProfileCode);
        this.TempConfigurationLine.Modify(false);
    end;

    local procedure AddRelationFilter(Modifier: Text; FilterType: Text[30]; TargetField: Text[100]; SourceField: Text[100]; Value: Text[250])
    begin
        this.RequireControl(Modifier, this.RelationKinds());
        this.RequireControlName(TargetField);
        if (FilterType = this.FieldFilterTypeTok) and (SourceField = '') then
            Error(this.LinkFilterRequiredErr, this.TempConfigurationLine."Control Name");
        this.AddRelationDetail(Enum::"BJF MN Config Operation"::"Relation Filter");
        this.TempConfigurationLine.Validate("Filter Type", FilterType);
        this.TempConfigurationLine.Validate("Target Filter Field", TargetField);
        this.TempConfigurationLine.Validate("Source Field", SourceField);
        this.TempConfigurationLine.Validate("Filter Value", Value);
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>Adds a detail line of the relation declared last; RequireControl has positioned the record on that control.</summary>
    /// <param name="LineOperation">Operation of the detail line.</param>
    local procedure AddRelationDetail(LineOperation: Enum "BJF MN Config Operation")
    var
        ControlName: Text[100];
    begin
        ControlName := this.TempConfigurationLine."Control Name";
        this.AddLine(LineOperation, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Modify(false);
    end;

    local procedure AddPageFilter(ControlName: Text[100]; FilterType: Text[30]; Comparison: Text[30]; Value: Text[250])
    begin
        this.RequirePage();
        this.RequireControlName(ControlName);
        this.AddLine(Enum::"BJF MN Config Operation"::"Page Filter", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Validate("Filter Type", FilterType);
        this.TempConfigurationLine.Validate(Comparison, Comparison);
        this.TempConfigurationLine.Validate("Filter Value", Value);
        this.TempConfigurationLine.Validate("Filter Scope", this.Vocabulary.FilterScopeName(Enum::"BJF MN Filter Scope"::Both));
        this.TempConfigurationLine.Modify(false);
        this.CurrentDetailEntryNo := this.TempConfigurationLine."Entry No.";
    end;

    /// <summary>A field operation when a control was declared last on this page, else a page operation.</summary>
    /// <param name="Kind">Operation to run.</param>
    /// <param name="SourceField">Field to read.</param>
    /// <param name="FilterType">Filter type of the operation.</param>
    /// <param name="DestinationField">Field to write.</param>
    /// <param name="Value">Fixed value for the operation.</param>
    local procedure AddOperation(Kind: Enum "BJF MN Operation Type"; SourceField: Text[100]; FilterType: Text[30]; DestinationField: Text[100]; Value: Text[250])
    var
        ControlName: Text[100];
    begin
        this.RequirePage();
        this.RequireControlName(SourceField);
        ControlName := this.LastControlName();
        this.AddLine(Enum::"BJF MN Config Operation"::Operation, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Validate("Operation Type", this.Vocabulary.OperationTypeName(Kind));
        this.TempConfigurationLine.Validate("Source Field", SourceField);
        this.TempConfigurationLine.Validate("Filter Type", FilterType);
        this.TempConfigurationLine.Validate("Target Filter Field", DestinationField);
        this.TempConfigurationLine.Validate("Filter Value", Value);
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>A caption of the control declared last, or of the page when there is none.</summary>
    /// <param name="LanguageCode">Language of the caption.</param>
    /// <param name="CaptionText">Caption text in that language.</param>
    local procedure AddCaptionLine(LanguageCode: Code[10]; CaptionText: Text[250])
    var
        ControlName: Text[100];
    begin
        ControlName := this.LastControlName();
        this.AddLine(Enum::"BJF MN Config Operation"::Caption, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Validate("Language Code", LanguageCode);
        this.TempConfigurationLine.Validate(Description, CaptionText);
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>The name of the control declared last on the current page, or empty when there is none.</summary>
    /// <returns>The control name.</returns>
    local procedure LastControlName(): Text[100]
    begin
        if this.CurrentControlEntryNo = 0 then
            exit('');
        if not this.TempConfigurationLine.Get(this.CurrentControlEntryNo) then
            exit('');
        exit(this.TempConfigurationLine."Control Name");
    end;

    local procedure AddLayoutCondition(Modifier: Text; ControlName: Text[100]; FilterType: Text[30]; Comparison: Text[30]; OtherControlName: Text[100]; Value: Text[250])
    var
        LayoutCode: Text[100];
    begin
        this.RequireLayout(Modifier);
        this.RequireControlName(ControlName);
        LayoutCode := this.TempConfigurationLine."Control Name";
        this.AddLine(Enum::"BJF MN Config Operation"::"Layout Condition", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", LayoutCode);
        this.TempConfigurationLine.Validate("Target Filter Field", ControlName);
        this.TempConfigurationLine.Validate("Filter Type", FilterType);
        this.TempConfigurationLine.Validate(Comparison, Comparison);
        this.TempConfigurationLine.Validate("Source Field", OtherControlName);
        this.TempConfigurationLine.Validate("Filter Value", Value);
        this.TempConfigurationLine.Modify(false);
    end;

    local procedure AddLayoutAction(Modifier: Text; ActionType: Text[30]; Name: Text[100]; CaptionCategory: Code[20]; Color: Text[30]; Icon: Code[20])
    var
        LayoutCode: Text[100];
    begin
        this.RequireLayout(Modifier);
        LayoutCode := this.TempConfigurationLine."Control Name";
        this.AddLine(Enum::"BJF MN Config Operation"::"Layout Action", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", LayoutCode);
        this.TempConfigurationLine.Validate("Action Type", ActionType);
        this.TempConfigurationLine.Validate("Target Filter Field", Name);
        this.TempConfigurationLine.Validate("Group Code", CaptionCategory);
        this.TempConfigurationLine.Validate(Color, Color);
        this.TempConfigurationLine.Validate(Icon, Icon);
        this.TempConfigurationLine.Modify(false);
    end;

    local procedure RequireLayout(Modifier: Text)
    begin
        if not this.GetDetail(Enum::"BJF MN Config Operation"::Layout) then
            Error(this.NoLayoutErr, Modifier);
    end;

    local procedure RequireSavedFilter(Modifier: Text)
    begin
        if not this.GetDetail(Enum::"BJF MN Config Operation"::"Saved Filter") then
            Error(this.NoSavedFilterErr, Modifier);
    end;

    /// <summary>Positions the shared record on the layout, page filter or saved filter declared last, when it has the given operation.</summary>
    /// <param name="LineOperation">The operation the modifier applies to.</param>
    /// <returns>True when the line declared last has that operation.</returns>
    local procedure GetDetail(LineOperation: Enum "BJF MN Config Operation"): Boolean
    begin
        if this.CurrentDetailEntryNo = 0 then
            exit(false);
        if not this.TempConfigurationLine.Get(this.CurrentDetailEntryNo) then
            exit(false);
        exit(this.TempConfigurationLine.Operation = LineOperation);
    end;

    /// <summary>Adds a page setting. The property catalog gives its Setting text, field, value kind and validation.</summary>
    /// <param name="Property">The setting.</param>
    /// <param name="Value">Value to write, in XML format.</param>
    local procedure AddPageProperty(Property: Enum "BJF MN Property"; Value: Text[250])
    begin
        this.RequirePage();
        this.AddProperty(Property, this.PropertyCatalog.Setting(Property), '', this.PropertyCatalog.FieldNo(Property), Value, this.PropertyCatalog.ValueKind(Property), this.PropertyCatalog.RunValidate(Property));
    end;

    /// <summary>Adds a page setting whose field depends on the value, so the caller resolves the field number.</summary>
    /// <param name="Property">The setting.</param>
    /// <param name="FieldNo">Field number on MobileNAV Service Setup.</param>
    /// <param name="Value">Value to write, in XML format.</param>
    local procedure AddPagePropertyAt(Property: Enum "BJF MN Property"; FieldNo: Integer; Value: Text[250])
    begin
        this.RequirePage();
        this.AddProperty(Property, this.PropertyCatalog.Setting(Property), '', FieldNo, Value, this.PropertyCatalog.ValueKind(Property), this.PropertyCatalog.RunValidate(Property));
    end;

    /// <summary>Adds a property of the control declared last; RequireControl has positioned the shared record on it.</summary>
    /// <param name="Property">The setting.</param>
    /// <param name="Value">Value to write, in XML format.</param>
    local procedure AddControlProperty(Property: Enum "BJF MN Property"; Value: Text[250])
    begin
        this.AddProperty(Property, this.PropertyCatalog.Setting(Property), this.TempConfigurationLine."Control Name", this.PropertyCatalog.FieldNo(Property), Value, this.PropertyCatalog.ValueKind(Property), this.PropertyCatalog.RunValidate(Property));
    end;

    /// <summary>A later declaration of the same setting replaces the earlier one.</summary>
    /// <param name="Property">The catalog entry the property is made from.</param>
    /// <param name="Setting">Builder verb that produced the property.</param>
    /// <param name="ControlName">Control the property applies to, empty for the page.</param>
    /// <param name="FieldNo">Field number on MobileNAV Service Setup.</param>
    /// <param name="Value">Value to write.</param>
    /// <param name="ValueKind">Kind of value, which sets its format.</param>
    /// <param name="RunValidate">Whether to run the field OnValidate trigger.</param>
    local procedure AddProperty(Property: Enum "BJF MN Property"; Setting: Text[50]; ControlName: Text[100]; FieldNo: Integer; Value: Text[250]; ValueKind: Enum "BJF MN Property Value"; RunValidate: Boolean)
    begin
        this.TempConfigurationProperty.Reset();
        this.TempConfigurationProperty.SetRange("Page ID", this.CurrentPageId);
        this.TempConfigurationProperty.SetRange("Control Name", ControlName);
        this.TempConfigurationProperty.SetRange("Field No.", FieldNo);
        if not this.TempConfigurationProperty.FindFirst() then begin
            this.NextPropertyEntryNo += 1;
            this.TempConfigurationProperty.Init();
            this.TempConfigurationProperty.Validate("Entry No.", this.NextPropertyEntryNo);
            this.TempConfigurationProperty.Validate("Page ID", this.CurrentPageId);
            this.TempConfigurationProperty.Validate("Control Name", ControlName);
            this.TempConfigurationProperty.Validate("Field No.", FieldNo);
            this.TempConfigurationProperty.Insert(false);
        end;
        this.TempConfigurationProperty.Validate(Property, Property);
        this.TempConfigurationProperty.Validate(Setting, Setting);
        this.TempConfigurationProperty.Validate(Value, Value);
        this.TempConfigurationProperty.Validate("Value Kind", ValueKind);
        this.TempConfigurationProperty.Validate(Validate, RunValidate);
        this.TempConfigurationProperty.Modify(false);
        this.TempConfigurationProperty.Reset();
    end;

    /// <summary>
    /// Appends the field settings of the declared Field, Function Field, Scan Field and Lookup
    /// Field lines as property rows, so the apply and the checks read them like every other
    /// setting. The rows follow the order MNFieldMgt wrote them in, and they come after the
    /// builder's own properties.
    /// </summary>
    /// <param name="TargetProperty">Receives the rows.</param>
    local procedure ExpandFieldSettings(var TargetProperty: Record "BJF MN Config Property" temporary)
    var
        EntryNo: Integer;
    begin
        TargetProperty.Reset();
        if TargetProperty.FindLast() then
            EntryNo := TargetProperty."Entry No.";
        this.TempConfigurationLine.Reset();
        this.TempConfigurationLine.SetFilter(Operation, '%1|%2|%3|%4',
            Enum::"BJF MN Config Operation"::Field, Enum::"BJF MN Config Operation"::"Function Field", Enum::"BJF MN Config Operation"::"Scan Field",
            Enum::"BJF MN Config Operation"::"Lookup Field");
        if this.TempConfigurationLine.FindSet() then
            repeat
                this.ExpandControlLine(TargetProperty, EntryNo);
            until this.TempConfigurationLine.Next() = 0;
        this.TempConfigurationLine.Reset();
    end;

    /// <summary>Appends the field settings of the control line the builder is on, by its kind.</summary>
    /// <param name="TargetProperty">Receives the rows.</param>
    /// <param name="EntryNo">Entry number of the last row. The new rows take the next ones.</param>
    local procedure ExpandControlLine(var TargetProperty: Record "BJF MN Config Property" temporary; var EntryNo: Integer)
    begin
        case this.TempConfigurationLine.Operation of
            Enum::"BJF MN Config Operation"::Field:
                this.ExpandFieldLine(TargetProperty, EntryNo);
            Enum::"BJF MN Config Operation"::"Function Field":
                this.ExpandFunctionFieldLine(TargetProperty, EntryNo);
            Enum::"BJF MN Config Operation"::"Scan Field":
                this.ExpandScanFieldLine(TargetProperty, EntryNo);
            Enum::"BJF MN Config Operation"::"Lookup Field":
                this.ExpandLookupFieldLine(TargetProperty, EntryNo);
        end;
    end;

    /// <summary>Appends the field settings of the Field line the builder is on.</summary>
    /// <param name="TargetProperty">Receives the rows.</param>
    /// <param name="EntryNo">Entry number of the last row. The new rows take the next ones.</param>
    local procedure ExpandFieldLine(var TargetProperty: Record "BJF MN Config Property" temporary; var EntryNo: Integer)
    begin
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldVisible, Format(this.TempConfigurationLine.Visible, 0, 9));
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldEditable, Format(this.TempConfigurationLine.Editable, 0, 9));
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldDisplayInMenu, Format(this.TempConfigurationLine."Display In Menu", 0, 9));
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldFilterable, Format(this.TempConfigurationLine.Filterable, 0, 9));
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldImportance, this.TempConfigurationLine.Importance);
        if this.TempConfigurationLine."Mobile Type" <> '' then
            this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldMobileType, this.TempConfigurationLine."Mobile Type");
    end;

    /// <summary>Appends the field settings of the Function Field line the builder is on.</summary>
    /// <param name="TargetProperty">Receives the rows.</param>
    /// <param name="EntryNo">Entry number of the last row. The new rows take the next ones.</param>
    local procedure ExpandFunctionFieldLine(var TargetProperty: Record "BJF MN Config Property" temporary; var EntryNo: Integer)
    begin
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldVisible, this.TrueTok);
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldEditable, Format(this.TempConfigurationLine.Editable, 0, 9));
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldDisplayInMenu, Format(not this.Vocabulary.RendersInline(this.TempConfigurationLine."Mobile Type"), 0, 9));
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldImportance, this.TempConfigurationLine.Importance);
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldMobileType, this.TempConfigurationLine."Mobile Type");
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldFunctionType, this.TempConfigurationLine."Function Type");
        if this.TempConfigurationLine."Validation Behavior" <> '' then
            this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldValidationBehavior, this.TempConfigurationLine."Validation Behavior");
    end;

    /// <summary>Appends the field settings of the Scan Field line the builder is on.</summary>
    /// <param name="TargetProperty">Receives the rows.</param>
    /// <param name="EntryNo">Entry number of the last row. The new rows take the next ones.</param>
    local procedure ExpandScanFieldLine(var TargetProperty: Record "BJF MN Config Property" temporary; var EntryNo: Integer)
    begin
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldVisible, this.TrueTok);
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldEditable, this.TrueTok);
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldImportance, this.TempConfigurationLine.Importance);
        this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldMobileType, this.TempConfigurationLine."Mobile Type");
        if this.TempConfigurationLine."Validation Behavior" <> '' then
            this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldValidationBehavior, this.TempConfigurationLine."Validation Behavior");
    end;

    /// <summary>
    /// Appends the mobile type and validation behavior of the Lookup Field line the builder is on,
    /// when the lookup declares them. "BJF MN Relation Mgt.".ConfigureLookup writes the lookup's
    /// visibility, editability, placement and relation.
    /// </summary>
    /// <param name="TargetProperty">Receives the rows.</param>
    /// <param name="EntryNo">Entry number of the last row. The new rows take the next ones.</param>
    local procedure ExpandLookupFieldLine(var TargetProperty: Record "BJF MN Config Property" temporary; var EntryNo: Integer)
    begin
        if this.TempConfigurationLine."Mobile Type" <> '' then
            this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldMobileType, this.TempConfigurationLine."Mobile Type");
        if this.TempConfigurationLine."Validation Behavior" <> '' then
            this.AddFieldSetting(TargetProperty, EntryNo, Enum::"BJF MN Property"::FieldValidationBehavior, this.TempConfigurationLine."Validation Behavior");
    end;

    /// <summary>Appends one field setting of the declared control line as a property row.</summary>
    /// <param name="TargetProperty">Receives the row.</param>
    /// <param name="EntryNo">Entry number of the last row. The new row takes the next one.</param>
    /// <param name="Property">The field setting.</param>
    /// <param name="Value">Value to write, in XML format.</param>
    local procedure AddFieldSetting(var TargetProperty: Record "BJF MN Config Property" temporary; var EntryNo: Integer; Property: Enum "BJF MN Property"; Value: Text[250])
    begin
        EntryNo += 1;
        TargetProperty.Init();
        TargetProperty.Validate("Entry No.", EntryNo);
        TargetProperty.Validate("Page ID", this.TempConfigurationLine."Page ID");
        TargetProperty.Validate("Control Name", this.TempConfigurationLine."Control Name");
        TargetProperty.Validate("Field No.", this.PropertyCatalog.FieldNo(Property));
        TargetProperty.Validate(Property, Property);
        TargetProperty.Validate(Setting, this.PropertyCatalog.Setting(Property));
        TargetProperty.Validate(Value, Value);
        TargetProperty.Validate("Value Kind", this.PropertyCatalog.ValueKind(Property));
        TargetProperty.Validate(Validate, this.PropertyCatalog.RunValidate(Property));
        TargetProperty.Insert(false);
    end;

    local procedure BeginControl(LineOperation: Enum "BJF MN Config Operation"; ControlName: Text[100])
    begin
        this.RequirePage();
        this.RequireControlName(ControlName);
        this.AddLine(LineOperation, this.CurrentPageId);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Validate("Group Code", this.CurrentGroupCode);
        // Standard placement: MobileNAV's own default is Additional, which hides the control
        // behind the card's "show more" section, for a button somewhere nobody looks.
        this.TempConfigurationLine.Validate(Importance, this.Vocabulary.ImportanceName(Enum::"BJF MN Importance"::Standard));
        this.TempConfigurationLine.Modify(false);
        this.CurrentControlEntryNo := this.TempConfigurationLine."Entry No.";
        this.CurrentDetailEntryNo := 0;
    end;

    local procedure AddStageField(ControlName: Text[100]; FieldEnabled: Boolean)
    var
        StageId: Code[100];
    begin
        this.RequireStageLine(this.ShowTok);
        this.RequireControlName(ControlName);
        StageId := this.TempConfigurationLine."Stage Id";
        this.AddLine(Enum::"BJF MN Config Operation"::"Stage Field", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Stage Id", StageId);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Validate("Stage Enabled", FieldEnabled);
        this.TempConfigurationLine.Modify(false);
    end;

    local procedure AddLineFormatElement(ElementType: Text[30]; ControlName: Text[100]; SeparatorText: Text[250])
    var
        Position: Integer;
    begin
        if ElementType = this.CaptionElementTok then
            this.RequireLineFormat(this.ShowCaptionTok)
        else
            this.RequireLineFormat(this.ShowTok);
        if ElementType <> this.SeparatorElementTok then
            this.RequireControlName(ControlName);
        Position := 1;
        if this.CurrentLineFormatEntryNo <> 0 then
            if this.TempConfigurationLine.Get(this.CurrentLineFormatEntryNo) then
                Position := this.TempConfigurationLine."Line Format Position" + 1;
        this.AddLine(Enum::"BJF MN Config Operation"::"Line Format", this.CurrentPageId);
        this.TempConfigurationLine.Validate("Line Format No.", this.CurrentLineFormatNo);
        this.TempConfigurationLine.Validate("Line Format Position", Position);
        this.TempConfigurationLine.Validate("Filter Type", ElementType);
        this.TempConfigurationLine.Validate("Control Name", ControlName);
        this.TempConfigurationLine.Validate("Filter Value", SeparatorText);
        this.TempConfigurationLine.Modify(false);
        this.CurrentLineFormatEntryNo := this.TempConfigurationLine."Entry No.";
    end;

    local procedure RequireLineFormat(Modifier: Text)
    begin
        if this.CurrentLineFormatNo = 0 then
            Error(this.NoLineFormatErr, Modifier);
    end;

    local procedure HasLineFormat(PageId: Integer; LineNo: Integer): Boolean
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        TempLine.Copy(this.TempConfigurationLine, true);
        TempLine.SetRange(Operation, Enum::"BJF MN Config Operation"::"Line Format");
        TempLine.SetRange("Page ID", PageId);
        TempLine.SetRange("Line Format No.", LineNo);
        exit(not TempLine.IsEmpty());
    end;

    local procedure AddLine(LineOperation: Enum "BJF MN Config Operation"; PageId: Integer)
    begin
        this.NextEntryNo += 1;
        this.TempConfigurationLine.Init();
        this.TempConfigurationLine.Validate("Entry No.", this.NextEntryNo);
        this.TempConfigurationLine.Validate(Operation, LineOperation);
        this.TempConfigurationLine.Validate("Page ID", PageId);
        this.TempConfigurationLine.Insert(false);
    end;

    local procedure AddProfileScope(var Scopes: Dictionary of [Integer, List of [Code[30]]]; ProfileCode: Code[30])
    var
        Profiles: List of [Code[30]];
    begin
        if Scopes.ContainsKey(this.CurrentControlEntryNo) then
            Profiles := Scopes.Get(this.CurrentControlEntryNo);
        if not Profiles.Contains(ProfileCode) then
            Profiles.Add(ProfileCode);
        Scopes.Set(this.CurrentControlEntryNo, Profiles);
    end;

    local procedure HasLine(LineOperation: Enum "BJF MN Config Operation"; PageId: Integer): Boolean
    var
        TempLine: Record "BJF MN Config Line" temporary;
    begin
        TempLine.Copy(this.TempConfigurationLine, true);
        TempLine.SetRange(Operation, LineOperation);
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

    local procedure RequireProfile(ProfileCode: Code[30])
    begin
        if ProfileCode = '' then
            Error(this.ProfileRequiredErr, this.TempConfigurationLine."Control Name");
    end;

    /// <summary>Positions the shared record on the control declared last, or errors naming the modifier and what it applies to.</summary>
    /// <param name="Modifier">Name of the modifier, used in the error message.</param>
    /// <param name="ApplicableKinds">Control kinds the modifier applies to.</param>
    local procedure RequireControl(Modifier: Text; ApplicableKinds: List of [Enum "BJF MN Config Operation"])
    begin
        if (this.CurrentControlEntryNo = 0) or not this.TempConfigurationLine.Get(this.CurrentControlEntryNo) then
            Error(this.NoControlErr, Modifier);
        if not ApplicableKinds.Contains(this.TempConfigurationLine.Operation) then
            Error(this.ModifierNotApplicableErr, Modifier, this.TempConfigurationLine."Control Name", this.KindName(this.TempConfigurationLine.Operation));
    end;

    local procedure RequirePublishedPageLine()
    begin
        if not this.FindPageLine(Enum::"BJF MN Config Operation"::"Published Page") then
            Error(this.PublishRequiredErr, this.CurrentPageId);
    end;

    local procedure RequireStagingLine(Modifier: Text)
    begin
        if not this.FindPageLine(Enum::"BJF MN Config Operation"::Staging) then
            Error(this.WizardRequiredForModifierErr, Modifier);
    end;

    /// <summary>Positions the shared record on the current page's first line of the operation.</summary>
    /// <param name="LineOperation">Operation of the line to find.</param>
    /// <returns>True when the page has such a line.</returns>
    local procedure FindPageLine(LineOperation: Enum "BJF MN Config Operation"): Boolean
    var
        Found: Boolean;
    begin
        this.RequirePage();
        this.TempConfigurationLine.SetRange(Operation, LineOperation);
        this.TempConfigurationLine.SetRange("Page ID", this.CurrentPageId);
        Found := this.TempConfigurationLine.FindFirst();
        this.TempConfigurationLine.Reset();
        exit(Found);
    end;

    local procedure RequireStageLine(Modifier: Text)
    begin
        if (this.CurrentStageEntryNo = 0) or not this.TempConfigurationLine.Get(this.CurrentStageEntryNo) then
            Error(this.NoStageErr, Modifier);
    end;

    local procedure KindName(LineOperation: Enum "BJF MN Config Operation"): Text
    begin
        case LineOperation of
            Enum::"BJF MN Config Operation"::Field:
                exit(this.FieldKindTok);
            Enum::"BJF MN Config Operation"::"Function Field":
                exit(this.ButtonKindTok);
            Enum::"BJF MN Config Operation"::"Linked Field":
                exit(this.LinkKindTok);
            Enum::"BJF MN Config Operation"::"Scan Field":
                exit(this.ScanKindTok);
            Enum::"BJF MN Config Operation"::"Lookup Field":
                exit(this.LookupKindTok);
        end;
        exit(Format(LineOperation));
    end;

    local procedure AllControlKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::Field);
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Linked Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    local procedure RelationKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::"Linked Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    local procedure LookupKind() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    local procedure FieldKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::Field);
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Scan Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    local procedure PlainFieldKind() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::Field);
    end;

    local procedure ButtonKind() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
    end;

    local procedure ButtonAndLookupKinds() Kinds: List of [Enum "BJF MN Config Operation"]
    begin
        Kinds.Add(Enum::"BJF MN Config Operation"::"Function Field");
        Kinds.Add(Enum::"BJF MN Config Operation"::"Lookup Field");
    end;

    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        Vocabulary: Codeunit "BJF MN Vocabulary";
        PropertyCatalog: Codeunit "BJF MN Property Catalog";
        OnlyProfiles: Dictionary of [Integer, List of [Code[30]]];
        ExceptProfiles: Dictionary of [Integer, List of [Code[30]]];
        UnprofiledControls: List of [Integer];
        NextEntryNo: Integer;
        NextPropertyEntryNo: Integer;
        CurrentPageId: Integer;
        CurrentControlEntryNo: Integer;
        CurrentStageEntryNo: Integer;
        // The layout, page filter or saved filter declared last. Declaring one replaces the other two.
        CurrentDetailEntryNo: Integer;
        CurrentGroupCode: Code[20];
        CurrentLineFormatNo: Integer;
        CurrentLineFormatEntryNo: Integer;
        PageIdRequiredErr: Label 'Page() needs a page object id, for example Page::"MobileNAV WhseShipment".';
        PageRequiredErr: Label 'Declare the page first: Configuration.Page(Page::"...") before Field, Button, Link, Scan, Publish, MineOnly or Wizard.';
        ServiceNameRequiredErr: Label 'Publish() needs the web service name to register the page under.';
        ControlNotDeclaredErr: Label 'Page %1 has no control %2 declared yet. Declare it with Field, Button, Scan, Lookup or Link before Control(''%2'').', Comment = '%1 = page id, %2 = control name';
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
        PageFunctionsRejectsDialogErr: Label 'PageFunctions() cannot be used on dialog page %1. Use Functions() with a separate function service name.', Comment = '%1 = page id';
        PageFunctionsTwiceErr: Label 'PageFunctions() is declared twice on page %1. A page has one companion codeunit.', Comment = '%1 = page id';
        PageFunctionsCodeunitRequiredErr: Label 'PageFunctions() on page %1 needs the object id of the companion codeunit.', Comment = '%1 = page id';
        WizardRequiredErr: Label 'Stage %1 needs Wizard() on the page first.', Comment = '%1 = stage id';
        WizardRequiredForModifierErr: Label '%1() needs Wizard() on the page first.', Comment = '%1 = modifier name';
        StageIdRequiredErr: Label 'Stage() needs a stage id.';
        NoStageErr: Label '%1() applies to the stage declared last, but no Stage has been declared yet.', Comment = '%1 = modifier name';
        PositiveValueRequiredErr: Label '%1() on %2 needs a value greater than zero.', Comment = '%1 = setting name, %2 = page id or control name';
        CodeRequiredErr: Label '%1() on page %2 needs a code.', Comment = '%1 = setting name, %2 = page id';
        PageFunctionRequiredErr: Label '%1() needs the name of a MobileNAV page function.', Comment = '%1 = setting name';
        RangeOrderErr: Label 'Range() on %1 needs the minimum below the maximum.', Comment = '%1 = control name';
        ValidationRequiredErr: Label 'AllowSkip() on %1 needs Validation() first: there is nothing to skip until a scan is required.', Comment = '%1 = control name';
        PatternRequiredErr: Label 'RegEx() on %1 needs a pattern.', Comment = '%1 = control name';
        ProfileCodeRequiredErr: Label '%1() on page %2 needs a MobileNAV profile code.', Comment = '%1 = modifier name, %2 = page id';
        LookupCodeFieldRequiredErr: Label 'Lookup %1 needs the target page''s code field.', Comment = '%1 = control name';
        GroupOpenErr: Label 'Group %1 is still open; call EndGroup() before opening group %2.', Comment = '%1 = open group, %2 = new group';
        NoGroupErr: Label 'EndGroup() was called with no group open.';
        NoPageFilterErr: Label 'Scope() applies to the page filter declared last, but no PageFilter has been declared yet.';
        NoLayoutErr: Label '%1() applies to the layout declared last, but no Layout has been declared yet.', Comment = '%1 = modifier name';
        LineFormatNoErr: Label 'LineFormat(%1) needs a line number from 1 to 8: 1 and 2 are the first and second line of a list row, 3 to 8 the list cells.', Comment = '%1 = line number';
        LineFormatOpenErr: Label 'LineFormat(%1) is still open; call EndLineFormat() before opening LineFormat(%2).', Comment = '%1 = open line number, %2 = new line number';
        LineFormatTwiceErr: Label 'LineFormat(%1) is declared twice on page %2. Declare each line once.', Comment = '%1 = line number, %2 = page id';
        NoLineFormatErr: Label '%1() applies to the open line format, but no LineFormat is open.', Comment = '%1 = verb name';
        EmptyLineFormatErr: Label 'LineFormat(%1) on page %2 has nothing to show; add Show, ShowCaption or Separator before EndLineFormat().', Comment = '%1 = line number, %2 = page id';
        SeparatorRequiredErr: Label 'Separator() in LineFormat(%1) needs a text.', Comment = '%1 = line number';
        SeparatorBracketErr: Label 'Separator ''%1'' contains a bracket. MobileNAV reads [ ] and { } in a line format as field references.', Comment = '%1 = separator text';
        SeparatorTooLongErr: Label 'Separator ''%1'' is longer than %2 characters, the most MobileNAV stores for one separator.', Comment = '%1 = separator text, %2 = maximum length';
        NoSavedFilterErr: Label '%1() applies to the saved filter declared last, but no SavedFilter has been declared yet.', Comment = '%1 = modifier name';
        FieldFilterTypeTok: Label 'FIELD', Locked = true;
        ConstFilterTypeTok: Label 'CONST', Locked = true;
        FilterFilterTypeTok: Label 'FILTER', Locked = true;
        ListViewTok: Label 'List', Locked = true;
        MapViewTok: Label 'Map', Locked = true;
        PngTok: Label 'png', Locked = true;
        HideFieldActionTok: Label 'HideField', Locked = true;
        FieldReadOnlyActionTok: Label 'FieldReadOnly', Locked = true;
        PageReadOnlyActionTok: Label 'PageReadOnly', Locked = true;
        FieldCaptionActionTok: Label 'FieldCaption', Locked = true;
        FieldCaptionColorActionTok: Label 'FieldCaptionColor', Locked = true;
        FieldValueColorActionTok: Label 'FieldValueColor', Locked = true;
        RowIconActionTok: Label 'RowIcon', Locked = true;
        ToolbarIconActionTok: Label 'ToolbarIcon', Locked = true;
        HideStageActionTok: Label 'HideStage', Locked = true;
        StageValidatedActionTok: Label 'StageValidated', Locked = true;
        FieldValidatedActionTok: Label 'FieldValidated', Locked = true;
        CategoryTok: Label 'Category', Locked = true;
        CategoryTranslationTok: Label 'CategoryTranslation', Locked = true;
        ProfileTok: Label 'Profile', Locked = true;
        MenuCategoryTok: Label 'MenuCategory', Locked = true;
        MenuCategoryInProfileTok: Label 'MenuCategoryInProfile', Locked = true;
        ExcludeFromProfileTok: Label 'ExcludeFromProfile', Locked = true;
        OnlineInProfileTok: Label 'OnlineInProfile', Locked = true;
        LookupOnlyInProfileTok: Label 'LookupOnlyInProfile', Locked = true;
        CaptionTok: Label 'Caption', Locked = true;
        TranslatedLanguageTok: Label '*', Locked = true;
        MenuPictureTok: Label 'MenuPicture', Locked = true;
        GroupTok: Label 'Group', Locked = true;
        FilterTok: Label 'Filter', Locked = true;
        FilterValueTok: Label 'FilterValue', Locked = true;
        FilterExpressionTok: Label 'FilterExpression', Locked = true;
        OnlyWhenTok: Label 'OnlyWhen', Locked = true;
        MultiSelectTok: Label 'MultiSelect', Locked = true;
        RefreshOnOpenTok: Label 'RefreshOnOpen', Locked = true;
        AdditionalCodeTok: Label 'AdditionalCode', Locked = true;
        PropagateTok: Label 'Propagate', Locked = true;
        ParentActionTok: Label 'ParentAction', Locked = true;
        WhereTok: Label 'Where', Locked = true;
        MineTok: Label 'Mine', Locked = true;
        AsMapTok: Label 'AsMap', Locked = true;
        LayoutTok: Label 'Layout', Locked = true;
        WhenValueTok: Label 'WhenValue', Locked = true;
        WhenFieldTok: Label 'WhenField', Locked = true;
        WhenFilterTok: Label 'WhenFilter', Locked = true;
        DisabledTok: Label 'Disabled', Locked = true;
        HidesFieldTok: Label 'HidesField', Locked = true;
        LocksFieldTok: Label 'LocksField', Locked = true;
        LocksPageTok: Label 'LocksPage', Locked = true;
        CaptionsFieldTok: Label 'CaptionsField', Locked = true;
        CaptionColorTok: Label 'CaptionColor', Locked = true;
        ValueColorTok: Label 'ValueColor', Locked = true;
        AreaColorTok: Label 'AreaColor', Locked = true;
        RowIconTok: Label 'RowIcon', Locked = true;
        ToolbarIconTok: Label 'ToolbarIcon', Locked = true;
        HidesStageTok: Label 'HidesStage', Locked = true;
        ValidatesStageTok: Label 'ValidatesStage', Locked = true;
        ValidatesFieldTok: Label 'ValidatesField', Locked = true;
        LookupKindTok: Label 'lookup', Locked = true;
        TrueTok: Label 'true', Locked = true;
        FalseTok: Label 'false', Locked = true;
        ListLimitTok: Label 'ListLimit', Locked = true;
        OnOpenTok: Label 'OnOpen', Locked = true;
        OnCloseTok: Label 'OnClose', Locked = true;
        StyleTok: Label 'Style', Locked = true;
        ChunkSizeTok: Label 'ChunkSize', Locked = true;
        CheckForChangesTok: Label 'CheckForChanges', Locked = true;
        DecimalPlacesTok: Label 'DecimalPlaces', Locked = true;
        QuantityTok: Label 'Quantity', Locked = true;
        IncreasesTok: Label 'Increases', Locked = true;
        RangeTok: Label 'Range', Locked = true;
        QuickEditTok: Label 'QuickEdit', Locked = true;
        PromotedOnGroupHeaderTok: Label 'PromotedOnGroupHeader', Locked = true;
        AllowSkipTok: Label 'AllowSkip', Locked = true;
        RegExTok: Label 'RegEx', Locked = true;
        NoRegExTok: Label 'NoRegEx', Locked = true;
        FieldCategoryTok: Label 'FieldCategory', Locked = true;
        HideDrillDownTok: Label 'HideDrillDown', Locked = true;
        ValidateAlwaysTok: Label 'ValidateAlways', Locked = true;
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
        ShowCaptionTok: Label 'ShowCaption', Locked = true;
        SeparatorTok: Label 'Separator', Locked = true;
        EndLineFormatTok: Label 'EndLineFormat', Locked = true;
        CaptionElementTok: Label 'Caption', Locked = true;
        ValueElementTok: Label 'Value', Locked = true;
        SeparatorElementTok: Label 'Separator', Locked = true;
        FieldBracketsTok: Label '[]{}', Locked = true;
        FieldKindTok: Label 'field', Locked = true;
        ButtonKindTok: Label 'button', Locked = true;
        LinkKindTok: Label 'link', Locked = true;
        ScanKindTok: Label 'scan', Locked = true;
}
