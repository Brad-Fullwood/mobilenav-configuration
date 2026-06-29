namespace BradFullwood.MobileNAV.Configuration;

codeunit 77780 "BJF Empty MN Provider" implements "BJF MN Config Provider"
{
    Access = Internal;

    procedure GetId(): Code[50]
    begin
        exit('');
    end;

    procedure GetName(): Text[100]
    begin
        exit('');
    end;

    procedure GetDescription(): Text[250]
    begin
        exit('');
    end;

    procedure GetVersion(): Integer
    begin
        exit(0);
    end;

    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
    begin
    end;
}
