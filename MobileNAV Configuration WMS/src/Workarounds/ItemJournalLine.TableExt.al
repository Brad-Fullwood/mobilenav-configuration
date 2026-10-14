namespace BradFullwood.MobileNAV.Configuration.WMS;

using BradFullwood.MobileNAV.Configuration;
using Microsoft.Inventory.Journal;

tableextension 77750 "BJF Item Journal Line" extends "Item Journal Line"
{
    fields
    {
        field(77750; "BJF MN Created Session ID"; Integer)
        {
            Caption = 'Created Session ID';
            DataClassification = SystemMetadata;
            Editable = false;
            AllowInCustomizations = Never;
        }
    }

    trigger OnInsert()
    begin
        // Stamped on every line so the Move-posts-own-lines workaround (codeunit
        // "BJF Post Move Lines Only") can tell this session's lines from stale ones.
        // Rolls back with the transaction, so it is always accurate.
        Rec.Validate("BJF MN Created Session ID", SessionId());
    end;
}
