namespace BradFullwood.MobileNAV.Example;

using System.Text;
using System.Utilities;

/// <summary>
/// The functions behind the stock count's photo, signature and print controls. MobileNAV has no
/// page functions for a table of your own, so the provider declares this codeunit with
/// PageFunctions() and the framework registers it under the page's web service. Each procedure
/// takes the tapped record as Key and has the shape of MobileNAV's own BLOB functions, such as
/// ItemPicture and SalesQuoteToPDF on "MobileNAV Page Functions". The stock count page calls the
/// same procedures from its web-service wrappers.
/// </summary>
codeunit 50106 "Example Stock Count Functions"
{
    Access = Public;

    /// <summary>
    /// Reads, stores or deletes the count's photo. MobileNAV sends the action: EXP to show the
    /// photo, IMP with the picture the device took, DEL to remove it, LEN for its size.
    /// </summary>
    /// <param name="Key">The stock count the device shows.</param>
    /// <param name="Action">MobileNAV's action code: EXP, IMP, DEL or LEN.</param>
    /// <param name="Base64Result">The picture as base64, in for IMP and out for EXP.</param>
    procedure StockCountPhoto("Key": Record "Example Stock Count"; "Action": Text[3]; var Base64Result: BigText)
    var
        ObjectFunctions: Codeunit "MobileNAV Object Functions";
    begin
        ObjectFunctions.HandleBase64EncodedData(Key, Key.FieldNo(Photo), Action, Base64Result);
    end;

    /// <summary>Reads, stores or deletes the count's signature, with the same actions as the photo.</summary>
    /// <param name="Key">The stock count the device shows.</param>
    /// <param name="Action">MobileNAV's action code: EXP, IMP, DEL or LEN.</param>
    /// <param name="Base64Result">The signature as base64, in for IMP and out for EXP.</param>
    procedure StockCountSignature("Key": Record "Example Stock Count"; "Action": Text[3]; var Base64Result: BigText)
    var
        ObjectFunctions: Codeunit "MobileNAV Object Functions";
    begin
        ObjectFunctions.HandleBase64EncodedData(Key, Key.FieldNo(Signature), Action, Base64Result);
    end;

    /// <summary>Runs the stock count report for the count and returns the PDF, which the device opens.</summary>
    /// <param name="Key">The stock count the device shows.</param>
    /// <param name="Base64Result">The PDF as base64.</param>
    procedure StockCountPrint("Key": Record "Example Stock Count"; var Base64Result: BigText)
    var
        StockCount: Record "Example Stock Count";
        TempBlob: Codeunit "Temp Blob";
        Base64Convert: Codeunit "Base64 Convert";
        StockCountRecordRef: RecordRef;
        PdfOutStream: OutStream;
        PdfInStream: InStream;
    begin
        StockCount.SetRange("Entry No.", Key."Entry No.");
        StockCountRecordRef.GetTable(StockCount);
        TempBlob.CreateOutStream(PdfOutStream);
        Report.SaveAs(Report::"Example Stock Count", '', ReportFormat::Pdf, PdfOutStream, StockCountRecordRef);
        TempBlob.CreateInStream(PdfInStream);
        Clear(Base64Result);
        Base64Result.AddText(Base64Convert.ToBase64(PdfInStream));
    end;
}
