import Database from 'better-sqlite3';
import { schemaSql } from './schema';

export type DatabaseHandle = {
  db: Database.Database;
  close(): void;
};

export function createDatabase(filename = ':memory:'): DatabaseHandle {
  const db = new Database(filename);
  db.exec(schemaSql);
  return { db, close: () => db.close() };
}
