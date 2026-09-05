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
/// One event for every device button tap. MobileNAV's Page Functions codeunit has one
/// record-typed dispatcher per source table (SalesHeaderExtFunc, ItemExtFunc, ...), each
/// raising its own event. This codeunit subscribes to all of them, resolves the service name
/// to the page id, and republishes a single OnPageFunction carrying the record as a RecordRef,
/// so a consumer writes one subscriber and never hardcodes a service name.
///
/// This is also the one place that knows which dispatcher serves which table: the builder
/// derives a button's function name from it, and Execute lets a page's own [ServiceEnabled]
/// wrapper invoke the dispatcher in one line.
/// </summary>
codeunit 77786 "BJF MN Function Router"
{
    Access = Public;

    /// <summary>Raised for every device button tap, whichever page or table it came from.</summary>
    /// <param name="PageId">The page the tap came in on, resolved from the MobileNAV service name.</param>
    /// <param name="ControlName">The tapped control.</param>
    /// <param name="ServiceName">The MobileNAV service the tap came in on.</param>
    /// <param name="FunctionRecord">The record the button was tapped on; SetTable it to work typed.</param>
    /// <param name="DeviceID">The device the tap came from.</param>
    /// <param name="FieldControlFactory">MobileNAV's result helper; pass it to "MobileNAV Object Functions" calls such as FcMessage or FcRefresh to answer the device.</param>
    // The public event is the consumer contract of this app.
#pragma warning disable AC0024
    [IntegrationEvent(false, false)]
    procedure OnPageFunction(PageId: Integer; ControlName: Text[75]; ServiceName: Text[100]; FunctionRecord: RecordRef; DeviceID: Text[190]; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    begin
    end;
#pragma warning restore AC0024

    /// <summary>The MobileNAV service a page is registered under; empty when it is not registered.</summary>
    procedure GetServiceName(PageId: Integer): Text[100]
    begin
        exit(this.Lookup.GetServiceName(PageId));
    end;

    /// <summary>The page registered under a MobileNAV service; 0 when the service is not registered.</summary>
    procedure GetPageId(ServiceName: Text[100]): Integer
    begin
        exit(this.Lookup.GetPageId(ServiceName));
    end;

    /// <summary>
    /// The MobileNAV Page Functions dispatcher that serves a source table, for example
    /// 'SalesHeaderExtFunc' for Sales Header. The names are MobileNAV's own procedure names.
    /// </summary>
    /// <returns>False when MobileNAV has no dispatcher for the table.</returns>
    internal procedure TryGetDispatcher(TableNo: Integer; var DispatcherName: Text[50]): Boolean
    begin
        case TableNo of
            Database::"Sales Header":
                DispatcherName := 'SalesHeaderExtFunc';
            Database::"Sales Line":
                DispatcherName := 'SalesLineExtFunc';
            Database::"Service Item Line":
                DispatcherName := 'ServiceTaskExtFunc';
            Database::"Service Line":
                DispatcherName := 'ServiceLineExtFunc';
            Database::Item:
                DispatcherName := 'ItemExtFunc';
            Database::Contact:
                DispatcherName := 'ContactExtFunc';
            Database::"Return Receipt Header":
                DispatcherName := 'SalesReturnReceiptExtFunc';
            Database::"Sales Shipment Header":
                DispatcherName := 'SalesShipmentExtFunc';
            Database::"Sales Invoice Header":
                DispatcherName := 'SalesInvoiceExtFunc';
            Database::"Sales Cr.Memo Header":
                DispatcherName := 'SalesCrMemoExtFunc';
            Database::Job:
                DispatcherName := 'JobExtFunc';
            Database::"Warehouse Activity Header":
                DispatcherName := 'WhseActHdrExtFunc';
            Database::"Warehouse Activity Line":
                DispatcherName := 'WhseActLineExtFunc';
            Database::"Approval Entry":
                DispatcherName := 'ApprovalEntryExtFunc';
            Database::"Job Journal Batch":
                DispatcherName := 'JobJournalBatchExtFunc';
            Database::"Job Journal Line":
                DispatcherName := 'JobJournalLineExtFunc';
            Database::"Warehouse Receipt Header":
                DispatcherName := 'WhseReceiptHdrExtFunc';
            Database::"Warehouse Receipt Line":
                DispatcherName := 'WhseReceiptLineExtFunc';
            Database::"Warehouse Shipment Header":
                DispatcherName := 'WhseShpmtHdrExtFunc';
            Database::"Warehouse Shipment Line":
                DispatcherName := 'WhseShpmtLineExtFunc';
            Database::"Transfer Header":
                DispatcherName := 'TransferHdrExtFunc';
            Database::"Transfer Line":
                DispatcherName := 'TransferLineExtFunc';
            Database::"Item Journal Batch":
                DispatcherName := 'ItemJrnlBatchExtFunc';
            Database::"Item Journal Line":
                DispatcherName := 'ItemJrnlLineExtFunc';
            Database::"Production Order":
                DispatcherName := 'ProdOrderExtFunc';
            Database::"Prod. Order Line":
                DispatcherName := 'ProdOrderLineExtFunc';
            Database::"Purchase Header":
                DispatcherName := 'PurchHeaderExtFunc';
            Database::"Purchase Line":
                DispatcherName := 'PurchLineExtFunc';
            Database::"Profile Questionnaire Line":
                DispatcherName := 'ProfQuestLineExtFunc';
            Database::"Whse. Worksheet Line":
                DispatcherName := 'WhseWrkshLineExtFunc';
            Database::"Warehouse Journal Line":
                DispatcherName := 'WhseJrnlLineExtFunc';
            Database::"MobileNAV Tracking Spec.":
                DispatcherName := 'MNTrackSpecExtFunc';
            Database::"MobileNAV Temporary Data":
                DispatcherName := 'MNTempDataExtFunc';
            Database::"Interaction Log Entry":
                DispatcherName := 'MNInteractionLEExtFunc';
            Database::"Assembly Header":
                DispatcherName := 'MNAssemblyOrderExtFunc';
            Database::"Assembly Line":
                DispatcherName := 'MNAssemblyLineExtFunc';
            Database::"Warehouse Request":
                DispatcherName := 'WhseRequestExtFunc';
            Database::"Warehouse Journal Batch":
                DispatcherName := 'WhseJrnlBatchExtFunc';
            Database::"Posted Whse. Shipment Header":
                DispatcherName := 'PostedWhseShipmentExtFunc';
            Database::"Service Item":
                DispatcherName := 'ServiceItemExtFunc';
            else begin
                DispatcherName := '';
                exit(false);
            end;
        end;
        exit(true);
    end;

    /// <summary>
    /// Invokes the MobileNAV Page Functions dispatcher for the record's table and converts its
    /// result: the one-line body of a page's own [ServiceEnabled] function wrapper.
    /// </summary>
    /// <param name="SourceRecord">The record the device tapped the button on.</param>
    /// <param name="PageName">The MobileNAV service the call came in on.</param>
    /// <param name="FieldName">The tapped control.</param>
    /// <param name="DeviceID">The device the call came from.</param>
    /// <returns>The result text devices expect back from a function call.</returns>
    procedure Execute(SourceRecord: Variant; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]): Text
    var
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
        MobileNAVTrackingSpec: Record "MobileNAV Tracking Spec.";
        MobileNAVTemporaryData: Record "MobileNAV Temporary Data";
        InteractionLogEntry: Record "Interaction Log Entry";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
        WarehouseRequest: Record "Warehouse Request";
        WarehouseJournalBatch: Record "Warehouse Journal Batch";
        PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header";
        ServiceItem: Record "Service Item";
        PageFunctions: Codeunit "MobileNAV Page Functions";
        ResultHelper: Codeunit "MobileNAV Result Helper";
        Base64Result: BigText;
        RecRef: RecordRef;
        FunctionResult: Text[1024];
    begin
        RecRef.GetTable(SourceRecord);
        case RecRef.Number() of
            Database::"Sales Header":
                begin
                    RecRef.SetTable(SalesHeader);
                    FunctionResult := CopyStr(PageFunctions.SalesHeaderExtFunc(SalesHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Line":
                begin
                    RecRef.SetTable(SalesLine);
                    FunctionResult := CopyStr(PageFunctions.SalesLineExtFunc(SalesLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Service Item Line":
                begin
                    RecRef.SetTable(ServiceItemLine);
                    FunctionResult := CopyStr(PageFunctions.ServiceTaskExtFunc(ServiceItemLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Service Line":
                begin
                    RecRef.SetTable(ServiceLine);
                    FunctionResult := CopyStr(PageFunctions.ServiceLineExtFunc(ServiceLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::Item:
                begin
                    RecRef.SetTable(Item);
                    FunctionResult := CopyStr(PageFunctions.ItemExtFunc(Item, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::Contact:
                begin
                    RecRef.SetTable(Contact);
                    FunctionResult := CopyStr(PageFunctions.ContactExtFunc(Contact, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Return Receipt Header":
                begin
                    RecRef.SetTable(ReturnReceiptHeader);
                    FunctionResult := CopyStr(PageFunctions.SalesReturnReceiptExtFunc(ReturnReceiptHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Shipment Header":
                begin
                    RecRef.SetTable(SalesShipmentHeader);
                    FunctionResult := CopyStr(PageFunctions.SalesShipmentExtFunc(SalesShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Invoice Header":
                begin
                    RecRef.SetTable(SalesInvoiceHeader);
                    FunctionResult := CopyStr(PageFunctions.SalesInvoiceExtFunc(SalesInvoiceHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Cr.Memo Header":
                begin
                    RecRef.SetTable(SalesCrMemoHeader);
                    FunctionResult := CopyStr(PageFunctions.SalesCrMemoExtFunc(SalesCrMemoHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::Job:
                begin
                    RecRef.SetTable(Job);
                    FunctionResult := CopyStr(PageFunctions.JobExtFunc(Job, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Activity Header":
                begin
                    RecRef.SetTable(WarehouseActivityHeader);
                    FunctionResult := CopyStr(PageFunctions.WhseActHdrExtFunc(WarehouseActivityHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Activity Line":
                begin
                    RecRef.SetTable(WarehouseActivityLine);
                    FunctionResult := CopyStr(PageFunctions.WhseActLineExtFunc(WarehouseActivityLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Approval Entry":
                begin
                    RecRef.SetTable(ApprovalEntry);
                    FunctionResult := CopyStr(PageFunctions.ApprovalEntryExtFunc(ApprovalEntry, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Job Journal Batch":
                begin
                    RecRef.SetTable(JobJournalBatch);
                    FunctionResult := CopyStr(PageFunctions.JobJournalBatchExtFunc(JobJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Job Journal Line":
                begin
                    RecRef.SetTable(JobJournalLine);
                    FunctionResult := CopyStr(PageFunctions.JobJournalLineExtFunc(JobJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Receipt Header":
                begin
                    RecRef.SetTable(WarehouseReceiptHeader);
                    FunctionResult := CopyStr(PageFunctions.WhseReceiptHdrExtFunc(WarehouseReceiptHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Receipt Line":
                begin
                    RecRef.SetTable(WarehouseReceiptLine);
                    FunctionResult := CopyStr(PageFunctions.WhseReceiptLineExtFunc(WarehouseReceiptLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Shipment Header":
                begin
                    RecRef.SetTable(WarehouseShipmentHeader);
                    FunctionResult := CopyStr(PageFunctions.WhseShpmtHdrExtFunc(WarehouseShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Shipment Line":
                begin
                    RecRef.SetTable(WarehouseShipmentLine);
                    FunctionResult := CopyStr(PageFunctions.WhseShpmtLineExtFunc(WarehouseShipmentLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Transfer Header":
                begin
                    RecRef.SetTable(TransferHeader);
                    FunctionResult := CopyStr(PageFunctions.TransferHdrExtFunc(TransferHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Transfer Line":
                begin
                    RecRef.SetTable(TransferLine);
                    FunctionResult := CopyStr(PageFunctions.TransferLineExtFunc(TransferLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Item Journal Batch":
                begin
                    RecRef.SetTable(ItemJournalBatch);
                    FunctionResult := CopyStr(PageFunctions.ItemJrnlBatchExtFunc(ItemJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Item Journal Line":
                begin
                    RecRef.SetTable(ItemJournalLine);
                    FunctionResult := CopyStr(PageFunctions.ItemJrnlLineExtFunc(ItemJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Production Order":
                begin
                    RecRef.SetTable(ProductionOrder);
                    FunctionResult := CopyStr(PageFunctions.ProdOrderExtFunc(ProductionOrder, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Prod. Order Line":
                begin
                    RecRef.SetTable(ProdOrderLine);
                    FunctionResult := CopyStr(PageFunctions.ProdOrderLineExtFunc(ProdOrderLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Purchase Header":
                begin
                    RecRef.SetTable(PurchaseHeader);
                    FunctionResult := CopyStr(PageFunctions.PurchHeaderExtFunc(PurchaseHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Purchase Line":
                begin
                    RecRef.SetTable(PurchaseLine);
                    FunctionResult := CopyStr(PageFunctions.PurchLineExtFunc(PurchaseLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Profile Questionnaire Line":
                begin
                    RecRef.SetTable(ProfileQuestionnaireLine);
                    FunctionResult := CopyStr(PageFunctions.ProfQuestLineExtFunc(ProfileQuestionnaireLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Whse. Worksheet Line":
                begin
                    RecRef.SetTable(WhseWorksheetLine);
                    FunctionResult := CopyStr(PageFunctions.WhseWrkshLineExtFunc(WhseWorksheetLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Journal Line":
                begin
                    RecRef.SetTable(WarehouseJournalLine);
                    FunctionResult := CopyStr(PageFunctions.WhseJrnlLineExtFunc(WarehouseJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"MobileNAV Tracking Spec.":
                begin
                    RecRef.SetTable(MobileNAVTrackingSpec);
                    FunctionResult := CopyStr(PageFunctions.MNTrackSpecExtFunc(MobileNAVTrackingSpec, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"MobileNAV Temporary Data":
                begin
                    RecRef.SetTable(MobileNAVTemporaryData);
                    FunctionResult := CopyStr(PageFunctions.MNTempDataExtFunc(MobileNAVTemporaryData, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Interaction Log Entry":
                begin
                    RecRef.SetTable(InteractionLogEntry);
                    FunctionResult := CopyStr(PageFunctions.MNInteractionLEExtFunc(InteractionLogEntry, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Assembly Header":
                begin
                    RecRef.SetTable(AssemblyHeader);
                    FunctionResult := CopyStr(PageFunctions.MNAssemblyOrderExtFunc(AssemblyHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Assembly Line":
                begin
                    RecRef.SetTable(AssemblyLine);
                    FunctionResult := CopyStr(PageFunctions.MNAssemblyLineExtFunc(AssemblyLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Request":
                begin
                    RecRef.SetTable(WarehouseRequest);
                    FunctionResult := CopyStr(PageFunctions.WhseRequestExtFunc(WarehouseRequest, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Journal Batch":
                begin
                    RecRef.SetTable(WarehouseJournalBatch);
                    FunctionResult := CopyStr(PageFunctions.WhseJrnlBatchExtFunc(WarehouseJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Posted Whse. Shipment Header":
                begin
                    RecRef.SetTable(PostedWhseShipmentHeader);
                    FunctionResult := CopyStr(PageFunctions.PostedWhseShipmentExtFunc(PostedWhseShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Service Item":
                begin
                    RecRef.SetTable(ServiceItem);
                    FunctionResult := CopyStr(PageFunctions.ServiceItemExtFunc(ServiceItem, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                Error(this.UnsupportedTableErr, RecRef.Name());
        end;
        exit(ResultHelper.ConvertReturnValuesToResult(Base64Result, '', FunctionResult));
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnSalesHeaderExtFunc, '', false, false)]
    local procedure RouteSalesHeader("Key": Record "Sales Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnSalesLineExtFunc, '', false, false)]
    local procedure RouteSalesLine("Key": Record "Sales Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnServiceTaskExtFunc, '', false, false)]
    local procedure RouteServiceTask("Key": Record "Service Item Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnServiceLineExtFunc, '', false, false)]
    local procedure RouteServiceLine("Key": Record "Service Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnItemExtFunc, '', false, false)]
    local procedure RouteItem("Key": Record Item; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnContactExtFunc, '', false, false)]
    local procedure RouteContact("Key": Record Contact; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnSalesReturnReceiptExtFunc, '', false, false)]
    local procedure RouteSalesReturnReceipt("Key": Record "Return Receipt Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnSalesShipmentExtFunc, '', false, false)]
    local procedure RouteSalesShipment("Key": Record "Sales Shipment Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnSalesInvoiceExtFunc, '', false, false)]
    local procedure RouteSalesInvoice("Key": Record "Sales Invoice Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnSalesCrMemoExtFunc, '', false, false)]
    local procedure RouteSalesCrMemo("Key": Record "Sales Cr.Memo Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnJobExtFunc, '', false, false)]
    local procedure RouteJob("Key": Record Job; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseActHdrExtFunc, '', false, false)]
    local procedure RouteWhseActHdr("Key": Record "Warehouse Activity Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseActLineExtFunc, '', false, false)]
    local procedure RouteWhseActLine("Key": Record "Warehouse Activity Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnApprovalEntryExtFunc, '', false, false)]
    local procedure RouteApprovalEntry("Key": Record "Approval Entry"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnJobJournalBatchExtFunc, '', false, false)]
    local procedure RouteJobJournalBatch("Key": Record "Job Journal Batch"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnJobJournalLineExtFunc, '', false, false)]
    local procedure RouteJobJournalLine("Key": Record "Job Journal Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseReceiptHdrExtFunc, '', false, false)]
    local procedure RouteWhseReceiptHdr("Key": Record "Warehouse Receipt Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseReceiptLineExtFunc, '', false, false)]
    local procedure RouteWhseReceiptLine("Key": Record "Warehouse Receipt Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseShpmtHdrExtFunc, '', false, false)]
    local procedure RouteWhseShpmtHdr("Key": Record "Warehouse Shipment Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseShpmtLineExtFunc, '', false, false)]
    local procedure RouteWhseShpmtLine("Key": Record "Warehouse Shipment Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnTransferHdrExtFunc, '', false, false)]
    local procedure RouteTransferHdr("Key": Record "Transfer Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnTransferLineExtFunc, '', false, false)]
    local procedure RouteTransferLine("Key": Record "Transfer Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnItemJrnlBatchExtFunc, '', false, false)]
    local procedure RouteItemJrnlBatch("Key": Record "Item Journal Batch"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnItemJrnlLineExtFunc, '', false, false)]
    local procedure RouteItemJrnlLine("Key": Record "Item Journal Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnProdOrderExtFunc, '', false, false)]
    local procedure RouteProdOrder("Key": Record "Production Order"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnProdOrderLineExtFunc, '', false, false)]
    local procedure RouteProdOrderLine("Key": Record "Prod. Order Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnPurchHeaderExtFunc, '', false, false)]
    local procedure RoutePurchHeader("Key": Record "Purchase Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnPurchLineExtFunc, '', false, false)]
    local procedure RoutePurchLine("Key": Record "Purchase Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnProfQuestLineExtFunc, '', false, false)]
    local procedure RouteProfQuestLine("Key": Record "Profile Questionnaire Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseWrkshLineExtFunc, '', false, false)]
    local procedure RouteWhseWrkshLine("Key": Record "Whse. Worksheet Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseJrnlLineExtFunc, '', false, false)]
    local procedure RouteWhseJrnlLine("Key": Record "Warehouse Journal Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnMNTrackSpecExtFunc, '', false, false)]
    local procedure RouteMNTrackSpec("Key": Record "MobileNAV Tracking Spec."; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnMNTempDataExtFunc, '', false, false)]
    local procedure RouteMNTempData("Key": Record "MobileNAV Temporary Data"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnInteractionLEExtFunc, '', false, false)]
    local procedure RouteMNInteractionLE("Key": Record "Interaction Log Entry"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnAssemblyOrderExtFunc, '', false, false)]
    local procedure RouteMNAssemblyOrder("Key": Record "Assembly Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnAssemblyLineExtFunc, '', false, false)]
    local procedure RouteMNAssemblyLine("Key": Record "Assembly Line"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseRequestExtFunc, '', false, false)]
    local procedure RouteWhseRequest("Key": Record "Warehouse Request"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnWhseJrnlBatchExtFunc, '', false, false)]
    local procedure RouteWhseJrnlBatch("Key": Record "Warehouse Journal Batch"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnPostedWhseShipmentExtFunc, '', false, false)]
    local procedure RoutePostedWhseShipment("Key": Record "Posted Whse. Shipment Header"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"MobileNAV Page Functions", OnServiceItemExtFunc, '', false, false)]
    local procedure RouteServiceItem("Key": Record "Service Item"; ServiceName: Text[100]; FieldName: Text[75]; var FieldControlFactory: Codeunit "MobileNAV Object Functions"; DeviceID: Text[190])
    begin
        this.Raise("Key", ServiceName, FieldName, DeviceID, FieldControlFactory);
    end;

    local procedure Raise(SourceRecord: Variant; ServiceName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable(SourceRecord);
        this.OnPageFunction(this.Lookup.GetPageId(ServiceName), FieldName, ServiceName, RecRef, DeviceID, FieldControlFactory);
    end;

    var
        Lookup: Codeunit "BJF MN Service Lookup";
        UnsupportedTableErr: Label 'MobileNAV Page Functions has no dispatcher for table %1.', Comment = '%1 = table name';
}
