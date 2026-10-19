namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Setup;
using Microsoft.Warehouse.Activity;

/// <summary>
/// Permissions for the WMS MobileNAV checks and workarounds, on top of MobileNAV Configuration.
/// </summary>
permissionset 77740 "BJF MN Config WMS"
{
    Caption = 'MobileNAV Config WMS', MaxLength = 30;
    Assignable = true;
    IncludedPermissionSets = "BJF MN Configuration";
    Permissions = tabledata "Inventory Setup" = r,
        tabledata "MUL WMS License Information" = r,
        tabledata "MUL WMS Package" = r,
        tabledata "Warehouse Activity Header" = r,
        tabledata "Warehouse Activity Line" = rm,
        codeunit "BJF Check Inventory Setup" = X,
        codeunit "BJF Check Item Tracking Codes" = X,
        codeunit "BJF Check Leftover Move Lines" = X,
        codeunit "BJF Check Movement Journals" = X,
        codeunit "BJF Check Package Consistency" = X,
        codeunit "BJF Check Split Packages" = X,
        codeunit "BJF Check WMS Licence" = X,
        codeunit "BJF Create Pkg Info On Post." = X,
        codeunit "BJF MN WMS Licence" = X,
        codeunit "BJF Movement Journal Mgt." = X,
        codeunit "BJF Post Move Lines Only" = X,
        codeunit "BJF WMS Tote Fill" = X,
        page "BJF MN WMS Licence" = X,
        query "BJF Package Bin Quantities" = X,
        query "BJF Package Locations" = X;
}
