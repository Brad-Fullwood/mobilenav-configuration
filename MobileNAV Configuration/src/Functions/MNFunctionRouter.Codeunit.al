namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Assembly.Document;
using Microsoft.CRM.Contact;
using Microsoft.CRM.Interaction;
using Microsoft.CRM.Profiling;
using Microsoft.Inventory.Item;
using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Transfer;
using Microsoft.Manufacturing.Document;
using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Journal;
using Microsoft.Purchases.Document;
using Microsoft.Sales.Document;
using Microsoft.Sales.History;
using Microsoft.Service.Document;
using Microsoft.Service.Item;
using Microsoft.Warehouse.Activity;
using Microsoft.Warehouse.Document;
using Microsoft.Warehouse.History;
using Microsoft.Warehouse.Journal;
using Microsoft.Warehouse.Request;
using Microsoft.Warehouse.Worksheet;
using System.Automation;

/// <summary>
/// Lets consumers handle device button taps through ONE framework event instead of
/// MobileNAV's per-table events, and without ever hardcoding a MobileNAV service name.
///
/// MobileNAV's "MobileNAV Page Functions" codeunit raises one record-typed integration event
/// per source table when a device taps a page's function control (its "ExtFunc" procedures,
/// one per table, each publishing a matching "On&lt;Name&gt;ExtFunc" event). This codeunit
/// subscribes to every one of those events, resolves the MobileNAV service name to the BC
/// page id it is published under, and republishes a single OnPageFunction event carrying the
/// tapped record as a RecordRef. Consumers therefore write one event subscriber per page (or
/// even one for several pages, switching on PageId) instead of one per MobileNAV table, and
/// never need to know or hardcode the service name a page happens to be registered under.
///
/// A consumer page's own [ServiceEnabled] function wrapper can instead call Execute directly
/// to invoke a specific MobileNAV dispatcher and convert its result, without going through
/// the event at all.
/// </summary>
codeunit 77786 "BJF MN Function Router"
{
    Access = Public;
    Permissions = tabledata "MobileNAV Service Setup" = r;

    /// <summary>
    /// Raised once for every MobileNAV device button tap, regardless of which page or table
    /// it originated from.
    /// </summary>
    /// <param name="PageId">The BC page object id resolved from the MobileNAV service the tap came in on.</param>
    /// <param name="ControlName">The name of the function control that was tapped.</param>
    /// <param name="ServiceName">The MobileNAV service name the tap came in on.</param>
    /// <param name="FunctionRecord">The record the button was tapped on. Call FunctionRecord.SetTable(YourRecord) to work with it typed.</param>
    /// <param name="DeviceID">The id of the device the tap came from.</param>
    /// <param name="FieldControlFactory">MobileNAV's result helper for the call; pass it through to "MobileNAV Object Functions" calls such as FcMessage or FcRefresh when a response needs to reach the device.</param>
    [IntegrationEvent(false, false)]
    procedure OnPageFunction(PageId: Integer; ControlName: Text[75]; ServiceName: Text[100]; FunctionRecord: RecordRef; DeviceID: Text[190]; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    begin
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnSalesHeaderExtFunc', '', false, false)]
    local procedure RouteSalesHeader("Key": Record "Sales Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnSalesLineExtFunc', '', false, false)]
    local procedure RouteSalesLine("Key": Record "Sales Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnServiceTaskExtFunc', '', false, false)]
    local procedure RouteServiceTask("Key": Record "Service Item Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnServiceLineExtFunc', '', false, false)]
    local procedure RouteServiceLine("Key": Record "Service Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnItemExtFunc', '', false, false)]
    local procedure RouteItem("Key": Record Item; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnContactExtFunc', '', false, false)]
    local procedure RouteContact("Key": Record Contact; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnSalesReturnReceiptExtFunc', '', false, false)]
    local procedure RouteSalesReturnReceipt("Key": Record "Return Receipt Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnSalesShipmentExtFunc', '', false, false)]
    local procedure RouteSalesShipment("Key": Record "Sales Shipment Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnSalesInvoiceExtFunc', '', false, false)]
    local procedure RouteSalesInvoice("Key": Record "Sales Invoice Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnSalesCrMemoExtFunc', '', false, false)]
    local procedure RouteSalesCrMemo("Key": Record "Sales Cr.Memo Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnJobExtFunc', '', false, false)]
    local procedure RouteJob("Key": Record Job; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseActHdrExtFunc', '', false, false)]
    local procedure RouteWhseActHdr("Key": Record "Warehouse Activity Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseActLineExtFunc', '', false, false)]
    local procedure RouteWhseActLine("Key": Record "Warehouse Activity Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnApprovalEntryExtFunc', '', false, false)]
    local procedure RouteApprovalEntry("Key": Record "Approval Entry"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnJobJournalBatchExtFunc', '', false, false)]
    local procedure RouteJobJournalBatch("Key": Record "Job Journal Batch"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnJobJournalLineExtFunc', '', false, false)]
    local procedure RouteJobJournalLine("Key": Record "Job Journal Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseReceiptHdrExtFunc', '', false, false)]
    local procedure RouteWhseReceiptHdr("Key": Record "Warehouse Receipt Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseReceiptLineExtFunc', '', false, false)]
    local procedure RouteWhseReceiptLine("Key": Record "Warehouse Receipt Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseShpmtHdrExtFunc', '', false, false)]
    local procedure RouteWhseShpmtHdr("Key": Record "Warehouse Shipment Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseShpmtLineExtFunc', '', false, false)]
    local procedure RouteWhseShpmtLine("Key": Record "Warehouse Shipment Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnTransferHdrExtFunc', '', false, false)]
    local procedure RouteTransferHdr("Key": Record "Transfer Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnTransferLineExtFunc', '', false, false)]
    local procedure RouteTransferLine("Key": Record "Transfer Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnItemJrnlBatchExtFunc', '', false, false)]
    local procedure RouteItemJrnlBatch("Key": Record "Item Journal Batch"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnItemJrnlLineExtFunc', '', false, false)]
    local procedure RouteItemJrnlLine("Key": Record "Item Journal Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnProdOrderExtFunc', '', false, false)]
    local procedure RouteProdOrder("Key": Record "Production Order"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnProdOrderLineExtFunc', '', false, false)]
    local procedure RouteProdOrderLine("Key": Record "Prod. Order Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnPurchHeaderExtFunc', '', false, false)]
    local procedure RoutePurchHeader("Key": Record "Purchase Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnPurchLineExtFunc', '', false, false)]
    local procedure RoutePurchLine("Key": Record "Purchase Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnProfQuestLineExtFunc', '', false, false)]
    local procedure RouteProfQuestLine("Key": Record "Profile Questionnaire Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseWrkshLineExtFunc', '', false, false)]
    local procedure RouteWhseWrkshLine("Key": Record "Whse. Worksheet Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseJrnlLineExtFunc', '', false, false)]
    local procedure RouteWhseJrnlLine("Key": Record "Warehouse Journal Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnMNTrackSpecExtFunc', '', false, false)]
    local procedure RouteMNTrackSpec("Key": Record "MobileNAV Tracking Spec."; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnMNTempDataExtFunc', '', false, false)]
    local procedure RouteMNTempData("Key": Record "MobileNAV Temporary Data"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnInteractionLEExtFunc', '', false, false)]
    local procedure RouteMNInteractionLE("Key": Record "Interaction Log Entry"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnAssemblyOrderExtFunc', '', false, false)]
    local procedure RouteMNAssemblyOrder("Key": Record "Assembly Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnAssemblyLineExtFunc', '', false, false)]
    local procedure RouteMNAssemblyLine("Key": Record "Assembly Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseRequestExtFunc', '', false, false)]
    local procedure RouteWhseRequest("Key": Record "Warehouse Request"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnWhseJrnlBatchExtFunc', '', false, false)]
    local procedure RouteWhseJrnlBatch("Key": Record "Warehouse Journal Batch"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnPostedWhseShipmentExtFunc', '', false, false)]
    local procedure RoutePostedWhseShipment("Key": Record "Posted Whse. Shipment Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", 'OnServiceItemExtFunc', '', false, false)]
    local procedure RouteServiceItem("Key": Record "Service Item"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable("Key");
        this.Raise(ServiceName, FieldName, RecRef, DeviceID, FieldControlFactory);
    end;

    local procedure Raise(ServiceName: Text[100]; FieldName: Text[75]; var FunctionRecord: RecordRef; DeviceID: Text[190]; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    var
        PageId: Integer;
    begin
        PageId := this.GetPageId(ServiceName);
        this.OnPageFunction(PageId, FieldName, ServiceName, FunctionRecord, DeviceID, FieldControlFactory);
    end;

    /// <summary>
    /// Looks up the MobileNAV service a page is registered under, without refreshing anything.
    /// </summary>
    /// <param name="PageId">The BC page object id to look up.</param>
    /// <returns>The service name of the page's Main row; empty when the page is not registered.</returns>
    procedure GetServiceName(PageId: Integer): Text[100]
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Object ID", PageId);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if not ServiceSetup.FindFirst() then
            exit('');
        exit(ServiceSetup."Service Name");
    end;

    /// <summary>
    /// Looks up the BC page object registered under a MobileNAV service, without refreshing
    /// anything. The reverse lookup of GetServiceName.
    /// </summary>
    /// <param name="ServiceName">The MobileNAV service name to look up.</param>
    /// <returns>The page object id of the service's Main row; 0 when the service is not registered.</returns>
    procedure GetPageId(ServiceName: Text[100]): Integer
    var
        ServiceSetup: Record "MobileNAV Service Setup";
    begin
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        ServiceSetup.SetRange("Service Name", ServiceName);
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        if not ServiceSetup.FindFirst() then
            exit(0);
        exit(ServiceSetup."Object ID");
    end;

    /// <summary>
    /// Invokes the MobileNAV Page Functions dispatcher for SourceRecord's table directly and
    /// converts its result, for use as the one-line body of a consumer page's [ServiceEnabled]
    /// function wrapper.
    /// </summary>
    /// <param name="SourceRecord">The record the device tapped the function control on.</param>
    /// <param name="PageName">The MobileNAV service (page) name the call came in on.</param>
    /// <param name="FieldName">The name of the tapped function control.</param>
    /// <param name="DeviceID">The id of the device the call came from.</param>
    /// <returns>The MobileNAV-formatted result string devices expect back from a function call.</returns>
    procedure Execute(SourceRecord: Variant; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
    var
        MNPageFunc: Codeunit "MobileNAV Page Functions";
        MNResultHelper: Codeunit "MobileNAV Result Helper";
        RecRef: RecordRef;
        Base64Result: BigText;
        FCResult: Text[1024];
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        ServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        Item: Record Item;
        Contact: Record Contact;
        ReturnReceiptHeader: Record "Return Receipt Header";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        Job: Record Job;
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        WarehouseActivityLine: Record "Warehouse Activity Line";
        ApprovalEntry: Record "Approval Entry";
        JobJournalBatch: Record "Job Journal Batch";
        JobJournalLine: Record "Job Journal Line";
        WarehouseReceiptHeader: Record "Warehouse Receipt Header";
        WarehouseReceiptLine: Record "Warehouse Receipt Line";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        ProfileQuestionnaireLine: Record "Profile Questionnaire Line";
        WhseWorksheetLine: Record "Whse. Worksheet Line";
        WarehouseJournalLine: Record "Warehouse Journal Line";
        MNTrackingSpec: Record "MobileNAV Tracking Spec.";
        MNTemporaryData: Record "MobileNAV Temporary Data";
        InteractionLogEntry: Record "Interaction Log Entry";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        WarehouseRequest: Record "Warehouse Request";
        WarehouseJournalBatch: Record "Warehouse Journal Batch";
        PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header";
        ServiceItem: Record "Service Item";
    begin
        RecRef.GetTable(SourceRecord);
        case RecRef.Number of
            Database::"Sales Header":
                begin
                    RecRef.SetTable(SalesHeader);
                    FCResult := CopyStr(MNPageFunc.SalesHeaderExtFunc(SalesHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Sales Line":
                begin
                    RecRef.SetTable(SalesLine);
                    FCResult := CopyStr(MNPageFunc.SalesLineExtFunc(SalesLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Service Item Line":
                begin
                    RecRef.SetTable(ServiceItemLine);
                    FCResult := CopyStr(MNPageFunc.ServiceTaskExtFunc(ServiceItemLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Service Line":
                begin
                    RecRef.SetTable(ServiceLine);
                    FCResult := CopyStr(MNPageFunc.ServiceLineExtFunc(ServiceLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::Item:
                begin
                    RecRef.SetTable(Item);
                    FCResult := CopyStr(MNPageFunc.ItemExtFunc(Item, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::Contact:
                begin
                    RecRef.SetTable(Contact);
                    FCResult := CopyStr(MNPageFunc.ContactExtFunc(Contact, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Return Receipt Header":
                begin
                    RecRef.SetTable(ReturnReceiptHeader);
                    FCResult := CopyStr(MNPageFunc.SalesReturnReceiptExtFunc(ReturnReceiptHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Sales Shipment Header":
                begin
                    RecRef.SetTable(SalesShipmentHeader);
                    FCResult := CopyStr(MNPageFunc.SalesShipmentExtFunc(SalesShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Sales Invoice Header":
                begin
                    RecRef.SetTable(SalesInvoiceHeader);
                    FCResult := CopyStr(MNPageFunc.SalesInvoiceExtFunc(SalesInvoiceHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Sales Cr.Memo Header":
                begin
                    RecRef.SetTable(SalesCrMemoHeader);
                    FCResult := CopyStr(MNPageFunc.SalesCrMemoExtFunc(SalesCrMemoHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::Job:
                begin
                    RecRef.SetTable(Job);
                    FCResult := CopyStr(MNPageFunc.JobExtFunc(Job, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Activity Header":
                begin
                    RecRef.SetTable(WarehouseActivityHeader);
                    FCResult := CopyStr(MNPageFunc.WhseActHdrExtFunc(WarehouseActivityHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Activity Line":
                begin
                    RecRef.SetTable(WarehouseActivityLine);
                    FCResult := CopyStr(MNPageFunc.WhseActLineExtFunc(WarehouseActivityLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Approval Entry":
                begin
                    RecRef.SetTable(ApprovalEntry);
                    FCResult := CopyStr(MNPageFunc.ApprovalEntryExtFunc(ApprovalEntry, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Job Journal Batch":
                begin
                    RecRef.SetTable(JobJournalBatch);
                    FCResult := CopyStr(MNPageFunc.JobJournalBatchExtFunc(JobJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Job Journal Line":
                begin
                    RecRef.SetTable(JobJournalLine);
                    FCResult := CopyStr(MNPageFunc.JobJournalLineExtFunc(JobJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Receipt Header":
                begin
                    RecRef.SetTable(WarehouseReceiptHeader);
                    FCResult := CopyStr(MNPageFunc.WhseReceiptHdrExtFunc(WarehouseReceiptHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Receipt Line":
                begin
                    RecRef.SetTable(WarehouseReceiptLine);
                    FCResult := CopyStr(MNPageFunc.WhseReceiptLineExtFunc(WarehouseReceiptLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Shipment Header":
                begin
                    RecRef.SetTable(WarehouseShipmentHeader);
                    FCResult := CopyStr(MNPageFunc.WhseShpmtHdrExtFunc(WarehouseShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Shipment Line":
                begin
                    RecRef.SetTable(WarehouseShipmentLine);
                    FCResult := CopyStr(MNPageFunc.WhseShpmtLineExtFunc(WarehouseShipmentLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Transfer Header":
                begin
                    RecRef.SetTable(TransferHeader);
                    FCResult := CopyStr(MNPageFunc.TransferHdrExtFunc(TransferHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Transfer Line":
                begin
                    RecRef.SetTable(TransferLine);
                    FCResult := CopyStr(MNPageFunc.TransferLineExtFunc(TransferLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Item Journal Batch":
                begin
                    RecRef.SetTable(ItemJournalBatch);
                    FCResult := CopyStr(MNPageFunc.ItemJrnlBatchExtFunc(ItemJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Item Journal Line":
                begin
                    RecRef.SetTable(ItemJournalLine);
                    FCResult := CopyStr(MNPageFunc.ItemJrnlLineExtFunc(ItemJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Production Order":
                begin
                    RecRef.SetTable(ProductionOrder);
                    FCResult := CopyStr(MNPageFunc.ProdOrderExtFunc(ProductionOrder, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Prod. Order Line":
                begin
                    RecRef.SetTable(ProdOrderLine);
                    FCResult := CopyStr(MNPageFunc.ProdOrderLineExtFunc(ProdOrderLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Purchase Header":
                begin
                    RecRef.SetTable(PurchaseHeader);
                    FCResult := CopyStr(MNPageFunc.PurchHeaderExtFunc(PurchaseHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Purchase Line":
                begin
                    RecRef.SetTable(PurchaseLine);
                    FCResult := CopyStr(MNPageFunc.PurchLineExtFunc(PurchaseLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Profile Questionnaire Line":
                begin
                    RecRef.SetTable(ProfileQuestionnaireLine);
                    FCResult := CopyStr(MNPageFunc.ProfQuestLineExtFunc(ProfileQuestionnaireLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Whse. Worksheet Line":
                begin
                    RecRef.SetTable(WhseWorksheetLine);
                    FCResult := CopyStr(MNPageFunc.WhseWrkshLineExtFunc(WhseWorksheetLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Journal Line":
                begin
                    RecRef.SetTable(WarehouseJournalLine);
                    FCResult := CopyStr(MNPageFunc.WhseJrnlLineExtFunc(WarehouseJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"MobileNAV Tracking Spec.":
                begin
                    RecRef.SetTable(MNTrackingSpec);
                    FCResult := CopyStr(MNPageFunc.MNTrackSpecExtFunc(MNTrackingSpec, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"MobileNAV Temporary Data":
                begin
                    RecRef.SetTable(MNTemporaryData);
                    FCResult := CopyStr(MNPageFunc.MNTempDataExtFunc(MNTemporaryData, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Interaction Log Entry":
                begin
                    RecRef.SetTable(InteractionLogEntry);
                    FCResult := CopyStr(MNPageFunc.MNInteractionLEExtFunc(InteractionLogEntry, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Assembly Header":
                begin
                    RecRef.SetTable(AssemblyHeader);
                    FCResult := CopyStr(MNPageFunc.MNAssemblyOrderExtFunc(AssemblyHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Assembly Line":
                begin
                    RecRef.SetTable(AssemblyLine);
                    FCResult := CopyStr(MNPageFunc.MNAssemblyLineExtFunc(AssemblyLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Request":
                begin
                    RecRef.SetTable(WarehouseRequest);
                    FCResult := CopyStr(MNPageFunc.WhseRequestExtFunc(WarehouseRequest, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Warehouse Journal Batch":
                begin
                    RecRef.SetTable(WarehouseJournalBatch);
                    FCResult := CopyStr(MNPageFunc.WhseJrnlBatchExtFunc(WarehouseJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Posted Whse. Shipment Header":
                begin
                    RecRef.SetTable(PostedWhseShipmentHeader);
                    FCResult := CopyStr(MNPageFunc.PostedWhseShipmentExtFunc(PostedWhseShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            Database::"Service Item":
                begin
                    RecRef.SetTable(ServiceItem);
                    FCResult := CopyStr(MNPageFunc.ServiceItemExtFunc(ServiceItem, PageName, FieldName, DeviceID), 1, MaxStrLen(FCResult));
                end;
            else
                Error(this.UnsupportedTableErr, RecRef.Name);
        end;
        exit(MNResultHelper.ConvertReturnValuesToResult(Base64Result, '', FCResult));
    end;

    var
        UnsupportedTableErr: Label 'MobileNAV Page Functions has no dispatcher for table %1.', Comment = '%1 = table caption';
}
