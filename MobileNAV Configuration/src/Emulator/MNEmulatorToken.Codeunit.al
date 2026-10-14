namespace BradFullwood.MobileNAV.Configuration;

using System.Azure.Identity;
using System.Security.Authentication;

/// <summary>
/// Holds the delegated token the emulator sends with its page service calls. Source "App Registration"
/// signs in through the System Application OAuth2 module with the app registration in the setup. Source
/// "MobileNAV Token" reuses the token MobileNAV stored for the signed-in user and refreshes it when it has
/// expired. Source "Supplied Token" uses a token the caller already holds for the signed-in user, which
/// SupplyToken stores in isolated storage until it expires. The token stays in a SecretText for this
/// session only, and no token is written to a table.
/// </summary>
codeunit 77730 "BJF MN Emulator Token"
{
    Access = Internal;
    SingleInstance = true;
    Permissions = tabledata "MobileNAV User Setup" = r;

    var
        Setup: Record "BJF MN Emulator Setup";
        AzureADTenant: Codeunit "Azure AD Tenant";
        OAuth2: Codeunit "OAuth2";
        Token: SecretText;
        CachedSource: Enum "BJF MN Emulator Token Source";
        ExpiresAt: DateTime;
        AuthorityTok: Label 'https://login.microsoftonline.com/%1/oauth2/v2.0/authorize', Locked = true;
        ScopeTok: Label 'https://api.businesscentral.dynamics.com/user_impersonation', Locked = true;
        SuppliedTokenKeyTok: Label 'BJF-MN-EMU-SUPPLIED', Locked = true;
        SuppliedExpiryKeyTok: Label 'BJF-MN-EMU-SUPPLIED-EXP', Locked = true;
        SignInFailedErr: Label 'The sign-in failed: %1', Comment = '%1 = the error text the OAuth2 module returned';
        MissingAppRegistrationErr: Label 'Enter the Client ID and the client secret in Emulator Setup on the MobileNAV Device Emulator page. The emulator connects after each change.';
        NoMobileNAVTokenErr: Label 'MobileNAV has no stored token for user %1. Choose Request MobileNAV Token on the MobileNAV Device Emulator page, then sign in with the O365 Auth. Email shown on the O365 Self-authorization (MobileNAV) page.', Comment = '%1 = the Business Central user ID';
        NoUserSetupErr: Label 'MobileNAV has no user setup for user %1. Set up MobileNAV for this user first.', Comment = '%1 = the Business Central user ID';
        MobileNAVRequestErr: Label '%1', Comment = '%1 = the reason MobileNAV gave for the failed token request';
        SuppliedSignInErr: Label 'Supplied Token has no sign-in. Run the token script from the MobileNAV Device Emulator page. The script sends the token to the emulator.';
        EmptySuppliedTokenErr: Label 'The supplied token is empty. Send a token that the signed-in user holds.';
        ShortSuppliedTokenErr: Label 'The supplied token lasts %1 seconds. Supply a token that lasts more than 60 seconds.', Comment = '%1 = the lifetime in seconds the caller sent';

    /// <summary>
    /// Signs in now and stores the token. Source "App Registration" opens the Microsoft sign-in page, so it
    /// needs an interactive session. Source "MobileNAV Token" only checks that MobileNAV has a usable token.
    /// Source "Supplied Token" has no sign-in, so this raises an error that points to SupplyToken.
    /// </summary>
    /// <remarks>Raises an error when the sign-in fails or the setup is incomplete.</remarks>
    [NonDebuggable]
    procedure Connect()
    var
        AccessToken: SecretText;
    begin
        this.Setup.GetSetup();
        if this.Setup."Token Source" = "BJF MN Emulator Token Source"::SuppliedToken then
            Error(this.SuppliedSignInErr);
        if this.Setup."Token Source" = "BJF MN Emulator Token Source"::MobileNAVToken then begin
            if not this.TryMobileNAVToken(AccessToken) then
                Error(this.NoMobileNAVTokenErr, UserId());
            exit;
        end;

        this.SignInWithAppRegistration();
    end;

    /// <summary>Opens the Microsoft sign-in page for the app registration and keeps the token it returns.</summary>
    /// <remarks>Raises an error when the setup is incomplete or the sign-in fails.</remarks>
    [NonDebuggable]
    local procedure SignInWithAppRegistration()
    var
        AccessToken: SecretText;
        AuthCodeErr: Text;
        RedirectUrl: Text;
    begin
        if (this.Setup."Client ID" = '') or not this.Setup.HasClientSecret() then
            Error(this.MissingAppRegistrationErr);

        this.OAuth2.GetDefaultRedirectURL(RedirectUrl);
        if not this.OAuth2.AcquireTokenByAuthorizationCode(this.Setup."Client ID", this.Setup.GetClientSecret(), this.AuthorityUrl(), RedirectUrl, this.RequestScopes(), "Prompt Interaction"::"Select Account", AccessToken, AuthCodeErr) then begin
            if AuthCodeErr = '' then
                AuthCodeErr := GetLastErrorText();
            Error(this.SignInFailedErr, AuthCodeErr);
        end;
        this.Remember(AccessToken, CurrentDateTime() + (50 * 60 * 1000)); // The Entra token lives about an hour. Reuse it for 50 minutes.
    end;

    /// <summary>
    /// Returns a usable token without asking the user. Reuses the token kept by this session while it is
    /// current, then asks the token source for one.
    /// </summary>
    /// <param name="AccessToken">The token, when the function returns true.</param>
    /// <returns>True when a token is available. False means the user must choose Connect.</returns>
    [NonDebuggable]
    procedure TryGetToken(var AccessToken: SecretText): Boolean
    begin
        this.Setup.GetSetup();
        if this.Setup."Token Source" = "BJF MN Emulator Token Source"::SuppliedToken then
            exit(this.TrySuppliedToken(AccessToken));

        if (this.CachedSource = this.Setup."Token Source") and (CurrentDateTime() < this.ExpiresAt) then begin
            AccessToken := this.Token;
            exit(true);
        end;

        if this.Setup."Token Source" = "BJF MN Emulator Token Source"::MobileNAVToken then
            exit(this.TryMobileNAVToken(AccessToken));
        exit(this.TryAppRegistrationToken(AccessToken));
    end;

    /// <summary>
    /// Stores a token the caller already holds for the signed-in user, for source "Supplied Token". The token
    /// and its expiry go to isolated storage for this user. Nothing is written to a table.
    /// </summary>
    /// <remarks>Raises an error when the token is empty or lasts 60 seconds or less.</remarks>
    /// <param name="AccessToken">The Business Central delegated token of the signed-in user.</param>
    /// <param name="ExpiresInSeconds">The token lifetime in seconds, as the token response gives it.</param>
    [NonDebuggable]
    procedure SupplyToken(AccessToken: SecretText; ExpiresInSeconds: Integer)
    var
        Expiry: DateTime;
    begin
        if AccessToken.IsEmpty() then
            Error(this.EmptySuppliedTokenErr);
        if ExpiresInSeconds <= 60 then
            Error(this.ShortSuppliedTokenErr, ExpiresInSeconds);

        Expiry := CurrentDateTime() + ((ExpiresInSeconds - 60) * 1000); // Stop reusing the token 60 seconds before it expires.
        IsolatedStorage.Set(this.SuppliedTokenKeyTok, AccessToken, DataScope::User);
#pragma warning disable LC0043 // The expiry time is not a secret. Only the token is.
        IsolatedStorage.Set(this.SuppliedExpiryKeyTok, Format(Expiry, 0, 9), DataScope::User);
#pragma warning restore LC0043
    end;

    /// <summary>Tells whether a token is available now, without asking the user.</summary>
    /// <returns>True when a token is available.</returns>
    [NonDebuggable]
    procedure IsConnected(): Boolean
    var
        AccessToken: SecretText;
    begin
        exit(this.TryGetToken(AccessToken));
    end;

    /// <summary>
    /// Runs the request that O365 Self-authorization (MobileNAV) runs for the signed-in user. MobileNAV asks for a
    /// confirmation, opens its sign-in dialog and stores the access token in the user's MobileNAV User Setup. The emulator
    /// then reads that token with TryGetToken.
    /// </summary>
    /// <remarks>Raises an error when the user has no MobileNAV User Setup or MobileNAV reports why the request failed. A cancelled request raises no error.</remarks>
    [NonDebuggable]
    procedure RequestMobileNAVToken()
    var
        MNUserSetup: Record "MobileNAV User Setup";
        MNOAuthHelper: Codeunit "MobileNAV OAuth Helper";
        MessageTxt: Text;
    begin
        if not MNUserSetup.Get(UserId()) then
            Error(this.NoUserSetupErr, UserId());
        if MNOAuthHelper.RequestAccessToken(MNUserSetup, MessageTxt, true) then
            exit;
        if MessageTxt <> '' then
            Error(this.MobileNAVRequestErr, MessageTxt);
    end;

    /// <summary>Reads the token from the signed-in user's MobileNAV setup, refreshing it when it has expired.</summary>
    /// <param name="AccessToken">The token, when the function returns true.</param>
    /// <returns>True when MobileNAV has a usable token for the user.</returns>
    [NonDebuggable]
    local procedure TryMobileNAVToken(var AccessToken: SecretText): Boolean
    var
        MNUserSetup: Record "MobileNAV User Setup";
        MNOAuthHelper: Codeunit "MobileNAV OAuth Helper";
        StoredToken: Text;
        MessageTxt: Text;
    begin
        if not MNUserSetup.Get(UserId()) then
            exit(false);
        if CurrentDateTime() >= this.MobileNAVTokenExpiry(MNUserSetup) then
            if not MNOAuthHelper.RefreshAccessToken(MNUserSetup, MessageTxt) then
                exit(false);

        StoredToken := MNOAuthHelper.GetAccessToken(MNUserSetup);
        if StoredToken = '' then
            exit(false);
        AccessToken := SecretStrSubstNo('%1', StoredToken);
        this.Remember(AccessToken, this.MobileNAVTokenExpiry(MNUserSetup));
        exit(true);
    end;

    /// <summary>Reads the token from the App Registration with the System Application OAuth2 module, without a sign-in page.</summary>
    /// <param name="AccessToken">The token, when the function returns true.</param>
    /// <returns>True when the module has a cached token for this app registration and user.</returns>
    [NonDebuggable]
    local procedure TryAppRegistrationToken(var AccessToken: SecretText): Boolean
    var
        RedirectUrl: Text;
    begin
        if (this.Setup."Client ID" = '') or not this.Setup.HasClientSecret() then
            exit(false);

        this.OAuth2.GetDefaultRedirectURL(RedirectUrl);
        if not this.OAuth2.AcquireAuthorizationCodeTokenFromCache(this.Setup."Client ID", this.Setup.GetClientSecret(), RedirectUrl, this.AuthorityUrl(), this.RequestScopes(), AccessToken) then
            exit(false);
        this.Remember(AccessToken, CurrentDateTime() + (50 * 60 * 1000));
        exit(true);
    end;

    /// <summary>Reads the token that SupplyToken stored for the signed-in user, while it has not expired.</summary>
    /// <param name="AccessToken">The token, when the function returns true.</param>
    /// <returns>True when a supplied token is stored for the user and has not expired.</returns>
    [NonDebuggable]
    local procedure TrySuppliedToken(var AccessToken: SecretText): Boolean
    var
        StoredToken: SecretText;
        ExpiryText: Text;
        Expiry: DateTime;
    begin
        if not IsolatedStorage.Get(this.SuppliedTokenKeyTok, DataScope::User, StoredToken) then
            exit(false);
#pragma warning disable LC0043 // The expiry time is not a secret. Only the token is.
        if not IsolatedStorage.Get(this.SuppliedExpiryKeyTok, DataScope::User, ExpiryText) then
#pragma warning restore LC0043
            exit(false);
        if not Evaluate(Expiry, ExpiryText, 9) then
            exit(false);
        if CurrentDateTime() >= Expiry then
            exit(false);

        AccessToken := StoredToken;
        exit(true);
    end;

    /// <summary>Keeps the token for this session until its expiry, with the source that gave it.</summary>
    /// <param name="AccessToken">The token to keep.</param>
    /// <param name="Expiry">The time after which the token is no longer reused.</param>
    [NonDebuggable]
    local procedure Remember(AccessToken: SecretText; Expiry: DateTime)
    begin
        this.Token := AccessToken;
        this.ExpiresAt := Expiry;
        this.CachedSource := this.Setup."Token Source";
    end;

    /// <summary>The moment a MobileNAV token expires: its last refresh plus its lifetime in seconds.</summary>
    /// <param name="MNUserSetup">The signed-in user's MobileNAV setup.</param>
    /// <returns>The expiry time. A token that was never refreshed has expired already.</returns>
    local procedure MobileNAVTokenExpiry(var MNUserSetup: Record "MobileNAV User Setup"): DateTime
    begin
        exit(MNUserSetup."Last Refresh Time" + (MNUserSetup."Expires In" * 1000));
    end;

    /// <summary>The Microsoft Entra authorize endpoint of the setup's tenant.</summary>
    /// <returns>The authority URL the OAuth2 module signs in against.</returns>
    local procedure AuthorityUrl(): Text
    begin
        exit(StrSubstNo(this.AuthorityTok, this.AzureADTenant.GetAadTenantId()));
    end;

    /// <summary>The Business Central delegated scope the emulator asks for.</summary>
    /// <returns>A list with the one scope.</returns>
    local procedure RequestScopes(): List of [Text]
    var
        Scopes: List of [Text];
    begin
        Scopes.Add(this.ScopeTok);
        exit(Scopes);
    end;
}
