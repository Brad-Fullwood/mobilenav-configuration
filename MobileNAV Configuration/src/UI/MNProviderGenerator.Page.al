namespace BradFullwood.MobileNAV.Configuration;

using System.Reflection;

/// <summary>
/// Restates the live MobileNAV setup of chosen pages as a provider: pick the pages, set the
/// provider's id and object, and download a zip file with the provider codeunit and enum extension as .al files.
/// The provider details sit on a temporary header row, and the pages sit in a list part.
/// </summary>
page 77719 "BJF MN Provider Generator"
{
    ApplicationArea = All;
    Caption = 'Generate MobileNAV Provider';
    DeleteAllowed = false;
    InsertAllowed = false;
    PageType = Card;
    Permissions = tabledata "MobileNAV Service Setup" = r;
    SourceTable = "BJF MN Generator Header";
    SourceTableTemporary = true;
    UsageCategory = Tasks;
    AdditionalSearchTerms = 'MobileNAV,provider,generate,reverse,configuration';

    layout
    {
        area(Content)
        {
            group(Options)
            {
                Caption = 'Provider';

                field(ProviderIdField; Rec."Provider ID")
                {
                }
                field(ObjectIdField; Rec."Object ID")
                {
                }
                field(ObjectNameField; Rec."Object Name")
                {
                }
                field(NamespaceField; Rec."Namespace Name")
                {
                }
                field(IncludeProfilesField; Rec."Include Profiles")
                {
                }
                field(IncludeHiddenField; Rec."Include Hidden Fields")
                {
                }
                field(IncludeAllCaptionsField; Rec."Include All Captions")
                {
                }
            }
            group(PagesGroup)
            {
                Caption = 'Pages';

                part(PagesPart; "BJF MN Page Selection Part")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(DownloadAl)
            {
                Caption = 'Download Provider (.zip)';
                Image = Export;
                ToolTip = 'Downloads a zip file with the provider codeunit and enum extension as .al files. They restate the selected pages'' MobileNAV setup as builder calls. Rows the builder cannot write appear as comments.';

                trigger OnAction()
                begin
                    this.DownloadProvider();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';

                actionref(DownloadAl_Promoted; DownloadAl)
                {
                }
            }
        }
    }

    trigger OnOpenPage()
    begin
        Rec.Init();
        Rec.Validate("Entry No.", 1);
        Rec.Insert(false);
        this.LoadPages();
        this.ApplySelectedProvider();
        CurrPage.PagesPart.Page.SetPages(this.TempPageSelection);
    end;

    /// <summary>
    /// Sets the provider the generator takes its defaults from. Call it before the page opens: the defaults are
    /// filled in when it does.
    /// </summary>
    /// <param name="Provider">The provider selected on MobileNAV Configuration. None keeps the generator's own defaults.</param>
    procedure SetSelectedProvider(Provider: Enum "BJF MN Config Provider")
    begin
        this.SelectedProvider := Provider;
    end;

    /// <summary>
    /// Fills the provider ID and the object ID from the selected provider. The object ID goes after the provider's
    /// app's last object and leaves room for the codeunit and the enum extension.
    /// </summary>
    local procedure ApplySelectedProvider()
    var
        ProviderDefaults: Codeunit "BJF MN Provider Defaults";
        PackageId: Guid;
        ProviderId: Code[50];
        Prefix: Text[20];
        Publisher: Text[100];
        AppName: Text[100];
        ProviderName: Text[100];
        ProviderDescription: Text[250];
    begin
        if not ProviderDefaults.ReadProvider(this.SelectedProvider, ProviderId, ProviderName, ProviderDescription, Prefix, Publisher, AppName, PackageId) then
            exit;
        Rec.Validate("Provider ID", ProviderId);
        Rec.Validate("Object ID", ProviderDefaults.FirstFreeObjectId(PackageId, 2));
        Rec.Modify(false);
    end;

    local procedure LoadPages()
    var
        ServiceSetup: Record "MobileNAV Service Setup";
        ServiceLookup: Codeunit "BJF MN Service Lookup";
    begin
        ServiceSetup.SetLoadFields("Service Name", Name, "Object ID");
        ServiceSetup.SetRange("Line Type", ServiceSetup."Line Type"::Main);
        ServiceSetup.SetRange("Object Type", ServiceSetup."Object Type"::Page);
        if ServiceSetup.FindSet() then
            repeat
                // A buffer row of a temporary table: no field has validation to run.
#pragma warning disable PC0037
                this.TempPageSelection.Init();
                this.TempPageSelection."Service Name" := ServiceSetup."Service Name";
                this.TempPageSelection."Page Name" := ServiceSetup.Name;
                this.TempPageSelection."Page ID" := ServiceSetup."Object ID";
                this.TempPageSelection."Own Page" := ServiceLookup.IsOwnServicePage(ServiceSetup.Name, ServiceSetup."Object ID");
#pragma warning restore PC0037
                if this.TempPageSelection.Insert(false) then; // A service is listed once.
            until ServiceSetup.Next() = 0;
        if this.TempPageSelection.FindFirst() then; // Opens on the first page when there is one.
    end;

    local procedure DownloadProvider()
    var
        ProviderWriter: Codeunit "BJF MN Provider Writer";
        ServiceNames: List of [Text];
    begin
        if Rec."Provider ID" = '' then
            Error(this.ProviderIdMissingErr);
        CurrPage.PagesPart.Page.SelectedServiceNames(ServiceNames);
        if ServiceNames.Count() = 0 then
            Error(this.NothingSelectedErr);
        ProviderWriter.SetProvider(Rec."Provider ID", Rec."Object ID", Rec."Object Name", Rec."Namespace Name");
        ProviderWriter.SetScope(Rec."Include Profiles", Rec."Include Hidden Fields", Rec."Include All Captions");
        ProviderWriter.Download(ServiceNames);
    end;

    var
        TempPageSelection: Record "BJF MN Page Selection" temporary;
        SelectedProvider: Enum "BJF MN Config Provider";
        ProviderIdMissingErr: Label 'Enter a provider id.';
        NothingSelectedErr: Label 'Select at least one page.';
}
