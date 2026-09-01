namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;

using Microsoft.Inventory.Setup;

codeunit 77740 "BJF Check Inventory Setup" implements "BJF Diagnostic Check"
{
    Permissions = tabledata "Inventory Setup" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        InventorySetup: Record "Inventory Setup";
    begin
        InventorySetup.Get();
        if InventorySetup."Package Nos." = '' then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Inventory Setup", Enum::"BJF Diagnostic Severity"::Blocker,
                StrSubstNo(MissingSetupMsg, InventorySetup.FieldCaption("Package Nos."), InventorySetup.TableCaption()), InventorySetup.RecordId());
        if not InventorySetup."MUL WMS Package Tracking" then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Inventory Setup", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(MissingSetupMsg, InventorySetup.FieldCaption("MUL WMS Package Tracking"), InventorySetup.TableCaption()), InventorySetup.RecordId());
        if InventorySetup."MUL WMS Undefined Package No." = '' then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Inventory Setup", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(MissingSetupMsg, InventorySetup.FieldCaption("MUL WMS Undefined Package No."), InventorySetup.TableCaption()), InventorySetup.RecordId());
        if InventorySetup."BJF MN Move Posts Own Lines" then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Inventory Setup", Enum::"BJF Diagnostic Severity"::Info,
                MoveWorkaroundActiveMsg, InventorySetup.RecordId());
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(NoAutomaticFixErr);
    end;

    var
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        MissingSetupMsg: Label '%1 is not set in %2.', Comment = '%1 = field caption, %2 = table caption';
        MoveWorkaroundActiveMsg: Label 'The "MobileNAV Move Posts Only Its Own Lines" workaround is active: Move Package postings are limited to the lines the move created. Remove the workaround once MultiSoft fixes MovePackage2.';
}
