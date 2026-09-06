namespace BradFullwood.MobileNAV.Configuration;

/// <summary>What an offline operation does. The names are MobileNAV's own Operation Type members.</summary>
enum 77765 "BJF MN Operation Type"
{
    Access = Public;
    Extensible = false;

    value(0; PosAdjmt) { Caption = 'Positive Adjustment'; }
    value(1; NegAdjmt) { Caption = 'Negative Adjustment'; }
    value(2; Transferfields_Creating) { Caption = 'Transfer Fields (Creating)'; }
    value(3; Transferfields_Lookup) { Caption = 'Transfer Fields (Lookup)'; }
    value(4; Multiplication) { Caption = 'Multiplication'; }
    value(5; Transferfields_Min) { Caption = 'Transfer Fields (Min)'; }
    value(6; Transferfields_Max) { Caption = 'Transfer Fields (Max)'; }
    value(7; Transferfields_Avg) { Caption = 'Transfer Fields (Avg)'; }
    value(8; Transferfields_Sum) { Caption = 'Transfer Fields (Sum)'; }
    value(9; Transferfields_Count) { Caption = 'Transfer Fields (Count)'; }
    value(10; Modification) { Caption = 'Modification'; }
}
