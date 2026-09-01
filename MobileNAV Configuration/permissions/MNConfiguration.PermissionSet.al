namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Grants full access to the objects used by the MobileNAV configuration feature.</summary>
permissionset 77780 "BJF MN Configuration"
{
    Assignable = true;
    Caption = 'MobileNAV Configuration', MaxLength = 30;
    Permissions = codeunit "BJF Check Config Apply State" = X,
        codeunit "BJF Check Config Fields" = X,
        codeunit "BJF Check Config Page Rules" = X,
        codeunit "BJF Check Config Profiles" = X,
        codeunit "BJF Check Config Services" = X,
        codeunit "BJF MN Config Hash" = X,
        codeunit "BJF MN Config Snapshot" = X,
        codeunit "BJF MN Doctor Support" = X,
        codeunit "BJF MN Function Map" = X,
        codeunit "BJF MN Function Router" = X,
        codeunit "BJF MN Profile Mgt." = X,
        codeunit "BJF MN Vocabulary" = X,
        page "BJF MN Doctor" = X,
codeunit "BJF Check Item Tracking Codes" = X,
        codeunit "BJF Check Leftover Jnl. Lines" = X,
        codeunit "BJF Check Movement Journals" = X,
        codeunit "BJF Check Page Relations" = X,
        codeunit "BJF Create Pkg Info On Post." = X,
        codeunit "BJF Diagnostics Runner" = X,
        codeunit "BJF Empty MN Provider" = X,
        codeunit "BJF Movement Journal Mgt." = X,
        codeunit "BJF MN Config Application" = X,
        codeunit "BJF MN Config Builder" = X,
        codeunit "BJF MN Config Validator" = X,
        codeunit "BJF MN Field Mgt." = X,
        codeunit "BJF MN Page Mgt." = X,
        codeunit "BJF MN Provider Catalog" = X,
        codeunit "BJF MN Stage Mgt." = X,
        codeunit "BJF Post Move Lines Only" = X,
        page "BJF Custom MN Config" = X,
        page "BJF Diagnostic Findings Part" = X,
        table "BJF Diagnostic Finding" = X,
        table "BJF MN Config Line" = X,
        table "BJF MN Config Status" = X,
        table "BJF MN Provider Buffer" = X,
        tabledata "BJF Diagnostic Finding" = RIMD,
        tabledata "BJF MN Config Status" = RIMD;
}
