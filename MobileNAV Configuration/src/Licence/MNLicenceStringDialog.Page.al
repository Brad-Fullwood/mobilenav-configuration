namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Asks for the MobileNAV licence string to install.</summary>
page 77704 "BJF MN Licence String Dialog"
{
    ApplicationArea = All;
    Caption = 'Install MobileNAV Licence String';
    Extensible = false;
    PageType = StandardDialog;
    UsageCategory = None;

    layout
    {
        area(Content)
        {
            field(LicenceStringField; this.LicenceString)
            {
                Caption = 'Licence string';
                MultiLine = true;
                ToolTip = 'Specifies the licence string copied from the MobileNAV Licence page of another environment of this tenant. It replaces the installed licence, and with it the number of licensed devices.';
            }
        }
    }

    /// <summary>The licence string the user entered.</summary>
    /// <returns>The licence string.</returns>
    procedure GetLicenceString(): Text
    begin
        exit(this.LicenceString);
    end;

    var
        LicenceString: Text;
}
