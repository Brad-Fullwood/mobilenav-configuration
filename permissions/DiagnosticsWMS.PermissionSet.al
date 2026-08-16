namespace BradFullwood.MobileNAV.Diagnostics.WMS;

using Microsoft.Inventory.Setup;

permissionset 77740 "BJF Diagnostics WMS"
{
    Caption = 'MobileNAV Diagnostics WMS';
    Assignable = true;
    Permissions = codeunit "BJF Check Inventory Setup" = X,
        codeunit "BJF Check Package Consistency" = X,
        tabledata "Inventory Setup" = r,
        tabledata "MUL WMS Package" = r;
}
