# Consumer extension example

A complete skeleton: the consuming app declares this extension as a dependency, implements the provider contract, registers it through an enum extension, wires up a page of its own for a button and an action dialog, and handles both taps.

## app.json dependency

```json
{
    "id": "fd09b53c-ff32-4d9c-91ce-6a82a87b8c9c",
    ...
    "dependencies": [
        {
            "id": "8943817b-00dd-4a15-b70a-209b96da80e2",
            "name": "MobileNAV Configuration",
            "publisher": "Brad Fullwood",
            "version": "4.0.0.0"
        }
    ]
}
```

## Provider codeunit

```al
namespace Contoso.MobileNAV.Setup;

using BradFullwood.MobileNAV.Configuration;
using Contoso.MobileNAV.CustomSN;

/// <summary>
/// Declarative Contoso MobileNAV configuration provider. Every control this extension adds to
/// a MobileNAV page is inert until this declaration describes it, so each page extension has a
/// matching declaration below. The shared configuration extension validates and applies the
/// definition and notices on its own when it changes; there is no version to maintain.
/// </summary>
codeunit 50100 "CTO MN Config Provider" implements "BJF MN Config Provider"
{
    Access = Internal;

    procedure GetId(): Code[50]
    begin
        exit(ProviderIdTok);
    end;

    procedure GetName(): Text[100]
    begin
        exit(CopyStr(ProviderNameLbl, 1, 100));
    end;

    procedure GetDescription(): Text[250]
    begin
        exit(ProviderDescriptionLbl);
    end;

    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        DefineDespatchNote(Configuration);
        DefineCustomSerialNumbers(Configuration);
    end;

    /// <summary>
    /// Packing instructions on the warehouse shipment, the shipment date a picker filters by,
    /// and the despatch note print button. The button's tap is handled in
    /// "CTO MN Despatch Events" below — MobileNAV never raises OnQueryClosePage on a device,
    /// so the print cannot hang off the page closing.
    /// </summary>
    /// <param name="Configuration">The builder collecting this provider's declarations.</param>
    local procedure DefineDespatchNote(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"MobileNAV WhseShipment")
            .Field('CTOPackingInstructions')
            .Field('Shipment Date').Filterable()
            .Button('CTOPrintDespatch');
    end;

    /// <summary>
    /// Publishes the custom serial number generator as an action dialog and hangs it off the
    /// item tracking card, beside MobileNAV's own generator. One parameter row exists per
    /// user, so MineOnly shows each device only its own row; the inputs are editable and
    /// Create is a button for the same reason the despatch button is one — no OnQueryClosePage
    /// on a device. The link filter is the tracking buffer's entry number, zero on both sides,
    /// which binds the pages without narrowing either.
    /// </summary>
    /// <param name="Configuration">The builder collecting this provider's declarations.</param>
    local procedure DefineCustomSerialNumbers(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.Page(Page::"CTO CSNCreateSNReport")
            .Publish(CustomSerialNumberServiceTok)
            .MineOnly('userId')
            .Field('prefix').Editable()
            .Field('qtyReqd').Editable()
            .Button('Create');

        Configuration.Page(Page::"MobileNAV ItemTrackingHdr Card")
            .Link('CTOCustomSNPrefixSuffix', Page::"CTO CSNCreateSNReport", 'Entry No.', 'Entry No.');
    end;

    var
        ProviderIdTok: Label 'CTO-MOBILENAV', Locked = true;
        CustomSerialNumberServiceTok: Label 'MNCTOCustomSNGenerator', Locked = true;
        ProviderNameLbl: Label 'Contoso MobileNAV';
        ProviderDescriptionLbl: Label 'Packing instructions and despatch note printing on warehouse shipments, plus the custom serial number generator on item tracking.';
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

## The action-dialog page's web-service wrapper

`Page::"CTO CSNCreateSNReport"` is a page of Contoso's own, so unlike MobileNAV's own pages, which already have theirs, it needs the `[ServiceEnabled]` function wrapper the `Button('Create')` declaration above depends on. Its source table is `"MobileNAV Tracking Spec."`, whose dispatcher (from the table → dispatcher mapping in the README) is `MNTrackSpecExtFunc`; the wrapper's name has to be exactly that:

```al
page 50100 "CTO CSNCreateSNReport"
{
    PageType = Card;
    SourceTable = "MobileNAV Tracking Spec.";
    ...

    layout
    {
        area(Content)
        {
            field(prefix; Rec."CTO Prefix") { ApplicationArea = All; }
            field(qtyReqd; Rec."CTO Qty Required") { ApplicationArea = All; }
        }
    }

    /// <summary>
    /// The one-line body every [ServiceEnabled] function wrapper needs: hand the tapped record,
    /// the service name and the control name to the router and return its converted result.
    /// The procedure name is not a free choice — it must be the dispatcher MobileNAV's Page
    /// Functions codeunit has for this page's source table.
    /// </summary>
    /// <param name="PageName">Service name of this page, passed through to the dispatcher.</param>
    /// <param name="FieldName">Name of the tapped button.</param>
    /// <param name="DeviceID">Identifier of the invoking device.</param>
    /// <returns>MobileNAV's encoded function-control result.</returns>
    [ServiceEnabled]
    procedure MNTrackSpecExtFunc(PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
    var
        FunctionRouter: Codeunit "BJF MN Function Router";
    begin
        exit(FunctionRouter.Execute(Rec, PageName, FieldName, DeviceID));
    end;
}
```

## Handling the taps

`"MobileNAV WhseShipment"` is MobileNAV's own page, so its `[ServiceEnabled]` wrapper already exists; the despatch button's tap only needs a subscriber:

```al
namespace Contoso.MobileNAV.DespatchNote;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Warehouse.Document;

/// <summary>
/// Runs the despatch-note print button on the warehouse shipment when the device taps it.
/// The configuration framework routes every device button tap through one event regardless
/// of which MobileNAV table it originated from, so this subscribes once and filters.
/// </summary>
codeunit 50101 "CTO MN Despatch Events"
{
    [EventSubscriber(ObjectType::Codeunit, Codeunit::"BJF MN Function Router", OnPageFunction, '', false, false)]
    local procedure OnPageFunction(PageId: Integer; ControlName: Text[75]; FunctionRecord: RecordRef)
    var
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
    begin
        if (PageId <> Page::"MobileNAV WhseShipment") or (ControlName <> 'CTOPrintDespatch') then
            exit;

        FunctionRecord.SetTable(WarehouseShipmentHeader);
        PrintDespatchNote(WarehouseShipmentHeader);
    end;

    local procedure PrintDespatchNote(WarehouseShipmentHeader: Record "Warehouse Shipment Header")
    begin
        // ... report/print logic ...
    end;
}
```

The `Create` button on `"CTO CSNCreateSNReport"` does not need a separate subscriber in this example: its own `[ServiceEnabled]` wrapper already calls `FunctionRouter.Execute` directly and returns the converted result, which is the pattern to prefer for a page you own outright. Use the `OnPageFunction` event instead when several pages should share one handler, or when the handling code belongs in a different codeunit than the page.

## Applying it

```al
codeunit 50102 "CTO Install"
{
    Subtype = Install;

    trigger OnInstallAppPerCompany()
    begin
        ApplyMobileNAVConfiguration();
    end;

    local procedure ApplyMobileNAVConfiguration()
    var
        ConfigurationApplication: Codeunit "BJF MN Config Application";
    begin
        ConfigurationApplication.ApplyProvider(Enum::"BJF MN Config Provider"::"Contoso MobileNAV");
    end;
}
```

Because install has no client to answer MobileNAV's confirmation dialogs, this apply writes the full configuration but is recorded with a pending device handover. **MobileNAV Configuration** shows the provider as Outdated until an administrator applies it again from there, where a client is available to finish the handover.

The consumer's permission set must grant execute permission to `"CTO MN Config Provider"` and `"CTO MN Despatch Events"`, and administrators need the `"BJF MN Configuration"` permission set to reach **MobileNAV Configuration** and **MobileNAV Doctor**.
