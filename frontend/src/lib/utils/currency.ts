import type { Readable } from 'svelte/store';
import { writable } from 'svelte/store';

interface CurrencyConfig {
  default: string;
  symbols: Record<string, string>;
  names: Record<string, string>;
  namesArabic: Record<string, string>;
}

let currencyConfig: CurrencyConfig | null = null;

// Fetch currency config from static folder
async function loadCurrencyConfig(): Promise<CurrencyConfig> {
  if (currencyConfig) return currencyConfig;

  try {
    const response = await fetch('/config/currency.json');
    if (!response.ok) throw new Error('Failed to load currency config');
    currencyConfig = await response.json();
    return currencyConfig;
  } catch (error) {
    console.error('Error loading currency config:', error);
    // Fallback config
    return {
      default: 'SAR',
      symbols: {
        'SAR': '﷼',
        'USD': '$',
        'EUR': '€',
        'GBP': '£'
      },
      names: {
        'SAR': 'Saudi Riyal',
        'USD': 'US Dollar',
        'EUR': 'Euro',
        'GBP': 'British Pound'
      },
      namesArabic: {
        'SAR': 'الريال السعودي',
        'USD': 'الدولار الأمريكي',
        'EUR': 'اليورو',
        'GBP': 'الجنيه الإسترليني'
      }
    };
  }
}

// Get currency symbol
export async function getCurrencySymbol(currency: string = 'SAR'): Promise<string> {
  const config = await loadCurrencyConfig();
  return config.symbols[currency] || '﷼';
}

// Get currency name
export async function getCurrencyName(currency: string = 'SAR', isArabic: boolean = false): Promise<string> {
  const config = await loadCurrencyConfig();
  const names = isArabic ? config.namesArabic : config.names;
  return names[currency] || currency;
}

// Create a store for currency config
export function createCurrencyStore(): Readable<CurrencyConfig> {
  const { subscribe, set } = writable<CurrencyConfig | null>(null);

  // Load config on creation
  loadCurrencyConfig().then(set);

  return {
    subscribe: (fn) => {
      return subscribe((value) => {
        if (value) fn(value);
      });
    }
  };
}

// Export sync version (use only if you've already loaded the config)
export function getCurrencySymbolSync(currency: string = 'SAR'): string {
  if (!currencyConfig) {
    return '﷼'; // Default SAR symbol
  }
  return currencyConfig.symbols[currency] || '﷼';
}
