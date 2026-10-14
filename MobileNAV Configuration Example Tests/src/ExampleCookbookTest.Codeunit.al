namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Example;
using System.Text;

/// <summary>
/// Runs the functions behind the stock count's photo, signature and print controls (levels 12,
/// 13 and 15 of the example provider) the way MobileNAV calls them, and checks the child rows of
/// level 14 go with their count.
/// </summary>
codeunit 50151 "Example Cookbook Test"
{
    Subtype = Test;
    Access = Internal;
    Permissions = tabledata "Example Stock Count" = rid,
        tabledata "Example Stock Count Line" = ri;

    /// <summary>A picture the device sends is stored in the Photo field and read back.</summary>
    [Test]
    procedure PhotoIsStoredAndReadBack()
    var
        StockCount: Record "Example Stock Count";
        StockCountFunctions: Codeunit "Example Stock Count Functions";
        Base64Picture: BigText;
    begin
        this.CreateStockCount(StockCount);
        Base64Picture.AddText(this.OnePixelPngTok);
        StockCountFunctions.StockCountPhoto(StockCount, this.ImportActionTok, Base64Picture);

        if not StockCount.Get(StockCount."Entry No.") then
            Error(this.CountMissingErr);
        if not StockCount.Photo.HasValue() then
            Error(this.NoPhotoErr);
        Clear(Base64Picture);
        StockCountFunctions.StockCountPhoto(StockCount, this.ExportActionTok, Base64Picture);
        if Base64Picture.Length() = 0 then
            Error(this.PhotoNotReadErr);
    end;

    /// <summary>A signature the device sends is stored in the Signature field.</summary>
    [Test]
    procedure SignatureIsStored()
    var
        StockCount: Record "Example Stock Count";
        StockCountFunctions: Codeunit "Example Stock Count Functions";
        Base64Signature: BigText;
    begin
        this.CreateStockCount(StockCount);
        Base64Signature.AddText(this.OnePixelPngTok);
        StockCountFunctions.StockCountSignature(StockCount, this.ImportActionTok, Base64Signature);

        if not StockCount.Get(StockCount."Entry No.") then
            Error(this.CountMissingErr);
        if not StockCount.Signature.HasValue() then
            Error(this.NoSignatureErr);
    end;

    /// <summary>The Print button's function returns a PDF of the count.</summary>
    [Test]
    procedure PrintReturnsAPdf()
    var
        StockCount: Record "Example Stock Count";
        StockCountFunctions: Codeunit "Example Stock Count Functions";
        Base64Convert: Codeunit "Base64 Convert";
        Base64Pdf: BigText;
        Base64PdfText: Text;
    begin
        this.CreateStockCount(StockCount);
        this.CreateStockCountLine(StockCount);
        StockCountFunctions.StockCountPrint(StockCount, Base64Pdf);

        Base64Pdf.GetSubText(Base64PdfText, 1);
        if not Base64Convert.FromBase64(Base64PdfText).StartsWith(this.PdfSignatureTok) then
            Error(this.NotAPdfErr);
    end;

    /// <summary>Deleting a count deletes its lines.</summary>
    [Test]
    procedure DeletingACountDeletesItsLines()
    var
        StockCount: Record "Example Stock Count";
        StockCountLine: Record "Example Stock Count Line";
    begin
        this.CreateStockCount(StockCount);
        this.CreateStockCountLine(StockCount);

        StockCount.Delete(true);

        StockCountLine.SetRange("Count Entry No.", StockCount."Entry No.");
        if not StockCountLine.IsEmpty() then
            Error(this.LinesLeftErr);
    end;

    local procedure CreateStockCount(var StockCount: Record "Example Stock Count")
    begin
        StockCount.Init();
        StockCount.Validate("Counted Quantity", 3);
        StockCount.Insert(true);
    end;

    local procedure CreateStockCountLine(StockCount: Record "Example Stock Count")
    var
        StockCountLine: Record "Example Stock Count Line";
    begin
        StockCountLine.Validate("Count Entry No.", StockCount."Entry No.");
        StockCountLine.Validate("Line No.", 10000);
        StockCountLine.Validate("Lot No.", this.LotNoTok);
        StockCountLine.Validate(Quantity, 3);
        StockCountLine.Insert(true);
    end;

    var
        OnePixelPngTok: Label 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=', Locked = true;
        ImportActionTok: Label 'IMP', Locked = true;
        ExportActionTok: Label 'EXP', Locked = true;
        PdfSignatureTok: Label '%PDF', Locked = true;
        LotNoTok: Label 'LOT-TEST', Locked = true;
        CountMissingErr: Label 'The stock count is missing after the function ran.';
        NoPhotoErr: Label 'The photo was not stored.';
        PhotoNotReadErr: Label 'The photo was not read back.';
        NoSignatureErr: Label 'The signature was not stored.';
        NotAPdfErr: Label 'The print function did not return a PDF.';
        LinesLeftErr: Label 'The lines of the deleted count are still there.';
}
