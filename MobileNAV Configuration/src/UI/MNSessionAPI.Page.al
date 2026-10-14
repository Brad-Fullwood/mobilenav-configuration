namespace BradFullwood.MobileNAV.Configuration;

using System.Environment;

#pragma warning disable LC0063, LC0092 // API names are the contract: camelCase, read by mnconfig.py.
/// <summary>
/// The environment's active sessions, for scripts diagnosing an apply that fails on a record lock
/// ("a record in table ... is being updated in a transaction done by another session"). The bound
/// action stops one session. Route: api/bjf/mobilenav/v1.0/companies({id})/sessions({id}).
/// </summary>
page 77792 "BJF MN Session API"
{
    APIGroup = 'mobilenav';
    APIPublisher = 'bjf';
    APIVersion = 'v1.0';
    Caption = 'Session';
    DelayedInsert = true;
    DeleteAllowed = false;
    EntityCaption = 'Session';
    EntityName = 'session';
    EntitySetCaption = 'Sessions';
    EntitySetName = 'sessions';
    Extensible = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    ODataKeyFields = SystemId;
    PageType = API;
    SourceTable = "Active Session";

    layout
    {
        area(Content)
        {
            repeater(Sessions)
            {
                field(id; Rec.SystemId) { }
                field(lastModifiedDateTime; Rec.SystemModifiedAt) { Caption = 'Last Modified Date Time'; Editable = false; }
                field(sessionId; Rec."Session ID") { }
                field(serverInstanceId; Rec."Server Instance ID") { }
                field(userId; Rec."User ID") { }
                field(clientType; Rec."Client Type") { }
                field(loginDateTime; Rec."Login Datetime") { }
                field(clientComputerName; Rec."Client Computer Name") { }
            }
        }
    }

    /// <summary>Stops this session; the session's open transaction is rolled back.</summary>
    /// <param name="ActionContext">The web service action context.</param>
    [ServiceEnabled]
    procedure stop(var ActionContext: WebServiceActionContext)
    begin
        Session.StopSession(Rec."Session ID", this.StoppedByLbl);
        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"BJF MN Session API");
        ActionContext.SetResultCode(WebServiceActionResultCode::Deleted);
    end;

    var
        StoppedByLbl: Label 'Stopped from the MobileNAV Configuration sessions API.';
}
