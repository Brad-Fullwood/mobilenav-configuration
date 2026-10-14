namespace BradFullwood.MobileNAV.Configuration;

/// <summary>A setting a builder verb writes to one MobileNAV Service Setup field. "BJF MN Property Catalog" holds its facts.</summary>
enum 77700 "BJF MN Property"
{
    Access = Internal;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 is a real setting, mapped to its field by "BJF MN Property Catalog".FieldNo.
    value(0; PageType) { Caption = 'PageType'; }
    #pragma warning restore AC0019
    value(1; Insertable) { Caption = 'Insertable'; }
    value(2; Updatable) { Caption = 'Updatable'; }
    value(3; Deletable) { Caption = 'Deletable'; }
    value(4; ListLimit) { Caption = 'ListLimit'; }
    value(5; DefaultDrillDown) { Caption = 'DefaultDrillDown'; }
    value(6; OnOpen) { Caption = 'OnOpen'; }
    value(7; OnClose) { Caption = 'OnClose'; }
    value(8; HideButton) { Caption = 'HideButton'; }
    value(9; HideTitlePrefix) { Caption = 'HideTitlePrefix'; }
    value(10; AutoRefresh) { Caption = 'AutoRefresh'; }
    value(11; AutoOpenSingleRecord) { Caption = 'AutoOpenSingleRecord'; }
    value(12; ShowFilterPanel) { Caption = 'ShowFilterPanel'; }
    value(13; ShowUnreadCount) { Caption = 'ShowUnreadCount'; }
    value(14; MineFilter) { Caption = 'MineFilter'; }
    value(15; AssignToMeCard) { Caption = 'AssignToMeCard'; }
    value(16; AssignToMeList) { Caption = 'AssignToMeList'; }
    value(17; Style) { Caption = 'Style'; }
    value(18; FilterByParent) { Caption = 'FilterByParent'; }
    value(19; ChunkSize) { Caption = 'ChunkSize'; }
    value(20; CheckForChanges) { Caption = 'CheckForChanges'; }
    value(21; MenuCategory) { Caption = 'MenuCategory'; }
    value(22; DecimalPlaces) { Caption = 'DecimalPlaces'; }
    value(23; Quantity) { Caption = 'Quantity'; }
    value(24; Increases) { Caption = 'Increases'; }
    value(25; RangeMin) { Caption = 'RangeMin'; }
    value(26; RangeMax) { Caption = 'RangeMax'; }
    value(27; QuickEdit) { Caption = 'QuickEdit'; }
    value(28; PromotedOnGroupHeader) { Caption = 'PromotedOnGroupHeader'; }
    value(29; AllowSkip) { Caption = 'AllowSkip'; }
    value(30; RegExPattern) { Caption = 'RegExPattern'; }
    value(31; RegExResults) { Caption = 'RegExResults'; }
    value(32; NoRegExPattern) { Caption = 'NoRegExPattern'; }
    value(33; NoRegExResults) { Caption = 'NoRegExResults'; }
    value(34; NoRegExInherited) { Caption = 'NoRegExInherited'; }
    value(35; FieldCategory) { Caption = 'FieldCategory'; }
    value(36; HideDrillDown) { Caption = 'HideDrillDown'; }
    value(37; ValidateAlways) { Caption = 'ValidateAlways'; }
    value(38; FieldVisible) { Caption = 'FieldVisible'; }
    value(39; FieldEditable) { Caption = 'FieldEditable'; }
    value(40; FieldDisplayInMenu) { Caption = 'FieldDisplayInMenu'; }
    value(41; FieldFilterable) { Caption = 'FieldFilterable'; }
    value(42; FieldImportance) { Caption = 'FieldImportance'; }
    value(43; FieldMobileType) { Caption = 'FieldMobileType'; }
    value(44; FieldFunctionType) { Caption = 'FieldFunctionType'; }
    value(45; FieldValidationBehavior) { Caption = 'FieldValidationBehavior'; }
}
