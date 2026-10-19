namespace BradFullwood.MobileNAV.Example.Tests;

using BradFullwood.MobileNAV.Example;

/// <summary>Runs the example's tests.</summary>
permissionset 50150 "Example MN Tests"
{
    Assignable = true;
    Caption = 'MobileNAV Example Tests', MaxLength = 30;
    IncludedPermissionSets = "Example MN Config";
    Permissions =
        table "Example Test Result" = X,
        tabledata "MobileNAV Login Log" = R,
        codeunit "Emulator Test" = X,
        codeunit "Example Cookbook Test" = X,
        codeunit "Example Device Preview Test" = X,
        codeunit "Example Provider Test" = X,
        codeunit "Example Test Runner" = X,
        codeunit "Lookup Scan Builder Test" = X,
        codeunit "New Provider Scaffold Test" = X,
        codeunit "Provider Writer Test" = X,
        page "Example Test Run API" = X;
}
