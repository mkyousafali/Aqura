/**
 * Content sanitization utility
 * Filters out offensive or inappropriate words from user-generated content
 */

// List of offensive Arabic words to filter
const OFFENSIVE_WORDS = [
  'عاهرة',
  // Add more offensive words as needed
];

/**
 * Sanitize text by removing offensive words
 * @param text - Text to sanitize
 * @param replacementChar - Character to replace offensive words with (default: *)
 * @returns Sanitized text
 */
export function sanitizeText(text: string, replacementChar = '*'): string {
  if (!text) return text;

  let sanitized = text;
  
  for (const word of OFFENSIVE_WORDS) {
    const regex = new RegExp(word, 'gi');
    sanitized = sanitized.replace(regex, replacementChar.repeat(word.length));
  }
  
  return sanitized;
}

/**
 * Sanitize object by cleaning all string properties
 * @param obj - Object to sanitize
 * @returns Sanitized object
 */
export function sanitizeObject(obj: any): any {
  if (!obj) return obj;
  
  if (typeof obj === 'string') {
    return sanitizeText(obj);
  }
  
  if (Array.isArray(obj)) {
    return obj.map(item => sanitizeObject(item));
  }
  
  if (typeof obj === 'object') {
    const sanitized: any = {};
    for (const key in obj) {
      sanitized[key] = sanitizeObject(obj[key]);
    }
    return sanitized;
  }
  
  return obj;
}

/**
 * Sanitize specific fields in an object
 * @param obj - Object to sanitize
 * @param fields - Array of field names to sanitize
 * @returns Object with sanitized fields
 */
export function sanitizeFields(obj: any, fields: string[]): any {
  if (!obj) return obj;
  
  const sanitized = { ...obj };
  
  for (const field of fields) {
    if (field in sanitized && typeof sanitized[field] === 'string') {
      sanitized[field] = sanitizeText(sanitized[field]);
    }
  }
  
  return sanitized;
}
