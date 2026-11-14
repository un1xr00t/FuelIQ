typedef FuelEvidence = ({String label, String text, String source, String url});

class FuelReport {
  const FuelReport(this.title, this.manufacturer);

  final String title;
  final FuelEvidence manufacturer;

  static FuelReport? forBrand(String brand) =>
      switch (brand.trim().toLowerCase()) {
        'shell' || 'shell express' => _shell,
        'sunoco' || 'sunoco gas station' => _sunoco,
        'exxon' || 'mobil' => _exxonMobil,
        'bp' || 'amoco' => _bp,
        'costco' || 'costco gasoline' => _costco,
        _ => null,
      };

  static const _shell = FuelReport('Shell V-Power NiTRO+ vs. Shell Regular', (
    label: 'Manufacturer statement',
    text:
        'Shell says V-Power contains six times the cleaning agents needed to meet federal standards. Shell also says its regular gasoline meets TOP TIER. The six-times figure uses the federal minimum as its baseline.',
    source: 'Shell product FAQ · Checked Nov 13, 2026',
    url:
        'https://www.shell.us/fuels-oils-and-coolants/shell-fuels/shell-v-power-nitro-premium-gasoline/shell-v-power-nitro-plus-premium-gasoline-faqs.html',
  ));

  static const _sunoco = FuelReport('Sunoco 94 Octane', (
    label: 'Manufacturer statement',
    text:
        'Sunoco offers 94 AKI at select locations. Sunoco says all its gasoline grades meet TOP TIER. Check its locator for availability and the pump label for the ethanol blend.',
    source: 'Sunoco 94 Octane · Checked Nov 13, 2026',
    url: 'https://www.sunoco.com/94-octane',
  ));

  static const _exxonMobil = FuelReport(
    'ExxonMobil Synergy Supreme+ vs. Synergy Regular',
    (
      label: 'Manufacturer statement',
      text:
          'ExxonMobil reports twice the engine keep-clean benefit for Synergy Supreme+ compared with Synergy Regular in port fuel-injected engines. The comparison comes from ExxonMobil and applies to that test setup.',
      source: 'ExxonMobil product sheet · Checked Nov 13, 2026',
      url:
          'https://www.exxon.com/-/media/project/wep/exxon/exxon-retail-us/sell-sheets/updated-ada/exxonmobilsynergy-supremepremiumgasoline2021.pdf',
    ),
  );

  static const _bp = FuelReport('bp and Amoco Ultimate with Invigorate', (
    label: 'Manufacturer statement',
    text:
        'bp claims up to 300 additional miles per year with continuous use, based on fuel economy restoration and 15,000 miles per year. Its comparison used minimum-detergent 87-octane E10 as the baseline. Results depend on the car and driving conditions.',
    source: 'bp product release · Checked Nov 13, 2026',
    url:
        'https://www.bp.com/content/dam/bp/country-sites/en_us/united-states/home/documents/news/press-releases/amoco-ultimate-with-invigorate-can-take-you-up-to-300-miles-farther-per-year.pdf',
  ));

  static const _costco = FuelReport('Kirkland Signature Regular and Premium', (
    label: 'Manufacturer statement',
    text:
        'Costco says both regular and premium contain five times the EPA detergent requirement. The published detergent multiplier applies to both grades. Use the pump’s octane rating and your owner’s manual to choose a grade.',
    source: 'Costco Fuel Promise · Checked Nov 13, 2026',
    url: 'https://www.costco.com/fuel-promise.html',
  ));

  static const octane = (
    label: 'Fuel science · Octane',
    text:
        'AKI is the U.S. pump rating for resistance to engine knock. Use at least the minimum octane listed in your owner’s manual.',
    source: 'U.S. EIA octane guide · Checked Nov 13, 2026',
    url: 'https://www.eia.gov/energyexplained/gasoline/octane-in-depth.php',
  );

  static const regular = (
    label: 'Independent test · Regular specified',
    text:
        'AAA found no significant gains in horsepower, fuel economy, or emissions from higher octane in the regular-fuel vehicles it tested.',
    source: 'AAA premium fuel study · September 2016',
    url:
        'https://newsroom.aaa.com/asset/u-s-drivers-waste-2-1-billion-annually-on-premium-gasoline-full-report/',
  );

  static const recommended = (
    label: 'Independent test · Premium recommended',
    text:
        'AAA found modest, vehicle-dependent gains in some premium-recommended vehicles under demanding test conditions such as towing or hard acceleration.',
    source: 'AAA premium fuel study · December 2017',
    url:
        'https://newsroom.aaa.com/asset/dont-be-fueled-premium-not-always-worth-the-price-full-report/',
  );

  static const deposits = (
    label: 'Independent test · Deposits',
    text:
        'AAA compared six 93-octane gasolines in 2016. The TOP TIER samples left fewer intake-valve deposits under the study conditions. The result applies to the fuels and test engine used in that study.',
    source: 'AAA gasoline quality study · July 2016',
    url:
        'https://www.aaa.com/AAA/common/AAR/files/Fuel-Quality-Full-Report.pdf',
  );
}
