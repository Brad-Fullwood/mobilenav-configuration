# MobileNAV Configuration

A Business Central framework for declaring, applying, and diagnosing custom MobileNAV configuration in AL.

You declare what a device shows in a few fluent lines — pages, fields, buttons, links, scan inputs, wizards — and the framework knows the MobileNAV mechanics behind them: which service a control belongs to, how profiles override service-level visibility, when a companion web service is needed for a button to work, when the page needs `Page Update`, and how to scope a page to the signed-in device user. One extension, wrapped around the same framework, also diagnoses and repairs the MobileNAV and posting problems that show up as cryptic device errors.

## Quick start

1. Add **MobileNAV Configuration 3.0.0.0** to the consumer's `app.json` dependencies.
2. Register the provider through an `enumextension` of `"BJF MN Config Provider"`.
3. Implement `"BJF MN Config Provider"` in one codeunit:

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

There is no `GetVersion()` — v2 had one and it is gone. The framework fingerprints the definition's *content* instead (see [Applying, fingerprints and states](#applying-fingerprints-and-states)), so a provider only ever states what it wants; it never has to remember to bump anything.

4. Apply it. Either an administrator opens **Apply custom MobileNAV config**, selects the provider, and runs **Apply selected** — or call it from the consumer's install/upgrade codeunit:

```al
local procedure ApplyMobileNAVConfiguration()
var
    ConfigurationApplication: Codeunit "BJF MN Config Application";
begin
    ConfigurationApplication.ApplyProvider(Enum::"BJF MN Config Provider"::"Contoso MobileNAV");
end;
```

