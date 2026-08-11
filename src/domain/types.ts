export type ExpiryWindow = {
  label: string;
  days: number;
  start: string;
  end: string;
};

export type SourceCitation = {
  documentId: string;
  documentTitle: string;
  page: number;
  field: string;
  value: string;
  confidence: number;
};

export type AnswerResult = {
  status: 'answered' | 'not-found' | 'unsupported';
  answer: string;
  confidence: 'high' | 'medium' | 'needs verification';
  citations: SourceCitation[];
  followUp?: string;
};

export type ParsedQuestion =
  | { kind: 'passport-expiry'; person: string }
  | { kind: 'date-of-birth'; person: string }
  | { kind: 'expiring-within-days'; days: number }
  | { kind: 'unsupported' };
