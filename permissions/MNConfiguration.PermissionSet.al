namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Grants full access to the objects used by the MobileNAV configuration feature.</summary>
permissionset 77780 "BJF MN Configuration"
{
    Assignable = true;
    Caption = 'MobileNAV Configuration', MaxLength = 30;
    Permissions = codeunit "BJF Empty MN Provider" = X,
        codeunit "BJF MN Config Application" = X,
        codeunit "BJF MN Config Builder" = X,
        codeunit "BJF MN Config Validator" = X,
        codeunit "BJF MN Field Mgt." = X,
        codeunit "BJF MN Page Mgt." = X,
        codeunit "BJF MN Provider Catalog" = X,
        codeunit "BJF MN Stage Mgt." = X,
        page "BJF Custom MN Config" = X,
        table "BJF MN Config Line" = X,
        table "BJF MN Config Status" = X,
        table "BJF MN Provider Buffer" = X,
        tabledata "BJF MN Config Status" = RIMD;
}
