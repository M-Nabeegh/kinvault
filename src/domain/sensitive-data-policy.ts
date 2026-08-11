export type SensitiveDataInput = {
  fileName?: string;
  category?: string;
  extractedText?: string;
};

const PAYMENT_CARD_CATEGORY = /\b(?:payment|credit|debit|bank)\s*-?\s*card\b/i;
const PAYMENT_CARD_LANGUAGE = /\b(?:credit|debit|payment|visa|mastercard|amex|american express|card\s+number|cvv|cvc)\b/i;
const CARD_NUMBER = /(?<!\d)(?:\d[ -]?){12,18}\d(?!\d)/g;

function isLuhnValid(value: string): boolean {
  const digits = value.replace(/\D/g, '');

  if (digits.length < 13 || digits.length > 19) {
    return false;
  }

  let total = 0;
  let shouldDouble = false;

  for (let index = digits.length - 1; index >= 0; index -= 1) {
    let digit = Number(digits[index]);
    if (shouldDouble) {
      digit *= 2;
      if (digit > 9) digit -= 9;
    }
    total += digit;
    shouldDouble = !shouldDouble;
  }

  return total % 10 === 0;
}

export function isPaymentCardContent(input: SensitiveDataInput): { blocked: boolean; reason?: string } {
  if (PAYMENT_CARD_CATEGORY.test(input.category ?? '')) {
    return { blocked: true, reason: 'Payment-card documents are outside KinVault\'s scope.' };
  }

  const content = [input.fileName, input.extractedText].filter(Boolean).join(' ');
  if (PAYMENT_CARD_LANGUAGE.test(content) && (content.match(CARD_NUMBER) ?? []).some(isLuhnValid)) {
    return { blocked: true, reason: 'Payment-card number detected.' };
  }

  return { blocked: false };
}
