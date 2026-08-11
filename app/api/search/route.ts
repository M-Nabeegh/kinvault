import { z } from 'zod';
import { NextResponse } from 'next/server';
import { AnswerService } from '@/services/answer-service';
import { demoRepository } from '@/services/demo-vault';

const querySchema = z.string().trim().min(1).max(240);
const invalidQuery = { error: { code: 'invalid_query', message: 'Query must be between 1 and 240 characters.' } };

export function GET(request: Request): NextResponse {
  const query = new URL(request.url).searchParams.get('q');
  const parsed = querySchema.safeParse(query);
  if (!parsed.success) return NextResponse.json(invalidQuery, { status: 400 });

  const answers = new AnswerService(demoRepository());
  return NextResponse.json({ result: answers.answer(parsed.data), results: answers.search(parsed.data) });
}
