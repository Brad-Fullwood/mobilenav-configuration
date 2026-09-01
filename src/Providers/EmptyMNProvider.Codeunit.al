namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Null-object implementation behind the None enum value; never applied.</summary>
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

    procedure DefineConfiguration(var Configuration: Codeunit "BJF MN Config Builder")
    begin
    end;
}
