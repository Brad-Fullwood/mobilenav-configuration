namespace BradFullwood.MobileNAV.Configuration;

using System.Azure.Identity;
using System.Text;

/// <summary>
/// Reads and installs the MobileNAV licence string, the base64 text that Change License on the
/// MobileNAV License Setup page takes. MobileNAV keeps the licence in one row of "MobileNAV License
/// Setup" with Type AddonLicense, shared by all companies, and its "Device ID" holds the decoded
/// licence XML. The licence is issued for the Microsoft Entra tenant, so the same string works in
/// every environment of that tenant. Nothing here asks the user anything, so the API can call it.
/// </summary>
codeunit 77777 "BJF MN Licence Transfer"
{
    Access = Internal;
    Permissions = tabledata "MobileNAV License Setup" = r;

    /// <summary>The installed licence as the base64 string Change License takes.</summary>
    /// <returns>The licence string.</returns>
    procedure GetLicenceString(): Text
    var
        LicenseSetup: Record "MobileNAV License Setup";
        Base64Convert: Codeunit "Base64 Convert";
    begin
        if not this.FindLicence(LicenseSetup) then
            Error(this.NoLicenceErr);
        exit(Base64Convert.ToBase64(LicenseSetup."Device ID"));
    end;

    /// <summary>
    /// Installs a licence string through MobileNAV's SaveLicenseKey, which replaces the installed
    /// licence and keeps its licence check history. Refuses a string issued for another tenant.
    /// </summary>
    /// <param name="LicenceString">The licence string, as GetLicenceString returns it in the source environment.</param>
    procedure InstallLicenceString(LicenceString: Text)
    var
        LicenseSetup: Record "MobileNAV License Setup";
        LicenseFunctions: Codeunit "MobileNAV License Functions";
        LicenceXml: Text;
        LicenceId: Text;
        ExpectedLicenceId: Text;
    begin
        LicenceString := LicenceString.Trim();
        if LicenceString = '' then
            Error(this.EmptyLicenceStringErr);
        if not this.TryFromBase64(LicenceString, LicenceXml) then
            Error(this.NotBase64Err);
        if not LicenceXml.StartsWith(this.LicenceElementStartTok) then
            Error(this.NotLicenceErr);
        if StrLen(LicenceXml) > MaxStrLen(LicenseSetup."Device ID") then
            Error(this.LicenceTooLongErr, StrLen(LicenceXml), MaxStrLen(LicenseSetup."Device ID"));
        LicenceId := this.ReadLicenceId(LicenceXml);
        if LicenceId = '' then
            Error(this.NoLicenceIdErr);
        ExpectedLicenceId := this.TenantLicenceId();
        if LicenceId <> ExpectedLicenceId then
            Error(this.OtherTenantErr, LicenceId, ExpectedLicenceId);

        LicenseFunctions.SaveLicenseKey(LicenceString);
    end;

    /// <summary>
    /// Fills one row with the installed licence: its id, the licensed and assigned device counts,
    /// the expiry date and the licence string. Without a licence only this tenant's licence id is filled.
    /// </summary>
    /// <param name="Licence">Returns the licence row. It is not inserted.</param>
    procedure GetLicenceInfo(var Licence: Record "BJF MN Licence" temporary)
    var
        LicenseSetup: Record "MobileNAV License Setup";
        DeviceSetup: Record "MobileNAV License Setup";
        LicenseFunctions: Codeunit "MobileNAV License Functions";
        Base64Convert: Codeunit "Base64 Convert";
        TenantId: Guid;
        LicensedDevices: Integer;
        ExpiryDate: Date;
    begin
        Licence.Init();
        Licence.Validate("Tenant Licence Id", CopyStr(this.TenantLicenceId(), 1, MaxStrLen(Licence."Tenant Licence Id")));
        if Evaluate(TenantId, Licence."Tenant Licence Id") then
            Licence.Validate(Id, TenantId);
        if not this.FindLicence(LicenseSetup) then
            exit;

        Licence.Validate("Licence Installed", true);
        Licence.Validate("Licence Id", CopyStr(this.ReadLicenceId(LicenseSetup."Device ID"), 1, MaxStrLen(Licence."Licence Id")));
        Licence.Validate("Licence String", CopyStr(Base64Convert.ToBase64(LicenseSetup."Device ID"), 1, MaxStrLen(Licence."Licence String")));

        LicensedDevices := LicenseFunctions.GetLicensedDeviceNo();
        // MobileNAV's License Setup page shows a count above 700 less 700, apart from 999.
        if (LicensedDevices > 700) and (LicensedDevices <> 999) then
            LicensedDevices -= 700;
        Licence.Validate("Licensed Devices", LicensedDevices);

        DeviceSetup.SetRange(Type, DeviceSetup.Type::Device);
        DeviceSetup.SetRange(Status, DeviceSetup.Status::Active);
        Licence.Validate("Assigned Devices", DeviceSetup.Count());

        ExpiryDate := LicenseFunctions.GetLicenseExpDate();
        if ExpiryDate <> 99991231D then
            Licence.Validate("Expiry Date", ExpiryDate);
    end;

    /// <summary>The licence id MobileNAV expects in Business Central online: the Entra tenant id in lowercase.</summary>
    /// <returns>The licence id.</returns>
    procedure TenantLicenceId(): Text
    var
        AzureADTenant: Codeunit "Azure AD Tenant";
    begin
        exit(LowerCase(AzureADTenant.GetAadTenantId()));
    end;

    local procedure FindLicence(var LicenseSetup: Record "MobileNAV License Setup"): Boolean
    begin
        LicenseSetup.SetRange(Type, LicenseSetup.Type::AddonLicense);
        if not LicenseSetup.FindFirst() then
            exit(false);
        exit(LicenseSetup."Device ID" <> '');
    end;

    local procedure ReadLicenceId(LicenceXml: Text): Text
    var
        Document: XmlDocument;
        Root: XmlElement;
        Attribute: XmlAttribute;
    begin
        if not XmlDocument.ReadFrom(LicenceXml, Document) then
            Error(this.NotLicenceErr);
        if not Document.GetRoot(Root) then
            Error(this.NotLicenceErr);
        if not Root.Attributes().Get(this.SerialNoAttributeTok, Attribute) then
            exit('');
        exit(Attribute.Value());
    end;

    [TryFunction]
    local procedure TryFromBase64(Base64Text: Text; var Decoded: Text)
    var
        Base64Convert: Codeunit "Base64 Convert";
    begin
        Decoded := Base64Convert.FromBase64(Base64Text);
    end;

    var
        EmptyLicenceStringErr: Label 'Enter a MobileNAV licence string.';
        LicenceElementStartTok: Label '<License ', Locked = true;
        LicenceTooLongErr: Label 'The licence is %1 characters long. MobileNAV stores up to %2.', Comment = '%1 = length of the decoded licence, %2 = maximum length';
        NoLicenceErr: Label 'No MobileNAV licence is installed in this environment.';
        NoLicenceIdErr: Label 'The licence string has no licence id (attribute sn).';
        NotBase64Err: Label 'The licence string is not valid base64 text. Copy the whole string from the MobileNAV Licence page of the source environment.';
        NotLicenceErr: Label 'The licence string is not a MobileNAV licence. Copy the whole string from the MobileNAV Licence page of the source environment.';
        OtherTenantErr: Label 'The licence string was issued for licence id %1, and this environment needs licence id %2. A MobileNAV licence works only in environments of the tenant it was issued for. The installed licence is unchanged.', Comment = '%1 = licence id in the string, %2 = licence id of this tenant';
        SerialNoAttributeTok: Label 'sn', Locked = true;
}
