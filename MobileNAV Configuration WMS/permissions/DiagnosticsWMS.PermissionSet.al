namespace BradFullwood.MobileNAV.Diagnostics.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Setup;

permissionset 77740 "BJF Diagnostics WMS"
{
    Caption = 'MobileNAV Diagnostics WMS';
    Assignable = true;
    IncludedPermissionSets = "BJF MN Configuration";
    Permissions = codeunit "BJF Check Inventory Setup" = X,
        codeunit "BJF Check Package Consistency" = X,
        codeunit "BJF Check Split Packages" = X,
        tabledata "Inventory Setup" = r,
        tabledata "MUL WMS Package" = r;
}
