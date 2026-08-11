import { NextResponse } from 'next/server';
import { demoRepository } from '@/services/demo-vault';

export function GET(): NextResponse {
  return NextResponse.json({ items: demoRepository().listReviewItems() });
}
