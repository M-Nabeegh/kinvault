import type { ExtractedFieldInput } from '@/data/repository';
import type { StoredFile } from './document-storage';

export type ExtractionResult = { pageCount: number; fields: ExtractedFieldInput[] };
export interface ExtractionService {
  extract(input: { storedFile: StoredFile; textHint?: string }): Promise<ExtractionResult>;
}

/** Parses only the synthetic fixture notation; it makes no network or OCR calls. */
export class DeterministicExtractionService implements ExtractionService {
  async extract(input: { storedFile: StoredFile; textHint?: string }): Promise<ExtractionResult> {
    return this.extractFixtureText(input.textHint ?? '');
  }

  extractFixtureText(text: string): ExtractionResult {
    const pages = [...text.matchAll(/^# Page (\d+)$/gm)].map((match) => Number(match[1]));
    const fields = [...text.matchAll(/^\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([^|]+?)\s*\|\s*([01](?:\.\d+)?)\s*\|\s*$/gm)]
      .filter((match) => match[1].trim() !== 'Field')
      .map((match): ExtractedFieldInput => ({
        pageNumber: pages.length ? pages[pages.length - 1] : 1,
        fieldKey: match[1].trim(), label: match[2].trim(), value: match[3].trim(), confidence: Number(match[4]),
        sourceText: `${match[2].trim()}: ${match[3].trim()}`,
      }));
    return { pageCount: Math.max(...pages, 1), fields };
  }
}
