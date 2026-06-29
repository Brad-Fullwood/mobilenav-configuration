# Consumer extension example

The consuming app declares this extension as a dependency, implements one setup module, and registers it through an enum extension.

```al
namespace Contoso.MobileNAV;

using BradFullwood.MobileNAV.Configuration;

codeunit 50100 "CTO MobileNAV Setup" implements "BJF MobileNAV Setup Module"
{
    procedure ApplySetup()
    var
        Configurator: Codeunit "BJF MobileNAV Configurator";
        HostServiceName: Text[100];
        TargetServiceName: Text[100];
    begin
        Configurator.EnsurePublishedPage(Page::"CTO Mobile Lookup", LookupServiceNameTok, TargetServiceName);

        if not Configurator.RefreshConfiguredPage(Page::"MobileNAV Item", HostServiceName) then
            Error(PageNotConfiguredErr, Page::"MobileNAV Item");
        if not Configurator.ShowField(HostServiceName, 'CTO Reference', false) then
            Error(FieldNotFoundErr, 'CTO Reference', HostServiceName);
        if not Configurator.ShowLinkedField(
            HostServiceName, 'CTO Open Lookup', CopyStr(TargetServiceName, 1, 75),
            'Item No.', 'No.')
        then
            Error(FieldNotFoundErr, 'CTO Open Lookup', HostServiceName);
    end;

    var
        LookupServiceNameTok: Label 'CTOMobileLookup', Locked = true;
        PageNotConfiguredErr: Label 'MobileNAV page %1 has not been configured.', Comment = '%1 = page object id';
        FieldNotFoundErr: Label 'Control %1 was not found on MobileNAV service %2.', Comment = '%1 = control name, %2 = service name';
}

enumextension 50100 "CTO MN Setup Modules" extends "BJF MobileNAV Setup Module"
{
    value(50100; "Contoso MobileNAV")
    {
        Caption = 'Contoso MobileNAV';
        Implementation = "BJF MobileNAV Setup Module" = "CTO MobileNAV Setup";
    }
}
```

Call only the consumer's module from its install and upgrade codeunits. This avoids reapplying unrelated modules while an app is being installed.

```al
local procedure ApplyMobileNAVSetup()
var
    SetupRunner: Codeunit "BJF MobileNAV Setup Runner";
begin
    SetupRunner.ApplyModule(Enum::"BJF MobileNAV Setup Module"::"Contoso MobileNAV");
end;
```

Users can also run **Apply MobileNAV Configuration** to apply every registered module on demand. The consumer's permission set must grant execute permission to its setup-module codeunit for that manual route.
