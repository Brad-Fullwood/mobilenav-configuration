namespace BradFullwood.MobileNAV.Configuration;

/// <summary>The shape MobileNAV gives a page. Report is the action-dialog pattern PublishAsDialog uses.</summary>
enum 77789 "BJF MN Page Type"
{
    Access = Public;
    Extensible = false;

    /// <summary>A list that opens a card.</summary>
    value(0; ListCard) { Caption = 'List and Card'; }
    value(1; List) { Caption = 'List'; }
    value(2; Card) { Caption = 'Card'; }
    /// <summary>Parameter fields plus a button; see PublishAsDialog.</summary>
    value(3; Report) { Caption = 'Dialog'; }
    /// <summary>A list kept on the device for offline use.</summary>
    value(4; Offline) { Caption = 'Offline'; }
    value(5; OfflineCard) { Caption = 'Offline Card'; }
}
