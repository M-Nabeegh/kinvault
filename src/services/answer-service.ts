import { citationFor } from '@/domain/citations';
import { parseQuestion } from '@/domain/question-parser';
import type { AnswerResult, SourceCitation } from '@/domain/types';
import type { DocumentRepository, DocumentSummary } from '@/data/repository';

export type SearchResult = DocumentSummary & { documentId: string };

const normalized = (value: string) => value.trim().toLocaleLowerCase();

function confidenceFor(citations: SourceCitation[]): AnswerResult['confidence'] {
  const lowest = Math.min(...citations.map((citation) => citation.confidence));
  if (lowest >= 0.9) return 'high';
  if (lowest >= 0.75) return 'medium';
  return 'needs verification';
}

function calendarDay(value: string, allowTime = true): string | null {
  const match = /^(\d{4}-\d{2}-\d{2})/.exec(value);
  if (!match || (!allowTime && match[1] !== value)) return null;
  const [year, month, day] = match[1].split('-').map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, day));
  if (parsed.getUTCFullYear() !== year || parsed.getUTCMonth() !== month - 1 || parsed.getUTCDate() !== day) return null;
  return match[1];
}

function expiryWindow(days: number, now: string): { start: string; end: string } {
  const start = calendarDay(now);
  if (!start) throw new Error('Expected an ISO calendar date');
  const end = new Date(`${start}T00:00:00.000Z`);
  end.setUTCDate(end.getUTCDate() + days);
  return { start, end: end.toISOString().slice(0, 10) };
}

function isPersonMatch(personName: string, askedPerson: string): boolean {
  const person = normalized(personName);
  const asked = normalized(askedPerson);
  return person === asked || person.startsWith(`${asked} `);
}

function notFound(): AnswerResult {
  return {
    status: 'not-found',
    answer: 'Not found in the vault.',
    confidence: 'needs verification',
    citations: [],
    followUp: 'Try searching the indexed documents instead.',
  };
}

export class AnswerService {
  constructor(private readonly repository: DocumentRepository) {}

  answer(input: string, now = new Date().toISOString()): AnswerResult {
    const question = parseQuestion(input);
    if (question.kind === 'unsupported') {
      return {
        status: 'unsupported',
        answer: 'KinVault could not find the requested field.',
        confidence: 'needs verification',
        citations: [],
        followUp: 'Try searching the indexed documents instead.',
      };
    }

    if (question.kind === 'expiring-within-days') {
      const { start, end } = expiryWindow(question.days, now);
      const citations = this.repository.listDocuments()
        .flatMap((document) => (this.repository.getDocument(document.id)?.fields ?? [])
          .filter((field) => field.fieldKey === 'expires_on')
          .flatMap((field) => {
            const expiry = calendarDay(field.value, false);
            return expiry ? [{ document, field, expiry }] : [];
          }))
        .filter((record) => record.expiry >= start && record.expiry <= end)
        .sort((left, right) => left.expiry.localeCompare(right.expiry))
        .map(({ document, field }) => citationFor({ id: field.id, page: field.pageNumber, label: field.label, value: field.value, confidence: field.confidence }, document));

      if (!citations.length) return notFound();
      const confidence = confidenceFor(citations);
      return {
        status: 'answered',
        answer: `Documents expiring within the next ${question.days} days: ${citations.map((citation) => `${citation.documentTitle} (${citation.value})`).join(', ')}.${confidence === 'needs verification' ? ' Some fields need verification.' : ''}`,
        confidence,
        citations,
      };
    }

    const fieldKey = question.kind === 'passport-expiry' ? 'expires_on' : 'date_of_birth';
    const document = this.repository.listDocuments()
      .find((candidate) => isPersonMatch(candidate.personName, question.person) && (question.kind !== 'passport-expiry' || candidate.category === 'passport'));
    if (!document) return notFound();

    const field = this.repository.getDocument(document.id)?.fields.find((candidate) => candidate.fieldKey === fieldKey);
    if (!field) return notFound();

    const citation = citationFor({ id: field.id, page: field.pageNumber, label: field.label, value: field.value, confidence: field.confidence }, document);
    const confidence = confidenceFor([citation]);
    const subject = question.kind === 'passport-expiry' ? `${document.personName}’s passport expires on` : `${document.personName}’s date of birth is`;
    return {
      status: 'answered',
      answer: `${subject} ${citation.value}.${confidence === 'needs verification' ? ' This field needs verification.' : ''}`,
      confidence,
      citations: [citation],
    };
  }

  search(input: string): SearchResult[] {
    const term = normalized(input);
    const question = parseQuestion(input);
    const documents = this.repository.listDocuments();
    const directMatches = documents.filter((document) => [document.title, document.personName, document.category, document.expiresOn ?? '']
      .some((value) => normalized(value).includes(term)));

    const matches = directMatches.length || question.kind === 'unsupported' || question.kind === 'expiring-within-days'
      ? directMatches
      : documents.filter((document) => isPersonMatch(document.personName, question.person) && (question.kind !== 'passport-expiry' || document.category === 'passport'));
    return matches.map((document) => ({ ...document, documentId: document.id }));
  }
}
