import { z } from 'zod';
import { NextResponse } from 'next/server';
import { demoRepository } from '@/services/demo-vault';
import { ReviewService } from '@/services/review-service';

const resolutionSchema = z.discriminatedUnion('action', [
  z.object({ action: z.literal('accept') }),
  z.object({ action: z.literal('dismiss') }),
  z.object({ action: z.literal('correct'), value: z.string().trim().min(1).max(500) }),
]);

export async function PATCH(request: Request, context: { params: Promise<{ id: string }> }): Promise<NextResponse> {
  const parsed = resolutionSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: { code: 'invalid_resolution', message: 'Choose accept, dismiss, or correct with a value.' } }, { status: 400 });
  const { id } = await context.params;
  const field = new ReviewService(demoRepository()).resolve(id, parsed.data);
  if (!field) return NextResponse.json({ error: { code: 'not_found', message: 'Review item not found.' } }, { status: 404 });
  return NextResponse.json({ field });
}
