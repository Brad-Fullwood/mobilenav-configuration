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
    /// Looked up from a dictionary built once on first use, to keep this a single branch
    /// instead of a 40-way case.
    /// </summary>
    /// <returns>False when MobileNAV has no dispatcher for the table.</returns>
    internal procedure TryGetDispatcher(TableNo: Integer; var DispatcherName: Text[50]): Boolean
    begin
        if this.DispatcherNames.Count() = 0 then
            this.LoadDispatcherNames();
        exit(this.DispatcherNames.Get(TableNo, DispatcherName));
    end;

    /// <summary>Table-to-dispatcher-name pairs for TryGetDispatcher, kept out of it so that procedure stays a single branch.</summary>
    local procedure LoadDispatcherNames()
    begin
        this.DispatcherNames.Add(Database::"Sales Header", 'SalesHeaderExtFunc');
        this.DispatcherNames.Add(Database::"Sales Line", 'SalesLineExtFunc');
        this.DispatcherNames.Add(Database::"Service Item Line", 'ServiceTaskExtFunc');
        this.DispatcherNames.Add(Database::"Service Line", 'ServiceLineExtFunc');
        this.DispatcherNames.Add(Database::Item, 'ItemExtFunc');
        this.DispatcherNames.Add(Database::Contact, 'ContactExtFunc');
        this.DispatcherNames.Add(Database::"Return Receipt Header", 'SalesReturnReceiptExtFunc');
        this.DispatcherNames.Add(Database::"Sales Shipment Header", 'SalesShipmentExtFunc');
        this.DispatcherNames.Add(Database::"Sales Invoice Header", 'SalesInvoiceExtFunc');
        this.DispatcherNames.Add(Database::"Sales Cr.Memo Header", 'SalesCrMemoExtFunc');
        this.DispatcherNames.Add(Database::Job, 'JobExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Activity Header", 'WhseActHdrExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Activity Line", 'WhseActLineExtFunc');
        this.DispatcherNames.Add(Database::"Approval Entry", 'ApprovalEntryExtFunc');
        this.DispatcherNames.Add(Database::"Job Journal Batch", 'JobJournalBatchExtFunc');
        this.DispatcherNames.Add(Database::"Job Journal Line", 'JobJournalLineExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Receipt Header", 'WhseReceiptHdrExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Receipt Line", 'WhseReceiptLineExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Shipment Header", 'WhseShpmtHdrExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Shipment Line", 'WhseShpmtLineExtFunc');
        this.DispatcherNames.Add(Database::"Transfer Header", 'TransferHdrExtFunc');
        this.DispatcherNames.Add(Database::"Transfer Line", 'TransferLineExtFunc');
        this.DispatcherNames.Add(Database::"Item Journal Batch", 'ItemJrnlBatchExtFunc');
        this.DispatcherNames.Add(Database::"Item Journal Line", 'ItemJrnlLineExtFunc');
        this.DispatcherNames.Add(Database::"Production Order", 'ProdOrderExtFunc');
        this.DispatcherNames.Add(Database::"Prod. Order Line", 'ProdOrderLineExtFunc');
        this.DispatcherNames.Add(Database::"Purchase Header", 'PurchHeaderExtFunc');
        this.DispatcherNames.Add(Database::"Purchase Line", 'PurchLineExtFunc');
        this.DispatcherNames.Add(Database::"Profile Questionnaire Line", 'ProfQuestLineExtFunc');
        this.DispatcherNames.Add(Database::"Whse. Worksheet Line", 'WhseWrkshLineExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Journal Line", 'WhseJrnlLineExtFunc');
        this.DispatcherNames.Add(Database::"MobileNAV Tracking Spec.", 'MNTrackSpecExtFunc');
        this.DispatcherNames.Add(Database::"MobileNAV Temporary Data", 'MNTempDataExtFunc');
        this.DispatcherNames.Add(Database::"Interaction Log Entry", 'MNInteractionLEExtFunc');
        this.DispatcherNames.Add(Database::"Assembly Header", 'MNAssemblyOrderExtFunc');
        this.DispatcherNames.Add(Database::"Assembly Line", 'MNAssemblyLineExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Request", 'WhseRequestExtFunc');
        this.DispatcherNames.Add(Database::"Warehouse Journal Batch", 'WhseJrnlBatchExtFunc');
        this.DispatcherNames.Add(Database::"Posted Whse. Shipment Header", 'PostedWhseShipmentExtFunc');
        this.DispatcherNames.Add(Database::"Service Item", 'ServiceItemExtFunc');
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
        ResultHelper: Codeunit "MobileNAV Result Helper";
        Base64Result: BigText;
        RecRef: RecordRef;
        FunctionResult: Text[1024];
    begin
        RecRef.GetTable(SourceRecord);
        if not this.TryExecute(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            Error(this.UnsupportedTableErr, RecRef.Name());
        exit(ResultHelper.ConvertReturnValuesToResult(Base64Result, '', FunctionResult));
    end;

    // The dispatchers are typed, so the call cannot be table-driven: one small case per
    // business area instead, each handling its tables and reporting whether it did.
    local procedure TryExecute(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    begin
        if this.TryExecuteSalesAndPurchase(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteWarehouse(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteInventoryAndProduction(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteServiceProjectsAndCrm(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        exit(false);
    end;

    local procedure TryExecuteSalesAndPurchase(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    begin
        if this.TryExecuteSales(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecutePurchaseAndTransfer(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        exit(false);
    end;

    local procedure TryExecuteWarehouse(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    begin
        if this.TryExecuteWarehouseDocuments(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteWarehouseJournals(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        exit(false);
    end;

    local procedure TryExecuteInventoryAndProduction(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    begin
        if this.TryExecuteItemJournals(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteProduction(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        exit(false);
    end;

    local procedure TryExecuteServiceProjectsAndCrm(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    begin
        if this.TryExecuteService(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteProjects(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteCrm(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        if this.TryExecuteApprovalsAndMobileNAV(RecRef, PageName, FieldName, DeviceID, FunctionResult) then
            exit(true);
        exit(false);
    end;

    local procedure TryExecuteSales(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        SalesHeader: Record "Sales Header";
        SalesLine: Record "Sales Line";
        SalesShipmentHeader: Record "Sales Shipment Header";
        SalesInvoiceHeader: Record "Sales Invoice Header";
        SalesCrMemoHeader: Record "Sales Cr.Memo Header";
        ReturnReceiptHeader: Record "Return Receipt Header";
    begin
        case RecRef.Number() of
            Database::"Sales Header":
                begin
                    RecRef.SetTable(SalesHeader);
                    FunctionResult := CopyStr(this.PageFunctions.SalesHeaderExtFunc(SalesHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Line":
                begin
                    RecRef.SetTable(SalesLine);
                    FunctionResult := CopyStr(this.PageFunctions.SalesLineExtFunc(SalesLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Shipment Header":
                begin
                    RecRef.SetTable(SalesShipmentHeader);
                    FunctionResult := CopyStr(this.PageFunctions.SalesShipmentExtFunc(SalesShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Invoice Header":
                begin
                    RecRef.SetTable(SalesInvoiceHeader);
                    FunctionResult := CopyStr(this.PageFunctions.SalesInvoiceExtFunc(SalesInvoiceHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Sales Cr.Memo Header":
                begin
                    RecRef.SetTable(SalesCrMemoHeader);
                    FunctionResult := CopyStr(this.PageFunctions.SalesCrMemoExtFunc(SalesCrMemoHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Return Receipt Header":
                begin
                    RecRef.SetTable(ReturnReceiptHeader);
                    FunctionResult := CopyStr(this.PageFunctions.SalesReturnReceiptExtFunc(ReturnReceiptHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecutePurchaseAndTransfer(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        PurchaseHeader: Record "Purchase Header";
        PurchaseLine: Record "Purchase Line";
        TransferHeader: Record "Transfer Header";
        TransferLine: Record "Transfer Line";
    begin
        case RecRef.Number() of
            Database::"Purchase Header":
                begin
                    RecRef.SetTable(PurchaseHeader);
                    FunctionResult := CopyStr(this.PageFunctions.PurchHeaderExtFunc(PurchaseHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Purchase Line":
                begin
                    RecRef.SetTable(PurchaseLine);
                    FunctionResult := CopyStr(this.PageFunctions.PurchLineExtFunc(PurchaseLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Transfer Header":
                begin
                    RecRef.SetTable(TransferHeader);
                    FunctionResult := CopyStr(this.PageFunctions.TransferHdrExtFunc(TransferHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Transfer Line":
                begin
                    RecRef.SetTable(TransferLine);
                    FunctionResult := CopyStr(this.PageFunctions.TransferLineExtFunc(TransferLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteWarehouseDocuments(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        WarehouseActivityLine: Record "Warehouse Activity Line";
        WarehouseReceiptHeader: Record "Warehouse Receipt Header";
        WarehouseReceiptLine: Record "Warehouse Receipt Line";
        WarehouseShipmentHeader: Record "Warehouse Shipment Header";
        WarehouseShipmentLine: Record "Warehouse Shipment Line";
    begin
        case RecRef.Number() of
            Database::"Warehouse Activity Header":
                begin
                    RecRef.SetTable(WarehouseActivityHeader);
                    FunctionResult := CopyStr(this.PageFunctions.WhseActHdrExtFunc(WarehouseActivityHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Activity Line":
                begin
                    RecRef.SetTable(WarehouseActivityLine);
                    FunctionResult := CopyStr(this.PageFunctions.WhseActLineExtFunc(WarehouseActivityLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Receipt Header":
                begin
                    RecRef.SetTable(WarehouseReceiptHeader);
                    FunctionResult := CopyStr(this.PageFunctions.WhseReceiptHdrExtFunc(WarehouseReceiptHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Receipt Line":
                begin
                    RecRef.SetTable(WarehouseReceiptLine);
                    FunctionResult := CopyStr(this.PageFunctions.WhseReceiptLineExtFunc(WarehouseReceiptLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Shipment Header":
                begin
                    RecRef.SetTable(WarehouseShipmentHeader);
                    FunctionResult := CopyStr(this.PageFunctions.WhseShpmtHdrExtFunc(WarehouseShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Shipment Line":
                begin
                    RecRef.SetTable(WarehouseShipmentLine);
                    FunctionResult := CopyStr(this.PageFunctions.WhseShpmtLineExtFunc(WarehouseShipmentLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteWarehouseJournals(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        PostedWhseShipmentHeader: Record "Posted Whse. Shipment Header";
        WarehouseRequest: Record "Warehouse Request";
        WarehouseJournalBatch: Record "Warehouse Journal Batch";
        WarehouseJournalLine: Record "Warehouse Journal Line";
        WhseWorksheetLine: Record "Whse. Worksheet Line";
    begin
        case RecRef.Number() of
            Database::"Posted Whse. Shipment Header":
                begin
                    RecRef.SetTable(PostedWhseShipmentHeader);
                    FunctionResult := CopyStr(this.PageFunctions.PostedWhseShipmentExtFunc(PostedWhseShipmentHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Request":
                begin
                    RecRef.SetTable(WarehouseRequest);
                    FunctionResult := CopyStr(this.PageFunctions.WhseRequestExtFunc(WarehouseRequest, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Journal Batch":
                begin
                    RecRef.SetTable(WarehouseJournalBatch);
                    FunctionResult := CopyStr(this.PageFunctions.WhseJrnlBatchExtFunc(WarehouseJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Warehouse Journal Line":
                begin
                    RecRef.SetTable(WarehouseJournalLine);
                    FunctionResult := CopyStr(this.PageFunctions.WhseJrnlLineExtFunc(WarehouseJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Whse. Worksheet Line":
                begin
                    RecRef.SetTable(WhseWorksheetLine);
                    FunctionResult := CopyStr(this.PageFunctions.WhseWrkshLineExtFunc(WhseWorksheetLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteItemJournals(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        Item: Record Item;
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
    begin
        case RecRef.Number() of
            Database::Item:
                begin
                    RecRef.SetTable(Item);
                    FunctionResult := CopyStr(this.PageFunctions.ItemExtFunc(Item, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Item Journal Batch":
                begin
                    RecRef.SetTable(ItemJournalBatch);
                    FunctionResult := CopyStr(this.PageFunctions.ItemJrnlBatchExtFunc(ItemJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Item Journal Line":
                begin
                    RecRef.SetTable(ItemJournalLine);
                    FunctionResult := CopyStr(this.PageFunctions.ItemJrnlLineExtFunc(ItemJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteProduction(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        ProductionOrder: Record "Production Order";
        ProdOrderLine: Record "Prod. Order Line";
        AssemblyHeader: Record "Assembly Header";
        AssemblyLine: Record "Assembly Line";
    begin
        case RecRef.Number() of
            Database::"Production Order":
                begin
                    RecRef.SetTable(ProductionOrder);
                    FunctionResult := CopyStr(this.PageFunctions.ProdOrderExtFunc(ProductionOrder, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Prod. Order Line":
                begin
                    RecRef.SetTable(ProdOrderLine);
                    FunctionResult := CopyStr(this.PageFunctions.ProdOrderLineExtFunc(ProdOrderLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Assembly Header":
                begin
                    RecRef.SetTable(AssemblyHeader);
                    FunctionResult := CopyStr(this.PageFunctions.MNAssemblyOrderExtFunc(AssemblyHeader, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Assembly Line":
                begin
                    RecRef.SetTable(AssemblyLine);
                    FunctionResult := CopyStr(this.PageFunctions.MNAssemblyLineExtFunc(AssemblyLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteService(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        ServiceItemLine: Record "Service Item Line";
        ServiceLine: Record "Service Line";
        ServiceItem: Record "Service Item";
    begin
        case RecRef.Number() of
            Database::"Service Item Line":
                begin
                    RecRef.SetTable(ServiceItemLine);
                    FunctionResult := CopyStr(this.PageFunctions.ServiceTaskExtFunc(ServiceItemLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Service Line":
                begin
                    RecRef.SetTable(ServiceLine);
                    FunctionResult := CopyStr(this.PageFunctions.ServiceLineExtFunc(ServiceLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Service Item":
                begin
                    RecRef.SetTable(ServiceItem);
                    FunctionResult := CopyStr(this.PageFunctions.ServiceItemExtFunc(ServiceItem, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteProjects(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        Job: Record Job;
        JobJournalBatch: Record "Job Journal Batch";
        JobJournalLine: Record "Job Journal Line";
    begin
        case RecRef.Number() of
            Database::Job:
                begin
                    RecRef.SetTable(Job);
                    FunctionResult := CopyStr(this.PageFunctions.JobExtFunc(Job, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Job Journal Batch":
                begin
                    RecRef.SetTable(JobJournalBatch);
                    FunctionResult := CopyStr(this.PageFunctions.JobJournalBatchExtFunc(JobJournalBatch, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Job Journal Line":
                begin
                    RecRef.SetTable(JobJournalLine);
                    FunctionResult := CopyStr(this.PageFunctions.JobJournalLineExtFunc(JobJournalLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteCrm(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        Contact: Record Contact;
        InteractionLogEntry: Record "Interaction Log Entry";
        ProfileQuestionnaireLine: Record "Profile Questionnaire Line";
    begin
        case RecRef.Number() of
            Database::Contact:
                begin
                    RecRef.SetTable(Contact);
                    FunctionResult := CopyStr(this.PageFunctions.ContactExtFunc(Contact, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Interaction Log Entry":
                begin
                    RecRef.SetTable(InteractionLogEntry);
                    FunctionResult := CopyStr(this.PageFunctions.MNInteractionLEExtFunc(InteractionLogEntry, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"Profile Questionnaire Line":
                begin
                    RecRef.SetTable(ProfileQuestionnaireLine);
                    FunctionResult := CopyStr(this.PageFunctions.ProfQuestLineExtFunc(ProfileQuestionnaireLine, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
    end;

    local procedure TryExecuteApprovalsAndMobileNAV(var RecRef: RecordRef; PageName: Text[100]; FieldName: Text[75]; DeviceID: Text[190]; var FunctionResult: Text[1024]): Boolean
    var
        ApprovalEntry: Record "Approval Entry";
        MobileNAVTrackingSpec: Record "MobileNAV Tracking Spec.";
        MobileNAVTemporaryData: Record "MobileNAV Temporary Data";
    begin
        case RecRef.Number() of
            Database::"Approval Entry":
                begin
                    RecRef.SetTable(ApprovalEntry);
                    FunctionResult := CopyStr(this.PageFunctions.ApprovalEntryExtFunc(ApprovalEntry, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"MobileNAV Tracking Spec.":
                begin
                    RecRef.SetTable(MobileNAVTrackingSpec);
                    FunctionResult := CopyStr(this.PageFunctions.MNTrackSpecExtFunc(MobileNAVTrackingSpec, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            Database::"MobileNAV Temporary Data":
                begin
                    RecRef.SetTable(MobileNAVTemporaryData);
                    FunctionResult := CopyStr(this.PageFunctions.MNTempDataExtFunc(MobileNAVTemporaryData, PageName, FieldName, DeviceID), 1, MaxStrLen(FunctionResult));
                end;
            else
                exit(false);
        end;
        exit(true);
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
        PageFunctions: Codeunit "MobileNAV Page Functions";
        DispatcherNames: Dictionary of [Integer, Text[50]];
        UnsupportedTableErr: Label 'MobileNAV Page Functions has no dispatcher for table %1.', Comment = '%1 = table name';
}
