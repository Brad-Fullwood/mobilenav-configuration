namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// How the device validates a scanned or typed value before accepting it. Default keeps
/// MobileNAV's own behavior for the control.
/// </summary>
enum 77786 "BJF MN Validation Behavior"
{
    Access = Public;
    Extensible = false;

    value(0; Default) { Caption = 'Default'; }
    value(1; ScanToValidate) { Caption = 'Scan to Validate'; }
    value(2; ScanWithChangeConfirm) { Caption = 'Scan with Change Confirm'; }
    value(3; Scan) { Caption = 'Scan'; }
    value(4; Mandatory) { Caption = 'Mandatory'; }
    value(5; MandatoryToValidate) { Caption = 'Mandatory to Validate'; }
    value(6; MandatoryWithChangeConfirm) { Caption = 'Mandatory with Change Confirm'; }
    value(7; ScanOrManualEntry) { Caption = 'Scan or Manual Entry'; }
    value(8; ScanOrManualEntryWithChangeConfirm) { Caption = 'Scan or Manual Entry with Change Confirm'; }
    value(9; ScanOrManualEntryToValidate) { Caption = 'Scan or Manual Entry to Validate'; }
}
