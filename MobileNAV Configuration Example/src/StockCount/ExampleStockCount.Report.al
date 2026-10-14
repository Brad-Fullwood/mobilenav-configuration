namespace BradFullwood.MobileNAV.Example;

/// <summary>A one-page print of a stock count and its lines. The device's Print button returns it as a PDF.</summary>
report 50100 "Example Stock Count"
{
    ApplicationArea = All;
    Caption = 'Stock Count';
    DefaultRenderingLayout = StockCountLayout;
    Permissions = tabledata "Example Stock Count" = r,
        tabledata "Example Stock Count Line" = r;
    UsageCategory = None;

    dataset
    {
        dataitem(StockCount; "Example Stock Count")
        {
            DataItemTableView = sorting("Entry No.");
            RequestFilterFields = "Entry No.";

            column(EntryNo; StockCount."Entry No.")
            {
                IncludeCaption = true;
            }
            column(ItemNo; StockCount."Item No.")
            {
                IncludeCaption = true;
            }
            column(BinCode; StockCount."Bin Code")
            {
                IncludeCaption = true;
            }
            column(CountedQuantity; StockCount."Counted Quantity")
            {
                IncludeCaption = true;
            }
            column(LotNo; StockCount."Lot No.")
            {
                IncludeCaption = true;
            }
            column(CountedAt; StockCount."Counted At")
            {
                IncludeCaption = true;
            }
            column(UserId; StockCount."User ID")
            {
                IncludeCaption = true;
            }
            dataitem(StockCountLine; "Example Stock Count Line")
            {
                DataItemLink = "Count Entry No." = field("Entry No.");
                DataItemTableView = sorting("Count Entry No.", "Line No.");

                column(LineLotNo; StockCountLine."Lot No.")
                {
                    IncludeCaption = true;
                }
                column(LineQuantity; StockCountLine.Quantity)
                {
                    IncludeCaption = true;
                }
            }
        }
    }

    rendering
    {
        layout(StockCountLayout)
        {
            Caption = 'Stock count';
            LayoutFile = './src/StockCount/ExampleStockCount.rdl';
            Summary = 'The count and its lines on one page.';
            Type = RDLC;
        }
    }
}
