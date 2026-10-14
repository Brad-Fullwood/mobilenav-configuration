namespace BradFullwood.MobileNAV.Configuration;

/// <summary>
/// Connects the device emulator and tells the user when it cannot. The emulator page calls Connect when it opens
/// and after each setup change. A failed connection shows a notification with the reason. Its Connect action retries,
/// and for the MobileNAV Token source its Request MobileNAV Token action runs MobileNAV's own token request first.
/// The notification is recalled once the emulator has a token.
/// </summary>
codeunit 77772 "BJF MN Emulator Connect"
{
    Access = Internal;

    var
        Setup: Record "BJF MN Emulator Setup";
        Token: Codeunit "BJF MN Emulator Token";
        NotificationIdTok: Label '{4D6C2B1E-9A3F-4E8B-8C27-5F0A1D9E7B31}', Locked = true;
        ConnectActionLbl: Label 'Connect';
        RequestActionLbl: Label 'Request MobileNAV Token';
        NotConnectedMsg: Label 'The emulator is not connected to Business Central. %1', Comment = '%1 = the reason the token source gave';

    /// <summary>
    /// Makes sure the emulator has a token. A token that is already held is used. Otherwise the token source signs in,
    /// which for source App Registration opens the Microsoft sign-in page. A failure shows a notification with the reason.
    /// </summary>
    /// <returns>True when the emulator has a token.</returns>
    procedure Connect(): Boolean
    begin
        if not this.Token.IsConnected() then
            if not this.TryConnect() then begin
                this.ShowNotConnected(GetLastErrorText());
                exit(false);
            end;
        this.Recall();
        exit(true);
    end;

    /// <summary>
    /// Runs MobileNAV's token request for the signed-in user, then connects. A request that MobileNAV refuses shows a
    /// notification with the reason. Cancelling the request shows nothing new.
    /// </summary>
    /// <returns>True when the emulator has a token after the request.</returns>
    procedure RequestMobileNAVToken(): Boolean
    begin
        if not this.TryRequest() then begin
            this.ShowNotConnected(GetLastErrorText());
            exit(false);
        end;
        exit(this.Connect());
    end;

    /// <summary>Runs the connection again. The Connect action of the notification calls this procedure.</summary>
    /// <param name="ConnectNotification">The notification whose action was chosen.</param>
    procedure ConnectFromNotification(ConnectNotification: Notification)
    begin
        ConnectNotification.Recall();
        this.Connect();
    end;

    /// <summary>Runs the MobileNAV token request. The Request MobileNAV Token action of the notification calls this procedure.</summary>
    /// <param name="ConnectNotification">The notification whose action was chosen.</param>
    procedure RequestFromNotification(ConnectNotification: Notification)
    begin
        ConnectNotification.Recall();
        this.RequestMobileNAVToken();
    end;

    /// <summary>Signs in or checks the token through the token source. Errors come back as the last error text.</summary>
    /// <returns>True when the token source gave a token.</returns>
    [TryFunction]
    local procedure TryConnect()
    begin
        this.Token.Connect();
    end;

    /// <summary>Runs the MobileNAV token request through the token codeunit. Errors come back as the last error text.</summary>
    /// <returns>True when the request ran without an error.</returns>
    [TryFunction]
    local procedure TryRequest()
    begin
        this.Token.RequestMobileNAVToken();
    end;

    /// <summary>
    /// Shows the notification that says why the emulator is not connected. It always offers Connect. With the MobileNAV
    /// Token source it also offers Request MobileNAV Token.
    /// </summary>
    /// <param name="Reason">The reason the token source gave.</param>
    local procedure ShowNotConnected(Reason: Text)
    var
        ConnectNotification: Notification;
    begin
        this.Setup.GetSetup();
        ConnectNotification.Id(this.NotificationId());
        ConnectNotification.Message(StrSubstNo(this.NotConnectedMsg, Reason));
        ConnectNotification.Scope(NotificationScope::LocalScope);
        ConnectNotification.AddAction(this.ConnectActionLbl, Codeunit::"BJF MN Emulator Connect", 'ConnectFromNotification');
        if this.Setup."Token Source" = "BJF MN Emulator Token Source"::MobileNAVToken then
            ConnectNotification.AddAction(this.RequestActionLbl, Codeunit::"BJF MN Emulator Connect", 'RequestFromNotification');
        ConnectNotification.Send();
    end;

    /// <summary>Removes the notification of a failed connection.</summary>
    local procedure Recall()
    var
        ConnectNotification: Notification;
    begin
        ConnectNotification.Id(this.NotificationId());
        ConnectNotification.Recall();
    end;

    /// <summary>The fixed ID of the connection notification, so that a later connection can recall it.</summary>
    /// <returns>The notification ID.</returns>
    local procedure NotificationId(): Guid
    var
        Id: Guid;
    begin
        Evaluate(Id, this.NotificationIdTok);
        exit(Id);
    end;
}
