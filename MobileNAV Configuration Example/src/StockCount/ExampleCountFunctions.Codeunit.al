namespace BradFullwood.MobileNAV.Example;

/// <summary>
/// The code behind the Quick Adjust dialog's button. MobileNAV calls the procedure named by
/// the button, with each parameter filled from the dialog control of the same name, and shows
/// the result it returns. The provider publishes this codeunit as the dialog's function service.
/// </summary>
codeunit 50101 "Example Count Functions"
{
    Access = Public;
    Permissions = tabledata "Example Stock Count" = i;

    /// <summary>Records the count as posted. Parameters match the dialog's control names.</summary>
    /// <param name="ItemNo">The item, from the dialog's ItemNo control.</param>
    /// <param name="CountedQuantity">The quantity, from the dialog's CountedQuantity control.</param>
    /// <returns>MobileNAV's function result text. Empty here, so the device shows no message.</returns>
    procedure PostCount(ItemNo: Code[20]; CountedQuantity: Decimal) Result: Text
    var
        StockCount: Record "Example Stock Count";
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
