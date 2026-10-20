# MobileNAV Configuration

A Business Central framework for declaring, applying and diagnosing MobileNAV configuration in AL.

You declare what a device shows in a few fluent lines: pages, fields, buttons, links, scan inputs, wizards. The framework knows the MobileNAV mechanics behind them: which service a control belongs to, how profile rows override service rows, when a companion web service is needed for a button to work, when a page needs Page Update, and how to scope a page to the signed-in device user. The same app diagnoses and repairs the MobileNAV and posting problems that surface as cryptic device errors.

## Quick start

1. Add **MobileNAV Configuration 4.5.1.0** to the consumer's `app.json` dependencies. The framework uses namespaces, so the consumer needs `runtime` 12.0 or later.
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

There is no version to maintain: the framework fingerprints the definition's content and notices on its own when it changes. The [MobileNAV Configuration Example](../MobileNAV%20Configuration%20Example/README.md) app is a complete provider to read and copy: fields, buttons with their handlers, a page of your own, a dialog, a field control, the install codeunit and the permission set.

A provider can be checked in a unit test with no MobileNAV data: "BJF MN Provider Assert" runs the validator against page metadata. The Example README's "Test your provider" section shows the three lines.

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
| `PageFunctions(CodeunitId)` | Gives a non-dialog page a custom same-name companion codeunit instead of the standard route (see [Buttons end to end](#buttons-end-to-end)): a page published with `Publish`, or one of MobileNAV's own pages without `Publish`. MobileNAV registers it unpublished, matching its standard page-function transport. Each `Button` must name its record-bound procedure with `FunctionName`. On a MobileNAV page it changes only the companion. The page keeps its menu and profile setup. |
| `MainMenuAction(Action)` | What the page's tile does when tapped: `Create` (new record) or `Open` (the single existing one). Needs `Publish` or `PublishAsDialog` first. |
| `MineOnly(UserIdControlName)` | Scopes the page to the signed-in device user through MobileNAV's own "Mine" mechanism. Required for a per-user parameter table; without it every device lists every user's row and a card cannot resolve one. |
| `MenuCategory(CategoryCode)` | Puts the page's tile under a category heading. Declare the category with `Category`. |
| `Caption(LanguageCode, Text)` | Captions the page in one language, or the control declared last when one has been. MobileNAV keeps captions per language. |
| `Control(ControlName)` | Selects a control declared earlier on this page as the target of the modifiers that follow, for example a `Caption` written by `mnconfig.py captions`. |
| `TranslatedCaptions()` | Captions the page, or the control declared last, in every MobileNAV language from your own translations. The framework raises `OnGetTranslatedCaption` once per supported language at apply time and your subscriber answers with a Label, so the app's XLIFF files are the single source. See [Captions](#captions). |
| `MenuPicture(PngBase64)` | A picture for the tile, as PNG bytes in base64. Rewritten, with MobileNAV's version counter bumped, only when the bytes change. |
| `OrderAsDeclared()` | Shows the declared controls first, in declaration order; the page's other controls follow. |
| `Group(CategoryCode)` ... `EndGroup()` | The controls declared in between sit together on the card under the category's description. |
| `ExcludeFromProfile(Profile)`, `OnlineInProfile(Profile)`, `LookupOnlyInProfile(Profile)` | Per-profile page switches: keep the page out of a profile's menu, open it online rather than from offline data, or offer it only as a lookup. |
| `MenuCategoryInProfile(Profile, Category)` | Files the page's tile under a category in one profile, leaving the category the other profiles give it alone. Use it on a MobileNAV page whose own profiles rely on the category it already has. |

### Page settings

Each applies to the page in context, published or MobileNAV's own.

| Method | Does |
|---|---|
| `PageType(Shape)` | `ListCard`, `List`, `Card`, `Report` (a dialog), `Offline`, `OfflineCard`. |
| `Insertable()`, `Updatable()`, `Deletable()` | Lets the device create, change or delete records. `Editable()` on a control already makes the page updatable. |
| `ShowInMenu()` | Gives a published page a tile on the device home menu. Pages without it are reached only through a `Link` (child rows, adapters); MobileNAV would otherwise tile every published page, and a Card would show as "New ...". The device menu follows the profile Page row's own Display in Menu flag (not the service-level one), and MobileNAV drops a Page row that is neither on the menu nor linked, so a page without `ShowInMenu()` must have a `Link` from another page; the apply refuses otherwise. Such a page gets a Page row only in the profiles that carry one of its parent pages and is removed from the others, where nothing could open it. The Doctor reports drift on both flags and a row left in a profile without a parent. |
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
| `Lookup(ControlName, TargetPageId, CodeField, DescriptionField)` | Visible, editable | The device fills the field by picking a record from the target page; the picked code lands in the field and the description shows beside it. A lookup can also carry `Validation`, `MobileType` and `RegEx`, so the device can scan into it as well, see [Link and lookup details](#link-and-lookup-details). |
| `FlowFilter(FieldName)` | Visible as filter | One of the source table's flow filters (for example `'Date Filter'`) offered in the filter pane. Not a control of the page; the field name is the table's. |
| `FieldControl(ControlName)` | Hidden, editable, `MobileType` FieldControl | MobileNAV's field-control channel, which carries dialogs and refresh directives to the device and returns the answer through the field's OnValidate. MobileNAV's own pages ship with one. A page of your own, or a page extension that adds one, needs it declared or the device never shows the dialog. Wire the control to "BJF MN Field Control", see [Field control](#field-control). |

### Modifiers

| Method | Applies to | Does |
|---|---|---|
| `Editable()` | Field, Button, Scan | Lets the device user change the value; also marks the page updatable as a whole. |
| `ReadOnly()` | Field, Button, Scan | Read-only (the default for `Field`). |
| `Hidden()` | Field | Keeps the field off the device at service level and in every profile. |
| `Filterable()` | Field | Offers the field in the device's filter pane. |
| `InMenu()` | Field | Draws the field as a menu entry instead of a card value. Rarely needed; `Button` and `Link` already produce menu entries. |
| `Importance(Level)` | Field, Button, Link, Scan | Where the device draws the control; see below. |
| `Validation(Behavior)` | Button, Scan, Lookup | How the device validates a scanned or typed value before accepting it. |
| `MobileType(ControlType)` | Button, Lookup | Renders the button as a special control: image capture, signature pad, file. Those three are drawn on the card itself rather than as a menu entry, because the Android client does not draw a capture control that sits in the menu. On a lookup it sets the field's mobile type, for example `Barcode`. |
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
| `AllowSkip()` | Button, Scan, Lookup | Lets the user skip a required scan. Needs `Validation()` first. |
| `RegEx(Pattern, Results)` | Field, Scan, Lookup | Validates and parses the scanned or typed value; `Results` lists the capture groups that form the value. |
| `NoRegEx()` | Field, Scan, Lookup | Clears the control's pattern, its RegEx Results and the inherited flag. A control filled from another control's pattern reaches the device as Normal, with no scan icon, even when it is declared as a scan; WMS MobileNAV does this to Serial No. on warehouse pick lines. |
| `FieldCategory(Role)` | Field, Scan | The role MobileNAV's warehouse features key on: bin, lot, serial, item, quantity, ... |
| `HideDrillDown()` | Field | Keeps the field from opening its related page from the card. |
| `ValidateAlways()` | Field, Scan | Runs the field's validation even when the value did not change. |

Every page and control setting is checked by the doctor's **Page & Control Settings** check and rewritten by its fix. A plain field's mobile type (`Quantity`, `FieldControl`) is written by the apply and compared by the **Config Fields** check; a `Field` without one leaves MobileNAV's own type alone.

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

From 4.9.0.0 a lookup can also take a scan. MobileNAV configures its own Bin_Code, Lot_No and Serial_No fields this way: one control with a validation behavior, a mobile type and a relation to the page the user picks from. Declare it as one `Lookup` with `Validation` and `MobileType`, and from 4.9.0.1 `RegEx`. Give a scanned lookup a `RegEx` as well: when a Barcode field has a lookup, the device collects the Barcode fields of the lookup's page as extra targets and asks the user which field takes the scan, and a field with its own pattern takes the scan itself. `RegEx('^(.*)$', '1')` accepts any value and keeps capture group 1 whole. Declaring `Scan` and `Lookup` on the same control stops the apply, because both write the same field row.

```al
Configuration.Page(Page::"MobileNAV WarehouseMovement L.")
    .Lookup('AzzBarcode', Page::"MobileNAV Item", 'No', 'Description')
        .Validation(Enum::"BJF MN Validation Behavior"::ScanOrManualEntry)
        .MobileType(Enum::"BJF MN Mobile Type"::Barcode)
        .RegEx('^(.*)$', '1')
        .Filter('No', 'Item_No');
```

The apply writes the mobile type, validation behavior, RegEx Text and RegEx Results to the lookup's field row after its relation. The doctor's **Page & Control Settings** check compares them with the live row and its fix rewrites them. A lookup without `Validation`, `MobileType` or `RegEx` leaves MobileNAV's own values alone.

### Page filters

| Method | Does |
|---|---|
| `PageFilter(ControlName, Comparison, Value)` | Filters the page's records by comparing the control with a fixed value. |
| `PageFilterExpression(ControlName, FilterText)` | Filters with a Business Central filter expression, for example `'<>0'`. |
| `Scope(FilterScope)` | Limits the page filter declared last to online or offline use; the default is both. |

`MineOnly` is a page filter too (MobileNAV's `Own` comparison). A page that declares any page filter owns all of them: the framework rewrites the page's filter rows from the declaration on every apply. The same holds for a page's saved filters and operations, and for a link's or lookup's detail rows.

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

### Line formats

What one line of a list row shows. Everything after `LineFormat` until `EndLineFormat` goes into the line, in order, and replaces what MobileNAV had for it.

| Method | Does |
|---|---|
| `LineFormat(LineNo)` | Opens a line: 1 and 2 are the first and second line of a list row (line 1 also heads the card), 3 to 8 the list cells Top/Left, Middle/Left, Bottom/Left, Top/Right, Middle/Right, Bottom/Right. |
| `Show(ControlName)` | Inside a line format, adds the control's value. Outside one it is the wizard verb. Inside `LineFormat` it adds a value to the line instead. |
| `ShowCaption(ControlName)` | Adds the control's caption. |
| `Separator(Text)` | Adds fixed text, at most 75 characters, without `[ ] { }`. |
| `EndLineFormat()` | Closes the line. |

### Captions

`Caption(LanguageCode, Text)` writes one caption for one language. `TranslatedCaptions()` writes one
caption for every language MobileNAV supports (the Supported Language rows in its master data). At
apply time the framework switches the global language to each supported language in turn and raises
the integration event `OnGetTranslatedCaption(PageId, ControlName, var Caption, var Handled)` on
"BJF MN Config Application". The consumer subscribes once and answers with its own Labels, so the
text comes from the app's XLIFF files and the provider holds no caption strings:

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Config Application", OnGetTranslatedCaption, '', false, false)]
local procedure "BJF MN Config Application_OnGetTranslatedCaption"(PageId: Integer; ControlName: Text; var Caption: Text; var Handled: Boolean)
begin
    if (PageId <> Page::"Example Stock Count") or (ControlName <> '') then
        exit;
    Caption := this.StockCountCaptionLbl;
    Handled := true;
end;
```

`ControlName` is empty for the page caption. A language the subscriber does not answer keeps MobileNAV's own caption. The Example's
`ExampleCaptions.Codeunit.al` shows the full subscriber and its German translation file.

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

**How a tap reaches Business Central.** The Android client calls the button's function name as an operation of the page's SOAP web service, with the record's key, the service name, the control name and the device id. Business Central adds operations to a page's SOAP service from the codeunit published under the same service name (the page's companion), and runs the procedure with the record bound to its `Key` parameter. The MobileNAV local test harness (`mobilenav-harness` in the Business Central tools repository) recorded these calls from client 12.1.0.27. A function the page's SOAP service does not have fails on the device with `Method "…" is invalid!`, and `mndevice.py wired` finds it before anyone taps. The framework registers the companion and fills in the function name:

- **MobileNAV Page Functions** for the 40 tables it has a dispatcher for (table below).
- **"BJF MN Table Functions"** for the 78 other tables that MobileNAV device pages show, such as Bin Content, Bin, Location, Customer and Item Ledger Entry. It has one procedure per table, generated from MobileNAV's symbols by `tools/generate_table_functions.py`, and each raises `OnPageFunction`.
- **Your codeunit** when the page declares `PageFunctions()`. Then each button names one of its record-bound procedures with `FunctionName()`.

So `Button()` works on any MobileNAV device page with nothing else to write. One customer's Extension 9 has run buttons on MobileNAV pages through companion codeunits this way since 2022, with no page wrapper.

**On a page of your own, keep the one-line web-service wrapper.** Earlier device tests showed taps failing with `Method "…" is invalid!` without it. The harness has not yet separated whether the page procedure or the companion supplies the SOAP operation on a page of your own, so keep both until it does. Its name must be the dispatcher for the page's source table. MobileNAV's own pages do not need one. The body is always the same line:

```al
[ServiceEnabled]
procedure MNTrackSpecExtFunc(PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
var
    FunctionRouter: Codeunit "BJF MN Function Router";
begin
    exit(FunctionRouter.Execute(Rec, PageName, FieldName, DeviceID));
end;
```

The tables MobileNAV Page Functions serves, and the dispatcher the framework uses when a button is declared without `FunctionName()`:

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

Any other table runs through "BJF MN Table Functions". A table that neither serves stops the apply with a message that names the control and the table, and suggests `PageFunctions()`.

**Checked function names.** A `FunctionName()` must be a procedure the companion has, or every tap fails on the device. The apply stops when MobileNAV Page Functions has no procedure of that name for the page's table, and lists the names it has (for example `WhseJrnlLineExtFunc` and its GPS and BLOB variants). On a "BJF MN Table Functions" page, leave `FunctionName()` out. The Doctor reports the same mismatch on rows written earlier. A name on a `PageFunctions()` or `Functions()` codeunit is not checked, because AL cannot list a codeunit's procedures.

**Companions another app owns.** When the page's companion web service already points at a different codeunit, the apply stops and names both codeunits, instead of failing on a TestField. Another app may rely on that registration, so the framework does not repoint it on its own. If that codeunit does not serve these buttons, apply the Doctor's fix, which repoints the service. If it does, declare `PageFunctions()` with it. The one exception is a companion pointing at MobileNAV Page Functions on a page it has no functions for, which "BJF MN Table Functions" replaces.

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

## Field control

Field control is how Business Central puts a dialog, a colour, a toast or a refresh in front of the device user, and how the user's answer comes back. It travels in a hidden field of mobile type FieldControl, declared with `FieldControl('FieldControl')`. MobileNAV's own pages that have one need nothing more. To add one to a page or page extension, wire it to `"BJF MN Field Control"` and handle its two events, filtered on the page id like `OnPageFunction`:

```al
pageextension 50100 "CTO MN Bin" extends "MobileNAV Bin"
{
    layout
    {
        addlast(Group)
        {
            field(FieldControl; FieldControlText)
            {
                ApplicationArea = All;
                Visible = false;

                trigger OnValidate()
                begin
                    FieldControl.Answer(Page::"MobileNAV Bin", Rec, FieldControlText);
                    if Rec.Find() then;
                end;
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        FieldControlText := FieldControl.Calculate(Page::"MobileNAV Bin", Rec);
    end;

    var
        FieldControl: Codeunit "BJF MN Field Control";
        FieldControlText: Text;
}
```

```al
[EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Field Control", OnCalculateFieldControl, '', false, false)]
local procedure OnCalculateFieldControl(PageId: Integer; SourceRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
var
    Bin: Record Bin;
begin
    if PageId <> Page::"MobileNAV Bin" then
        exit;
    SourceRecord.SetTable(Bin);
    if not Bin.Empty then
        FieldControlFactory.FcSetFirstLineColor(Bin, 0, 128, 0);
end;
```

`OnFieldControlAnswer` receives the device's answer to a dialog the same way. In a page extension, refer to the extension's variables without `this.`, which means the base page there.

## Profiles are automatic

MobileNAV resolves a control's visibility in two layers: the service-level configuration is the default, but a row for the control in the device user's profile overrides it outright. MobileNAV writes those profile rows itself whenever it rebuilds a profile's page hierarchy, and a control it has never been told about there is not visible, however correct the service-level row is. So every `Field`, `Button`, `Link` and `Scan` writes its own profile rows, for every defined profile, using its own visibility and editability.

Three opt-outs, when a control should not follow that default:

- **`OnlyInProfile(Profile)`** shows the control in one profile instead of every profile. Repeat for several.
- **`ExceptInProfile(Profile)`** shows it in every profile except the named one. Repeat for several.
- **`NotInProfiles()`** writes no profile rows at all.

A `Publish`ed page is added to every profile's menu the same way, and a `Link`'s target page is made reachable as a child of the page the link sits on: a page or button MobileNAV has not been told belongs to a profile does not appear there.

A page without `ShowInMenu()` is reached through its parents: the declared links, or else the relations MobileNAV already has to it. `Publish()` on one of MobileNAV's own pages without `ShowInMenu()` leaves its tiles and profile rows as the administrator set them. Taking them over would remove its tiles, and MobileNAV then deletes the root rows of other pages that hang off it. To give buttons on a MobileNAV page a codeunit of your own, declare `PageFunctions()` without `Publish()`.

## Applying, fingerprints and states

**MobileNAV Configuration** shows every registered provider in one of three states:

- **Not Applied**: no successful application is recorded.
- **Applied**: the applied content hash matches the provider's current definition.
- **Outdated**: the definition's content hash no longer matches what was applied, an administrator ran **Mark selected outdated**, or the last apply ran without a client attached (a device handover is pending).

The hash fingerprints the definition's content, canonically ordered, so reordering declarations is not a change while adding, removing or altering one is. No MobileNAV row is written until the complete definition, rebuilt from scratch, has passed validation.

**Device handover pending.** MobileNAV only carries configuration through to devices for changes made inside its "construction window", and finishing that handover (rebuilding the profile hierarchy, regenerating the page templates devices render from, telling devices to reload) runs routines that can raise a confirmation dialog. Install and upgrade codeunits have no client to answer one, so an apply without a GUI writes the full configuration, skips the handover and records the provider as outdated. Apply the same provider again from the administration page, where a client is available.

**MobileNAV not set up yet.** A company where MobileNAV's Setup Wizard has not imported the base
configuration has no page rows to declare against, and an apply fails. An install codeunit checks
`MobileNAVIsConfigured()` on "BJF MN Config Application" first and exits when it is false, so the
app installs and the provider stays Not Applied until the administrator runs the wizard and applies
it from the page. The Example's install codeunit and the files *New provider* writes do this.

**Applying from a script.** The API `api/bjf/mobilenav/v1.0/companies({id})/configProviders` lists the providers with their state; the bound actions `apply`, `markOutdated`, `runConfigChecks` and `runAllDiagnostics` do what the administration and Doctor pages do, and `diagnosticFindings` returns the findings (with `applyFix`). An API apply has no client, so it commits the configuration rows, then runs MobileNAV's device handover unattended; if MobileNAV refuses, the construction window is closed, the provider stays Outdated with the handover pending, and the action fails with MobileNAV's error. `sessions` lists the environment's active sessions and `stop` ends one, for an apply that fails because "a record in table ... is being updated in a transaction done by another session". MobileNAV asks a delegated administrator to confirm the device handover, which an API call cannot answer: run the API as a licensed user of the tenant. The command-line wrapper is `mnconfig.py` in the Business Central tools repository.

**Reading MobileNAV from a script.** Read-only API pages under the same route expose MobileNAV's own configuration and data per company, so an agent or script can inspect a device page without the administration screens:

| Entity set | Page | Source | Use it for |
|---|---|---|---|
| `serviceSetupLines` | 77793 | MobileNAV Service Setup | A page's field, relation, filter and stage rows: mobile type, importance, validation, stage mask, RegEx. |
| `profileSetupLines` | 77794 | MobileNAV Profile Setup | Which pages a profile carries, their tiles, categories and exclusions, parent links, field overrides, and which users have the profile. |
| `masterData` | 77795 | MobileNAV Master Data | Profiles, menu categories and the general setup row (device activation, configuration version). |
| `devices` | 77796 | MobileNAV License Setup | Registered devices and user licences with status and last login, when a device cannot log in. |
| `userSetups` | 77797 | MobileNAV User Setup | Per-user location, movement journal and worksheet, login mode. |
| `loginLogEntries` | 77798 | MobileNAV Login Log | The server side of device logins with timings. |
| `dynamicLayouts`, `dynamicLayoutConditions`, `dynamicLayoutActions`, `dynamicLayoutActionLines` | 77734 to 77737 | MobileNAV Dynamic Layout and its rows | A page's layout rules: conditions, actions and the controls they target. |
| `captionTranslations` | 77738 | MobileNAV CaptionML Admin. | Page and control captions per language. |
| `categoryTranslations` | 77739 | MobileNAV Category Translation | Menu category names per language. |

From 4.6.0.0 `serviceSetupLines` also exposes the page and control settings, field class, visible as filter, multi select, filter scope, saved filter and operation types, and three worked out names: the dialog's function codeunit, the page's companion codeunit and a flow filter's table field. `mnconfig.py reverse` reads all of it back as a provider codeunit, `screen` draws a provider's device pages as HTML, `new-provider` writes a provider, handler and page extensions into an app, and `captions` writes `Caption` calls from the app's XLIFF files. The `mobilenav-config` skill documents each.

Output spells a space in an option value as `_x0020_`; a `$filter` takes the plain caption (`profileType eq 'Parent Page'`). `mnconfig.py` wraps them as `fields`, `profile`, `masterdata`, `devices`, `users`, `loginlog` and `raw`.

**The delegated-admin dialog.** Publishing a page's web service and registering its function companion each write to Tenant Web Service. The first time either happens for a service name, the platform may ask for a delegated-admin or API-access confirmation, so applying a provider that publishes a new page with buttons can raise the dialog twice in one apply. Answer Yes both times.

**Preview an apply.** The bound action `preview` on `configProviders` shows what applying a provider would change, without changing it. The apply runs in full, including MobileNAV's own triggers and metadata refresh, inside a transaction that is then rolled back. Commits inside the apply are ignored and the device handover is skipped. `configPreviewLines` returns the result: one line per changed field, inserted or deleted record, and changed web service registration, or the error the apply would stop with. Rows are matched on their primary key, so rows MobileNAV deletes and inserts again during a refresh show only real differences. While it runs, the preview locks the MobileNAV rows it changes, as an apply does, so run it outside working hours in a live environment. `mnconfig.py preview <id>` prints it grouped by record. A page published for the first time is the one thing a preview cannot show in full: MobileNAV's metadata refresh reads the page's endpoint from another session, which does not see a web service that is not committed, so the preview stops with a field error for that page. Apply such a provider in a sandbox instead.

**Export live snapshot** on the same page downloads every MobileNAV row the selected provider's configuration touches, for diffing between environments or versions.

## Developer actions on the MobileNAV Configuration page

The page's **Develop** group holds the actions a developer uses before and after writing a provider.

**New provider.** Choose *New provider*. Enter the app's prefix, publisher, name, namespace and
first free object ID. Select the MobileNAV pages. For each page, select the fields the device shows
and mark them editable or filterable. Fields that are not on the page get a control in a page
extension. Add the device buttons with a caption each. Finish downloads a zip file with the provider
codeunit, enum extension, one page extension per page, a handler codeunit with a toast per button,
an install codeunit, a permission set, the app.json dependencies and a README.txt with the steps.
Check the group each page extension adds its controls to (Group on most pages, General on some).
The codeunit "BJF MN Scaffold Writer" renders the same files from code.

**Preview on device.** Select a provider and choose *Preview on device*. The page draws each
device page the provider declares as phone screens: the list with its rows, filters and saved
filters, the card with its importance sections, groups, scan inputs, lookups and menu, one card per
wizard stage, and the layout rules. The provider's definition is laid over MobileNAV's live Service
Setup rows, so new and changed controls are marked. Change the language to see the captions for
another MobileNAV language, and use *Download HTML* to save the drawing. From AL,
`"BJF MN Screen Renderer".Render(Provider, 'ENU')` returns the same HTML.
The page draws in the app's own control add-in, "BJF MN HTML Viewer", because Business Central
online does not permit Microsoft's WebPageViewer in a per-tenant extension.

**Device emulator.** The *MobileNAV Device Emulator* page draws a chosen user's device menu, lists, cards, lookups, buttons and edits from the configuration. See [Device emulator](#device-emulator) below for setup, the write gate and the API.

**Generate provider from pages.** Choose *Generate provider from pages*. Tick the MobileNAV pages
to restate and enter a provider id. The object id, object name and namespace are optional. You can
also include profile overrides, hidden fields of MobileNAV's own pages, and control captions.
*Download .al* saves `<ProviderId>.al`, which holds a provider codeunit and its enum extension. Rows
the builder cannot express appear as comments where they belong. Keep what your app owns and delete
the rest. The codeunit "BJF MN Provider Writer" does the same from AL: call `SetProvider`,
`SetScope`, then `Generate` or `Download`.

## Copying configuration between companies

MobileNAV keeps snapshots of the whole configuration on its **MobileNAV Configuration Handling** page (Config Snapshot List, page 42013165). From 4.5.1.0 three API pages under `api/bjf/mobilenav/v1.0/companies({id})` take, read and import them without a client, so a script can copy a configuration from one environment or company to another:

| Entity set | Page | Request | Does |
|---|---|---|---|
| `configSnapshots` | 77799 | GET | Lists the snapshots: `code`, `description`, `created`, `loaded`, `dirty`, `configHash`, `baseConfigVersion`, `baseConfig`, `parent`. |
| `configSnapshots` | 77799 | POST `{"description": "..."}` | Takes a snapshot of the current configuration, as **Take Snapshot** does, and returns it with its `code`. The description is optional. |
| `configSnapshotContents` | 77782 | GET `?$filter=code eq '...'` | One snapshot's configuration XML, base64 encoded, in `configXmlBase64`. The XML is returned only when the request selects exactly one snapshot, by id or by a filter on code. |
| `configImports` | 77783 | POST `{"configXmlBase64": "..."}` | Imports the XML as a custom configuration, as **Import Custom Configuration** does, and returns `backupSnapshotCode`, `importedSnapshotCode`, `configKind` (Full, Partial or Skin), `configDescription` and `baseConfigVersion`. |

Taking a snapshot and importing are POST requests that create a record: the request body carries the description or the XML, and the response is the created record with the codes the caller needs next. A bound action acts on a record that already exists and answers with that record. MobileNAV's own actions ask questions a call without a client cannot answer: Export Snapshot asks for a description, and Import Custom Configuration confirms the change and opens a file dialog. The framework calls the routines underneath them instead (`TakeSnapshot`, `ImportConfigFromStream` and `TakeSnapshotFromLastImported` in MobileNAV's Config Snapshot Func and Config Handling Func codeunits). A description given to `configSnapshots` is written into the XML's `ConfigInfo` element as well, so a company that imports it shows the same description.

Before an import changes anything, `configImports` takes a snapshot of the target's current configuration and commits it. If the import goes wrong, select that snapshot on the MobileNAV Configuration Handling page and run **Load Snapshot**. A failed import names the backup snapshot in its error. MobileNAV commits partway through an import, so a failure late in the import can leave the configuration partly replaced.

**What an import replaces.** MobileNAV's `PrepareDbForConfigImport` deletes these rows and the import loads them again from the XML:

- MobileNAV Service Setup, Svc. Setup Main, Dynamic Layout (with its conditions and actions), Offline Admin., Offline Admin. D., CaptionML Admin. and Line Format: every row.
- MobileNAV Master Data: every type except ConfigSnapshot and SuppLang. Profiles, categories, functions, colors, icons, styles, fonts, RegEx setup, test data and the general setup row are all replaced.
- MobileNAV Profile Setup rows of type Page, Field, Parent Page, Root Page, Saved Filter and Predefined Filter.

The general setup row is rebuilt from the XML: device activation, login timeout, offline cockpit, GPS tracking, list display limit, auto resume lock, login PIN generation, card payment provider, modern design and the configuration version come from the source. `FinalizeDbAfterConfigImport` then puts back the target's own connection and environment settings: server, instance, tenant, web service URL, SSL, authentication type, communication protocol, the Microsoft 365 app registration and client secret, the service user, push notification settings, debugging settings, the general RegEx field, picture cache size, the login configuration settings, Under Construction, the last known add-on version and background refresh logging. Any other general setup field, Testing Mode among them, starts from MobileNAV's defaults for a new row.

**What an import keeps.** Profile Setup rows of type User and Device, apart from User rows for a profile the imported configuration does not have. The MobileNAV User Setup table. User Key Selection rows, apart from those for pages the imported configuration does not have. Category translations, which the import adds to and updates. Licence and device rows, though the import clears each device user's cached user code and web service URL in the company. Configuration snapshots and supported languages.

**What else an import does.** It registers the web service and function companion of every imported page, refreshes each page's metadata from the target's page objects, and sets Configuration Changed on every user licence row, so devices download the new configuration at their next login. The target therefore needs the same apps installed as the source. It does not run MobileNAV's enforced major configuration change. Without a client, MobileNAV skips its comparison between the XML's fields and the target's page metadata, which a user in the client would be asked to confirm. A partial or skin configuration (`configKind` Partial or Skin) is not saved as a snapshot, and MobileNAV recommends running its configuration validation report after a partial one. The framework's own provider status is left as it was, so run the Doctor after an import and apply the providers it reports.

**What stops an import.** Both are checked before the backup is taken, so nothing changes:

- The caller is a delegated administrator. MobileNAV's import asks a delegated administrator to confirm (`InitializeImport` calls `CheckUserDelegatedAdmin`), which an API call cannot answer. Call the API as a licensed user of the tenant or as a Microsoft Entra application, as for an unattended apply.
- A device user is frozen. MobileNAV rejects every configuration change while one is.
- The caller lacks MobileNAV's own permission set. MobileNAV's snapshot code inserts the snapshot row itself, so `"BJF MN Configuration"` alone is not enough for `configSnapshots` and `configImports`: the caller also needs a MobileNAV permission set that writes MobileNAV Master Data.

`mnconfig.py` wraps these as `snapshots`, `snapshot-take`, `snapshot-export`, `config-import` and `config-copy`.

## Copying the MobileNAV licence between environments

MobileNAV keeps its licence in one row of the MobileNAV License Setup table, shared by all companies of an environment. The licence string is that row as base64 text, the same text **Change License** on MobileNAV's License Setup page takes. MobileNAV issues the licence for the Microsoft Entra tenant, so its string works in every environment of the same tenant, for example from production to a new sandbox.

Search for **MobileNAV Licence Transfer**, or choose **MobileNAV licence** on the MobileNAV Configuration page. The **MobileNAV Licence** page (77702) shows the licence id, this tenant's licence id, the licensed and assigned devices, the expiry date and the licence string to copy. **Install licence string** in the target environment asks for the string and installs it through MobileNAV's `SaveLicenseKey`. The installed string replaces the target's licence, and with it the number of licensed devices. A string issued for another tenant is refused and the target's licence stays as it was.

The `mobilenavLicences` API (page 77705, `api/bjf/mobilenav/v1.0/companies({id})/mobilenavLicences`) has one row with `licenceId`, `licensedDevices`, `assignedDevices`, `expiryDate` and `licenceString`. A GET returns the string. A POST with `{"licenceString": "..."}`, or a PATCH of `licenceString` on the row, installs it and answers with the new licence. Installing writes MobileNAV License Setup through MobileNAV's own code, so the caller needs a MobileNAV permission set that writes that table as well as `"BJF MN Configuration"`. `mnconfig.py` wraps the API as `licence` and `licence-copy`.

## Doctor and diagnostics

**MobileNAV Doctor** (Administration) is the single place to check and repair MobileNAV setup:

- **Run config checks** compares every provider's declaration with MobileNAV's live data: **Services & Web Services** (page, companion and dialog function-codeunit registration), **Fields & Importance** (controls hidden at Additional, rows that contradict the declaration), **Profiles** (missing page, parent and field rows), **Relations & Page Rules** (lookup bindings on links, missing `Own` scope, editable pages without Page Update), **Page & Control Settings** (every property verb), **Wizards** (staging switches, stage rows, stage masks), **Links & Lookups** (relation rows and their filters, conditions, additional code fields, propagated fields and parent actions), **Filters & Operations** (page filters, flow filters, saved filters, offline operations), **Groups & Order**, **Dynamic Layouts**, **Line Formats**, **Categories & Profiles** (with per-profile page switches), **Captions & Pictures** and **Apply State** (providers outdated or with a pending device handover). Every finding of these checks carries a fix that rewrites the rows from the declaration.
- **Run all diagnostics** adds the general checks below and every check other extensions register in `"BJF Diagnostic Check Type"`.

Findings show a **Severity** (Blocker, Warning, Info), the **Check** that produced them and a message. **Apply Fix** dispatches to the owning check's `ApplyFix` for any finding recorded with a fix, then re-runs every check; **Open Related Record** jumps to the record the finding is about.

### Nightly run and telemetry

The Doctor page has two actions. **Schedule nightly run** creates or updates a Job Queue Entry for codeunit "BJF MN Doctor Job", recurring every day at 02:00. **Run now** runs the same codeunit once. The job runs all diagnostics for the company, then logs one telemetry event per finding and one summary event per run. The events reach Application Insights when the environment has a connection string.

| Event id | Meaning | Custom dimensions |
|---|---|---|
| BJF-MN-0001 | One finding. Verbosity Warning for Blocker and Warning, Normal for Info | CheckType, Severity, Fixable, Message, Company |
| BJF-MN-0000 | One per run | Company, Findings, Blockers, Warnings, Infos, Fixable |

Findings per company and check over the last day:

```kusto
traces
| where timestamp > ago(1d)
| where customDimensions.eventId == 'BJF-MN-0001'
| extend Company = tostring(customDimensions.Company),
         CheckType = tostring(customDimensions.CheckType),
         Severity = tostring(customDimensions.Severity),
         Environment = tostring(customDimensions.environmentName),
         Tenant = tostring(customDimensions.aadTenantId)
| where Severity in ('Blocker', 'Warning')
| summarize Findings = count() by Tenant, Environment, Company, CheckType, Severity
| order by Tenant, Environment, Company, Severity asc
```

### General MobileNAV checks

| Check | Catches |
|---|---|
| **Leftover Journal Lines** | Stale lines in the shared output batch left by an abandoned card or failed posting (lines under an hour old are skipped, they may belong to an in-flight wizard). The fix deletes the line with its item tracking. |
| **Page Relations** | A relation or list-to-card reference pointing at a page with no Main configuration row. MobileNAV's profile-hierarchy rebuild resolves every such reference with a direct Get and aborts the entire rebuild on the first that fails, reported against the owning page rather than the missing one, so no configuration reaches any device until it is cleared. The fix deletes the relation with its filters, or clears the related page. |

### WMS MobileNAV checks and workarounds

The Movement Journals, Item Tracking Codes and Leftover Move Lines checks, and the opt-in posting workarounds for package tracking and Move Package, are in [MobileNAV Configuration WMS](../MobileNAV%20Configuration%20WMS/README.md). They need WMS MobileNAV, so they ship in that app.

### Contributing a check from another extension

Implement `"BJF Diagnostic Check"` (`RunCheck` records findings through `Finding.Add` and `Finding.AddWithFix`; `ApplyFix` repairs one, or raises an error when the check has no automatic fix) and register it with an `enumextension` of `"BJF Diagnostic Check Type"`. Use ordinals inside your own app's id range. [MobileNAV Configuration WMS](../MobileNAV%20Configuration%20WMS/README.md) is one such app, with 77740 to 77745.

## Device emulator

Page "BJF MN Device Emulator" draws the device menu, lists and cards for any user and profile, from MobileNAV's own configuration build. The build runs inside a rollback, so it uses no device login, writes no Login Log row and uses no licence.

### Reads

Lists and cards read the records in process, through the page's source table view. A list applies the user's sort, the page's predefined filters, the user's flow filters, the relation filters from the parent record, a saved filter, the filter panel and the search text. Dynamic layouts are evaluated in AL, in their Order, and the first layout that sets a property wins. The stage settings and the stage tokens of each field are also computed in AL. A lookup lists the related page with its predefined and flow filters and its sort. The parent relation, the saved filter and the filter panel do not apply to a lookup. Reads need no setup.

### Writes, buttons, scans, dialogs, pictures and signatures

These go to the tenant's own SOAP page service of the MobileNAV page, with a delegated token of the signed-in user. Page triggers and `[ServiceEnabled]` functions run on the service as they do for a device. The FieldControl commands in each answer drive the screen. Pictures and signatures use the `EXP` and `IMP` actions of the page function.

A new record opens in a form with empty inputs. The New button of a list opens one when the page allows inserts, and so does a menu tile whose main menu action is Create. A tile of a Report page opens its form too. When the list has a parent, each field that the parent's relation filter fixes to one value starts with that value. Save sends the values as `create`. The emulator runs SOAP `Create` on the page service, and the answer is the card of the new record.

A dialog page (page type Report) has no Save. Each of its buttons sends `dialogRun` with the values of the form and the function of the button. The function runs as a codeunit call on the function service: the OptionValues2 of the page's Main row, or `MobileNAVReport` when that is empty. A function answer comes from the `return_value` element. A procedure with no return value, such as a picture function with var parameters, answers with its output parameters as children of the result element, and the emulator reads them the same way. The answer's commands run, a file shows as a picture or a PDF and gets a download link, and an empty answer shows "Done.". The form stays open for the next entry.

Create and dialogs need Allow Writes.

### Setup

The *MobileNAV Device Emulator* page holds the device and the setup side by side. The left column has the Options group, which picks the user, the language and the profile, then the Emulator Setup group. The right column has the phone, which stays at phone width. The Emulator help FactBox opens with the description of the emulator, then the steps of the selected token source. The Emulator help FactBox shows the steps of the selected token source. The emulator connects when the page opens and after each setup change. When it has no token, a notification says why and offers Connect, and for the MobileNAV Token source also Request MobileNAV Token.

The page keeps the user, the language and the profile of each signed-in user in table 77830 "BJF MN Emulator Pref". The page restores them on open. Each value is checked first: the user needs a MobileNAV User Setup, the language must be a supported MobileNAV language, and the profile must be one the user has in MobileNAV. A value that fails its check falls back to the signed-in user, the session language or no profile.

The Token group of the page holds the token actions: Get Token from MobileNAV Setup, Request MobileNAV Token, and the two Download Emulator Sign-in Script actions.

Token source "App Registration":

1. In Microsoft Entra ID, register an app with a Web redirect URI equal to the Redirect URI on the page.
2. Add the delegated API permission "Dynamics 365 Business Central, user_impersonation".
3. Create a client secret. Enter the Client ID and the secret on the page. The secret goes to isolated storage and shows as `***` once saved.
4. In Extension Management, turn on Allow HttpClient Requests for the extension. Without it the emulator cannot call the page services. The Doctor check "Emulator: HttpClient Requests" reports it while it is off.
5. The emulator signs in. When it has no token, it opens the Microsoft sign-in page. The Connected field then shows that a token is held.

Token source "MobileNAV Token" reuses the token that MobileNAV stored for the signed-in user. Its steps:

1. Set up MobileNAV for the user. The user needs a MobileNAV User Setup, and the O365 app registration (O365 App ID, tenant and client secret) is kept in MobileNAV Master Data.
2. On the emulator page, choose "Request MobileNAV Token". It runs the token request of "O365 Self-authorization (MobileNAV)" for the signed-in user, which is the procedure RequestAccessToken of codeunit "MobileNAV OAuth Helper" with self-authorization on. MobileNAV asks for a confirmation and opens its sign-in dialog.
3. Sign in with the O365 Auth. Email shown on the O365 Self-authorization page. The emulator then connects with the token that MobileNAV stored.

"Get Token from MobileNAV Setup" reads a token that MobileNAV stored earlier, without signing in. MobileNAV refreshes the token when it expires. If no token is stored, the notification offers Request MobileNAV Token.

Token source "Supplied Token" takes a token that the caller already holds for the signed-in user. The extension ships two sign-in scripts for it, which the page downloads with "Download Emulator Sign-in Script (PowerShell)" and "Download Emulator Sign-in Script (Python)". The downloaded files are `mobilenav-emulator-sign-in.ps1` and `mobilenav-emulator-sign-in.py`. The download fills in the tenant ID, the environment name, the company, the API base URL and the client ID. The client ID defaults to the O365 App ID of MobileNAV Master Data, and to the Client ID of Emulator Setup when that is empty. Each value is a parameter with that default, and a command-line argument overrides it. Each script signs the user in with the device code flow, using a public client app registration that allows public client flows and the delegated permission "Dynamics 365 Business Central, user_impersonation". It holds no secret. The script then sends the token with its lifetime in seconds to the bound action `supplyToken` of API page "BJF MN Emulator Setup API" (77703):

```
POST .../emulatorSetups({id})/Microsoft.NAV.supplyToken
{"accessToken": "...", "expiresIn": 3600}
```

The token goes to isolated storage for that user, and no table holds it. The emulator stops reusing the token 60 seconds before it expires, so a lifetime of 60 seconds or less is refused. Connect does not sign in for this source. It raises an error that says to run the script. The connection line names the token source and says when a supplied token is missing or has expired.

The page `emulatorSetups` publishes `id`, `tokenSource`, `allowWrites`, `deviceId`, `clientId` and `lastModifiedDateTime`. It also publishes the read-only `allowWritesInProduction`, `connected` and `sandbox`. The token never appears in a field or a response.

The API names of the token sources are `AppRegistration`, `MobileNAVToken` and `SuppliedToken`.

### Writes gate

"Allow Writes" lets buttons, field edits and scans change data. It can be turned on in a sandbox. Outside a sandbox, "Allow Writes in Production" must be on first, and turning it on asks for confirmation. While writes are on, a red bar under the title names the environment that the writes go to.

### Opening the emulator

"MobileNAV Emulator" on the MobileNAV Configuration Providers page opens the emulator on the menu. On a Doctor finding, it opens the emulator on the finding's service list when the finding names a service, and on the menu otherwise.

### API

Page "BJF MN Emulator Request API" (77701) is published as `emulatorRequests`, under `api/bjf/mobilenav/v1.0/companies({id})`. Each request is one POST. The request is a JSON text in `request`, and the answer is a JSON text in `response`:

```
POST .../emulatorRequests
{"request": "{\"kind\":\"list\",\"service\":\"MNItem\",\"search\":\"Airpot\",\"top\":5}"}
```

| Kind | Answers |
|---|---|
| `menu` | The device menu of a user, profile and language. Rebuilds the configuration on each call. |
| `profiles` | Every profile of the company, and the profiles assigned to the user. |
| `list` | One page of rows of a service, with search, sort, filters and drill-down. |
| `card` | Groups, fields, drill-downs, actions, layout and stages of one record. |
| `lookup` | One page of the related page's records for a lookup field. |
| `connection` | Whether a token is held, and whether writes are allowed. |
| `action` | Presses a button. |
| `update` | Writes one field, such as a scanned value. |
| `dialogAnswer` | Answers a dialog that the page raised. |
| `newCard` | A new-record form. A dialog page also gives `dialog` true and its `functionService`. Writes nothing. |
| `create` | Saves a new record through the page service and answers with its card and `created` true. |
| `dialogRun` | Runs a dialog page's function and answers with `commands`, `fileName`, `base64Result` and `message`. |
| `bufferState` | The settings buffer rows and the licence marks of a user, to check that a menu build left nothing behind. |

The `list`, `card` and `profiles` kinds take `user`, `language` and `profile`, and each may be left out. A missing user is the user of the loaded configuration, or else the signed-in user. A missing language and profile come from the loaded configuration when it belongs to that user. Otherwise they are the session language and no profile.

`newCard` takes `service` and, under a list, `parent`. `create` takes `service`, `values` keyed by field name, and `parent`. `dialogRun` takes `service`, `functionName` and `values` keyed by control name. `create` and `dialogRun` need Allow Writes.

Set `"debug": true` on an `action`, `update`, `create` or `dialogRun` request to get `soapExchange`, the SOAP request and reply of the call. A failed call then answers with kind `error` and the same `soapExchange`. `mnconfig.py emulate <kind>` in the tools repository (mobilenav-config) sends the same requests from the command line.

### Limits

- A Card tile on the menu opens a new record when its main menu action is Create. Any other Card tile shows a notice, because card pages open from a list in this version.
- The emulator does not run the offline JavaScript of the device.
- The FieldControl of an in-process read is empty. A live read through the page service fills it, and needs the connection.
- Where the MobileNAV source does not say how the device evaluates a rule, the emulator follows its own reading, and a code comment names the rule. Two examples: a layout without conditions matches every record, and auto next moves on when every mandatory field that is editable on the stage has a value.

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
| Line Format Configuration (list lines and list cells) | `LineFormat`, `Show`, `ShowCaption`, `Separator`, `EndLineFormat` |
| Caption translations | `Caption`, `TranslatedCaptions` |
| Web services and function companions | `Publish`, `Functions`, automatic companion registration |

Left to the administrator, on purpose:

| Administration page | Why |
|---|---|
| User Setup, No. Series Setup, User Key Selection, per-user flow filter values | Per-user data, not configuration. |
| Offline JavaScript templates, HTML and ZPL print templates | Binary assets edited in their own tools; import them on the Page Setup page. |
| Icon and color setup, fonts, general setup | Environment-wide look and connection settings, one per tenant. |
| Menu position of a page within a profile | MobileNAV renumbers positions per profile from its editor; a declared position would fight it. |
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
13. A relation is a **lookup** when its code field is set and a **link** (an action that opens the page) when it is empty; the same row kind serves both.
14. Fields show in the order of MobileNAV's dense **Order** number, not their line numbers; a **group** is two marker rows squeezed in around its first and last member, so members have to sit together.
15. A **flow filter** is a field row of its own with class FlowFilter; it only shows in the filter pane when both Visible and Visible as Filter are set.
16. A **dynamic layout** keeps one action row per action type and one action line per field or stage it targets; the layout runs while every condition holds.
17. Captions live per **language** in MobileNAV's caption table, not on the field row; MobileNAV regenerates them from page metadata on a metadata refresh, which the doctor's caption check catches.
18. A **line format** is one row per caption, value or separator in MobileNAV's Line Format table. MobileNAV turns a field name it cannot find into plain text, and fails the device configuration build when line 1 or 2 is longer than 100 characters with each field written as its order number.

## Build

The app targets Business Central 26 (`runtime 16.0`) and MobileNAV 11 or later, with object ids 77700 to 77739 and 77760 to 77799. Consumers need `runtime` 12.0 or later for its namespaces.

After a MobileNAV upgrade, regenerate the table functions, the Page Functions catalog and the preview subscribers from the new symbols, then commit them:

```sh
# The committed output comes from MobileNAV 12.0.0.46 and Base Application 28.3.52162.53725.
python3 tools/generate_table_functions.py "<MULTISOFT KFT_MobileNAV_12.0.0.46 .app>" "<Microsoft_Base Application_28.3.52162.53725 .app>"
```

The generator writes the MobileNAV build it ran against into `VerifiedMobileNAVVersion()` on "BJF MN Page Function Catalog". The Doctor's **MobileNAV Version** check compares it with the installed MobileNAV and reports Information when MobileNAV is newer, Warning when older.

| MobileNAV build | Generated output |
|---|---|
| 12.0.0.45 | Differs: "MobileNAV Temporary Data" lacks AdhocMovDeleteLines |
| 12.0.0.46 | The committed output |
| 12.0.0.47 | Not compared, no package available |
| 12.0.0.48 | Identical to 12.0.0.46 |
| 12.0.0.49 | Identical to 12.0.0.46 |

`ci/README.md` describes the pull request pipeline: build with the full cop set, deploy to a sandbox, preview and apply every provider, run the Doctor. Put compatible Microsoft and `MULTISOFT KFT_MobileNAV` symbol packages in `.alpackages`, then compile with the AL extension or `alc`:

```sh
alc /project:. /packagecachepath:.alpackages /out:build/MobileNAV-Configuration.app
```

The repository does not include proprietary MobileNAV or Microsoft symbol packages.
