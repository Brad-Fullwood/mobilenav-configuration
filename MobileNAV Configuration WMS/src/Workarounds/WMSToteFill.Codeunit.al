namespace BradFullwood.MobileNAV.Configuration.WMS;

using Microsoft.Warehouse.Activity;

/// <summary>
/// Fills the tote scanned on one pick line into the other take lines of the pick that belong in the same tote.
/// WMS MobileNAV refuses to register a single line from the device ("Missing tote no.") while any take line on
/// the pick has no tote, so on a pick with several lines the picker had to go back to the pick and register it
/// from there. Lines share a tote when the pick's Tote Combination puts them together: same order, same shipment
/// or same customer. Lines that already have a tote keep it.
/// </summary>
codeunit 77743 "BJF WMS Tote Fill"
{
    Access = Internal;
    SingleInstance = true;
    Permissions = tabledata "Warehouse Activity Header" = r,
        tabledata "Warehouse Activity Line" = rm;

    [EventSubscriber(ObjectType::Table, Database::"Warehouse Activity Line", OnAfterValidateEvent, "MUL WMS Tote No", false, false)]
    local procedure "Warehouse Activity Line_OnAfterValidateEvent_MUL WMS Tote No"(var Rec: Record "Warehouse Activity Line"; var xRec: Record "Warehouse Activity Line")
    begin
        if Rec."MUL WMS Tote No" = '' then
            exit;
        if Rec."MUL WMS Tote No" = xRec."MUL WMS Tote No" then
            exit;
        if (Rec."Activity Type" <> Rec."Activity Type"::Pick) or (Rec."Action Type" <> Rec."Action Type"::Take) then
            exit;
        // Validating the tote on the other lines raises this subscriber again for each of them, while the scanned
        // line is not saved yet. Those calls carry the same pick and tote on another line. An error inside the fill
        // leaves Filling set, so any other call counts as a new scan instead of being ignored.
        if this.IsFillCall(Rec) then
            exit;
        this.Filling := true;
        this.FillingPickNo := Rec."No.";
        this.FillingToteNo := Rec."MUL WMS Tote No";
        this.FillingLineNo := Rec."Line No.";
        this.FillOtherLines(Rec);
        this.Filling := false;
    end;

    local procedure IsFillCall(var Line: Record "Warehouse Activity Line"): Boolean
    begin
        if not this.Filling then
            exit(false);
        exit((Line."No." = this.FillingPickNo) and (Line."MUL WMS Tote No" = this.FillingToteNo) and (Line."Line No." <> this.FillingLineNo));
    end;

    local procedure FillOtherLines(var ScannedLine: Record "Warehouse Activity Line")
    var
        WarehouseActivityHeader: Record "Warehouse Activity Header";
        WarehouseActivityLine: Record "Warehouse Activity Line";
        LineNo: Integer;
    begin
        WarehouseActivityHeader.SetLoadFields("MUL WMS Tote Pick Enabled", "MUL WMS Tote Combination");
        if not WarehouseActivityHeader.Get(ScannedLine."Activity Type", ScannedLine."No.") then
            exit;
        if not WarehouseActivityHeader."MUL WMS Tote Pick Enabled" then
            exit;
        if not this.SetSameToteFilter(WarehouseActivityLine, ScannedLine, WarehouseActivityHeader."MUL WMS Tote Combination") then
            exit;

        foreach LineNo in this.CollectLineNos(WarehouseActivityLine) do
            if WarehouseActivityLine.Get(ScannedLine."Activity Type", ScannedLine."No.", LineNo) then
                if WarehouseActivityLine."MUL WMS Tote No" = '' then begin
                    WarehouseActivityLine.Validate("MUL WMS Tote No", ScannedLine."MUL WMS Tote No");
                    WarehouseActivityLine.Modify(true);
                end;
    end;

    local procedure CollectLineNos(var WarehouseActivityLine: Record "Warehouse Activity Line") LineNos: List of [Integer]
    begin
        // Collected first, because validating the tote on a line raises this subscriber for that line.
        WarehouseActivityLine.SetLoadFields("Line No.");
        if WarehouseActivityLine.FindSet(false) then
            repeat
                LineNos.Add(WarehouseActivityLine."Line No.");
            until WarehouseActivityLine.Next() = 0;
        WarehouseActivityLine.SetLoadFields();
        exit(LineNos);
    end;

    #pragma warning disable LC0088 // Mirrors MobileNAV's option "MUL WMS Tote Combination".
    local procedure SetSameToteFilter(var WarehouseActivityLine: Record "Warehouse Activity Line"; var ScannedLine: Record "Warehouse Activity Line"; ToteCombination: Option " ",Order,Shipment,Customer): Boolean
    begin
        WarehouseActivityLine.SetRange("Activity Type", ScannedLine."Activity Type");
        WarehouseActivityLine.SetRange("No.", ScannedLine."No.");
        WarehouseActivityLine.SetFilter("Line No.", '<>%1', ScannedLine."Line No.");
        WarehouseActivityLine.SetRange("Action Type", WarehouseActivityLine."Action Type"::Take);
        WarehouseActivityLine.SetRange("MUL WMS Tote No", '');
        case ToteCombination of
            ToteCombination::Order:
                WarehouseActivityLine.SetSourceFilter(ScannedLine."Source Type", ScannedLine."Source Subtype", ScannedLine."Source No.", -1, -1, false);
            ToteCombination::Shipment:
                begin
                    WarehouseActivityLine.SetRange("Whse. Document Type", ScannedLine."Whse. Document Type");
                    WarehouseActivityLine.SetRange("Whse. Document No.", ScannedLine."Whse. Document No.");
                end;
            ToteCombination::Customer:
                begin
                    WarehouseActivityLine.SetRange("Destination Type", ScannedLine."Destination Type");
                    WarehouseActivityLine.SetRange("Destination No.", ScannedLine."Destination No.");
                end;
            else
                exit(false);
        end;
        exit(true);
    end;
    #pragma warning restore LC0088

    var
        Filling: Boolean;
        FillingPickNo: Code[20];
        FillingToteNo: Code[50];
        FillingLineNo: Integer;
}
