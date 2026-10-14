namespace BradFullwood.MobileNAV.Example;

using BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Everything the example needs: its own objects, and "BJF MN Configuration" so the user can
/// open MobileNAV Configuration and MobileNAV Doctor. Assign it to device users and administrators.
/// </summary>
permissionset 50100 "Example MN Config"
{
    Assignable = true;
    Caption = 'MobileNAV Example', MaxLength = 30;
    IncludedPermissionSets = "BJF MN Configuration";
    Permissions =
        table "Example Stock Count" = X,
        tabledata "Example Stock Count" = RIMD,
        table "Example Stock Count Line" = X,
        tabledata "Example Stock Count Line" = RIMD,
        codeunit "Example Bin Handler" = X,
        codeunit "Example Captions" = X,
        codeunit "Example Count Functions" = X,
        codeunit "Example Install" = X,
        codeunit "Example Item Handler" = X,
        codeunit "Example MN Provider" = X,
        codeunit "Example Stock Count Functions" = X,
        page "Example Quick Adjust" = X,
        page "Example Stock Count" = X,
        page "Example Stock Count Lines" = X,
        report "Example Stock Count" = X;
}
