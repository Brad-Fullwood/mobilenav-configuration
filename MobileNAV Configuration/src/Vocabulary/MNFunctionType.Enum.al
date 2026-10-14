namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// The shape of the result a button's function returns. Normal returns a field-control result;
/// the BLOB variants return a file; the GPS variants also receive the device position.
/// </summary>
enum 77785 "BJF MN Function Type"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; Normal) { Caption = 'Normal'; }
    #pragma warning restore AC0019
    value(1; "Generated BLOB") { Caption = 'Generated BLOB'; }
    value(2; BLOB) { Caption = 'BLOB'; }
    value(3; "Normal with GPS") { Caption = 'Normal with GPS'; }
    value(4; "Generated BLOB with GPS") { Caption = 'Generated BLOB with GPS'; }
    value(5; "BLOB with GPS") { Caption = 'BLOB with GPS'; }
}
