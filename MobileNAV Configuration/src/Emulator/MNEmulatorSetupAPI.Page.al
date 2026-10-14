namespace BradFullwood.MobileNAV.Configuration;

using System.Environment;

#pragma warning disable LC0063, LC0092 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The device emulator's setup row over the API: the token source, the write switches and the device ID.
/// Reads whether a token is available now and whether this is a sandbox. Allow Writes In Production is read
/// only here, so production writes stay a choice on the setup page. The bound action supplyToken stores a
/// token the caller already holds for the signed-in user. The token never appears in a field or response.
/// Route: api/bjf/mobilenav/v1.0/companies({id})/emulatorSetups({id}).
/// Action: POST .../emulatorSetups({id})/Microsoft.NAV.supplyToken with {"accessToken": "...", "expiresIn": 3600}.
/// </summary>
page 77703 "BJF MN Emulator Setup API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'MobileNAV Emulator Setup';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'MobileNAV Emulator Setup';
    EntityName = 'emulatorSetup';
    EntitySetCaption = 'MobileNAV Emulator Setups';
    EntitySetName = 'emulatorSetups';
    Extensible = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "BJF MN Emulator Setup";

    layout
    {
        area(Content)
        {
            repeater(Setups)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt)
                {
                    Caption = 'Last Modified Date Time';
                    Editable = false;
                }
                field(tokenSource; Rec."Token Source") { }
                field(allowWrites; Rec."Allow Writes") { }
                field(deviceId; Rec."Device ID") { }
                field(clientId; Rec."Client ID") { }
                field(allowWritesInProduction; Rec."Allow Writes in Production")
                {
                    Editable = false;
                }
                field(connected; this.ConnectedValue)
                {
                    Editable = false;
                }
                field(sandbox; this.SandboxValue)
                {
                    Editable = false;
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.GetSetup();
    end;

    trigger OnAfterGetRecord()
    var
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        this.ConnectedValue := this.Token.IsConnected();
        this.SandboxValue := EnvironmentInformation.IsSandbox();
    end;

    /// <summary>Stores a token the caller holds for the signed-in user, for the token source Supplied Token.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    /// <param name="accessToken">The Business Central delegated token of the signed-in user.</param>
    /// <param name="expiresIn">The token lifetime in seconds, as the token response gives it.</param>
    [ServiceEnabled]
    [NonDebuggable]
    procedure supplyToken(var ActionContext: WebServiceActionContext; accessToken: Text; expiresIn: Integer)
    var
        SuppliedToken: SecretText;
    begin
        SuppliedToken := SecretStrSubstNo('%1', accessToken);
        this.Token.SupplyToken(SuppliedToken, expiresIn);
        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"BJF MN Emulator Setup API");
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    var
        Token: Codeunit "BJF MN Emulator Token";
        ConnectedValue: Boolean;
        SandboxValue: Boolean;
}
