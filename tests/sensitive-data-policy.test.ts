import { describe, expect, it } from 'vitest';
import { isPaymentCardContent } from '@/domain/sensitive-data-policy';

describe('payment-card policy', () => {
  it('blocks an explicitly payment-card category', () => {
    expect(isPaymentCardContent({ category: 'payment card' })).toMatchObject({ blocked: true });
  });

  it('blocks a Luhn-valid card number only when payment-card language is present', () => {
    expect(
      isPaymentCardContent({ extractedText: 'Visa card number: 4111 1111 1111 1111' }),
    ).toMatchObject({ blocked: true });
  });

  it('blocks a Luhn-valid 13-digit payment-card number', () => {
    expect(
      isPaymentCardContent({ extractedText: 'Visa card number: 4222 2222 2222 2' }),
    ).toMatchObject({ blocked: true });
  });

  it('blocks a Luhn-valid 19-digit number with separators', () => {
    expect(
      isPaymentCardContent({ extractedText: 'Visa card number: 4000-0000-0000-0000-006' }),
    ).toMatchObject({ blocked: true });
  });

  it('does not treat a 12-digit number as a payment-card number', () => {
    expect(
      isPaymentCardContent({ extractedText: 'Visa card number: 4000 0000 0000' }),
    ).toEqual({ blocked: false });
  });

  it('does not match a 19-digit card-like substring inside a 20-digit run', () => {
    expect(
      isPaymentCardContent({ extractedText: 'Visa card number: 40000000000000000060' }),
    ).toEqual({ blocked: false });
  });

  it('allows ordinary identity and insurance records', () => {
    expect(
      isPaymentCardContent({ category: 'identity', extractedText: 'National ID: DEMO-8472-AB' }),
    ).toEqual({ blocked: false });
    expect(
      isPaymentCardContent({ category: 'insurance', extractedText: 'Policy number: POL-2048-XY' }),
    ).toEqual({ blocked: false });
  });
});
