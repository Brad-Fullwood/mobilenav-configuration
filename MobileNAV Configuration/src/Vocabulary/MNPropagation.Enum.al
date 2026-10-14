namespace BradFullwood.MobileNAV.Configuration;

/// <summary>What a relation copies from the related record. The names are MobileNAV's own Propagation Type members.</summary>
enum 77799 "BJF MN Propagation"
{
    Access = Public;
    Extensible = false;

    #pragma warning disable AC0019 // Ordinal 0 maps to MobileNAV's own option value 0.
    value(0; Barcode) { Caption = 'Barcode'; }
    #pragma warning restore AC0019
    value(1; CacheableImageCard) { Caption = 'Cacheable Image on Card'; }
    value(2; CacheableImageList) { Caption = 'Cacheable Image on List'; }
}
