namespace BradFullwood.MobileNAV.Diagnostics.WMS;

using BradFullwood.MobileNAV.Diagnostics;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Ledger;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Tracking;
using Microsoft.Warehouse.Ledger;

/// <summary>
/// Finds packages whose stock is spread over more than one bin or location. The WMS package
/// integrity check (MUL WMS Package Tracking.PerformIntegrityCheck) runs after every posting
/// and errors when a package it touched spans bins, so a split package silently blocks every
/// posting that references it - including production output whose flushed consumption picks
/// the package. Splits usually come from a partial move out of a receipt bin or from reusing
/// a package number across receipts into different bins.
///
/// The fix posts an item reclassification that consolidates the package into the bin holding
/// most of its quantity, carrying lot/serial/package tracking. The posting itself re-runs the
/// vendor integrity check, which then passes and repairs the MUL WMS Package bin fields.
/// Checks each package individually; nested package families that place parent and children
/// in different bins are not detected.
/// </summary>
codeunit 77742 "BJF Check Split Packages" implements "BJF Diagnostic Check"
{
    Permissions = tabledata "Item Ledger Entry" = r,
        tabledata "Warehouse Entry" = r,
        tabledata "Item Journal Template" = r,
        tabledata "Item Journal Batch" = ri,
        tabledata "Item Journal Line" = rimd,
        tabledata "Reservation Entry" = rimd,
        tabledata "MUL WMS Package" = ri;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        WMSPackage: Record "MUL WMS Package";
        BinPlacements: Dictionary of [Text, List of [Text]];
        LocationPlacements: Dictionary of [Text, List of [Text]];
        PackageNo: Text;
        FindingCount: Integer;
    begin
        CollectLocationPlacements(LocationPlacements);
        CollectBinPlacements(BinPlacements);

        foreach PackageNo in LocationPlacements.Keys() do
            if LocationPlacements.Get(PackageNo).Count() > 1 then begin
                FindingCount += 1;
                if FindingCount <= MaxFindings() then
                    Finding.Add(Enum::"BJF Diagnostic Check Type"::"Split Packages", Enum::"BJF Diagnostic Severity"::Blocker,
                        StrSubstNo(SplitLocationMsg, PackageNo, JoinPlacements(LocationPlacements.Get(PackageNo))));
            end;

        foreach PackageNo in BinPlacements.Keys() do
            if (BinPlacements.Get(PackageNo).Count() > 1) and not IsMultiLocation(LocationPlacements, PackageNo) then begin
                FindingCount += 1;
                if FindingCount <= MaxFindings() then begin
                    // The package number rides in Fix Context; the Related Record ID is only
                    // for navigation and may legitimately be blank - the fix creates a
                    // missing MUL WMS Package record itself.
                    Clear(WMSPackage);
                    if WMSPackage.Get(PackageNo) then;
                    Finding.AddWithFix(Enum::"BJF Diagnostic Check Type"::"Split Packages", Enum::"BJF Diagnostic Severity"::Blocker,
                        StrSubstNo(SplitBinMsg, PackageNo, JoinPlacements(BinPlacements.Get(PackageNo))),
                        WMSPackage.RecordId(),
                        StrSubstNo(ConsolidateFixLbl, PackageNo),
                        PackageNo);
                end;
            end;

        if FindingCount > MaxFindings() then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Split Packages", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(MoreFindingsMsg, FindingCount - MaxFindings()));
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    var
        WMSPackage: Record "MUL WMS Package";
        RecRef: RecordRef;
        PackageNo: Code[50];
    begin
        PackageNo := CopyStr(Finding."Fix Context", 1, MaxStrLen(PackageNo));
        // Findings recorded before Fix Context existed anchored the package to its record id.
        if (PackageNo = '') and (Finding."Related Record ID".TableNo() = Database::"MUL WMS Package") then
            if RecRef.Get(Finding."Related Record ID") then begin
                RecRef.SetTable(WMSPackage);
                PackageNo := WMSPackage."Package No.";
            end;
        if PackageNo = '' then
            Error(NoAutomaticFixErr);
        ConsolidatePackage(PackageNo);
    end;

    /// <summary>
    /// Open item ledger entries per package and location. Location splits need a transfer
    /// order, so they are reported without a fix; this also covers locations without bins,
    /// which leave no warehouse entries.
    /// </summary>
    local procedure CollectLocationPlacements(var LocationPlacements: Dictionary of [Text, List of [Text]])
    var
        ItemLedgerEntry: Record "Item Ledger Entry";
    begin
        ItemLedgerEntry.SetLoadFields("Package No.", "Location Code");
        ItemLedgerEntry.SetFilter("Package No.", '<>%1', '');
        ItemLedgerEntry.SetRange(Open, true);
        if ItemLedgerEntry.FindSet() then
            repeat
                AddPlacement(LocationPlacements, ItemLedgerEntry."Package No.", ItemLedgerEntry."Location Code");
            until ItemLedgerEntry.Next() = 0;
    end;

    /// <summary>
    /// Net warehouse quantity per package, location and bin; a package with two or more bins
    /// carrying stock is what the vendor integrity check errors on.
    /// </summary>
    local procedure CollectBinPlacements(var BinPlacements: Dictionary of [Text, List of [Text]])
    var
        WarehouseEntry: Record "Warehouse Entry";
        PlacementQty: Dictionary of [Text, Decimal];
        PackageOfPlacement: Dictionary of [Text, Text];
        Placement: Text;
        Qty: Decimal;
    begin
        WarehouseEntry.SetLoadFields("Package No.", "Location Code", "Bin Code", "Qty. (Base)");
        WarehouseEntry.SetFilter("Package No.", '<>%1', '');
        if WarehouseEntry.FindSet() then
            repeat
                Placement := WarehouseEntry."Package No." + Format(Separator()) + WarehouseEntry."Location Code" + '/' + WarehouseEntry."Bin Code";
                Qty := 0;
                if PlacementQty.Get(Placement, Qty) then;
                PlacementQty.Set(Placement, Qty + WarehouseEntry."Qty. (Base)");
                PackageOfPlacement.Set(Placement, WarehouseEntry."Package No.");
            until WarehouseEntry.Next() = 0;

        foreach Placement in PlacementQty.Keys() do
            if PlacementQty.Get(Placement) <> 0 then
                AddPlacement(
                    BinPlacements, PackageOfPlacement.Get(Placement),
                    Placement.Split(Format(Separator())).Get(2) + ': ' + Format(PlacementQty.Get(Placement)));
    end;

    /// <summary>
    /// Consolidates the package into the bin holding its largest quantity by posting an item
    /// reclassification per item/variant/lot/serial from every other bin, mirroring how MUL
    /// WMS Packing Order Mgt. posts tracked reclassifications. Uses a dedicated batch on the
    /// first Transfer-type template so nothing else is swept into the posting.
    /// </summary>
    local procedure ConsolidatePackage(PackageNo: Code[50])
    var
        WMSPackage: Record "MUL WMS Package";
        ItemJournalBatch: Record "Item Journal Batch";
        ItemJournalLine: Record "Item Journal Line";
        ItemJnlPostBatch: Codeunit "Item Jnl.-Post Batch";
        GroupQty: Dictionary of [Text, Decimal];
        BinQty: Dictionary of [Text, Decimal];
        GroupKey: Text;
        GroupParts: List of [Text];
        TargetBin: Text;
        LineNo: Integer;
    begin
        CollectPackageGroups(PackageNo, GroupQty, BinQty);
        TargetBin := FindTargetBin(BinQty);
        if TargetBin = '' then
            Error(NothingToConsolidateErr, PackageNo);

        // The vendor integrity check hard-Gets this record after the posting below; create
        // it when missing (validating Package No. computes location, bin and hierarchy).
        if not WMSPackage.Get(PackageNo) then begin
            WMSPackage.Init();
            WMSPackage.Validate("Package No.", PackageNo);
            WMSPackage.Insert();
        end;

        PrepareFixBatch(ItemJournalBatch);

        foreach GroupKey in GroupQty.Keys() do begin
            GroupParts := GroupKey.Split(Format(Separator()));
            if GroupParts.Get(2) <> TargetBin then begin
                if GroupQty.Get(GroupKey) < 0 then
                    Error(NegativeStockErr, PackageNo, GroupParts.Get(2));
                if GroupQty.Get(GroupKey) > 0 then begin
                    LineNo += 10000;
                    InsertReclassLine(ItemJournalLine, ItemJournalBatch, LineNo, PackageNo, GroupParts, TargetBin, GroupQty.Get(GroupKey));
                end;
            end;
        end;

        if LineNo = 0 then
            Error(NothingToConsolidateErr, PackageNo);

        // Posting re-runs the vendor package integrity check, which now passes and rewrites
        // the MUL WMS Package and Package No. Information bin fields to the target bin.
        ItemJnlPostBatch.SetSuppressCommit(true);
        ItemJnlPostBatch.Run(ItemJournalLine);
    end;

    /// <summary>
    /// Sums the package's warehouse quantity per location/bin/item/variant/lot/serial. Errors
    /// when the package spans locations - that consolidation needs a transfer order.
    /// </summary>
    local procedure CollectPackageGroups(PackageNo: Code[50]; var GroupQty: Dictionary of [Text, Decimal]; var BinQty: Dictionary of [Text, Decimal])
    var
        WarehouseEntry: Record "Warehouse Entry";
        LocationCode: Code[10];
        GroupKey: Text;
        Qty: Decimal;
    begin
        WarehouseEntry.SetRange("Package No.", PackageNo);
        if WarehouseEntry.FindSet() then
            repeat
                if LocationCode = '' then
                    LocationCode := WarehouseEntry."Location Code";
                if LocationCode <> WarehouseEntry."Location Code" then
                    Error(MultiLocationErr, PackageNo, LocationCode, WarehouseEntry."Location Code");
                GroupKey :=
                    WarehouseEntry."Location Code" + Format(Separator()) + WarehouseEntry."Bin Code" +
                    Format(Separator()) + WarehouseEntry."Item No." + Format(Separator()) + WarehouseEntry."Variant Code" +
                    Format(Separator()) + WarehouseEntry."Lot No." + Format(Separator()) + WarehouseEntry."Serial No.";
                Qty := 0;
                if GroupQty.Get(GroupKey, Qty) then;
                GroupQty.Set(GroupKey, Qty + WarehouseEntry."Qty. (Base)");
                Qty := 0;
                if BinQty.Get(WarehouseEntry."Bin Code", Qty) then;
                BinQty.Set(WarehouseEntry."Bin Code", Qty + WarehouseEntry."Qty. (Base)");
            until WarehouseEntry.Next() = 0;
    end;

    local procedure FindTargetBin(BinQty: Dictionary of [Text, Decimal]): Text
    var
        BinCode: Text;
        TargetBin: Text;
        LargestQty: Decimal;
    begin
        foreach BinCode in BinQty.Keys() do
            if BinQty.Get(BinCode) > LargestQty then begin
                LargestQty := BinQty.Get(BinCode);
                TargetBin := BinCode;
            end;
        exit(TargetBin);
    end;

    local procedure PrepareFixBatch(var ItemJournalBatch: Record "Item Journal Batch")
    var
        ItemJournalTemplate: Record "Item Journal Template";
        StaleLine: Record "Item Journal Line";
        ReservationManagement: Codeunit "Reservation Management";
    begin
        ItemJournalTemplate.SetRange(Type, ItemJournalTemplate.Type::Transfer);
        if not ItemJournalTemplate.FindFirst() then
            Error(NoTransferTemplateErr);

        if not ItemJournalBatch.Get(ItemJournalTemplate.Name, FixBatchTok) then begin
            ItemJournalBatch.Init();
            ItemJournalBatch."Journal Template Name" := ItemJournalTemplate.Name;
            ItemJournalBatch.Name := FixBatchTok;
            ItemJournalBatch.Description := FixBatchDescriptionLbl;
            ItemJournalBatch.Insert(true);
        end;

        // The batch is owned by this fix, so anything left in it is a previous failed run.
        StaleLine.SetRange("Journal Template Name", ItemJournalBatch."Journal Template Name");
        StaleLine.SetRange("Journal Batch Name", ItemJournalBatch.Name);
        while StaleLine.FindFirst() do begin
            Clear(ReservationManagement);
            ReservationManagement.SetReservSource(StaleLine);
            ReservationManagement.SetItemTrackingHandling(1); // Allow deletion
            ReservationManagement.DeleteReservEntries(true, 0);
            StaleLine.Delete(true);
        end;
    end;

    local procedure InsertReclassLine(var ItemJournalLine: Record "Item Journal Line"; ItemJournalBatch: Record "Item Journal Batch"; LineNo: Integer; PackageNo: Code[50]; GroupParts: List of [Text]; TargetBin: Text; QtyBase: Decimal)
    begin
        ItemJournalLine.Init();
        ItemJournalLine."Journal Template Name" := ItemJournalBatch."Journal Template Name";
        ItemJournalLine."Journal Batch Name" := ItemJournalBatch.Name;
        ItemJournalLine."Line No." := LineNo;
        ItemJournalLine.Validate("Entry Type", ItemJournalLine."Entry Type"::Transfer);
        ItemJournalLine.Validate("Posting Date", WorkDate());
        ItemJournalLine."Document No." := FixDocumentTok;
        ItemJournalLine.Validate("Item No.", CopyStr(GroupParts.Get(3), 1, 20));
        ItemJournalLine.Validate("Variant Code", CopyStr(GroupParts.Get(4), 1, 10));
        ItemJournalLine.Validate("Location Code", CopyStr(GroupParts.Get(1), 1, 10));
        ItemJournalLine.Validate("New Location Code", CopyStr(GroupParts.Get(1), 1, 10));
        ItemJournalLine.Validate("Bin Code", CopyStr(GroupParts.Get(2), 1, 20));
        ItemJournalLine.Validate("New Bin Code", CopyStr(TargetBin, 1, 20));
        ItemJournalLine.Validate(Quantity, QtyBase);
        ItemJournalLine.Insert();
        CreateTrackingEntry(
            ItemJournalLine, PackageNo, CopyStr(GroupParts.Get(5), 1, 50), CopyStr(GroupParts.Get(6), 1, 50));
    end;

    /// <summary>
    /// Attaches lot/serial/package tracking to the reclassification line, keeping the same
    /// tracking on the new side. Mirrors MUL WMS Packing Order Mgt.CreateResEntry.
    /// </summary>
    local procedure CreateTrackingEntry(ItemJournalLine: Record "Item Journal Line"; PackageNo: Code[50]; LotNo: Code[50]; SerialNo: Code[50])
    var
        TempReservationEntry: Record "Reservation Entry" temporary;
        TempTrackingSpecification: Record "Tracking Specification" temporary;
        CreateReservEntry: Codeunit "Create Reserv. Entry";
        ReservationStatus: Enum "Reservation Status";
    begin
        TempReservationEntry.Init();
        TempReservationEntry."Entry No." := 1;
        TempReservationEntry.Validate("Lot No.", LotNo);
        TempReservationEntry.Validate("Serial No.", SerialNo);
        TempReservationEntry.Validate("Package No.", PackageNo);
        TempReservationEntry.Validate(Quantity, ItemJournalLine.Quantity);
        TempReservationEntry.Insert();

        TempTrackingSpecification.Init();
        TempTrackingSpecification.Validate("Serial No.", SerialNo);
        TempTrackingSpecification.Validate("Lot No.", LotNo);
        TempTrackingSpecification.Validate("Package No.", PackageNo);
        TempTrackingSpecification.Validate("New Serial No.", SerialNo);
        TempTrackingSpecification.Validate("New Lot No.", LotNo);
        TempTrackingSpecification.Validate("New Package No.", PackageNo);
        TempTrackingSpecification.Validate("Quantity (Base)", ItemJournalLine."Quantity (Base)");
        TempTrackingSpecification.Insert();

        CreateReservEntry.CreateReservEntryFor(
            Database::"Item Journal Line", ItemJournalLine."Entry Type".AsInteger(),
            ItemJournalLine."Journal Template Name", ItemJournalLine."Journal Batch Name", 0, ItemJournalLine."Line No.",
            ItemJournalLine."Qty. per Unit of Measure", ItemJournalLine.Quantity, ItemJournalLine."Quantity (Base)",
            TempReservationEntry);
        CreateReservEntry.SetNewTrackingFromNewTrackingSpecification(TempTrackingSpecification);
        CreateReservEntry.CreateEntry(
            ItemJournalLine."Item No.", ItemJournalLine."Variant Code", ItemJournalLine."Location Code",
            '', 0D, 0D, 0, ReservationStatus::Prospect);
    end;

    local procedure AddPlacement(var Placements: Dictionary of [Text, List of [Text]]; PackageNo: Text; Placement: Text)
    var
        PlacementList: List of [Text];
    begin
        if Placements.Get(PackageNo, PlacementList) then begin
            if not PlacementList.Contains(Placement) then
                PlacementList.Add(Placement);
        end else begin
            PlacementList.Add(Placement);
            Placements.Set(PackageNo, PlacementList);
        end;
    end;

    local procedure IsMultiLocation(LocationPlacements: Dictionary of [Text, List of [Text]]; PackageNo: Text): Boolean
    var
        Locations: List of [Text];
    begin
        if not LocationPlacements.Get(PackageNo, Locations) then
            exit(false);
        exit(Locations.Count() > 1);
    end;

    local procedure JoinPlacements(Placements: List of [Text]): Text
    var
        Placement: Text;
        Result: TextBuilder;
    begin
        foreach Placement in Placements do begin
            if Result.Length() > 0 then
                Result.Append(', ');
            Result.Append(Placement);
        end;
        exit(Result.ToText());
    end;

    local procedure Separator(): Char
    begin
        exit(31); // unit separator: cannot occur in Code fields, safe to join/split keys on
    end;

    local procedure MaxFindings(): Integer
    begin
        exit(25);
    end;

    var
        FixBatchTok: Label 'BJFPKGFIX', Locked = true;
        FixDocumentTok: Label 'PKGFIX', Locked = true;
        FixBatchDescriptionLbl: Label 'Split package repair (MobileNAV Diagnostics)', MaxLength = 100;
        SplitBinMsg: Label 'Package %1 has stock in more than one bin (%2). The WMS package integrity check fails every posting that touches this package - including production output that flush-consumes it.', Comment = '%1 = package no., %2 = bin: quantity list';
        SplitLocationMsg: Label 'Package %1 has open item ledger entries in more than one location (%2). Consolidating across locations needs a transfer order; no automatic fix.', Comment = '%1 = package no., %2 = location list';
        ConsolidateFixLbl: Label 'Post an item reclassification consolidating package %1 into the bin holding its largest quantity.', Comment = '%1 = package no.';
        MoreFindingsMsg: Label '... and %1 more split packages.', Comment = '%1 = count';
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        NoTransferTemplateErr: Label 'No Transfer-type item journal template exists to post the consolidating reclassification.';
        MultiLocationErr: Label 'Package %1 has warehouse entries in locations %2 and %3. Consolidate across locations with a transfer order; the automatic fix only handles bins within one location.', Comment = '%1 = package no., %2/%3 = locations';
        NegativeStockErr: Label 'Package %1 has negative net stock in bin %2. Inspect the warehouse entries; the automatic fix cannot consolidate negative quantities.', Comment = '%1 = package no., %2 = bin';
        NothingToConsolidateErr: Label 'Package %1 has no positive quantity outside its main bin - nothing to consolidate. Re-run the diagnostics.', Comment = '%1 = package no.';
}
