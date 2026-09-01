namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Where the device draws a control. Standard is the card's main section and is the framework's
/// default for every control; Additional folds the control behind the card's "show more"
/// section, which for a button means a device user never finds it.
/// </summary>
enum 77783 "BJF MN Importance"
{
    Access = Public;
    Extensible = false;

    /// <summary>The card's main section — MobileNAV's 'None' importance.</summary>
    value(0; Standard) { Caption = 'Standard'; }
    /// <summary>Required before a record can be inserted.</summary>
    value(1; RequiredForInsert) { Caption = 'Required for Insert'; }
    /// <summary>Required before the record can be saved.</summary>
    value(2; Mandatory) { Caption = 'Mandatory'; }
    /// <summary>Hidden behind the card's additional fields section.</summary>
    value(3; Additional) { Caption = 'Additional'; }
}