An apply with no client attached (install/upgrade) still writes the configuration, but cannot finish handing it to devices — see [Applying, fingerprints and states](#applying-fingerprints-and-states).

5. Grant execute permission to the consumer's provider codeunit (and any event subscriber codeunits) and assign the library's `"BJF MN Configuration"` permission set to administrators.

See [examples/ConsumerExtension.md](examples/ConsumerExtension.md) for a complete, DMS-shaped skeleton including a button handler.

## Fluent reference

Every method returns the builder, so a page reads as one sentence:

```al
Configuration.Page(Page::"MobileNAV WhseShipment")
    .Field('AUKPackingInstructions')
    .Field('Shipment Date').Filterable()
    .Button('AUKPrintDespatch');
```

A modifier refines the control declared last (the one immediately before it in the chain). Calling a modifier that does not apply to that control's kind — `Filterable()` on a button, `Validation()` on a plain field — fails immediately with a message naming the modifier, the control, and its actual kind.

### Page context

| Method | Does |
|---|---|
| `Page(PageId)` | Makes a page the context for what follows. Repeatable — calling it again for the same id continues that page. A MobileNAV page needs nothing more; a page of your own needs `Publish` or `PublishAsDialog`. |
| `Publish(ServiceName)` | Registers the current page as a MobileNAV web service, gives it a tile, and adds it to every profile's menu. Reuses an existing service if the page object already has one. |
| `PublishAsDialog(ServiceName)` | `Publish`, then marks the page as MobileNAV's action-dialog pattern (parameter fields plus a button) instead of a browsable page — for a page that exists to collect inputs and run something. |
| `MainMenuAction(Action)` | Sets what the page's tile does when tapped: `Create` (new record) or `Open` (the single existing one). Needs `Publish`/`PublishAsDialog` first. |
| `MineOnly(UserIdControlName)` | Scopes the page to the signed-in device user via MobileNAV's own "Mine" mechanism, over a per-user parameter table. Required for such a table — without it every device lists every user's row and a card cannot resolve one. |

### Controls

| Method | Default | Notes |
|---|---|---|
| `Field(ControlName)` | Visible, read-only, standard section, every profile | |
| `Button(ControlName)` | Visible, editable, `MobileType` Normal, `FunctionType` Normal, function name auto-derived | Runs Business Central code when tapped. See [Buttons end to end](#buttons-end-to-end). |
| `Link(ControlName, TargetPageId, TargetFilterField, SourceField)` | Visible, read-only | Opens another page filtered to the current record; the target becomes reachable from this page in every profile so the button is actually drawn. A page of your own as the target must have its own `Page(...).Publish(...)`. |
| `Scan(ControlName)` | Visible, editable, `MobileType` Barcode | An input the device fills from its scanner. |

### Modifiers

| Method | Applies to | Does |
|---|---|---|
| `Editable()` | Field, Button, Scan | Lets the device user change the value; also marks the page updatable as a whole. |
| `ReadOnly()` | Field, Button, Scan | Read-only (the default for `Field`). |
| `Hidden()` | Field | Keeps the field off the device at service level and in every profile. |
| `Filterable()` | Field | Offers the field in the device's filter pane. |
| `InMenu()` | Field | Draws the field as a menu entry instead of a card value. Rarely needed — `Button` and `Link` already produce menu entries. |
| `Importance(Level)` | Field, Button, Link, Scan | Where the device draws the control — see the `"BJF MN Importance"` values below. |
| `Validation(Behavior)` | Button, Scan | How the device validates a scanned/typed value before accepting it. |
| `MobileType(ControlType)` | Button | Renders the button as a special control — image capture, signature pad, etc. |
| `FunctionType(FunctionKind)` | Button | Shape of the function's result — field-control value, file, with/without device position. |
| `FunctionName(DispatcherName)` | Button | Overrides the MobileNAV dispatcher the framework would otherwise derive from the page's table. See [Buttons end to end](#buttons-end-to-end). |
| `OnlyInProfile(Profile)` | Field, Button, Link, Scan | Limits the control to one profile instead of every profile. Repeatable. |
| `ExceptInProfile(Profile)` | Field, Button, Link, Scan | Shows the control in every profile except the named one. Repeatable. |
| `NotInProfiles()` | Field, Button, Link, Scan | Writes no profile rows at all — the escape hatch. The control is not drawn until a profile row exists for it some other way. |

`Importance` values (`"BJF MN Importance"`): `Standard` (the card's main section — MobileNAV's own `None`), `RequiredForInsert`, `Mandatory`, `Additional` (hidden behind the card's "show more" section — for a button, wherever a device user never finds it). Every control the builder produces defaults to `Standard` explicitly, because MobileNAV itself defaults a new field to `Additional`.

### Wizard

| Method | Does |
|---|---|
| `Wizard()` | Turns the current page into a staged wizard. Restarts on every record by default. |
| `AutoNext()` | Advances to the next stage automatically once a stage is complete. |
| `HideBackNext()` | Hides the Back/Next controls — pair with `AutoNext()` for a scan-driven flow. |
| `Behavior(StagingBehavior)` | `Always` (restart every record), `CreationOnly`, or `PersistState` (resume a part-finished wizard). |
| `Stage(StageId, Description)` | Adds the next stage, in declaration order. `StageId` is a category code, at most 20 characters. |
| `RestartsHere()` | Marks the stage declared last as the one a later record resumes at, keeping what earlier stages captured. One per page, and never the first stage. |
| `Show(ControlName)` | Shows a field editable while the stage declared last is active. |
| `ShowReadOnly(ControlName)` | Shows a field read-only, for context, while the stage declared last is active. |

Fields not shown by the active stage's `Show`/`ShowReadOnly` stay hidden while that stage runs.

## Buttons end to end

A device button needs three pieces, for three different reasons.

**(a) Declare it:**

```al
Configuration.Page(Page::"MobileNAV WhseShipment")
    .Button('AUKPrintDespatch');
```

**(b) For a page of your own, add the one-line web-service wrapper.** MobileNAV's SOAP transport calls a page's functions through a *companion codeunit web service registered under the page's own service name* — resolving to MobileNAV's `"MobileNAV Page Functions"` codeunit. The framework registers that companion for you (`PublishFunctionCompanion`), but the page still needs a `[ServiceEnabled]` procedure for the call to land on, and **its name must be the dispatcher MobileNAV's Page Functions codeunit has for the page's source table**. MobileNAV's own pages already have theirs; a page of your own does not. The body is always the same one line:

```al
[ServiceEnabled]
procedure MNTrackSpecExtFunc(PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
var
    FunctionRouter: Codeunit "BJF MN Function Router";
begin
    exit(FunctionRouter.Execute(Rec, PageName, FieldName, DeviceID));
end;
```

Skip this wrapper and the button renders fine but every tap dies client-side with `Method "…" is invalid!` before any request reaches Business Central.

The table → dispatcher name mapping (from `"BJF MN Function Map"`, which the framework consults automatically when a button is declared without `FunctionName()`):

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

A table not on this list needs an explicit `FunctionName()` naming a dispatcher of your own; declaring `Button()` without one on such a table fails at apply time naming the control and table.

**(c) Handle the tap.** Subscribe once to `"BJF MN Function Router"`'s `OnPageFunction`, filtering on the page id and control name, instead of writing one subscriber per MobileNAV table event:

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

`FunctionRecord.SetTable(YourRecord)` gives you the tapped record typed. A page's own `[ServiceEnabled]` wrapper can instead call `"BJF MN Function Router".Execute(...)` directly (as the example above does) to invoke a specific MobileNAV dispatcher and get its converted result back, bypassing the event entirely — that is what the wrapper's one line does. `GetServiceName(PageId)` on the same codeunit looks up the MobileNAV service name a page is registered under, for the rare case something still needs it by name.

## Profiles are automatic

MobileNAV resolves a control's visibility in two layers: the service-level configuration is the default, but a row for the control in the device user's *profile* overrides it outright. MobileNAV writes those profile rows itself whenever it rebuilds a profile's page hierarchy — a control it has never been told about there is simply not visible, even though the service-level configuration is correct. This is the gap v2's `AddToProfile` closed by hand; in v3 it closes itself: every `Field`, `Button`, `Link`, and `Scan` writes its own profile rows automatically, for every defined profile, using its own visibility and editability.

Three opt-outs, when a control should not follow that default:

- **`OnlyInProfile(Profile)`** — show the control in one profile instead of every profile. Repeat for several.
- **`ExceptInProfile(Profile)`** — show it in every profile except the named one. Repeat for several.
- **`NotInProfiles()`** — write no profile rows at all. The control is then invisible until a profile row exists for it some other way.

A `Publish`ed page is also added to every profile's menu automatically, and a `Link`'s target page is made reachable as a child of the page the link control sits on — both for the same reason: a page or button MobileNAV has not been told belongs to a profile does not appear there, no matter how correctly its service-level row is configured.

## Applying, fingerprints and states

**Apply custom MobileNAV config** shows every registered provider in one of three states:

- **Not Applied** — no successful application is recorded.
- **Applied** — the applied content hash matches the provider's current definition.
- **Outdated** — the definition's content hash no longer matches what was applied, an administrator ran **Mark selected outdated**, or the last apply ran without a GUI attached (a *device handover pending*).

The hash (`"BJF MN Config Hash"`) replaces v2's `GetVersion()`: it fingerprints the definition's *content*, canonically ordered so reordering declarations is not a change while adding, removing, or altering one is. A provider never has to remember to bump a version number — change the declaration and the framework notices on its own.

**Device handover pending**: MobileNAV only carries configuration through to devices for changes made inside its "construction window", and finishing that handover — rebuilding the profile hierarchy, regenerating the page templates devices render from, telling devices to reload — runs routines that can raise a confirmation dialog. Install and upgrade codeunits have no client to answer one, so when `ApplyProvider` runs without a GUI it still writes the full configuration but skips the handover and records the provider outdated (pending). The fix is simply to apply the same provider again from the administration page, where a client is available.

**The delegated-admin dialog gotcha**: publishing a page's web service and publishing its function companion each write to `Tenant Web Service` independently (`PublishPage`, `PublishFunctionCompanion`) — the first time either happens for a given service name, expect a delegated-admin/API-access confirmation from the platform. Because a button's declaration touches both, applying a provider that publishes a new page with buttons can raise this dialog **twice** in the same apply. Answer it (Yes) both times; it is not an error.

Check `MNPageMgt.PublishConfigurationToDevices`'s doc comments for the current state of that handover if MobileNAV's own routines change — the comments there call out an "Under Construction" flag explicitly and are the source of truth this section summarizes.

## Doctor & diagnostics

Page 77781 **"BJF MN Doctor"** (caption "MobileNAV Doctor", Administration) is the single place to check and repair MobileNAV setup:

- **Run Config Checks** — the checks over the configuration and setup tables this app itself owns: **Services & Web Services** (page/companion registration, one service per page object), **Fields & Importance** (Additional-hidden controls, missing profile rows), **Profiles** (profile rows out of sync with service rows), **Relations / Scope / Page Update** (broken page relations, missing `Own` scope, editable pages without Page Update), **Apply State** (providers outdated or with a pending device handover).
- **Run All Diagnostics** — the config checks plus every check registered in `"BJF Diagnostic Check Type"`, including the ported ones below.
- **Export live snapshot** — downloads every MobileNAV row the selected provider's configuration touches, for diffing between environments (the same export as **Apply custom MobileNAV config**'s own action).

Findings appear on the **"BJF Diagnostic Findings Part"**: a **Severity** (Blocker/Warning/Info), the **Check** that produced it, and a message. **Apply Fix** dispatches to the owning check's `ApplyFix` for any finding recorded with a fix, then re-runs every check; **Open Related Record** jumps to the record the finding is about (an Item Tracking Code, a journal line, ...).

### Ported checks (from the retired MobileNAV Diagnostics app)

| Check | Catches |
|---|---|
| **Movement Journals** | MobileNAV User Setup without a Movement Journal Name; the batch missing on a Transfer-type template; the batch lacking a No. Series (Move/Split Package then fails "Document No. must have a value" — the fix assigns an `MNMOVE` series, creating it if needed). |
| **Item Tracking Codes** | "Package Info. Inb./Outb. Must Exist" enabled without the create-on-posting workaround (breaks Split/Move Package); "Package Transfer Tracking" disabled. |
| **Leftover Journal Lines** | Lines stuck in a MobileNAV movement batch (flagged Blocker when missing Bin/New Bin Code at a bin-mandatory location, since Move Package posts the *whole* batch); stale lines in the shared MobileNAV output batch left by an abandoned card or failed posting (skips lines under an hour old, which may belong to an in-flight wizard). Fix deletes the line together with its item tracking. |
| **Page Relations** | A `MobileNAV Service Setup` relation or list-to-card reference pointing at a page with no Main configuration row. MobileNAV's profile-hierarchy rebuild resolves every such reference with a direct `Get` and aborts the *entire* rebuild on the first one that fails — reported against the *owning* page, not the missing one, so no configuration reaches any device until it is cleared. Fix deletes the relation (with its filters) or clears the related page. |

### Opt-in posting workarounds

Both are off by default; enable only where the underlying MobileNAV/BC gap actually bites.

- **Create Package Info. on Posting** (Item Tracking Code Card, Package fasttab) — standard BC has "Create SN/Lot No. Info on Posting" but no package equivalent. With "Package Info. Inb./Outb. Must Exist" on, a reclass to a freshly generated package number (MobileNAV Split Package) fails because BC does a hard `Get` of `Package No. Information` for the *new* number. The workaround subscribes to `Item Jnl.-Post Line.OnBeforeCheckItemTrackingInformation` and creates the missing record for both the old and new number, mirroring `ItemTrackingManagement.CreateLotNoInformation`. Remove it once Microsoft ships the standard toggle.
- **Move Posts Only Its Own Lines** (Inventory Setup, General fasttab) — `MUL WMS PageFunctions.MovePackage2` posts the *whole* movement batch instead of just the lines it created (unlike its sibling `SplitPackageInternal`), so any stale line blocks or silently co-posts with every Move Package. Every item journal line is stamped with its creating session (rolls back with the transaction); when enabled, non-interactive postings of a MobileNAV movement batch are narrowed to the current session's lines. Interactive desktop posting and callers that already scope their own lines (Split Package) are untouched. Remove once MultiSoft fixes `MovePackage2`.

### Contributing a check from another extension

Implement `"BJF Diagnostic Check"` (`RunCheck` records findings via `Finding.Add`/`Finding.AddWithFix`; `ApplyFix` repairs one, or raises an error if the check has no automatic fix) and register it with an `enumextension` of `"BJF Diagnostic Check Type"` — no change to this app required.

### Knowledge base

Root causes already encoded as checks, carried over from the retired MobileNAV Diagnostics app:

**"The Package No. Information does not exist ... Package No.='\<new no>'" on Split/Move Package.** BC's `PackageInfoManagement` codeunit (subscriber to `Item Jnl.-Post Line.OnAfterCheckItemTrackingInformation`) does a hard `Get` of Package No. Information for the **New Package No.** of a reclass when the Item Tracking Code has either must-exist toggle enabled. MobileNAV WMS auto-creates package info when a *Package No.* is validated but never for *New Package No.* — so any device split fails, whether the number is typed or generated. **Fix:** disable both must-exist toggles (with "Package Transfer Tracking" on, BC then auto-creates the info record on posting, which in turn auto-creates the WMS package record), or enable **Create Package Info. on Posting** to keep the gate.

**"New Bin Code must have a value in Item Journal Line ..." on Move Package.** `MovePackage2` posts the entire movement batch without filtering to its own lines. Any stale line left in the batch (e.g. a half-filled manual reclass line missing New Bin Code) blocks every Move Package with the same line number, and benign leftovers get silently co-posted with the move. **Fix:** delete leftover lines (**Apply Fix** on the finding).

## The MobileNAV rules the framework encodes

For a developer who will never read MobileNAV's own source:

1. A control's **Importance** defaults to `Additional` in MobileNAV itself, which hides it behind the card's "show more" section — for a button, somewhere nobody looks. The framework always writes `Standard` (MobileNAV's `None`) explicitly unless told otherwise.
2. **Profile rows override service-level rows.** A field configured perfectly at service level is still invisible on a device whose profile has no row for it.
3. A page needs a profile **Page** row (to appear at all, with a tile) and, for anything that links to it, a profile **Parent** row (to be reachable from the linking page) — both are what MobileNAV calls "collecting" a page for a profile.
4. A relation with `RelatedPgCodeFldName` set turns into a **lookup binding**, not a button — the framework deliberately leaves it unset so a `Link` renders as the action that opens the target page.
5. The **Page Update** flag on a page's Main row gates whether the device may write back *anything*; an `Editable` field on a page with Page Update off is drawn read-only regardless of its own configuration.
6. A page over a **per-user table** needs the `Own` filter comparison over a control marked `MobileType` `UserID` — MobileNAV replaces `Own` with an equality against the signed-in MobileNAV user at config-build time, which is what makes a shared parameter table resolve to exactly one row per device.
7. A button's SOAP call needs a **companion codeunit web service** registered under the page's own service name, resolving to `"MobileNAV Page Functions"` — without it the tap fails client-side (`Method "…" is invalid!`) before any request is made.
8. A page's function procedures need `[ServiceEnabled]`, and the procedure's **name must be the dispatcher** MobileNAV's Page Functions codeunit has for the page's source table.
9. MobileNAV allows only **one service per page object** — registering a second service name over a page that already has one does not survive the next metadata refresh, which renames the Main row back to the existing service.
10. Configuration changes reach devices **only** through MobileNAV's construction window plus an enforced major config change / page-hierarchy rebuild — writes made outside that window land in the setup tables and stop there.
11. A wizard **stage id** is a category code, at most 20 characters.
12. A stage marked `RestartsHere` (`Staging Restart From`) can never be the **first** stage of a wizard.

## Migrating from v2

The old verb API is gone; every declaration now reads through `Page(...)` context.

| v2 verb | v3 fluent equivalent |
|---|---|
| `AddPublishedPage(PageId, ServiceName)` | `Page(PageId).Publish(ServiceName)` |
| `AddPublishedReportPage(PageId, ServiceName)` | `Page(PageId).PublishAsDialog(ServiceName)` |
| `AddField` / `AddVisibleField` (standard, visible) | `Page(PageId).Field(ControlName)` |
| `AddFilterableField` | `Page(PageId).Field(ControlName).Filterable()` |
| `AddField(..., Editable: true, ...)` | `Field(ControlName).Editable()` |
| `AddField(..., Importance, Filterable, ...)` | `Field(ControlName).Importance(Level)[.Filterable()]` |
| `AddLinkedField(PageId, ControlName, TargetPageId, TargetFilterField, SourceField)` | `Link(ControlName, TargetPageId, TargetFilterField, SourceField)` |
| `AddFunctionField(PageId, ControlName, Editable, MobileType, FunctionName, FunctionType, ValidationBehavior)` | `Button(ControlName)[.MobileType(...)][.FunctionType(...)][.FunctionName(...)][.Validation(...)]` |
| `AddScanField` | `Scan(ControlName)` |
| `AddUserScope(PageId, ControlName)` | `Page(PageId).MineOnly(ControlName)` |
| `AddToProfile(...)` | Automatic for every control; use `OnlyInProfile`, `ExceptInProfile`, or `NotInProfiles` only to deviate from "every profile". |
| `EnableStaging` / `AddStage` / `AddStageField` | `Wizard()` / `Stage(StageId, Description)` / `Show(ControlName)` \| `ShowReadOnly(ControlName)` |
| `GetVersion()` | Removed. See [Applying, fingerprints and states](#applying-fingerprints-and-states). |
| Event subscriber per MobileNAV table (`OnSalesHeaderExtFunc`, `OnItemExtFunc`, ...) | One subscriber to `"BJF MN Function Router".OnPageFunction`, filtered on `PageId`/`ControlName`. |

### Migrating from MobileNAV Diagnostics

The standalone **MobileNAV Diagnostics** app is retired; its checks and workarounds live inside this extension now (see [Doctor & diagnostics](#doctor--diagnostics)). Install this extension, let its **2.5.0.0** sunset release copy the workaround toggles across (Create Package Info. on Posting, Move Posts Only Its Own Lines), confirm the ported checks still pass on **MobileNAV Doctor**, then uninstall MobileNAV Diagnostics.

## Build

The app targets Business Central 26 (`runtime 16.0`) and MobileNAV 11 or later, with object ids 77760–77799. There is no preprocessor symbol gating the objects in v3 — the app is a normal dependency, not a nested submodule. Put compatible Microsoft and `MULTISOFT KFT_MobileNAV` symbol packages in `.alpackages`, then compile with the AL extension or `alc`:

```sh
alc /project:. /packagecachepath:.alpackages /out:MobileNAV-Configuration.app
```

The repository does not include proprietary MobileNAV or Microsoft symbol packages.

## A caveat worth keeping

AL interfaces cannot enforce purity: a deliberately hostile `DefineConfiguration` implementation can still perform side effects inside an interface method. What the framework does guarantee is that no provider receives an arbitrary execution callback, and no MobileNAV mutation starts until the complete declared plan — built fresh, from scratch, every time it is inspected — has passed validation.
