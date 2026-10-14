namespace BradFullwood.MobileNAV.Configuration.WMS;

using Microsoft.Inventory.Ledger;

/// <summary>Counts open item ledger entries per package and location, for the split package check.</summary>
query 77755 "BJF Package Locations"
{
    Caption = 'Package Locations';
    QueryType = Normal;
    Access = Internal;
    Permissions = tabledata "Item Ledger Entry" = r;

    elements
    {
        dataitem(ItemLedgerEntry; "Item Ledger Entry")
        {
            DataItemTableFilter = "Package No." = filter(<> ''), Open = const(true);

            column(PackageNo; "Package No.")
            {
            }
            column(LocationCode; "Location Code")
            {
            }
            column(EntryCount)
            {
                Method = Count;
            }
        }
    }
}
