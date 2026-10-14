namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The field-control channel for a page or page extension that adds its own FieldControl
/// control. Field control is how Business Central puts a dialog, a colour or a refresh in front
/// of the device user, and how the user's answer comes back. Declare the control with
/// FieldControl('FieldControl'), wire it with the two calls below, and handle the events here,
/// filtered on the page id, the same way buttons are handled in OnPageFunction. In a page
/// extension (this. would mean the base page there):
///
///     field(FieldControl; FieldControlText)
///     {
///         ApplicationArea = All;
///         Visible = false;
///         trigger OnValidate()
///         begin
///             FieldControl.Answer(Page::"MobileNAV Bin", Rec, FieldControlText);
///             if Rec.Find() then;
///         end;
///     }
///     trigger OnAfterGetRecord()
///     begin
///         FieldControlText := FieldControl.Calculate(Page::"MobileNAV Bin", Rec);
///     end;
///     var
///         FieldControl: Codeunit "BJF MN Field Control";
///         FieldControlText: Text;
/// </summary>
codeunit 77709 "BJF MN Field Control"
{
    Access = Public;

    /// <summary>Builds the field-control value for the record. Call it from OnAfterGetRecord.</summary>
    /// <param name="PageId">The page the control sits on, passed to the subscribers.</param>
    /// <param name="SourceRecord">The page's current record.</param>
    /// <returns>The value for the FieldControl control.</returns>
    procedure Calculate(PageId: Integer; SourceRecord: Variant) FieldControl: Text
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable(SourceRecord);
        this.OnCalculateFieldControl(PageId, RecRef, this.FieldControlFactory);
        this.FieldControlFactory.FcGetAsText(SourceRecord, FieldControl);
    end;

    /// <summary>
    /// Passes the device's answer to the subscribers. Call it from the FieldControl control's
    /// OnValidate, then re-read the record, because a subscriber may have changed it.
    /// </summary>
    /// <param name="PageId">The page the control sits on, passed to the subscribers.</param>
    /// <param name="SourceRecord">The page's current record.</param>
    /// <param name="FieldControl">The answer as the device sent it, replaced by what the subscribers return.</param>
    procedure Answer(PageId: Integer; SourceRecord: Variant; var FieldControl: Text)
    var
        RecRef: RecordRef;
    begin
        RecRef.GetTable(SourceRecord);
        this.OnFieldControlAnswer(PageId, RecRef, FieldControl, this.FieldControlFactory);
    end;

    // The public events are the consumer contract of this app.
#pragma warning disable AC0024
    /// <summary>Raised when the device reads a record of the page: set dialogs, colours and field states here.</summary>
    /// <param name="PageId">The page the control sits on.</param>
    /// <param name="SourceRecord">The record being read. SetTable it to work typed.</param>
    /// <param name="FieldControlFactory">Pass it to the "MobileNAV Object Functions" Fc procedures, such as FcSetDialog or FcSetFieldProperties.</param>
    [IntegrationEvent(false, false)]
    procedure OnCalculateFieldControl(PageId: Integer; SourceRecord: RecordRef; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    begin
    end;

    /// <summary>Raised when the device answers a dialog or sends a field-control value back.</summary>
    /// <param name="PageId">The page the control sits on.</param>
    /// <param name="SourceRecord">The record the answer is for. SetTable it to work typed.</param>
    /// <param name="FieldControl">The answer as the device sent it. Set it to what the device should get back.</param>
    /// <param name="FieldControlFactory">Pass it to the "MobileNAV Object Functions" Fc procedures.</param>
    [IntegrationEvent(false, false)]
    procedure OnFieldControlAnswer(PageId: Integer; SourceRecord: RecordRef; var FieldControl: Text; var FieldControlFactory: Codeunit "MobileNAV Object Functions")
    begin
    end;
#pragma warning restore AC0024

    var
        FieldControlFactory: Codeunit "MobileNAV Object Functions";
}
