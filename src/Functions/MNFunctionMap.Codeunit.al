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
/// Maps a page's source table to the name of the MobileNAV Page Functions procedure that
/// dispatches record-level function ("ExtFunc") calls for that table. The names returned are
/// MobileNAV's own procedure names on codeunit "MobileNAV Page Functions", not this
/// extension's; they are literal text because the vendor app exposes no enum or option to
/// resolve them against.
/// </summary>
codeunit 77787 "BJF MN Function Map"
{
    Access = Internal;

    /// <summary>
    /// Resolves the MobileNAV Page Functions dispatcher procedure that serves record-level
    /// function calls for a page built on the given source table.
    /// </summary>
    /// <param name="TableNo">The source table id of the page whose dispatcher is needed.</param>
    /// <param name="DispatcherName">Returns the name of the dispatcher procedure on codeunit "MobileNAV Page Functions" (for example 'SalesHeaderExtFunc'); empty when TableNo is unmapped.</param>
    /// <returns>True when TableNo is one of the tables MobileNAV's Page Functions codeunit dispatches for.</returns>
    procedure TryGetDispatcher(TableNo: Integer; var DispatcherName: Text[50]): Boolean
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
}
