/// A small set of dial codes for the phone-number field. Extend as needed.
class CountryCode {
  const CountryCode(this.flag, this.dialCode, this.name);

  final String flag;
  final String dialCode; // e.g. "+1"
  final String name;
}

const List<CountryCode> kCountryCodes = [
  CountryCode('🇺🇸', '+1', 'United States'),
  CountryCode('🇬🇧', '+44', 'United Kingdom'),
  CountryCode('🇺🇿', '+998', 'Uzbekistan'),
  CountryCode('🇰🇿', '+7', 'Kazakhstan'),
  CountryCode('🇹🇷', '+90', 'Türkiye'),
  CountryCode('🇮🇳', '+91', 'India'),
  CountryCode('🇩🇪', '+49', 'Germany'),
  CountryCode('🇦🇪', '+971', 'UAE'),
];
