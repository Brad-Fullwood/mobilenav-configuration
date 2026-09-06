namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Lists the registered providers with their state, and applies the selected ones.</summary>
page 77780 "BJF MN Config Providers"
{
    ApplicationArea = All;
    Caption = 'MobileNAV Configuration';
    Editable = false;
    PageType = List;
    SourceTable = "BJF MN Provider Buffer";
    SourceTableTemporary = true;
    UsageCategory = Administration;

    layout
    {
        area(Content)
        {
            repeater(Providers)
            {
                field(Name; Rec.Name)
                {
                }
                field(Description; Rec.Description)
                {
                }
                field(State; Rec.State)
                {
                    StyleExpr = this.StateStyle;
                }
                field("Applied Previously"; Rec."Applied Previously")
                {
                }
                field("Applied At"; Rec."Applied At")
                {
                }
                field("Applied By"; Rec."Applied By")
                {
                }
                field("Provider ID"; Rec."Provider ID")
                {
                }
            }
        }
    }

    actions
    {
        area(Processing)
        {
            action(ApplySelected)
            {
                ApplicationArea = All;
                Caption = 'Apply selected';
                Image = Apply;
                ToolTip = 'Validates and applies the selected MobileNAV configuration providers.';

                trigger OnAction()
                begin
                    this.ApplySelectedProviders();
                end;
            }
            action(OpenDoctor)
            {
                ApplicationArea = All;
                Caption = 'Doctor';
                Image = Troubleshoot;
                RunObject = page "BJF MN Doctor";
                ToolTip = 'Opens the MobileNAV Doctor, which checks every provider''s configuration against MobileNAV''s live data and fixes what it can.';
            }
            action(ExportSnapshot)
            {
                ApplicationArea = All;
                Caption = 'Export live snapshot';
                Image = Export;
                ToolTip = 'Downloads every MobileNAV row the selected provider''s configuration touches, for diffing against another environment or version.';

                trigger OnAction()
                begin
                    this.ExportSnapshotForCurrentProvider();
                end;
            }
            action(MarkSelectedOutdated)
            {
                ApplicationArea = All;
                Caption = 'Mark selected outdated';
                Image = ChangeStatus;
                ToolTip = 'Marks previously applied providers as outdated without changing their MobileNAV configuration.';

                trigger OnAction()
                begin
                    this.MarkSelectedProvidersOutdated();
                end;
            }
        }
        area(Promoted)
        {
            group(Category_Process)
            {
                Caption = 'Process';
                actionref(ApplySelected_Promoted; ApplySelected)
                {
                }
                actionref(MarkSelectedOutdated_Promoted; MarkSelectedOutdated)
                {
                }
                actionref(ExportSnapshot_Promoted; ExportSnapshot)
                {
                }
                actionref(OpenDoctor_Promoted; OpenDoctor)
                {
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.State of
            Enum::"BJF MN Config State"::Applied:
                this.StateStyle := Format(PageStyle::Favorable);
            Enum::"BJF MN Config State"::Outdated:
                this.StateStyle := Format(PageStyle::Ambiguous);
            else
                this.StateStyle := Format(PageStyle::Attention);
        end;
    end;

    trigger OnOpenPage()
    begin
        this.ReloadProviders();
    end;

    local procedure ApplySelectedProviders()
    var
        TempSelectedProvider: Record "BJF MN Provider Buffer" temporary;
        AppliedCount: Integer;
    begin
        this.GetSelectedProviders(TempSelectedProvider);
        if TempSelectedProvider.IsEmpty() then
            Error(this.SelectionRequiredErr);

        if TempSelectedProvider.FindSet() then
            repeat
                this.ConfigurationApplication.ApplyProvider(TempSelectedProvider.Provider);
                AppliedCount += 1;
            until TempSelectedProvider.Next() = 0;

        this.ReloadProviders();
        CurrPage.Update(false);
        Message(this.AppliedMsg, AppliedCount);
    end;

    local procedure MarkSelectedProvidersOutdated()
    var
        TempSelectedProvider: Record "BJF MN Provider Buffer" temporary;
    begin
        this.GetSelectedProviders(TempSelectedProvider);
        TempSelectedProvider.SetRange("Applied Previously", true);
        if TempSelectedProvider.IsEmpty() then
            Error(this.AppliedSelectionRequiredErr);

        if TempSelectedProvider.FindSet() then
            repeat
                this.ConfigurationStatus.MarkOutdated(TempSelectedProvider."Provider ID");
            until TempSelectedProvider.Next() = 0;

        this.ReloadProviders();
        CurrPage.Update(false);
    end;

    local procedure ExportSnapshotForCurrentProvider()
    var
        TempConfigurationLine: Record "BJF MN Config Line" temporary;
        TempConfigurationProperty: Record "BJF MN Config Property" temporary;
        ConfigurationSnapshot: Codeunit "BJF MN Config Snapshot";
    begin
        this.ProviderCatalog.BuildDefinition(Rec.Provider, TempConfigurationLine, TempConfigurationProperty);
        ConfigurationSnapshot.Download(StrSubstNo(this.SnapshotFileNameTok, Rec."Provider ID"), TempConfigurationLine);
    end;

    local procedure GetSelectedProviders(var TempSelectedProvider: Record "BJF MN Provider Buffer" temporary)
    begin
        TempSelectedProvider.Copy(Rec, true);
        CurrPage.SetSelectionFilter(TempSelectedProvider);
    end;

    local procedure ReloadProviders()
    begin
        this.ProviderCatalog.Populate(Rec);
    end;

    var
        ConfigurationStatus: Record "BJF MN Config Status";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        StateStyle: Text;
        SelectionRequiredErr: Label 'Select at least one configuration provider.';
        AppliedSelectionRequiredErr: Label 'Select at least one provider that has been applied previously.';
        AppliedMsg: Label '%1 MobileNAV configuration provider(s) were applied.', Comment = '%1 = number of providers';
        SnapshotFileNameTok: Label '%1-mobilenav-snapshot.txt', Locked = true;
}
