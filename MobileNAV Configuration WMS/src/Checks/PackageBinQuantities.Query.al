namespace BradFullwood.MobileNAV.Configuration.WMS;

using Microsoft.Warehouse.Ledger;

/// <summary>Sums warehouse quantity per package, location and bin, for the split package check.</summary>
query 77756 "BJF Package Bin Quantities"
{
    Caption = 'Package Bin Quantities';
    QueryType = Normal;
    Access = Internal;
    Permissions = tabledata "Warehouse Entry" = r;

    elements
    {
        dataitem(WarehouseEntry; "Warehouse Entry")
        {
            DataItemTableFilter = "Package No." = filter(<> '');

            column(PackageNo; "Package No.")
            {
            }
            column(LocationCode; "Location Code")
            {
            }
            column(BinCode; "Bin Code")
            {
            }
            column(QtyBase; "Qty. (Base)")
            {
                Method = Sum;
            }
        }
    }
}
