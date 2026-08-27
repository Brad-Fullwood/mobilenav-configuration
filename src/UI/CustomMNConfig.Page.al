
namespace BradFullwood.MobileNAV.Configuration;

/// <summary>Lists registered providers and applies or invalidates the selected rows.</summary>
page 77780 "BJF Custom MN Config"
{
    ApplicationArea = All;
    Caption = 'Apply custom MobileNAV config';
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
                    StyleExpr = StateStyle;
                }
                field("Applied Previously"; Rec."Applied Previously")
                {
                }
                field("Defined Version"; Rec."Defined Version")
                {
                }
                field("Applied Version"; Rec."Applied Version")
                {
                    BlankZero = true;
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
                    ApplySelectedProviders();
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
                    MarkSelectedProvidersOutdated();
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
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        case Rec.State of
            Enum::"BJF MN Config State"::Applied:
                StateStyle := Format(PageStyle::Favorable);
            Enum::"BJF MN Config State"::Outdated:
                StateStyle := Format(PageStyle::Ambiguous);
            else
                StateStyle := Format(PageStyle::Attention);
        end;
    end;

    trigger OnOpenPage()
    begin
        ReloadProviders();
    end;

    local procedure ApplySelectedProviders()
    var
        TempSelectedProvider: Record "BJF MN Provider Buffer" temporary;
        AppliedCount: Integer;
    begin
        GetSelectedProviders(TempSelectedProvider);
        if TempSelectedProvider.IsEmpty() then
            Error(SelectionRequiredErr);

        if TempSelectedProvider.FindSet() then
            repeat
                ConfigurationApplication.ApplyProvider(TempSelectedProvider.Provider);
                AppliedCount += 1;
            until TempSelectedProvider.Next() = 0;

        ReloadProviders();
        CurrPage.Update(false);
        Message(AppliedMsg, AppliedCount);
    end;

    local procedure MarkSelectedProvidersOutdated()
    var
        TempSelectedProvider: Record "BJF MN Provider Buffer" temporary;
    begin
        GetSelectedProviders(TempSelectedProvider);
        TempSelectedProvider.SetRange("Applied Previously", true);
        if TempSelectedProvider.IsEmpty() then
            Error(AppliedSelectionRequiredErr);

        if TempSelectedProvider.FindSet() then
            repeat
                ConfigurationStatus.MarkOutdated(TempSelectedProvider."Provider ID");
            until TempSelectedProvider.Next() = 0;

        ReloadProviders();
        CurrPage.Update(false);
    end;

    local procedure GetSelectedProviders(var TempSelectedProvider: Record "BJF MN Provider Buffer" temporary)
    begin
        TempSelectedProvider.Copy(Rec, true);
        CurrPage.SetSelectionFilter(TempSelectedProvider);
    end;

    local procedure ReloadProviders()
    begin
        ProviderCatalog.Populate(Rec);
    end;

    var
        ConfigurationStatus: Record "BJF MN Config Status";
        ProviderCatalog: Codeunit "BJF MN Provider Catalog";
        ConfigurationApplication: Codeunit "BJF MN Config Application";
        StateStyle: Text;
        SelectionRequiredErr: Label 'Select at least one configuration provider.';
        AppliedSelectionRequiredErr: Label 'Select at least one provider that has been applied previously.';
        AppliedMsg: Label '%1 MobileNAV configuration provider(s) were applied.', Comment = '%1 = number of providers';
}
