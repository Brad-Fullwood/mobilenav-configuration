# MobileNAV Configuration

A Business Central framework for declaring, applying and diagnosing MobileNAV configuration in AL.

You declare what a device shows in a few fluent lines: pages, fields, buttons, links, scan inputs, wizards. The framework knows the MobileNAV mechanics behind them: which service a control belongs to, how profile rows override service rows, when a companion web service is needed for a button to work, when a page needs Page Update, and how to scope a page to the signed-in device user. The same app diagnoses and repairs the MobileNAV and posting problems that surface as cryptic device errors.

## Quick start

1. Add **MobileNAV Configuration 4.1.0.0** to the consumer's `app.json` dependencies.
2. Implement `"BJF MN Config Provider"` in one codeunit and register it through an `enumextension` of `"BJF MN Config Provider"`:

```al
codeunit 50100 "CTO MN Config Provider" implements "BJF MN Config Provider"
{
    procedure GetId(): Code[50]
    begin
        exit('CONTOSO-MOBILE');
    end;

    procedure GetName(): Text[100]
    begin
        exit('Contoso MobileNAV');
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Configures Contoso item fields and the mobile lookup page.');
    end;

    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV Item")
            .Field('CTO Reference')
            .Field('CTO Region Code').Filterable();
    end;
}

enumextension 50100 "CTO MN Config Providers" extends "BJF MN Config Provider"
{
    value(50100; "Contoso MobileNAV")
    {
        Caption = 'Contoso MobileNAV';
        Implementation = "BJF MN Config Provider" = "CTO MN Config Provider";
    }
}
```

3. Apply it. An administrator opens **MobileNAV Configuration**, selects the provider and runs **Apply selected**, or the consumer's install codeunit calls it:

```al
local procedure ApplyMobileNAVConfiguration()
var
    ConfigurationApplication: Codeunit "BJF MN Config Application";
begin
    ConfigurationApplication.ApplyProvider(Enum::"BJF MN Config Provider"::"Contoso MobileNAV");
end;
```

