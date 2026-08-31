
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Constrained builder used by providers to declare supported MobileNAV configuration.
/// It records intent only; it cannot apply configuration.
/// </summary>
codeunit 77781 "BJF MN Config Builder"
{
    /// <summary>Registers, refreshes, and publishes a MobileNAV page web service.</summary>
    /// <param name="PageId">ID of the page to publish as a MobileNAV web service.</param>
    /// <param name="PreferredServiceName">Preferred name for the published web service.</param>
    procedure AddPublishedPage(PageId: Integer; PreferredServiceName: Text[100])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Published Page", PageId);
        this.TempConfigurationLine."Service Name" := PreferredServiceName;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Publishes a page as a MobileNAV Report page — the action-dialog pattern: parameter
    /// fields plus an execute control. This is the only page type for which a control linking
    /// to the page from another card renders as a toolbar action; a linked field targeting a
    /// List page renders as a lookup binding instead, which an empty read-only card does not
    /// draw at all. Use for pages that exist to collect inputs and run something, like a
    /// serial-number generator.
    /// </summary>
    /// <param name="PageId">ID of the page to publish as a MobileNAV web service.</param>
    /// <param name="PreferredServiceName">Preferred name for the published web service.</param>
    procedure AddPublishedReportPage(PageId: Integer; PreferredServiceName: Text[100])
    begin
        this.AddPublishedPage(PageId, PreferredServiceName);
        this.TempConfigurationLine."Page Type" := this.ReportPageTypeTok;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Adds an explicit field configuration for an existing MobileNAV page, placing the field
    /// in MobileNAV's standard section and leaving it out of the device filter pane. Use the
    /// Importance/Filterable overload to place a field elsewhere or make it filterable.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Visible">Whether the field is shown on the page.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    /// <param name="DisplayInMenu">Whether the field is shown as a menu entry rather than a card value.</param>
    procedure AddField(PageId: Integer; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean)
    begin
        this.AddField(PageId, ControlName, Visible, Editable, DisplayInMenu, this.StandardImportanceTok, false);
    end;

    /// <summary>
    /// Adds an explicit field configuration for an existing MobileNAV page and controls where
    /// the device draws it and whether it can be filtered on. Importance follows MobileNAV's
    /// vocabulary: 'None' places the field in the standard section, 'RequiredForInsert' and
    /// 'Mandatory' mark it as required, and 'Additional' hides it behind the card's additional
    /// fields section (MobileNAV's own default for a new field). Filterable true also offers
    /// the field in the device's filter pane. Filter Scope is left at MobileNAV's default.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Visible">Whether the field is shown on the page.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    /// <param name="DisplayInMenu">Whether the field is shown as a menu entry rather than a card value.</param>
    /// <param name="Importance">MobileNAV importance vocabulary controlling where the field is drawn.</param>
    /// <param name="Filterable">Whether the field is offered in the device's filter pane.</param>
    procedure AddField(PageId: Integer; ControlName: Text[100]; Visible: Boolean; Editable: Boolean; DisplayInMenu: Boolean; Importance: Text[30]; Filterable: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Field, PageId);
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine.Visible := Visible;
        this.TempConfigurationLine.Editable := Editable;
        this.TempConfigurationLine."Display In Menu" := DisplayInMenu;
        this.TempConfigurationLine.Importance := Importance;
        this.TempConfigurationLine.Filterable := Filterable;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Makes a field visible on the page in MobileNAV's standard section and sets its
    /// editability.
    ///
    /// Display in Menu is deliberately not set. In MobileNAV that flag marks a field as an
    /// entry in the page's menu — which is what a drill-down button is — rather than a value
    /// drawn on the card, so setting it on an ordinary field keeps that field off the card.
    /// Use AddLinkedField for drill-downs, or AddField if a caller genuinely needs the flag.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    procedure AddVisibleField(PageId: Integer; ControlName: Text[100]; Editable: Boolean)
    begin
        this.AddField(PageId, ControlName, true, Editable, false, this.StandardImportanceTok, false);
    end;

    /// <summary>
    /// Makes a field visible in MobileNAV's standard section, sets its editability, and offers
    /// it in the device's filter pane. Filter Scope is left at MobileNAV's default, so the
    /// filter applies wherever that default allows.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    procedure AddFilterableField(PageId: Integer; ControlName: Text[100]; Editable: Boolean)
    begin
        this.AddField(PageId, ControlName, true, Editable, false, this.StandardImportanceTok, true);
    end;

    /// <summary>
    /// Makes a field visible and binds it to a target MobileNAV page using one FIELD filter.
    /// The target page can be declared with AddPublishedPage or already exist in MobileNAV.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="TargetPageId">ID of the MobileNAV page the field links to.</param>
    /// <param name="TargetFilterField">Field on the target page to filter on.</param>
    /// <param name="SourceField">Field on this page supplying the filter value.</param>
    procedure AddLinkedField(PageId: Integer; ControlName: Text[100]; TargetPageId: Integer; TargetFilterField: Text[100]; SourceField: Text[100])
    begin
        // Standard placement: the linked field is the button that opens the target page, and
        // MobileNAV's Additional default would hide the only route to it.
        this.AddLinkedField(
            PageId, ControlName, TargetPageId, TargetFilterField, SourceField, this.StandardImportanceTok);
    end;

    /// <summary>
    /// Adds a linked field and places it explicitly. Importance follows MobileNAV's vocabulary:
    /// 'None' places the control in the standard section, 'Additional' hides it behind the
    /// card's additional fields section (MobileNAV's own default for a new field).
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="TargetPageId">ID of the MobileNAV page the field links to.</param>
    /// <param name="TargetFilterField">Field on the target page to filter on.</param>
    /// <param name="SourceField">Field on this page supplying the filter value.</param>
    /// <param name="Importance">MobileNAV Importance option member name, for example 'None'.</param>
    procedure AddLinkedField(PageId: Integer; ControlName: Text[100]; TargetPageId: Integer; TargetFilterField: Text[100]; SourceField: Text[100]; Importance: Text[30])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Linked Field", PageId);
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine."Target Page ID" := TargetPageId;
        this.TempConfigurationLine."Target Filter Field" := TargetFilterField;
        this.TempConfigurationLine."Source Field" := SourceField;
        this.TempConfigurationLine.Importance := Importance;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Makes a field visible and binds it to a MobileNAV page function so the device renders
    /// it as a special control (for example a Signature pad bound to a BLOB function).
    /// Editable false shows the control read-only, for example a captured signature on a
    /// posted document. Names are matched against MobileNAV's own option members at apply
    /// time, so they follow MobileNAV's vocabulary: MobileType (for example 'Signature',
    /// 'Image'), FunctionType (for example 'BLOB', 'BLOB with GPS'), and ValidationBehavior
    /// (for example 'Mandatory'; empty leaves the field optional).
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    /// <param name="MobileType">MobileNAV control type to render, for example 'Signature' or 'Image'.</param>
    /// <param name="FunctionName">Name of the page function the control is bound to.</param>
    /// <param name="FunctionType">MobileNAV function type, for example 'BLOB' or 'BLOB with GPS'.</param>
    /// <param name="ValidationBehavior">MobileNAV validation behavior, for example 'Mandatory'.</param>
    procedure AddFunctionField(PageId: Integer; ControlName: Text[100]; Editable: Boolean; MobileType: Text[30]; FunctionName: Text[50]; FunctionType: Text[30]; ValidationBehavior: Text[50])
    begin
        // Standard placement, not MobileNAV's Additional default: a function control is a button,
        // and a button behind the card's additional fields section is one the device user never
        // finds. Use the Importance overload to place it elsewhere deliberately.
        this.AddFunctionField(
            PageId, ControlName, Editable, MobileType, FunctionName, FunctionType,
            ValidationBehavior, this.StandardImportanceTok);
    end;

    /// <summary>
    /// Adds a function-bound control and places it explicitly. Importance follows MobileNAV's
    /// vocabulary: 'None' places the control in the standard section, 'Additional' hides it
    /// behind the card's additional fields section (MobileNAV's own default for a new field).
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Editable">Whether the field can be edited.</param>
    /// <param name="MobileType">MobileNAV control type to render, for example 'Signature' or 'Image'.</param>
    /// <param name="FunctionName">Name of the page function the control is bound to.</param>
    /// <param name="FunctionType">MobileNAV function type, for example 'BLOB' or 'BLOB with GPS'.</param>
    /// <param name="ValidationBehavior">MobileNAV validation behavior, for example 'Mandatory'.</param>
    /// <param name="Importance">MobileNAV Importance option member name, for example 'None'.</param>
    procedure AddFunctionField(PageId: Integer; ControlName: Text[100]; Editable: Boolean; MobileType: Text[30]; FunctionName: Text[50]; FunctionType: Text[30]; ValidationBehavior: Text[50]; Importance: Text[30])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Function Field", PageId);
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine.Editable := Editable;
        this.TempConfigurationLine."Mobile Type" := MobileType;
        this.TempConfigurationLine."Function Name" := FunctionName;
        this.TempConfigurationLine."Function Type" := FunctionType;
        this.TempConfigurationLine."Validation Behavior" := ValidationBehavior;
        this.TempConfigurationLine.Importance := Importance;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Registers, refreshes, and publishes a MobileNAV page web service and sets its main menu
    /// action. MainMenuAction follows MobileNAV's vocabulary ('Create' opens the page straight
    /// onto a new record from the home tile, 'Open' opens the single existing record). When a
    /// Main row for the page already exists under a different service name, a second,
    /// independently configured service is created for this one.
    /// </summary>
    /// <param name="PageId">ID of the page to publish as a MobileNAV web service.</param>
    /// <param name="PreferredServiceName">Preferred name for the published web service.</param>
    /// <param name="MainMenuAction">MobileNAV main menu action, for example 'Create' or 'Open'.</param>
    procedure AddPublishedPage(PageId: Integer; PreferredServiceName: Text[100]; MainMenuAction: Text[30])
    begin
        this.AddPublishedPage(PageId, PreferredServiceName);
        this.TempConfigurationLine."Main Menu Action" := MainMenuAction;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Makes a field visible and editable and renders it as a barcode-scannable control.
    /// ValidationBehavior follows MobileNAV's vocabulary (for example 'ScanOrManualEntry';
    /// empty leaves the default behavior).
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="ValidationBehavior">MobileNAV validation behavior, for example 'ScanOrManualEntry'.</param>
    procedure AddScanField(PageId: Integer; ControlName: Text[100]; ValidationBehavior: Text[50])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Scan Field", PageId);
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine."Mobile Type" := 'Barcode';
        this.TempConfigurationLine."Validation Behavior" := ValidationBehavior;
        // See AddFunctionField: a scan control left at MobileNAV's Additional default is hidden.
        this.TempConfigurationLine.Importance := this.StandardImportanceTok;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Scopes a page to the signed-in device user through MobileNAV's "Mine" filter.
    ///
    /// For a page over a shared per-user table — one parameter row per user — every device
    /// would otherwise see every user's rows, and a card over such a page cannot resolve a
    /// unique record at all ("More than one item found"). The named control is marked as the
    /// page's user identity and a page-level Own filter is written over it, so each device
    /// sees exactly its own row. The control can stay hidden; it exists for the filter.
    /// </summary>
    /// <param name="PageId">ID of the page to scope.</param>
    /// <param name="UserIdControlName">Control on the page carrying the user id.</param>
    procedure AddUserScope(PageId: Integer; UserIdControlName: Text[100])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"User Scope", PageId);
        this.TempConfigurationLine."Control Name" := UserIdControlName;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Ensures a control is shown for MobileNAV's profiles, not just at service level.
    ///
    /// MobileNAV resolves visibility in two layers: the service-level field configuration is
    /// the default, but a row for the control in the device user's profile overrides it. Those
    /// profile rows are written by MobileNAV itself when it rebuilds a profile's page
    /// hierarchy, and a control it has not been told about is not visible there — so a field
    /// can be configured correctly and still be absent from the device screen. Declaring the
    /// field for the profile closes that gap, and re-declaring it is safe.
    ///
    /// Prefer the no-profile overload: it covers every profile, so the field does not depend on
    /// which profile an administrator happens to put a device user on.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    procedure AddToProfile(PageId: Integer; ControlName: Text[100])
    begin
        this.AddToProfile(PageId, ControlName, '', true, false);
    end;

    /// <summary>
    /// Ensures a control is shown for one named MobileNAV profile. See the single-argument
    /// overload for why a profile declaration is needed at all.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Profile">Profile to configure; empty configures every defined profile.</param>
    procedure AddToProfile(PageId: Integer; ControlName: Text[100]; Profile: Code[30])
    begin
        this.AddToProfile(PageId, ControlName, Profile, true, false);
    end;

    /// <summary>
    /// Sets a control's visibility and editability for a MobileNAV profile, or for every
    /// defined profile when no profile is named. See the single-argument overload for why a
    /// profile declaration is needed at all.
    /// </summary>
    /// <param name="PageId">ID of the page the field belongs to.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="Profile">Profile to configure; empty configures every defined profile.</param>
    /// <param name="Visible">Whether the field is shown for the profile.</param>
    /// <param name="Editable">Whether the field can be edited for the profile.</param>
    procedure AddToProfile(PageId: Integer; ControlName: Text[100]; Profile: Code[30]; Visible: Boolean; Editable: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Profile Field", PageId);
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine.Profile := Profile;
        this.TempConfigurationLine.Visible := Visible;
        this.TempConfigurationLine.Editable := Editable;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Turns the page into a staged wizard (staging behavior 'Always from scratch'). Declare
    /// this before any AddStage or AddStageField call for the same page; stages render in the
    /// order they are added.
    /// </summary>
    /// <param name="PageId">ID of the page to turn into a staged wizard.</param>
    /// <param name="AutoNext">Whether the wizard advances to the next stage automatically.</param>
    /// <param name="BackNextVisible">Whether the Back/Next navigation controls are shown.</param>
    procedure EnableStaging(PageId: Integer; AutoNext: Boolean; BackNextVisible: Boolean)
    begin
        this.EnableStaging(PageId, AutoNext, BackNextVisible, '');
    end;

    /// <summary>
    /// Turns the page into a staged wizard with an explicit staging behavior. StagingBehavior
    /// follows MobileNAV's vocabulary ('Always' restarts the wizard on every record,
    /// 'CreationOnly' stages only while a record is being created, 'PersistState' resumes a
    /// part-finished wizard; empty keeps 'Always'). Declare this before any AddStage or
    /// AddStageField call for the same page; stages render in the order they are added.
    /// </summary>
    /// <param name="PageId">ID of the page to turn into a staged wizard.</param>
    /// <param name="AutoNext">Whether the wizard advances to the next stage automatically.</param>
    /// <param name="BackNextVisible">Whether the Back/Next navigation controls are shown.</param>
    /// <param name="StagingBehavior">MobileNAV staging behavior vocabulary, for example 'PersistState'.</param>
    procedure EnableStaging(PageId: Integer; AutoNext: Boolean; BackNextVisible: Boolean; StagingBehavior: Text[30])
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Staging, PageId);
        this.TempConfigurationLine."Auto Next Stage" := AutoNext;
        this.TempConfigurationLine."Back-Next Visible" := BackNextVisible;
        this.TempConfigurationLine."Staging Behavior" := StagingBehavior;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Adds a wizard stage to a page declared with EnableStaging. The description becomes the
    /// stage's caption (a MobileNAV category record); fields not assigned to a stage via
    /// AddStageField stay hidden while that stage is active.
    /// </summary>
    /// <param name="PageId">ID of the page the stage belongs to.</param>
    /// <param name="StageId">Code identifying the stage.</param>
    /// <param name="Description">Caption shown for the stage.</param>
    procedure AddStage(PageId: Integer; StageId: Code[100]; Description: Text[250])
    begin
        this.AddStage(PageId, StageId, Description, false);
    end;

    /// <summary>
    /// Adds a wizard stage and optionally marks it as the stage the wizard restarts from
    /// (MobileNAV's 'Restart From Here'). When a later record starts the wizard again, the
    /// device re-enters at this stage and keeps what the earlier stages captured — for
    /// example a scanned bin retained while items in that bin are counted one after another.
    /// MobileNAV allows one restart-from stage per page, and it cannot be the first stage.
    /// </summary>
    /// <param name="PageId">ID of the page the stage belongs to.</param>
    /// <param name="StageId">Code identifying the stage.</param>
    /// <param name="Description">Caption shown for the stage.</param>
    /// <param name="RestartFrom">Whether the wizard restarts from this stage on a later record.</param>
    procedure AddStage(PageId: Integer; StageId: Code[100]; Description: Text[250]; RestartFrom: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::Stage, PageId);
        this.TempConfigurationLine."Stage Id" := StageId;
        this.TempConfigurationLine."Stage Description" := Description;
        this.TempConfigurationLine."Stage Restart From" := RestartFrom;
        this.TempConfigurationLine.Modify(false);
    end;

    /// <summary>
    /// Shows a field while the given stage is active. FieldEnabled=true lets the user edit or
    /// tap it; false shows it read-only for context. Declare the stage with AddStage first.
    /// </summary>
    /// <param name="PageId">ID of the page the stage belongs to.</param>
    /// <param name="StageId">Code identifying the stage the field is shown for.</param>
    /// <param name="ControlName">Name of the control on the page to configure.</param>
    /// <param name="FieldEnabled">Whether the field is editable while the stage is active.</param>
    procedure AddStageField(PageId: Integer; StageId: Code[100]; ControlName: Text[100]; FieldEnabled: Boolean)
    begin
        this.AddLine(Enum::"BJF MN Config Operation"::"Stage Field", PageId);
        this.TempConfigurationLine."Stage Id" := StageId;
        this.TempConfigurationLine."Control Name" := ControlName;
        this.TempConfigurationLine."Stage Enabled" := FieldEnabled;
        this.TempConfigurationLine.Modify(false);
    end;

    internal procedure GetLines(var Target: Record "BJF MN Config Line" temporary)
    begin
        Target.Copy(this.TempConfigurationLine, true);
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

    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        NextEntryNo: Integer;
        // 'None' is MobileNAV's own Importance option member (the standard card section),
        // not a Business Central page style, so PageStyle::None does not apply here.
#pragma warning disable LC0086
        StandardImportanceTok: Label 'None', Locked = true;
        ReportPageTypeTok: Label 'Report', Locked = true;
#pragma warning restore LC0086
}
