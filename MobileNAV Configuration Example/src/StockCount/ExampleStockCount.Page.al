namespace BradFullwood.MobileNAV.Example;

/// <summary>
/// The count sheet the device shows: a plain card over the table. The control names are what the
/// provider refers to. The photo, signature, lines and print controls are placeholders the
/// provider turns into device controls, and the procedures at the end are the web-service
/// wrappers their functions travel through.
/// </summary>
page 50100 "Example Stock Count"
{
    ApplicationArea = All;
    Caption = 'Stock Count';
    PageType = Card;
    SourceTable = "Example Stock Count";
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            group(Count)
            {
                Caption = 'Count';
                field(EntryNo; Rec."Entry No.")
                {
                }
                field(UserId; Rec."User ID")
                {
                }
                field(ItemNo; Rec."Item No.")
                {
                }
                field(BinCode; Rec."Bin Code")
                {
                }
                field(CountedQuantity; Rec."Counted Quantity")
                {
                }
                field(LotNo; Rec."Lot No.")
                {
                }
                field(CountedAt; Rec."Counted At")
                {
                }
                field(Posted; Rec.Posted)
                {
                }
                // An image or signature is a placeholder control plus a hidden size field named
                // after it. Binding the Media field itself gives "No file specified" on the device.
                field(Photo; '')
                {
                    Caption = 'Photo';
                    ToolTip = 'Specifies the device control that takes and shows the photo of the count. The provider declares it.';
                }
                field(Photo_Size; this.ObjectFunctions.GetSizeOfBinaryData(Rec, Rec.FieldNo(Photo)))
                {
                    Caption = 'Photo Size';
                    ToolTip = 'Specifies the size of the photo, which tells the device whether there is one to show.';
                    Visible = false;
                }
                field(Signature; '')
                {
                    Caption = 'Signature';
                    ToolTip = 'Specifies the device control where the count is signed. The provider declares it.';
                }
                field(Signature_Size; this.ObjectFunctions.GetSizeOfBinaryData(Rec, Rec.FieldNo(Signature)))
                {
                    Caption = 'Signature Size';
                    ToolTip = 'Specifies the size of the signature, which tells the device whether there is one to show.';
                    Visible = false;
                }
                field(ExampleCountLines; '')
                {
                    Caption = 'Lines';
                    ToolTip = 'Specifies the device button that opens the lines of the count. The provider declares it.';
                }
                field(PrintCount; '')
                {
                    Caption = 'Print';
                    ToolTip = 'Specifies the device button that prints the count as a PDF. The provider declares it.';
                }
            }
        }
    }

    actions
    {
        area(Navigation)
        {
            action(Lines)
            {
                Caption = 'Lines';
                Image = AllLines;
                RunObject = page "Example Stock Count Lines";
                RunPageLink = "Count Entry No." = field("Entry No.");
                ToolTip = 'Open the lines of the count.';
            }
        }
    }

    /// <summary>The web-service wrapper for the Photo control, as MobileNAV's own pages have one per BLOB function.</summary>
    /// <param name="Action">MobileNAV's action code: EXP, IMP, DEL or LEN.</param>
    /// <param name="Base64Result">The picture as base64, for IMP.</param>
    /// <returns>MobileNAV's function result text, carrying the picture for EXP.</returns>
    [ServiceEnabled]
    procedure StockCountPhoto("Action": Text[3]; Base64Result: BigText): Text
    begin
        this.StockCountFunctions.StockCountPhoto(Rec, Action, Base64Result);
        exit(this.ResultHelper.ConvertReturnValuesToResult(Base64Result, '', ''));
    end;

    /// <summary>The web-service wrapper for the Signature control.</summary>
    /// <param name="Action">MobileNAV's action code: EXP, IMP, DEL or LEN.</param>
    /// <param name="Base64Result">The signature as base64, for IMP.</param>
    /// <returns>MobileNAV's function result text, carrying the signature for EXP.</returns>
    [ServiceEnabled]
    procedure StockCountSignature("Action": Text[3]; Base64Result: BigText): Text
    begin
        this.StockCountFunctions.StockCountSignature(Rec, Action, Base64Result);
        exit(this.ResultHelper.ConvertReturnValuesToResult(Base64Result, '', ''));
    end;

    /// <summary>The web-service wrapper for the Print button.</summary>
    /// <returns>MobileNAV's function result text, carrying the PDF.</returns>
    [ServiceEnabled]
    procedure StockCountPrint(): Text
    var
        Base64Result: BigText;
    begin
        this.StockCountFunctions.StockCountPrint(Rec, Base64Result);
        exit(this.ResultHelper.ConvertReturnValuesToResult(Base64Result, '', ''));
    end;

    var
        ObjectFunctions: Codeunit "MobileNAV Object Functions";
        ResultHelper: Codeunit "MobileNAV Result Helper";
        StockCountFunctions: Codeunit "Example Stock Count Functions";
}