An apply with no client attached (install, upgrade) writes the configuration but cannot finish handing it to devices; see [Applying, fingerprints and states](#applying-fingerprints-and-states).

4. Grant execute permission to the provider codeunit (and any event subscriber codeunits) and assign `"BJF MN Configuration"` to administrators.

There is no version to maintain: the framework fingerprints the definition's content and notices on its own when it changes. See [examples/ConsumerExtension.md](examples/ConsumerExtension.md) for a complete skeleton with a button handler and an action dialog.

## Fluent reference

Every method returns the builder, so a page reads as one sentence:

```al
Configuration.Page(Page::"MobileNAV WhseShipment")
    .Field('AUKPackingInstructions')
    .Field('Shipment Date').Filterable()
    .Button('AUKPrintDespatch');
```

A modifier refines the thing declared last: a control, a link or lookup, a page filter, a saved filter or a layout. A modifier that does not apply to that control's kind (`Filterable()` on a button, `Validation()` on a plain field) fails immediately, naming the modifier, the control and its kind.

### Page context

| Method | Does |
|---|---|
| `Page(PageId)` | Makes a page the context for what follows. Repeatable; calling it again for the same id continues that page. A MobileNAV page needs nothing more; a page of your own needs `Publish` or `PublishAsDialog`. |
| `Publish(ServiceName)` | Registers the page as a MobileNAV web service, gives it a tile and adds it to every profile's menu. Reuses an existing service if the page object already has one. |
| `PublishAsDialog(ServiceName)` | `Publish`, then marks the page as MobileNAV's action-dialog pattern (parameter fields plus a button) instead of a browsable page. |
| `Functions(CodeunitId, ServiceName)` | Gives a dialog page its own function codeunit, published as a web service under `ServiceName`. MobileNAV runs a dialog's buttons through a codeunit service, by default its own report-function codeunit, which knows nothing of your buttons. Each `Button` then names its procedure with `FunctionName`; the procedure's parameters are filled from the dialog's controls of the same name and it returns MobileNAV's function result text. Needs `PublishAsDialog` first. |
| `MainMenuAction(Action)` | What the page's tile does when tapped: `Create` (new record) or `Open` (the single existing one). Needs `Publish` or `PublishAsDialog` first. |
| `MineOnly(UserIdControlName)` | Scopes the page to the signed-in device user through MobileNAV's own "Mine" mechanism. Required for a per-user parameter table; without it every device lists every user's row and a card cannot resolve one. |
| `MenuCategory(CategoryCode)` | Puts the page's tile under a category heading. Declare the category with `Category`. |
| `Caption(LanguageCode, Text)` | Captions the page in one language, or the control declared last when one has been. MobileNAV keeps captions per language. |
| `MenuPicture(PngBase64)` | A picture for the tile, as PNG bytes in base64. Rewritten, with MobileNAV's version counter bumped, only when the bytes change. |
| `OrderAsDeclared()` | Shows the declared controls first, in declaration order; the page's other controls follow. |
| `Group(CategoryCode)` ... `EndGroup()` | The controls declared in between sit together on the card under the category's description. |
| `ExcludeFromProfile(Profile)`, `OnlineInProfile(Profile)`, `LookupOnlyInProfile(Profile)` | Per-profile page switches: keep the page out of a profile's menu, open it online rather than from offline data, or offer it only as a lookup. |

### Page settings

Each applies to the page in context, published or MobileNAV's own.

| Method | Does |
|---|---|
| `PageType(Shape)` | `ListCard`, `List`, `Card`, `Report` (a dialog), `Offline`, `OfflineCard`. |
| `Insertable()`, `Updatable()`, `Deletable()` | Lets the device create, change or delete records. `Editable()` on a control already makes the page updatable. |
| `ListLimit(MaxRecords)` | Caps how many records a list fetches. |
| `DefaultDrillDown(ControlName)` | The control whose related page opens when a record is tapped. |
| `OnOpen(PageFunction)`, `OnClose(PageFunction)` | MobileNAV page functions the device calls when the page opens or closes. |
| `HideButton(ToolbarButton)` | Removes a standard toolbar button (card refresh, list sort, list filter, ...). Repeatable. |
| `HideTitlePrefix(Prefix)` | Removes "New", the page name on a card, or the parent on a drill-down from the title. Repeatable. |
| `AutoRefresh(Moment)` | Reloads on open, on child update (card or list), or on update (list). Repeatable. |
| `AutoOpenSingleRecord()` | Opens the record straight away when a list holds exactly one. |
| `ShowFilterPanel()` | Shows the filter panel instead of the empty-list placeholder. |
| `ShowUnreadCount()` | Puts an unread-record badge on the tile. Not with an assign-to-me control. |
| `MineFilter(Views)`, `AssignToMe(Placement)` | The "assigned to me" views a list offers, and where the assign-to-me control sits. |
| `Style(PageStyleCode)` | A MobileNAV page style from its master data. |
| `FilterByParent()` | Filters a child page to the record that opened it. |
| `ChunkSize(Records)`, `CheckForChanges(Hours)` | Offline download batch size and change-polling interval. |

### Controls

| Method | Default | Notes |
|---|---|---|
| `Field(ControlName)` | Visible, read-only, standard section, every profile | |
| `Button(ControlName)` | Visible, editable, `MobileType` Normal, `FunctionType` Normal, function name derived, drawn as a menu entry | Runs Business Central code when tapped. See [Buttons end to end](#buttons-end-to-end). |
| `Link(ControlName, TargetPageId, TargetFilterField, SourceField)` | Visible, read-only | Opens another page filtered to the current record. The target becomes reachable from this page in every profile, so the button is drawn. A page of your own as the target needs its own `Page(...).Publish(...)`. |
| `Scan(ControlName)` | Visible, editable, `MobileType` Barcode | An input the device fills from its scanner. |
| `Lookup(ControlName, TargetPageId, CodeField, DescriptionField)` | Visible, editable | The device fills the field by picking a record from the target page; the picked code lands in the field and the description shows beside it. |
| `FlowFilter(FieldName)` | Visible as filter | One of the source table's flow filters (for example `'Date Filter'`) offered in the filter pane. Not a control of the page; the field name is the table's. |

### Modifiers

| Method | Applies to | Does |
|---|---|---|
| `Editable()` | Field, Button, Scan | Lets the device user change the value; also marks the page updatable as a whole. |
| `ReadOnly()` | Field, Button, Scan | Read-only (the default for `Field`). |
| `Hidden()` | Field | Keeps the field off the device at service level and in every profile. |
| `Filterable()` | Field | Offers the field in the device's filter pane. |
| `InMenu()` | Field | Draws the field as a menu entry instead of a card value. Rarely needed; `Button` and `Link` already produce menu entries. |
| `Importance(Level)` | Field, Button, Link, Scan | Where the device draws the control; see below. |
| `Validation(Behavior)` | Button, Scan | How the device validates a scanned or typed value before accepting it. |
| `MobileType(ControlType)` | Button | Renders the button as a special control: image capture, signature pad, file. Those three are drawn on the card itself rather than as a menu entry, because the Android client does not draw a capture control that sits in the menu. |
| `FunctionType(FunctionKind)` | Button | Shape of the function's result: field-control value, file, with or without device position. |
| `FunctionName(Name)` | Button | Overrides the MobileNAV dispatcher derived from the page's table, or names the procedure on a `Functions` codeunit. |
| `OnlyInProfile(Profile)` | Field, Button, Link, Scan | Limits the control to one profile instead of every profile. Repeatable. |
| `ExceptInProfile(Profile)` | Field, Button, Link, Scan | Shows the control in every profile except the named one. Repeatable. |
| `NotInProfiles()` | Field, Button, Link, Scan | Writes no profile rows at all. The control is not drawn until a profile row exists for it some other way. |

`Importance` values: `Standard` (the card's main section, MobileNAV's own `None`), `RequiredForInsert`, `Mandatory`, `Additional` (behind the card's "show more" section, where a device user never finds a button). Every control defaults to `Standard` explicitly, because MobileNAV itself defaults a new field to `Additional`.

### Control settings

| Method | Applies to | Does |
|---|---|---|
| `DecimalPlaces('2:2')` | Field | Business Central DecimalPlaces notation for a decimal. |
| `Quantity(Increment)` | Field | Draws the field as a quantity with plus/minus steppers. |
| `Increases(QuantityControlName)` | Field, Button, Scan | A scan into this control adds to the named quantity ("scan to add"). |
| `Range(Min, Max)` | Field | Bounds a numeric field. |
| `QuickEdit()` | Field | Editable from the list row without opening the card. One per page. |
| `PromotedOnGroupHeader()` | Field | Shown on a collapsed group header when the list is grouped. |
| `AllowSkip()` | Button, Scan | Lets the user skip a required scan. Needs `Validation()` first. |
| `RegEx(Pattern, Results)` | Field, Scan | Validates and parses the scanned or typed value; `Results` lists the capture groups that form the value. |
| `FieldCategory(Role)` | Field, Scan | The role MobileNAV's warehouse features key on: bin, lot, serial, item, quantity, ... |
| `HideDrillDown()` | Field | Keeps the field from opening its related page from the card. |
| `ValidateAlways()` | Field, Scan | Runs the field's validation even when the value did not change. |

Every page and control setting is checked by the doctor's **Page & Control Settings** check and rewritten by its fix.

### Link and lookup details

Each refines the `Link` or `Lookup` declared last. MobileNAV keeps them as rows under the relation; the framework rebuilds those rows on every apply.

| Method | Applies to | Does |
|---|---|---|
| `Filter(TargetField, SourceField)` | Link, Lookup | The target's field must equal this page's field. A `Link` already has one from its own arguments; repeat for more. |
| `FilterValue(TargetField, Value)` | Link, Lookup | The target's field must equal a fixed value. |
| `FilterExpression(TargetField, FilterText)` | Link, Lookup | The target's field must match a Business Central filter expression. |
| `OnlyWhen(SourceField, Value)` | Link, Lookup | Offered only while this page's field holds the value. |
| `RefreshOnOpen()` | Link, Lookup | Reloads the target's data when it opens. |
| `MultiSelect()` | Lookup | Several records can be picked at once. |
| `AdditionalCode(SourceField, DestinationField)` | Lookup | Copies one more field of the picked record into this page. |
| `Propagate(What, DestinationField)` | Lookup | Shows the picked record's barcode or cached image on this page. |
| `ParentAction(ButtonControlName)` | Link, Lookup | Shows one of this page's buttons on the page the relation opens. |

### Page filters

| Method | Does |
|---|---|
| `PageFilter(ControlName, Comparison, Value)` | Filters the page's records by comparing the control with a fixed value. |
| `PageFilterExpression(ControlName, FilterText)` | Filters with a Business Central filter expression, for example `'<>0'`. |
| `Scope(FilterScope)` | Limits the page filter declared last to online or offline use; the default is both. |

`MineOnly` is a page filter too (MobileNAV's `Own` comparison); all of a page's filters are rewritten together.

### Saved filters

| Method | Does |
|---|---|
| `SavedFilter(Name)` | A named, ready-made filter the device offers on the list. |
| `Where(ControlName, Match, Criteria)` | One field the saved filter declared last filters on: begins with, whole word or contains. Repeatable. |
| `Mine()` | Only the device user's own records. |
| `AsMap()` | Shown on a map instead of a list. |

### Offline operations

| Method | Does |
|---|---|
| `Operation(Kind, SourceField, DestinationField)` | An operation over an offline page's records between two fields: transfer, sum, min, max, average, count, multiplication, adjustment. Declared after a control, it runs for that field; otherwise for the page. |
| `OperationValue(Kind, SourceField, Value)` | The same with a fixed value. |

### Dynamic layouts

A layout is a rule that changes the page's look while its conditions hold. Everything after `Layout` until the next `Layout`, control or page refines it.

| Method | Does |
|---|---|
| `Layout(Code, Description)` | Starts a rule. |
| `WhenValue(ControlName, Comparison, Value)`, `WhenField(ControlName, Comparison, OtherControlName)`, `WhenFilter(ControlName, FilterText)` | Conditions; all must hold. |
| `Disabled()` | Keeps the rule without running it. |
| `HidesField(ControlName)`, `LocksField(ControlName)`, `LocksPage()` | Hide a control, make it read-only, or make the whole page read-only. |
| `CaptionsField(ControlName, CategoryCode)` | Captions a control with a category's description. |
| `CaptionColor(ControlName, Color)`, `ValueColor(ControlName, Color)`, `AreaColor(Area, Color)` | Color a control's caption or value, or a part of the row or card, with a color from MobileNAV's color setup. |
| `RowIcon(IconCode)`, `ToolbarIcon(IconCode)` | Show an icon from MobileNAV's icon set on the row or in the toolbar. |
| `HidesStage(StageId)`, `ValidatesStage(StageId)`, `ValidatesField(ControlName)` | Skip a wizard stage, or mark a stage or control validated. |

### Master data

Declared without a page context.

| Method | Does |
|---|---|
| `Category(Code, Description)` | A MobileNAV category: a menu heading (`MenuCategory`) and a field group caption (`Group`). |
| `CategoryTranslation(Code, LanguageCode, Description)` | The category's description in one language. |
| `Profile(Code, Description)` | A MobileNAV profile, the menu and visibility set a device user logs in against. Assigning users to it stays with the administrator. |

### Wizard

| Method | Does |
|---|---|
| `Wizard()` | Turns the page into a staged wizard. Restarts on every record by default. |
| `AutoNext()` | Advances to the next stage automatically once a stage is complete. |
| `HideBackNext()` | Hides the Back/Next controls; pair with `AutoNext()` for a scan-driven flow. |
| `Behavior(StagingBehavior)` | `Always` (restart every record), `CreationOnly`, or `PersistState` (resume a part-finished wizard). |
| `Stage(StageId, Description)` | Adds the next stage, in declaration order. `StageId` is a MobileNAV category code, at most 20 characters. |
| `RestartsHere()` | Marks the stage declared last as the one a later record resumes at, keeping what earlier stages captured. One per page, never the first stage. |
| `Show(ControlName)` | Shows a field editable while the stage declared last is active. |
| `ShowReadOnly(ControlName)` | Shows a field read-only, for context, while the stage declared last is active. |

Fields not shown by the active stage stay hidden while that stage runs.

## Buttons end to end

A device button needs three pieces.

**Declare it:**

```al
Configuration.Page(Page::"MobileNAV WhseShipment")
    .Button('AUKPrintDespatch');
```

**For a page of your own, add the one-line web-service wrapper.** MobileNAV's SOAP transport calls a page's functions through a companion codeunit web service registered under the page's own service name, resolving to MobileNAV's `"MobileNAV Page Functions"` codeunit. The framework registers that companion. The page still needs a `[ServiceEnabled]` procedure for the call to land on, and its name must be the dispatcher MobileNAV's Page Functions codeunit has for the page's source table. MobileNAV's own pages already have theirs. The body is always the same line:

```al
[ServiceEnabled]
procedure MNTrackSpecExtFunc(PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
var
    FunctionRouter: Codeunit "BJF MN Function Router";
begin
    exit(FunctionRouter.Execute(Rec, PageName, FieldName, DeviceID));
end;
```

Without the wrapper the button renders, but every tap dies on the device with `Method "…" is invalid!` before any request reaches Business Central.

The table to dispatcher mapping, which the framework consults when a button is declared without `FunctionName()`:

| Table | Dispatcher | Table | Dispatcher |
|---|---|---|---|
| Sales Header | `SalesHeaderExtFunc` | Item Journal Line | `ItemJrnlLineExtFunc` |
| Sales Line | `SalesLineExtFunc` | Production Order | `ProdOrderExtFunc` |
| Service Item Line | `ServiceTaskExtFunc` | Prod. Order Line | `ProdOrderLineExtFunc` |
| Service Line | `ServiceLineExtFunc` | Purchase Header | `PurchHeaderExtFunc` |
| Item | `ItemExtFunc` | Purchase Line | `PurchLineExtFunc` |
| Contact | `ContactExtFunc` | Profile Questionnaire Line | `ProfQuestLineExtFunc` |
| Return Receipt Header | `SalesReturnReceiptExtFunc` | Whse. Worksheet Line | `WhseWrkshLineExtFunc` |
| Sales Shipment Header | `SalesShipmentExtFunc` | Warehouse Journal Line | `WhseJrnlLineExtFunc` |
| Sales Invoice Header | `SalesInvoiceExtFunc` | MobileNAV Tracking Spec. | `MNTrackSpecExtFunc` |
| Sales Cr.Memo Header | `SalesCrMemoExtFunc` | MobileNAV Temporary Data | `MNTempDataExtFunc` |
| Job | `JobExtFunc` | Interaction Log Entry | `MNInteractionLEExtFunc` |
| Warehouse Activity Header | `WhseActHdrExtFunc` | Assembly Header | `MNAssemblyOrderExtFunc` |
| Warehouse Activity Line | `WhseActLineExtFunc` | Assembly Line | `MNAssemblyLineExtFunc` |
| Approval Entry | `ApprovalEntryExtFunc` | Warehouse Request | `WhseRequestExtFunc` |
| Job Journal Batch | `JobJournalBatchExtFunc` | Warehouse Journal Batch | `WhseJrnlBatchExtFunc` |
| Job Journal Line | `JobJournalLineExtFunc` | Posted Whse. Shipment Header | `PostedWhseShipmentExtFunc` |
| Warehouse Receipt Header | `WhseReceiptHdrExtFunc` | Service Item | `ServiceItemExtFunc` |
| Warehouse Receipt Line | `WhseReceiptLineExtFunc` | Transfer Header | `TransferHdrExtFunc` |
| Warehouse Shipment Header | `WhseShpmtHdrExtFunc` | Transfer Line | `TransferLineExtFunc` |
| Warehouse Shipment Line | `WhseShpmtLineExtFunc` | Item Journal Batch | `ItemJrnlBatchExtFunc` |

A table not on this list needs an explicit `FunctionName()`; `Button()` without one on such a table fails at apply time, naming the control and table.

**Handle the tap.** Subscribe once to `"BJF MN Function Router"`'s `OnPageFunction`, filtering on the page id and control name, instead of one subscriber per MobileNAV table event:

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Function Router", OnPageFunction, '', false, false)]
local procedure OnPageFunction(PageId: Integer; ControlName: Text[75]; FunctionRecord: RecordRef)
var
    WarehouseShipmentHeader: Record "Warehouse Shipment Header";
begin
    if (PageId <> Page::"MobileNAV WhseShipment") or (ControlName <> 'AUKPrintDespatch') then
        exit;
    FunctionRecord.SetTable(WarehouseShipmentHeader);
    // ... do the work ...
end;
```

`FunctionRecord.SetTable(YourRecord)` gives you the tapped record typed. `GetServiceName(PageId)` on the same codeunit looks up the MobileNAV service name a page is registered under, for the rare case something still needs it by name.

## Profiles are automatic

MobileNAV resolves a control's visibility in two layers: the service-level configuration is the default, but a row for the control in the device user's profile overrides it outright. MobileNAV writes those profile rows itself whenever it rebuilds a profile's page hierarchy, and a control it has never been told about there is not visible, however correct the service-level row is. So every `Field`, `Button`, `Link` and `Scan` writes its own profile rows, for every defined profile, using its own visibility and editability.

Three opt-outs, when a control should not follow that default:

- **`OnlyInProfile(Profile)`** shows the control in one profile instead of every profile. Repeat for several.
- **`ExceptInProfile(Profile)`** shows it in every profile except the named one. Repeat for several.
- **`NotInProfiles()`** writes no profile rows at all.

A `Publish`ed page is added to every profile's menu the same way, and a `Link`'s target page is made reachable as a child of the page the link sits on: a page or button MobileNAV has not been told belongs to a profile does not appear there.

## Applying, fingerprints and states

**MobileNAV Configuration** shows every registered provider in one of three states:

- **Not Applied**: no successful application is recorded.
- **Applied**: the applied content hash matches the provider's current definition.
- **Outdated**: the definition's content hash no longer matches what was applied, an administrator ran **Mark selected outdated**, or the last apply ran without a client attached (a device handover is pending).

The hash fingerprints the definition's content, canonically ordered, so reordering declarations is not a change while adding, removing or altering one is. No MobileNAV row is written until the complete definition, rebuilt from scratch, has passed validation.

**Device handover pending.** MobileNAV only carries configuration through to devices for changes made inside its "construction window", and finishing that handover (rebuilding the profile hierarchy, regenerating the page templates devices render from, telling devices to reload) runs routines that can raise a confirmation dialog. Install and upgrade codeunits have no client to answer one, so an apply without a GUI writes the full configuration, skips the handover and records the provider as outdated. Apply the same provider again from the administration page, where a client is available.

**The delegated-admin dialog.** Publishing a page's web service and registering its function companion each write to Tenant Web Service. The first time either happens for a service name, the platform may ask for a delegated-admin or API-access confirmation, so applying a provider that publishes a new page with buttons can raise the dialog twice in one apply. Answer Yes both times.

**Export live snapshot** on the same page downloads every MobileNAV row the selected provider's configuration touches, for diffing between environments or versions.

## Doctor and diagnostics

**MobileNAV Doctor** (Administration) is the single place to check and repair MobileNAV setup:

- **Run config checks** compares every provider's declaration with MobileNAV's live data: **Services & Web Services** (page, companion and dialog function-codeunit registration), **Fields & Importance** (controls hidden at Additional, rows that contradict the declaration), **Profiles** (missing page, parent and field rows), **Relations & Page Rules** (lookup bindings on links, missing `Own` scope, editable pages without Page Update), **Page & Control Settings** (every property verb), **Wizards** (staging switches, stage rows, stage masks), **Links & Lookups** (relation rows and their filters, conditions, additional code fields, propagated fields and parent actions), **Filters & Operations** (page filters, flow filters, saved filters, offline operations), **Groups & Order**, **Dynamic Layouts**, **Categories & Profiles** (with per-profile page switches), **Captions & Pictures** and **Apply State** (providers outdated or with a pending device handover). Every finding of these checks carries a fix that rewrites the rows from the declaration.
- **Run all diagnostics** adds the general checks below and every check other extensions register in `"BJF Diagnostic Check Type"`.

Findings show a **Severity** (Blocker, Warning, Info), the **Check** that produced them and a message. **Apply Fix** dispatches to the owning check's `ApplyFix` for any finding recorded with a fix, then re-runs every check; **Open Related Record** jumps to the record the finding is about.

### General MobileNAV checks

| Check | Catches |
|---|---|
| **Movement Journals** | MobileNAV User Setup without a Movement Journal Name; the batch missing on a Transfer-type template; the batch lacking a No. Series, which makes Move/Split Package fail with "Document No. must have a value". The fix assigns an `MNMOVE` series, creating it if needed. |
| **Item Tracking Codes** | "Package Info. Inb./Outb. Must Exist" enabled without the create-on-posting workaround (breaks Split/Move Package); "Package Transfer Tracking" disabled. |
| **Leftover Journal Lines** | Lines stuck in a MobileNAV movement batch (a Blocker when Bin or New Bin Code is missing at a bin-mandatory location, since Move Package posts the whole batch); stale lines in the shared output batch left by an abandoned card or failed posting (lines under an hour old are skipped, they may belong to an in-flight wizard). The fix deletes the line with its item tracking. |
| **Page Relations** | A relation or list-to-card reference pointing at a page with no Main configuration row. MobileNAV's profile-hierarchy rebuild resolves every such reference with a direct Get and aborts the entire rebuild on the first that fails, reported against the owning page rather than the missing one, so no configuration reaches any device until it is cleared. The fix deletes the relation with its filters, or clears the related page. |

### Opt-in posting workarounds

Both are off by default; enable only where the underlying gap bites.

- **Create Package Info. on Posting** (Item Tracking Code Card). Standard BC has "Create SN/Lot No. Info on Posting" but no package equivalent. With "Package Info. Inb./Outb. Must Exist" on, a reclass to a freshly generated package number (MobileNAV Split Package) fails because BC hard-gets Package No. Information for the new number. The workaround creates the missing record for both numbers before the check runs. Remove it once Microsoft ships the standard toggle.
- **Move Posts Only Its Own Lines** (Inventory Setup). `MUL WMS PageFunctions.MovePackage2` posts the whole movement batch instead of the lines it created, so any stale line blocks or silently co-posts with every Move Package. Every item journal line is stamped with its creating session; when enabled, non-interactive postings of a MobileNAV movement batch are narrowed to the current session's lines. Interactive posting and callers that already scope their lines are untouched. Remove once MultiSoft fixes `MovePackage2`.

### Contributing a check from another extension

Implement `"BJF Diagnostic Check"` (`RunCheck` records findings through `Finding.Add` and `Finding.AddWithFix`; `ApplyFix` repairs one, or raises an error when the check has no automatic fix) and register it with an `enumextension` of `"BJF Diagnostic Check Type"`. Values 100 to 199 are reserved for satellite apps; [MobileNAV Configuration WMS](../MobileNAV%20Configuration%20WMS/README.md) is one.

## Coverage

What the MobileNAV administration pages can configure, and how this framework covers it. Everything in the first group is declared in code, applied, checked by the doctor and repaired by its fix.

| Administration page | Covered by |
|---|---|
| Page Setup: page type, menu action, insert/update/delete, list limit, default drill-down, on-open and on-close functions, toolbar buttons, title prefixes, auto refresh, filter panel, unread count, mine filter, assign-to-me, page style, filter by parent, chunk size, check for changes, menu category, menu picture | `Publish`, `PublishAsDialog`, `MainMenuAction` and the page settings verbs; `MenuCategory`; `MenuPicture` |
| Field Setup: visibility, editability, importance, visible as filter, display in menu, mobile type, function name and type, validation behavior, allow skip, decimal places, quantity increment and field to increase, min and max, quick edit, promoted on group header, field category, hide drill-down, validate if not changed, regular expressions, groups, order | `Field`, `Button`, `Scan`, `Lookup` and their modifiers; the control settings verbs; `Group`, `OrderAsDeclared` |
| Relation Setup, Filter Setup, Condition Setup, Add. Code Field Setup, Propagated Field Setup, parent actions | `Link`, `Lookup` and the link and lookup details |
| PageFilter Setup, FlowFilter Setup | `PageFilter`, `PageFilterExpression`, `Scope`, `MineOnly`, `FlowFilter` |
| Saved Filter Card | `SavedFilter`, `Where`, `Mine`, `AsMap` |
| Operation Setup | `Operation`, `OperationValue` |
| Stage Configurator, Page Stage List | `Wizard`, `Stage`, `Show`, `ShowReadOnly`, `RestartsHere`, `AutoNext`, `HideBackNext`, `Behavior` |
| Dynamic Layout Setup with its conditions, actions and action lines | `Layout` and the layout verbs |
| Categories, Category Translations, Profiles | `Category`, `CategoryTranslation`, `Profile` |
| Main Menu Editor, Profiled Page Editor, Profiled Field List | Automatic profile rows for every control and published page; `OnlyInProfile`, `ExceptInProfile`, `NotInProfiles`; `ExcludeFromProfile`, `OnlineInProfile`, `LookupOnlyInProfile` |
| Caption translations | `Caption` |
| Web services and function companions | `Publish`, `Functions`, automatic companion registration |

Left to the administrator, on purpose:

| Administration page | Why |
|---|---|
| User Setup, No. Series Setup, User Key Selection, per-user flow filter values | Per-user data, not configuration. |
| Offline JavaScript templates, HTML and ZPL print templates | Binary assets edited in their own tools; import them on the Page Setup page. |
| Icon and color setup, fonts, general setup | Environment-wide look and connection settings, one per tenant. |
| Menu position of a page within a profile | MobileNAV renumbers positions per profile from its editor; a declared position would fight it. |
| Line format builder (card cell formats) | An expression grammar of MobileNAV's own; the field order and groups cover the common layout needs. |
| Report-type pages' parameter binding | Dialog pages are covered through `PublishAsDialog` and `Functions`; report parameter mapping is not. |

## The MobileNAV rules the framework encodes

1. A control's **Importance** defaults to `Additional` in MobileNAV, which hides it behind the card's "show more" section. The framework writes `Standard` (MobileNAV's `None`) explicitly unless told otherwise.
2. **Profile rows override service rows.** A field configured perfectly at service level is still invisible on a device whose profile has no row for it.
3. A page needs a profile **Page** row (to appear at all, with a tile) and, for anything that links to it, a profile **Parent Page** row (to be reachable from the linking page).
4. A relation with `RelatedPgCodeFldName` set becomes a **lookup binding**, not a button. The framework leaves it unset so a `Link` renders as the action that opens the target page.
5. **Page Update** on a page's Main row gates whether the device may write anything back; an `Editable` field on a page with Page Update off is drawn read-only.
6. A page over a **per-user table** needs the `Own` filter comparison over a control marked `MobileType` `UserID`. MobileNAV replaces `Own` with an equality against the signed-in user at config-build time.
7. A button's SOAP call needs a **companion codeunit web service** registered under the page's own service name, resolving to `"MobileNAV Page Functions"`; without it the tap fails on the device before any request is made.
8. A page's function procedure needs `[ServiceEnabled]`, and its **name must be the dispatcher** MobileNAV's Page Functions codeunit has for the page's source table.
9. MobileNAV allows **one service per page object**; a second service name over a page that already has one does not survive the next metadata refresh.
10. Configuration changes reach devices **only** through MobileNAV's construction window plus a page-hierarchy rebuild and an enforced major config change.
11. A wizard **stage id** is a category code, at most 20 characters.
12. A stage marked `RestartsHere` can never be the **first** stage of a wizard.

## Build

The app targets Business Central 26 (`runtime 16.0`) and MobileNAV 11 or later, with object ids 77760 to 77799. Put compatible Microsoft and `MULTISOFT KFT_MobileNAV` symbol packages in `.alpackages`, then compile with the AL extension or `alc`:

```sh
alc /project:. /packagecachepath:.alpackages /out:build/MobileNAV-Configuration.app
```

The repository does not include proprietary MobileNAV or Microsoft symbol packages.
