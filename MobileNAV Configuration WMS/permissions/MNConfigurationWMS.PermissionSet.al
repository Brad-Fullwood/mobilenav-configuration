namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Setup;

permissionset 77740 "BJF MN Config WMS"
{
    Caption = 'MobileNAV Config WMS', MaxLength = 30;
    Assignable = true;
    IncludedPermissionSets = "BJF MN Configuration";
    Permissions = codeunit "BJF Check Inventory Setup" = X,
        codeunit "BJF Check Package Consistency" = X,
        codeunit "BJF Check Split Packages" = X,
        tabledata "Inventory Setup" = r,
        tabledata "MUL WMS Package" = r;
}
