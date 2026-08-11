import { randomUUID } from 'node:crypto';
import type { DatabaseHandle } from './db';

export type DocumentCategory = 'passport' | 'identity' | 'insurance' | 'school' | 'vehicle' | 'visa' | 'certificate' | 'utility';
export type DocumentStatus = 'indexed' | 'review' | 'rejected';
export type ReviewStatus = 'accepted' | 'pending' | 'corrected' | 'dismissed';

export type NewPersonInput = { id?: string; displayName: string; relationship: string; initials: string };
export type NewDocumentInput = {
  id?: string; personId: string; title: string; category: DocumentCategory; fileName: string; storagePath: string;
  mimeType: string; pageCount: number; status?: DocumentStatus; issuedOn?: string; expiresOn?: string;
};
export type ExtractedFieldInput = {
  id?: string; pageNumber: number; fieldKey: string; label: string; value: string; confidence: number;
  sourceText: string; reviewStatus?: ReviewStatus;
};
export type DocumentFilters = { personId?: string; category?: DocumentCategory; status?: DocumentStatus };
export type PersonSummary = { id: string; displayName: string; relationship: string; initials: string; documentCount: number };
export type DocumentSummary = { id: string; personId: string; personName: string; title: string; category: DocumentCategory; status: DocumentStatus; expiresOn: string | null; createdAt: string };
export type ExtractedField = ExtractedFieldInput & { id: string; documentId: string; reviewStatus: ReviewStatus; createdAt: string; updatedAt: string };
export type DocumentDetail = DocumentSummary & { fileName: string; storagePath: string; mimeType: string; pageCount: number; issuedOn: string | null; fields: ExtractedField[] };
export type ReviewItem = { id: string; fieldId: string; documentId: string; documentTitle: string; personName: string; pageNumber: number; fieldKey: string; label: string; value: string; confidence: number; sourceText: string; reviewStatus: ReviewStatus; reason: string; createdAt: string };
export type DashboardSnapshot = { documentCount: number; categoryCounts: Array<{ category: DocumentCategory; count: number }>; nextExpiry: DocumentSummary | null; reviewCount: number; recentDocuments: DocumentSummary[] };
export type ReviewResolution = { action: 'accept' | 'dismiss' | 'correct'; value?: string };

const now = () => new Date().toISOString();
const rowToSummary = (row: any): DocumentSummary => ({ id: row.id, personId: row.person_id, personName: row.person_name, title: row.title, category: row.category, status: row.status, expiresOn: row.expires_on, createdAt: row.created_at });

export class DocumentRepository {
  constructor(private readonly database: DatabaseHandle) {}

  savePerson(input: NewPersonInput): PersonSummary {
    const id = input.id ?? randomUUID();
    const createdAt = now();
    this.database.db.prepare('INSERT INTO people (id, display_name, relationship, initials, created_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET display_name = excluded.display_name, relationship = excluded.relationship, initials = excluded.initials').run(id, input.displayName, input.relationship, input.initials, createdAt);
    return { id, displayName: input.displayName, relationship: input.relationship, initials: input.initials, documentCount: 0 };
  }

  hasDocument(id: string): boolean {
    return Boolean(this.database.db.prepare('SELECT 1 FROM documents WHERE id = ?').get(id));
  }

  hasPerson(id: string): boolean {
    return Boolean(this.database.db.prepare('SELECT 1 FROM people WHERE id = ?').get(id));
  }

  listDashboard(): DashboardSnapshot {
    const documentCount = (this.database.db.prepare('SELECT COUNT(*) AS count FROM documents').get() as { count: number }).count;
    const categoryCounts = this.database.db.prepare('SELECT category, COUNT(*) AS count FROM documents GROUP BY category ORDER BY category').all() as Array<{ category: DocumentCategory; count: number }>;
    const next = this.database.db.prepare("SELECT d.*, p.display_name AS person_name FROM documents d JOIN people p ON p.id = d.person_id WHERE d.expires_on IS NOT NULL AND d.expires_on >= date('now') ORDER BY d.expires_on ASC LIMIT 1").get();
    const reviewCount = (this.database.db.prepare('SELECT COUNT(*) AS count FROM review_items WHERE resolved_at IS NULL').get() as { count: number }).count;
    const recent = this.database.db.prepare('SELECT d.*, p.display_name AS person_name FROM documents d JOIN people p ON p.id = d.person_id ORDER BY d.created_at DESC LIMIT 5').all().map(rowToSummary);
    return { documentCount, categoryCounts, nextExpiry: next ? rowToSummary(next) : null, reviewCount, recentDocuments: recent };
  }

  listDocuments(filters: DocumentFilters = {}): DocumentSummary[] {
    const conditions: string[] = [];
    const values: unknown[] = [];
    if (filters.personId) { conditions.push('d.person_id = ?'); values.push(filters.personId); }
    if (filters.category) { conditions.push('d.category = ?'); values.push(filters.category); }
    if (filters.status) { conditions.push('d.status = ?'); values.push(filters.status); }
    const where = conditions.length ? ` WHERE ${conditions.join(' AND ')}` : '';
    return this.database.db.prepare(`SELECT d.*, p.display_name AS person_name FROM documents d JOIN people p ON p.id = d.person_id${where} ORDER BY d.created_at DESC`).all(...values).map(rowToSummary);
  }

  listPeople(): PersonSummary[] {
    return this.database.db.prepare('SELECT p.id, p.display_name, p.relationship, p.initials, COUNT(d.id) AS document_count FROM people p LEFT JOIN documents d ON d.person_id = p.id GROUP BY p.id ORDER BY p.display_name').all().map((row: any) => ({ id: row.id, displayName: row.display_name, relationship: row.relationship, initials: row.initials, documentCount: row.document_count }));
  }

