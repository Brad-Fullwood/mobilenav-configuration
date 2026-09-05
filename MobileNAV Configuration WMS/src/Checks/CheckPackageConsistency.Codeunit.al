namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Tracking;

codeunit 77741 "BJF Check Package Consistency" implements "BJF Diagnostic Check"
{
    Access = Internal;
    Permissions = tabledata "Package No. Information" = r,
        tabledata "MUL WMS Package" = r;

    procedure RunCheck(var Finding: Record "BJF Diagnostic Finding")
    var
        PackageNoInformation: Record "Package No. Information";
        WMSPackage: Record "MUL WMS Package";
        MissingCount: Integer;
    begin
        if PackageNoInformation.FindSet() then
            repeat
                if not WMSPackage.Get(PackageNoInformation."Package No.") then begin
                    MissingCount += 1;
                    // The WMS integrity check (MUL WMS Package Tracking) does a hard Get on this record
                    // after every package posting, so a missing record breaks Split/Move for that package.
                    if MissingCount <= 10 then
                        Finding.Add(Enum::"BJF Diagnostic Check Type"::"Package Consistency", Enum::"BJF Diagnostic Severity"::Warning,
                            StrSubstNo(this.MissingWMSPackageMsg, PackageNoInformation."Package No.", PackageNoInformation."Item No."), PackageNoInformation.RecordId());
                end;
            until PackageNoInformation.Next() = 0;
        if MissingCount > 10 then
            Finding.Add(Enum::"BJF Diagnostic Check Type"::"Package Consistency", Enum::"BJF Diagnostic Severity"::Warning,
                StrSubstNo(this.MoreMissingMsg, MissingCount - 10));
    end;

    procedure ApplyFix(var Finding: Record "BJF Diagnostic Finding")
    begin
        Error(this.NoAutomaticFixErr);
    end;

    var
        NoAutomaticFixErr: Label 'This finding has no automatic fix.';
        MissingWMSPackageMsg: Label 'Package No. Information %1 (item %2) has no matching MUL WMS Package record. The WMS package integrity check will fail for this package.', Comment = '%1 = package no., %2 = item no.';
        MoreMissingMsg: Label '... and %1 more Package No. Information records without a MUL WMS Package record.', Comment = '%1 = count';
}
