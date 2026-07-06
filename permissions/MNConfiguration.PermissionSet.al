
namespace BradFullwood.MobileNAV.Configuration;

permissionset 77780 "BJF MN Configuration"
{
    Assignable = true;
    Caption = 'MobileNAV Configuration';
    Permissions = table "BJF MN Config Line" = X,
        table "BJF MN Config Status" = X,
        tabledata "BJF MN Config Status" = RIMD,
        table "BJF MN Provider Buffer" = X,
        codeunit "BJF Empty MN Provider" = X,
        codeunit "BJF MN Config Builder" = X,
        codeunit "BJF MN Provider Catalog" = X,
        codeunit "BJF MN Config Application" = X,
        codeunit "BJF MN Config Validator" = X,
        codeunit "BJF MN Page Mgt." = X,
        codeunit "BJF MN Field Mgt." = X,
        page "BJF Custom MN Config" = X;
}
