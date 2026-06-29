# Consumer extension example

The consuming app declares this extension as a dependency, implements the provider contract, and registers the implementation through an enum extension.

```al
namespace Contoso.MobileNAV;

using BradFullwood.MobileNAV.Configuration;

codeunit 50100 "CTO MN Config Provider" implements "BJF MN Config Provider"
{
    procedure GetId(): Code[50]
    begin
        exit('CONTOSO-MOBILE');
    end;

    procedure GetName(): Text[100]
    begin
        exit('Contoso MobileNAV');
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('Configures Contoso item fields and the mobile lookup page.');
    end;

    procedure GetVersion(): Integer
    begin
        exit(1);
    end;

    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
    begin
        Configuration.AddPublishedPage(Page::"CTO Mobile Lookup", 'CTOMobileLookup');
        Configuration.AddVisibleField(Page::"MobileNAV Item", 'CTO Reference', false);
        Configuration.AddLinkedField(
            Page::"MobileNAV Item", 'CTO Open Lookup', Page::"CTO Mobile Lookup",
            'Item No.', 'No.');
    end;
}

enumextension 50100 "CTO MN Config Providers" extends "BJF MN Config Provider"
{
    value(50100; "Contoso MobileNAV")
    {
        Caption = 'Contoso MobileNAV';
        Implementation = "BJF MN Config Provider" = "CTO MN Config Provider";
    }
}
```

To apply this provider automatically from the consumer's install or upgrade codeunit:

```al
local procedure ApplyMobileNAVConfiguration()
var
    ConfigurationApplication: Codeunit "BJF MN Config Application";
begin
    ConfigurationApplication.ApplyProvider(
        Enum::"BJF MN Config Provider"::"Contoso MobileNAV");
end;
```

The consumer permission set must grant execute permission to `"CTO MN Config Provider"`. Administrators can then use **Apply custom MobileNAV config** to inspect state, select providers, apply them, or mark previously applied providers outdated.