  getDocument(id: string): DocumentDetail | null {
    const row: any = this.database.db.prepare('SELECT d.*, p.display_name AS person_name FROM documents d JOIN people p ON p.id = d.person_id WHERE d.id = ?').get(id);
    if (!row) return null;
    const fields = this.database.db.prepare('SELECT * FROM extracted_fields WHERE document_id = ? ORDER BY page_number, created_at').all(id).map((field: any): ExtractedField => ({ id: field.id, documentId: field.document_id, pageNumber: field.page_number, fieldKey: field.field_key, label: field.label, value: field.value, confidence: field.confidence, sourceText: field.source_text, reviewStatus: field.review_status, createdAt: field.created_at, updatedAt: field.updated_at }));
    return { ...rowToSummary(row), fileName: row.file_name, storagePath: row.storage_path, mimeType: row.mime_type, pageCount: row.page_count, issuedOn: row.issued_on, fields };
  }

  saveUpload(input: NewDocumentInput, fields: ExtractedFieldInput[]): DocumentDetail {
    const id = input.id ?? randomUUID();
    const createdAt = now();
    const transaction = this.database.db.transaction(() => {
      this.database.db.prepare('INSERT INTO documents (id, person_id, title, category, file_name, storage_path, mime_type, page_count, status, issued_on, expires_on, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)').run(id, input.personId, input.title, input.category, input.fileName, input.storagePath, input.mimeType, input.pageCount, input.status ?? 'indexed', input.issuedOn ?? null, input.expiresOn ?? null, createdAt);
      for (const field of fields) {
        const fieldId = field.id ?? randomUUID();
        const reviewStatus = field.reviewStatus ?? (field.confidence < 0.75 ? 'pending' : 'accepted');
        this.database.db.prepare('INSERT INTO extracted_fields (id, document_id, page_number, field_key, label, value, confidence, source_text, review_status, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)').run(fieldId, id, field.pageNumber, field.fieldKey, field.label, field.value, field.confidence, field.sourceText, reviewStatus, createdAt, createdAt);
        if (reviewStatus === 'pending') this.database.db.prepare('INSERT INTO review_items (id, field_id, reason, created_at, resolved_at) VALUES (?, ?, ?, ?, NULL)').run(randomUUID(), fieldId, 'Low extraction confidence', createdAt);
      }
    });
    transaction();
    return this.getDocument(id)!;
  }

  listReviewItems(): ReviewItem[] {
    return this.database.db.prepare('SELECT r.id, r.field_id, r.reason, r.created_at, f.document_id, f.page_number, f.field_key, f.label, f.value, f.confidence, f.source_text, f.review_status, d.title AS document_title, p.display_name AS person_name FROM review_items r JOIN extracted_fields f ON f.id = r.field_id JOIN documents d ON d.id = f.document_id JOIN people p ON p.id = d.person_id WHERE r.resolved_at IS NULL ORDER BY r.created_at').all().map((row: any) => ({ id: row.id, fieldId: row.field_id, documentId: row.document_id, documentTitle: row.document_title, personName: row.person_name, pageNumber: row.page_number, fieldKey: row.field_key, label: row.label, value: row.value, confidence: row.confidence, sourceText: row.source_text, reviewStatus: row.review_status, reason: row.reason, createdAt: row.created_at }));
  }

  resolveReviewItem(reviewId: string, resolution: ReviewResolution): ExtractedField | null {
    const review = this.database.db.prepare('SELECT field_id FROM review_items WHERE id = ? AND resolved_at IS NULL').get(reviewId) as { field_id: string } | undefined;
    if (!review) return null;
    if (resolution.action === 'correct' && !resolution.value?.trim()) throw new Error('A corrected value is required.');

    const updatedAt = now();
    const reviewStatus: ReviewStatus = resolution.action === 'accept' ? 'accepted' : resolution.action === 'dismiss' ? 'dismissed' : 'corrected';
    const transaction = this.database.db.transaction(() => {
      if (resolution.action === 'correct') {
        this.database.db.prepare('UPDATE extracted_fields SET value = ?, review_status = ?, updated_at = ? WHERE id = ?').run(resolution.value!.trim(), reviewStatus, updatedAt, review.field_id);
      } else {
        this.database.db.prepare('UPDATE extracted_fields SET review_status = ?, updated_at = ? WHERE id = ?').run(reviewStatus, updatedAt, review.field_id);
      }
      this.database.db.prepare('UPDATE review_items SET resolved_at = ? WHERE id = ?').run(updatedAt, reviewId);
      const document = this.database.db.prepare('SELECT document_id FROM extracted_fields WHERE id = ?').get(review.field_id) as { document_id: string };
      const pending = this.database.db.prepare('SELECT 1 FROM review_items r JOIN extracted_fields f ON f.id = r.field_id WHERE f.document_id = ? AND r.resolved_at IS NULL LIMIT 1').get(document.document_id);
      if (!pending) this.database.db.prepare("UPDATE documents SET status = 'indexed' WHERE id = ?").run(document.document_id);
    });
    transaction();
    const field = this.database.db.prepare('SELECT * FROM extracted_fields WHERE id = ?').get(review.field_id) as any;
    return { id: field.id, documentId: field.document_id, pageNumber: field.page_number, fieldKey: field.field_key, label: field.label, value: field.value, confidence: field.confidence, sourceText: field.source_text, reviewStatus: field.review_status, createdAt: field.created_at, updatedAt: field.updated_at };
  }
}
