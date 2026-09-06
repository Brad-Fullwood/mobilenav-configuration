namespace BradFullwood.MobileNAV.Showcase;

/// <summary>
/// The code behind the Quick Adjust dialog's button. MobileNAV calls the procedure named by
/// the button, with each parameter filled from the dialog control of the same name, and shows
/// the result it returns. The provider publishes this codeunit as the dialog's function service.
/// </summary>
codeunit 50101 "Showcase Count Functions"
{
    Access = Public;

    /// <summary>Records the count as posted. Parameters match the dialog's control names.</summary>
    procedure PostCount(ItemNo: Code[20]; CountedQuantity: Decimal) Result: Text
    var
        StockCount: Record "Showcase Stock Count";
        ResultHelper: Codeunit "MobileNAV Result Helper";
        Base64Result: BigText;
    begin
        StockCount.Init();
        StockCount.Validate("Item No.", ItemNo);
        StockCount.Validate("Counted Quantity", CountedQuantity);
        StockCount.Validate(Posted, true);
        StockCount.Insert(true);
        Result := ResultHelper.ConvertReturnValuesToResult(Base64Result, '', '');
    end;
}
