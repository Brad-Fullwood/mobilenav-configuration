namespace Test.Example;

using BradFullwood.MobileNAV.Configuration;

codeunit 50100 "Example MN Provider" implements "BJF MN Config Provider"
{
    Access = Internal;

    procedure GetId(): Code[50]
    begin
        exit(this.ProviderIdTok);
    end;

    procedure GetName(): Text[100]
    begin
        exit(this.ProviderNameLbl);
    end;

    var
        ProviderIdTok: Label 'EXAMPLE', Locked = true;
        ProviderNameLbl: Label 'MobileNAV Configuration Example';
}

codeunit 50101 "Literal Provider" implements "BJF MN Config Provider"
{
    procedure GetId(): Code[50]
    begin
        exit('LIT-1');
    end;
}

codeunit 50102 "Unrelated"
{
    procedure GetId(): Code[50]
    begin
        exit('NOPE');
    end;
}
