// GENERATED FILE - DO NOT EDIT.
// Source of truth: src/engine/currency.ts (POPULAR_CURRENCIES, DEFAULT_RATES_USD)
// Regenerate with: npx tsx flutter_app/tools/gen_engine_data.ts

class CurrencyItem {
  final String code;
  final String name;
  final String symbol;
  final String flag;

  const CurrencyItem({required this.code, required this.name, required this.symbol, required this.flag});
}

const List<CurrencyItem> popularCurrencies = [
  CurrencyItem(code: 'INR', name: 'Indian Rupee', symbol: '₹', flag: '🇮🇳'),
  CurrencyItem(code: 'USD', name: 'US Dollar', symbol: '\$', flag: '🇺🇸'),
  CurrencyItem(code: 'EUR', name: 'Euro', symbol: '€', flag: '🇪🇺'),
  CurrencyItem(code: 'GBP', name: 'British Pound', symbol: '£', flag: '🇬🇧'),
  CurrencyItem(code: 'AED', name: 'UAE Dirham', symbol: 'د.إ', flag: '🇦🇪'),
  CurrencyItem(code: 'JPY', name: 'Japanese Yen', symbol: '¥', flag: '🇯🇵'),
  CurrencyItem(code: 'CAD', name: 'Canadian Dollar', symbol: 'C\$', flag: '🇨🇦'),
  CurrencyItem(code: 'AUD', name: 'Australian Dollar', symbol: 'A\$', flag: '🇦🇺'),
  CurrencyItem(code: 'SGD', name: 'Singapore Dollar', symbol: 'S\$', flag: '🇸🇬'),
  CurrencyItem(code: 'CHF', name: 'Swiss Franc', symbol: 'CHF', flag: '🇨🇭'),
  CurrencyItem(code: 'CNY', name: 'Chinese Yuan', symbol: '¥', flag: '🇨🇳'),
  CurrencyItem(code: 'SAR', name: 'Saudi Riyal', symbol: '﷼', flag: '🇸🇦'),
  CurrencyItem(code: 'QAR', name: 'Qatari Riyal', symbol: 'ر.ق', flag: '🇶🇦'),
  CurrencyItem(code: 'KWD', name: 'Kuwaiti Dinar', symbol: 'د.ك', flag: '🇰🇼'),
  CurrencyItem(code: 'BHD', name: 'Bahraini Dinar', symbol: '.د.ب', flag: '🇧🇭'),
  CurrencyItem(code: 'OMR', name: 'Omani Rial', symbol: 'ر.ع.', flag: '🇴🇲'),
  CurrencyItem(code: 'NZD', name: 'New Zealand Dollar', symbol: 'NZ\$', flag: '🇳🇿'),
  CurrencyItem(code: 'THB', name: 'Thai Baht', symbol: '฿', flag: '🇹🇭'),
  CurrencyItem(code: 'MYR', name: 'Malaysian Ringgit', symbol: 'RM', flag: '🇲🇾'),
  CurrencyItem(code: 'KRW', name: 'South Korean Won', symbol: '₩', flag: '🇰🇷'),
  CurrencyItem(code: 'BRL', name: 'Brazilian Real', symbol: 'R\$', flag: '🇧🇷'),
  CurrencyItem(code: 'ZAR', name: 'South African Rand', symbol: 'R', flag: '🇿🇦'),
  CurrencyItem(code: 'SEK', name: 'Swedish Krona', symbol: 'kr', flag: '🇸🇪'),
  CurrencyItem(code: 'NOK', name: 'Norwegian Krone', symbol: 'kr', flag: '🇳🇴'),
  CurrencyItem(code: 'DKK', name: 'Danish Krone', symbol: 'kr', flag: '🇩🇰'),
  CurrencyItem(code: 'HKD', name: 'Hong Kong Dollar', symbol: 'HK\$', flag: '🇭🇰'),
  CurrencyItem(code: 'TRY', name: 'Turkish Lira', symbol: '₺', flag: '🇹🇷'),
  CurrencyItem(code: 'RUB', name: 'Russian Ruble', symbol: '₽', flag: '🇷🇺'),
  CurrencyItem(code: 'MXN', name: 'Mexican Peso', symbol: 'Mex\$', flag: '🇲🇽'),
  CurrencyItem(code: 'IDR', name: 'Indonesian Rupiah', symbol: 'Rp', flag: '🇮🇩'),
  CurrencyItem(code: 'PHP', name: 'Philippine Peso', symbol: '₱', flag: '🇵🇭'),
  CurrencyItem(code: 'VND', name: 'Vietnamese Dong', symbol: '₫', flag: '🇻🇳'),
  CurrencyItem(code: 'EGP', name: 'Egyptian Pound', symbol: 'E£', flag: '🇪🇬'),
  CurrencyItem(code: 'PKR', name: 'Pakistani Rupee', symbol: '₨', flag: '🇵🇰'),
  CurrencyItem(code: 'BDT', name: 'Bangladeshi Taka', symbol: '৳', flag: '🇧🇩'),
  CurrencyItem(code: 'LKR', name: 'Sri Lankan Rupee', symbol: 'Rs', flag: '🇱🇰'),
  CurrencyItem(code: 'NPR', name: 'Nepalese Rupee', symbol: 'रू', flag: '🇳🇵'),
];

/// Fallback rates relative to USD (USD = 1.0).
const Map<String, double> defaultRatesUsd = {
  'USD': 1.0,
  'INR': 86.82,
  'EUR': 0.952,
  'GBP': 0.794,
  'AED': 3.6725,
  'JPY': 154.3,
  'CAD': 1.412,
  'AUD': 1.583,
  'SGD': 1.352,
  'CHF': 0.908,
  'CNY': 7.285,
  'SAR': 3.751,
  'QAR': 3.641,
  'KWD': 0.309,
  'BHD': 0.377,
  'OMR': 0.385,
  'NZD': 1.745,
  'THB': 34.6,
  'MYR': 4.46,
  'KRW': 1442.0,
  'BRL': 6.08,
  'ZAR': 18.25,
  'SEK': 10.82,
  'NOK': 11.15,
  'DKK': 7.1,
  'HKD': 7.78,
  'TRY': 35.8,
  'RUB': 98.5,
  'MXN': 20.4,
  'IDR': 16250.0,
  'PHP': 58.6,
  'VND': 25400.0,
  'EGP': 50.4,
  'PKR': 278.5,
  'BDT': 121.0,
  'LKR': 292.0,
  'NPR': 138.9,
};
