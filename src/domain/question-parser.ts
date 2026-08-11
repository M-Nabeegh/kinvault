import type { ParsedQuestion } from '@/domain/types';

const normalizePerson = (person: string) => person.trim().replace(/\s+/g, ' ');

export function parseQuestion(input: string): ParsedQuestion {
  const question = input.trim();
  const passportExpiry = /^when\s+(?:does|will)\s+(.+?)(?:'s|’s)\s+passport\s+expire\??$/i.exec(question);
  if (passportExpiry) {
    return { kind: 'passport-expiry', person: normalizePerson(passportExpiry[1]) };
  }

  const dateOfBirth = /^(?:what\s+is|when\s+is)\s+(.+?)(?:'s|’s)\s+(?:date\s+of\s+birth|birth\s+date)\??$/i.exec(question);
  if (dateOfBirth) {
    return { kind: 'date-of-birth', person: normalizePerson(dateOfBirth[1]) };
  }

  const expiryWindow = /^which\s+documents\s+expire\s+(?:in|within)\s+(?:the\s+)?next\s+(\d+)\s+days\??$/i.exec(question);
  if (expiryWindow) {
    return { kind: 'expiring-within-days', days: Number(expiryWindow[1]) };
  }

  return { kind: 'unsupported' };
}
