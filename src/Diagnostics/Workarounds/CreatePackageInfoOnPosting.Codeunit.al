namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Journal;
using Microsoft.Inventory.Posting;
using Microsoft.Inventory.Tracking;

/// <summary>
/// WORKAROUND: emulates the "Create Package Info on Posting" toggle that standard BC has for
/// serial numbers (ITC field 34) and lot numbers (ITC field 64) but never implemented for packages.
///
/// Why it is needed: with "Package Info. Inb./Outb. Must Exist" enabled, the standard
/// PackageInfoManagement codeunit (subscriber to Item Jnl.-Post Line.OnAfterCheckItemTrackingInformation)
/// does a hard Get of Package No. Information for both the Package No. and the New Package No. of a
/// reclassification. Numbers generated at posting time (e.g. MobileNAV WMS Split Package) can never
/// be pre-registered, so those postings always fail with "The Package No. Information does not exist".
///
/// This subscriber runs just before that check (OnBeforeCheckItemTrackingInformation) and creates the
/// missing records, mirroring ItemTrackingManagement.CreateLotNoInformation line for line. It is
/// opt-in per Item Tracking Code via "Create Package Info. on Posting (Workaround)".
///
/// Delete this workaround (codeunit, table extension field and page extension field) once Microsoft
/// ships a standard "Create Package Info on Posting" toggle.
/// </summary>
codeunit 77776 "BJF Create Pkg Info On Post."
{
    Access = Internal;
    Permissions = tabledata "Package No. Information" = ri;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"Item Jnl.-Post Line", OnBeforeCheckItemTrackingInformation, '', false, false)]
    local procedure ItemJnlPostLineOnBeforeCheckItemTrackingInformation(var ItemJnlLine2: Record "Item Journal Line"; var TrackingSpecification: Record "Tracking Specification"; var ItemTrackingSetup: Record "Item Tracking Setup"; var SignFactor: Decimal; var ItemTrackingCode: Record "Item Tracking Code"; var IsHandled: Boolean; var GlobalItemTrackingCode: Record "Item Tracking Code")
    begin
        if IsHandled then
            exit;
        // Only relevant while the must-exist gate is on: with it off, standard BC
        // (PackageInfoManagement) already auto-creates missing package info on posting.
        if not ItemTrackingSetup."Package No. Info Required" then
            exit;
        if not ItemTrackingCode."BJF MN Create Pkg Info on Post" then
            exit;
        CreatePackageNoInformation(TrackingSpecification);
    end;

    local procedure CreatePackageNoInformation(TrackingSpecification: Record "Tracking Specification")
    var
        PackageNoInfo: Record "Package No. Information";
        PackageNumbers: List of [Code[50]];
        PackageNumber: Code[50];
    begin
        if TrackingSpecification."Package No." <> '' then
            PackageNumbers.Add(TrackingSpecification."Package No.");
        if (TrackingSpecification."New Package No." <> '') and (not PackageNumbers.Contains(TrackingSpecification."New Package No.")) then
            PackageNumbers.Add(TrackingSpecification."New Package No.");

        // Validating "Package No." also lets WMS MobileNAV create its matching
        // MUL WMS Package record through its own table extension trigger.
        foreach PackageNumber in PackageNumbers do
            if not PackageNoInfo.Get(TrackingSpecification."Item No.", TrackingSpecification."Variant Code", PackageNumber) then begin
                PackageNoInfo.Init();
                PackageNoInfo.Validate("Item No.", TrackingSpecification."Item No.");
                PackageNoInfo.Validate("Variant Code", TrackingSpecification."Variant Code");
                PackageNoInfo.Validate("Package No.", PackageNumber);
                PackageNoInfo.Insert(true);
            end;
    end;
}
