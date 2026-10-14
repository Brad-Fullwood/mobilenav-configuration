namespace BradFullwood.MobileNAV.Configuration;

using System.Azure.Identity;
using System.Environment;
using System.Utilities;

/// <summary>
/// Hands out the sign-in scripts that the extension holds as resources. The scripts sign the user in with the device code
/// flow and give the token to the device emulator. They hold no secret. Before a script is downloaded, its placeholders take
/// the values of this environment: the tenant ID, the environment name, the company, the API base URL of the emulator setup
/// and the client ID. The client ID is the O365 App ID of MobileNAV Master Data when that is filled in, and the Client ID of
/// the emulator setup otherwise.
/// </summary>
codeunit 77776 "BJF MN Emulator Script"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV Master Data" = r;

    var
        Setup: Record "BJF MN Emulator Setup";
        AzureADTenant: Codeunit "Azure AD Tenant";
        EnvironmentInformation: Codeunit "Environment Information";
        PowerShellPathTok: Label 'supplied-token-powershell.txt', Locked = true;
        PythonPathTok: Label 'supplied-token-python.txt', Locked = true;
        PowerShellFileTok: Label 'mobilenav-emulator-sign-in.ps1', Locked = true;
        PythonFileTok: Label 'mobilenav-emulator-sign-in.py', Locked = true;
        TenantPlaceholderTok: Label '<<TenantId>>', Locked = true;
        ClientPlaceholderTok: Label '<<ClientId>>', Locked = true;
        CompanyPlaceholderTok: Label '<<CompanyName>>', Locked = true;
        EnvironmentPlaceholderTok: Label '<<EnvironmentName>>', Locked = true;
        ApiPlaceholderTok: Label '<<ApiBaseUrl>>', Locked = true;
        ApiBaseUrlTok: Label 'https://api.businesscentral.dynamics.com/v2.0/%1/%2/api/bjf/mobilenav/v1.0', Locked = true;
        DownloadCaptionLbl: Label 'Download the emulator sign-in script';
        MissingScriptErr: Label 'The sign-in script %1 is not in this extension.', Comment = '%1 = the resource path of the script';

    /// <summary>Downloads the PowerShell sign-in script to the user's computer.</summary>
    procedure DownloadPowerShell()
    begin
        this.Download(this.PowerShellPathTok, this.PowerShellFileTok, true);
    end;

    /// <summary>Downloads the Python sign-in script to the user's computer.</summary>
    procedure DownloadPython()
    begin
        this.Download(this.PythonPathTok, this.PythonFileTok, false);
    end;

    /// <summary>Reads a script resource of the extension, fills its placeholders and downloads it under the given file name.</summary>
    /// <param name="ResourcePath">The resource path of the script, relative to the resource folder.</param>
    /// <param name="FileName">The file name the download gets.</param>
    /// <param name="IsPowerShell">True for a PowerShell script, which quotes values differently from Python.</param>
    local procedure Download(ResourcePath: Text; FileName: Text; IsPowerShell: Boolean)
    var
        TempBlob: Codeunit "Temp Blob";
        ScriptText: Text;
        ScriptOut: OutStream;
        ScriptIn: InStream;
    begin
        ScriptText := NavApp.GetResourceAsText(ResourcePath, TextEncoding::UTF8);
        if ScriptText = '' then
            Error(this.MissingScriptErr, ResourcePath);
        ScriptText := this.FillPlaceholders(ScriptText, IsPowerShell);
        TempBlob.CreateOutStream(ScriptOut, TextEncoding::UTF8);
        ScriptOut.WriteText(ScriptText);
        TempBlob.CreateInStream(ScriptIn, TextEncoding::UTF8);
        DownloadFromStream(ScriptIn, this.DownloadCaptionLbl, '', '', FileName);
    end;

    /// <summary>Replaces the placeholders of a sign-in script with the values of this environment and this company.</summary>
    /// <param name="ScriptText">The script text as the resource holds it.</param>
    /// <param name="IsPowerShell">True for a PowerShell script, which quotes values differently from Python.</param>
    /// <returns>The script text with its values filled in.</returns>
    local procedure FillPlaceholders(ScriptText: Text; IsPowerShell: Boolean): Text
    var
        TenantId: Text;
        EnvironmentName: Text;
        ApiBaseUrl: Text;
    begin
        this.Setup.GetSetup();
        TenantId := this.AzureADTenant.GetAadTenantId();
        EnvironmentName := this.EnvironmentInformation.GetEnvironmentName();
        ApiBaseUrl := StrSubstNo(this.ApiBaseUrlTok, TenantId, EnvironmentName);

        ScriptText := ScriptText.Replace(this.TenantPlaceholderTok, this.Quoted(TenantId, IsPowerShell));
        ScriptText := ScriptText.Replace(this.ClientPlaceholderTok, this.Quoted(this.DefaultClientId(), IsPowerShell));
        ScriptText := ScriptText.Replace(this.CompanyPlaceholderTok, this.Quoted(CompanyName(), IsPowerShell));
        ScriptText := ScriptText.Replace(this.EnvironmentPlaceholderTok, this.Quoted(EnvironmentName, IsPowerShell));
        ScriptText := ScriptText.Replace(this.ApiPlaceholderTok, this.Quoted(ApiBaseUrl, IsPowerShell));
        exit(ScriptText);
    end;

    /// <summary>The client ID the script signs in with: the O365 App ID that MobileNAV keeps in its General Master Data, or the Client ID of the emulator setup when that is empty.</summary>
    /// <returns>The client ID, or an empty text when neither holds one.</returns>
    local procedure DefaultClientId(): Text
    var
        MasterData: Record "MobileNAV Master Data";
    begin
        MasterData.SetLoadFields("O365 App ID");
        if MasterData.Get(MasterData.Type::General, '', 0, '', MasterData.Area::Normal) then
            if MasterData."O365 App ID" <> '' then
                exit(MasterData."O365 App ID");
        exit(this.Setup."Client ID");
    end;

    /// <summary>Escapes a value for the quotes of the script language. PowerShell doubles a single quote. Python escapes a backslash and a double quote.</summary>
    /// <param name="Value">The value to put inside the quotes.</param>
    /// <param name="IsPowerShell">True for a PowerShell script.</param>
    /// <returns>The escaped value.</returns>
    local procedure Quoted(Value: Text; IsPowerShell: Boolean): Text
    begin
        if IsPowerShell then
            exit(Value.Replace('''', ''''''));
        exit(Value.Replace('\', '\\').Replace('"', '\"'));
    end;
}
