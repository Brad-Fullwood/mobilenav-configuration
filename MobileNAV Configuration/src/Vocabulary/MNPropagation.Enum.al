namespace BradFullwood.MobileNAV.Configuration;

/// <summary>What a relation copies from the related record. The names are MobileNAV's own Propagation Type members.</summary>
enum 77799 "BJF MN Propagation"
{
    Access = Public;
    Extensible = false;

    value(0; Barcode) { Caption = 'Barcode'; }
    value(1; CacheableImageCard) { Caption = 'Cacheable Image on Card'; }
    value(2; CacheableImageList) { Caption = 'Cacheable Image on List'; }
}
