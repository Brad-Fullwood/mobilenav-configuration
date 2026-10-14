namespace BradFullwood.MobileNAV.Configuration;

using System.Apps;
using System.Reflection;

/// <summary>
/// Reads the defaults for a new provider from the provider the user selected on MobileNAV Configuration: the
/// object name prefix, the app, the provider ID, name and description, and the first free object ID after
/// the app's last object.
/// </summary>
codeunit 77771 "BJF MN Provider Defaults"
{
    Access = Internal;
    Permissions = tabledata "NAV App Installed App" = r;

    /// <summary>
    /// Reads what the selected provider and its app say about the provider. The provider's codeunit is found
    /// by its object ID, which the scaffold writer gives the same ID as the provider's enum value, and its name
    /// must end in MN Provider. Sets the outputs only when every read succeeds.
    /// </summary>
    /// <param name="Provider">The provider the user selected.</param>
    /// <param name="ProviderId">Receives the provider ID the provider returns from GetId.</param>
    /// <param name="ProviderName">Receives the name the provider returns from GetName.</param>
    /// <param name="ProviderDescription">Receives the description the provider returns from GetDescription.</param>
    /// <param name="Prefix">Receives the object name prefix: the codeunit name without MN Provider.</param>
    /// <param name="Publisher">Receives the publisher of the provider's app.</param>
    /// <param name="AppName">Receives the name of the provider's app.</param>
    /// <param name="PackageId">Receives the package ID of the provider's app, which the objects carry in AllObj.</param>
    /// <returns>True when the provider's codeunit and app were found.</returns>
    procedure ReadProvider(Provider: Enum "BJF MN Config Provider"; var ProviderId: Code[50]; var ProviderName: Text[100]; var ProviderDescription: Text[250]; var Prefix: Text[20]; var Publisher: Text[100]; var AppName: Text[100]; var PackageId: Guid): Boolean
    var
        AllObj: Record AllObj;
        InstalledApp: Record "NAV App Installed App";
        ProviderIntf: Interface "BJF MN Config Provider";
        CodeunitName: Text;
        PrefixText: Text;
    begin
        if Provider = Enum::"BJF MN Config Provider"::None then
            exit(false);
        AllObj.SetLoadFields("Object Name", "App Package ID");
        if not AllObj.Get(AllObj."Object Type"::Codeunit, Provider.AsInteger()) then
            exit(false);
        CodeunitName := AllObj."Object Name";
        if not CodeunitName.EndsWith(this.ProviderSuffixTok) then
            exit(false);
        PrefixText := CopyStr(CodeunitName, 1, StrLen(CodeunitName) - StrLen(this.ProviderSuffixTok)).Trim();
        if (PrefixText = '') or (StrLen(PrefixText) > MaxStrLen(Prefix)) then
            exit(false);
        InstalledApp.SetLoadFields(Name, Publisher);
        InstalledApp.SetRange("Package ID", AllObj."App Package ID");
        if not InstalledApp.FindFirst() then
            exit(false);

        ProviderIntf := Provider;
        ProviderId := ProviderIntf.GetId();
        ProviderName := ProviderIntf.GetName();
        ProviderDescription := ProviderIntf.GetDescription();
        Prefix := CopyStr(PrefixText, 1, MaxStrLen(Prefix));
        Publisher := CopyStr(InstalledApp.Publisher, 1, MaxStrLen(Publisher));
        AppName := CopyStr(InstalledApp.Name, 1, MaxStrLen(AppName));
        PackageId := AllObj."App Package ID";
        exit(true);
    end;

    /// <summary>
    /// Returns the first object ID after the app's last object that leaves BlockSize IDs free. The check is
    /// stricter than AL needs: an object of any type inside the block moves the start past it.
    /// </summary>
    /// <param name="PackageId">The package ID of the app the new objects go next to.</param>
    /// <param name="BlockSize">The number of IDs the new objects need.</param>
    /// <returns>The first free object ID.</returns>
    procedure FirstFreeObjectId(PackageId: Guid; BlockSize: Integer): Integer
    var
        Candidate: Integer;
        TakenUpTo: Integer;
        Attempt: Integer;
    begin
        Candidate := this.LastObjectId(PackageId) + 1;
        for Attempt := 1 to 100 do begin
            TakenUpTo := this.LastTakenObjectId(Candidate, Candidate + BlockSize - 1);
            if TakenUpTo = 0 then
                exit(Candidate);
            Candidate := TakenUpTo + 1;
        end;
        exit(Candidate);
    end;

    local procedure LastObjectId(PackageId: Guid): Integer
    var
        AllObj: Record AllObj;
        LastId: Integer;
    begin
        LastId := 0;
        AllObj.SetLoadFields("Object ID");
        AllObj.SetRange("App Package ID", PackageId);
        if AllObj.FindSet() then
            repeat
                if AllObj."Object ID" > LastId then
                    LastId := AllObj."Object ID";
            until AllObj.Next() = 0;
        exit(LastId);
    end;

    local procedure LastTakenObjectId(FromId: Integer; ToId: Integer): Integer
    var
        AllObj: Record AllObj;
        LastTaken: Integer;
    begin
        LastTaken := 0;
        AllObj.SetLoadFields("Object ID");
        AllObj.SetRange("Object ID", FromId, ToId);
        if AllObj.FindSet() then
            repeat
                if AllObj."Object ID" > LastTaken then
                    LastTaken := AllObj."Object ID";
            until AllObj.Next() = 0;
        exit(LastTaken);
    end;

    var
        ProviderSuffixTok: Label 'MN Provider', Locked = true;
}
