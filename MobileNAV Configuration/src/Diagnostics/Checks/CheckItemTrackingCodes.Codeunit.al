namespace BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Tracking;

codeunit 77772 "BJF Check Item Tracking Codes" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Item Tracking Code" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        ItemTrackingCode: Record "Item Tracking Code";
    begin
        ItemTrackingCode.SetRange("Package Specific Tracking", true);
        if ItemTrackingCode.FindSet() then
            repeat
                this.CheckMustExistWorkaround(Finding, ItemTrackingCode);
                this.CheckTransferTracking(Finding, ItemTrackingCode);
            until ItemTrackingCode.Next() = 0;
    end;

    // BC posting (PackageInfoManagement subscriber to Item Jnl.-Post Line) does a hard Get of
    // Package No. Information for the New Package No. of a reclass when either toggle is on.
    // MobileNAV WMS never creates that record for the new package, so Split/Move Package fails
    // unless the create-on-posting workaround (codeunit "BJF Create Pkg Info On Post.") is enabled.
    local procedure CheckMustExistWorkaround(var Finding: Record "BJF Diagnostic Finding"; ItemTrackingCode: Record "Item Tracking Code")
    begin
        if not (ItemTrackingCode."Package Info. Inb. Must Exist" or ItemTrackingCode."Package Info. Outb. Must Exist") then
            exit;
        if ItemTrackingCode."BJF MN Create Pkg Info on Post" then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Item Tracking Codes", Enum::"BJF Diagnostic Severity"::Info,
                StrSubstNo(this.MustExistWorkaroundMsg, ItemTrackingCode.Code), ItemTrackingCode.RecordId())
        else
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Item Tracking Codes", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(this.MustExistOnMsg, ItemTrackingCode.Code), ItemTrackingCode.RecordId());
    end;

    local procedure CheckTransferTracking(var Finding: Record "BJF Diagnostic Finding"; ItemTrackingCode: Record "Item Tracking Code")
    begin
        if not ItemTrackingCode."Package Transfer Tracking" then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Item Tracking Codes", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(this.NoTransferTrackingMsg, ItemTrackingCode.Code), ItemTrackingCode.RecordId());
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    var
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        MustExistOnMsg: Label 'Item Tracking Code %1 has "Package Info. Inb./Outb. Must Exist" enabled. Posting a package reclass then requires a Package No. Information record for the NEW package number, which MobileNAV WMS never creates - Split Package / Move Package fail with "The Package No. Information does not exist". Disable both toggles (BC then auto-creates the record on posting) or enable "Create Package Info. on Posting (Workaround)" on the code.', Comment = '%1 = item tracking code';
        MustExistWorkaroundMsg: Label 'Item Tracking Code %1 has "Package Info. Inb./Outb. Must Exist" enabled and relies on the "Create Package Info. on Posting" workaround. Remove the workaround once Microsoft ships the standard toggle.', Comment = '%1 = item tracking code';
        NoTransferTrackingMsg: Label 'Item Tracking Code %1 has "Package Transfer Tracking" disabled. Package numbers are not required on reclass postings, so package info records are not auto-created for new packages.', Comment = '%1 = item tracking code';
}
