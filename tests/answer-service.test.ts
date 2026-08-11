import { afterEach, describe, expect, it } from 'vitest';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { seedDemoData } from '@/data/seed';
import { DocumentStorage } from '@/services/document-storage';
import { AnswerService } from '@/services/answer-service';

const temporaryDirectories: string[] = [];

afterEach(() => {
  for (const directory of temporaryDirectories.splice(0)) {
    rmSync(directory, { recursive: true, force: true });
  }
});

function seededAnswerService(): AnswerService {
  const directory = mkdtempSync(join(tmpdir(), 'kinvault-answer-'));
  temporaryDirectories.push(directory);
  const repository = new DocumentRepository(createDatabase(join(directory, 'vault.sqlite')));
  seedDemoData(repository, new DocumentStorage(join(directory, 'files')));
  return new AnswerService(repository);
}

describe('AnswerService', () => {
  it("returns Dad's exact passport expiry with a complete source citation", () => {
    const result = seededAnswerService().answer("When does Dad's passport expire?");

    expect(result).toMatchObject({
      status: 'answered',
      answer: 'Dad Rowan’s passport expires on 2026-11-09.',
      confidence: 'high',
      citations: [{
        documentId: 'demo-dad-passport',
        documentTitle: 'Dad Passport (Synthetic)',
        page: 2,
        field: 'Expiry date',
        value: '2026-11-09',
        confidence: 0.96,
      }],
    });
  });

  it('marks a returned low-confidence field as needing verification', () => {
    const result = seededAnswerService().answer("What is Sana's date of birth?");

    expect(result).toMatchObject({
      status: 'answered',
      confidence: 'needs verification',
      citations: [expect.objectContaining({ value: '2004-04-18', confidence: 0.62 })],
    });
    expect(result.answer).toContain('needs verification');
  });

  it('returns not-found without citations when the requested DOB is absent', () => {
    const result = seededAnswerService().answer("What is Dad's date of birth?");

    expect(result).toEqual({
      status: 'not-found',
      answer: 'Not found in the vault.',
      confidence: 'needs verification',
      citations: [],
      followUp: 'Try searching the indexed documents instead.',
    });
  });

  it('returns only expiry records in the inclusive requested window', () => {
    const result = seededAnswerService().answer('Which documents expire within the next 90 days?', '2026-08-11');

    expect(result).toMatchObject({
      status: 'answered',
      citations: [{ documentId: 'demo-dad-passport', value: '2026-11-09' }],
    });
    expect(result.citations).toHaveLength(1);
  });
});
