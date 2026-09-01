namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// How the device renders a button or input. The value names are MobileNAV's own MobileType
/// members, limited to the ones proven on a device; a member missing here is deliberate.
/// </summary>
enum 77784 "BJF MN Mobile Type"
{
    Access = Public;
    Extensible = false;

    value(0; Normal) { Caption = 'Normal'; }
    value(1; Image) { Caption = 'Image'; }
    value(2; PDF) { Caption = 'PDF'; }
    value(3; Hyperlink) { Caption = 'Hyperlink'; }
    value(4; Barcode) { Caption = 'Barcode'; }
    value(5; Email) { Caption = 'Email'; }
    value(6; PhoneNumber) { Caption = 'Phone Number'; }
    value(7; Signature) { Caption = 'Signature'; }
    value(8; File) { Caption = 'File'; }
    value(9; MultilineText) { Caption = 'Multiline Text'; }
    value(10; NoSeries) { Caption = 'No. Series'; }
}
