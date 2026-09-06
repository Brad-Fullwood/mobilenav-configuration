namespace BradFullwood.MobileNAV.Showcase;

using BradFullwood.MobileNAV.Configuration;

permissionset 50100 "Showcase MN Config"
{
    Assignable = true;
    Caption = 'MobileNAV Showcase', MaxLength = 30;
    IncludedPermissionSets = "BJF MN Configuration";
    Permissions =
        codeunit "Showcase Button Handler" = X,
        codeunit "Showcase Count Functions" = X,
        codeunit "Showcase Install" = X,
        codeunit "Showcase MN Provider" = X,
        page "Showcase Quick Adjust" = X,
        page "Showcase Stock Count" = X,
        table "Showcase Stock Count" = X,
        tabledata "Showcase Stock Count" = RIMD;
}
