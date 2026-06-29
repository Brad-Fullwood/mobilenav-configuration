namespace BradFullwood.MobileNAV.Configuration;

permissionset 77780 "BJF MN Configuration"
{
    Assignable = true;
    Caption = 'MobileNAV Configuration';
    Permissions = codeunit "BJF MobileNAV Configurator" = X,
        codeunit "BJF Empty MN Setup Module" = X,
        codeunit "BJF MobileNAV Setup Runner" = X,
        report "BJF Apply MN Configuration" = X;
}
