import { createDatabase } from '@/data/db';
import { DocumentRepository } from '@/data/repository';
import { seedDemoData } from '@/data/seed';
import { DocumentStorage } from '@/services/document-storage';

let repository: DocumentRepository | undefined;

/** The server-side synthetic demo repository used until the local UI adds upload configuration. */
export function demoRepository(): DocumentRepository {
  if (!repository) {
    repository = new DocumentRepository(createDatabase());
    seedDemoData(repository, new DocumentStorage());
  }
  return repository;
}
