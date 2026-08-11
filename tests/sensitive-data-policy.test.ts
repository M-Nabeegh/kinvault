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

  it('allows ordinary identity and insurance records', () => {
    expect(
      isPaymentCardContent({ category: 'identity', extractedText: 'National ID: DEMO-8472-AB' }),
    ).toEqual({ blocked: false });
    expect(
      isPaymentCardContent({ category: 'insurance', extractedText: 'Policy number: POL-2048-XY' }),
    ).toEqual({ blocked: false });
  });
});
