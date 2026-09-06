
namespace BradFullwood.MobileNAV.Configuration;

enum 77781 "BJF MN Config Operation"
{
    Access = Internal;
    Caption = 'MobileNAV Configuration Operation';
    Extensible = false;

    // Ordinal 0 carries meaning here: the enum is Access = Internal and
    // Extensible = false, so no external code or table extension can land on it
    // by accident, and the value is shown to administrators.
#pragma warning disable AC0019
    value(0; "Published Page")
    {
        Caption = 'Published Page';
    }
#pragma warning restore AC0019
    value(1; Field)
    {
        Caption = 'Field';
    }
    value(2; "Linked Field")
    {
        Caption = 'Linked Field';
    }
    value(3; "Function Field")
    {
        Caption = 'Function Field';
    }
    value(4; "Scan Field")
    {
        Caption = 'Scan Field';
    }
    value(5; Staging)
    {
        Caption = 'Staging';
    }
    value(6; Stage)
    {
        Caption = 'Stage';
    }
    value(7; "Stage Field")
    {
        Caption = 'Stage Field';
    }
    value(8; "Profile Field")
    {
        Caption = 'Profile Field';
    }
    value(9; "User Scope")
    {
        Caption = 'User Scope';
    }
    value(10; Group)
    {
        Caption = 'Group';
    }
    value(11; "Field Order")
    {
        Caption = 'Field Order';
    }
    value(12; "Lookup Field")
    {
        Caption = 'Lookup Field';
    }
    value(13; "Relation Filter")
    {
        Caption = 'Relation Filter';
    }
    value(14; "Relation Condition")
    {
        Caption = 'Relation Condition';
    }
    value(15; "Additional Code Field")
    {
        Caption = 'Additional Code Field';
    }
    value(16; "Propagated Field")
    {
        Caption = 'Propagated Field';
    }
    value(17; "Parent Action")
    {
        Caption = 'Parent Action';
    }
    value(18; "Page Filter")
    {
        Caption = 'Page Filter';
    }
    value(19; "Flow Filter")
    {
        Caption = 'Flow Filter';
    }
    value(20; Layout)
    {
        Caption = 'Layout';
    }
    value(21; "Layout Condition")
    {
        Caption = 'Layout Condition';
    }
    value(22; "Layout Action")
    {
        Caption = 'Layout Action';
    }
    value(23; Category)
    {
        Caption = 'Category';
    }
    value(24; "Category Translation")
    {
        Caption = 'Category Translation';
    }
    value(25; Profile)
    {
        Caption = 'Profile';
    }
    value(26; "Profile Page")
    {
        Caption = 'Profile Page';
    }
    value(27; "Saved Filter")
    {
        Caption = 'Saved Filter';
    }
    value(28; "Saved Filter Field")
    {
        Caption = 'Saved Filter Field';
    }
    value(29; Operation)
    {
        Caption = 'Operation';
    }
    value(30; Caption)
    {
        Caption = 'Caption';
    }
    value(31; "Menu Picture")
    {
        Caption = 'Menu Picture';
    }
}
