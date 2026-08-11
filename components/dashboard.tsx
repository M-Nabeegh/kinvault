'use client';

import { useCallback, useEffect, useState } from 'react';
import type { DashboardSnapshot } from '@/data/repository';
import { ExpiryCard } from './expiry-card';
import { StatusPill } from './status-pill';

function displayDate(value: string): string {
  return new Intl.DateTimeFormat('en', { day: 'numeric', month: 'short', year: 'numeric', timeZone: 'UTC' }).format(new Date(`${value.slice(0, 10)}T00:00:00.000Z`));
}

export function Dashboard({ snapshot }: { snapshot: DashboardSnapshot }) {
  const [currentSnapshot, setCurrentSnapshot] = useState(snapshot);
  const [refreshing, setRefreshing] = useState(false);
  const [refreshError, setRefreshError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    setRefreshing(true);
    setRefreshError(null);
    try {
      const response = await fetch('/api/dashboard', { cache: 'no-store' });
      if (!response.ok) throw new Error('The overview could not refresh.');
      setCurrentSnapshot(await response.json() as DashboardSnapshot);
    } catch (caught) {
      setRefreshError(caught instanceof Error ? caught.message : 'The overview could not refresh.');
    } finally {
      setRefreshing(false);
    }
  }, []);

  useEffect(() => {
    const refreshAfterMutation = () => { void refresh(); };
    window.addEventListener('kinvault:dashboard-mutated', refreshAfterMutation);
    return () => window.removeEventListener('kinvault:dashboard-mutated', refreshAfterMutation);
  }, [refresh]);

  return (
    <section aria-labelledby="overview-heading" className="dashboard">
      <header className="dashboard__header">
        <div>
          <p className="eyebrow">Overview</p>
          <h1 id="overview-heading">Your records, kept in view.</h1>
          <p className="dashboard__intro">The sample vault is ready to explore. Every answer points back to its indexed source.</p>
        </div>
        <button className="secondary-button" disabled={refreshing} onClick={() => void refresh()} type="button">
          {refreshing ? 'Refreshing…' : 'Refresh overview'}
        </button>
      </header>

      {refreshError && <p className="inline-message" role="status">{refreshError}</p>}

      <div className="dashboard__primary-grid">
        <ExpiryCard snapshot={currentSnapshot} />
        <article className="metric-card">
          <p className="eyebrow">Indexed records</p>
          <strong className="metric-card__number">{currentSnapshot.documentCount}</strong>
          <p>{currentSnapshot.documentCount === 1 ? 'document in this vault' : 'documents in this vault'}</p>
        </article>
        <article className="metric-card">
          <p className="eyebrow">Needs review</p>
          <strong className="metric-card__number">{currentSnapshot.reviewCount}</strong>
          <p>{currentSnapshot.reviewCount ? 'field awaiting a decision' : 'no fields awaiting a decision'}</p>
        </article>
      </div>

      <div className="dashboard__detail-grid">
        <section className="dashboard-panel" aria-labelledby="category-heading">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Cabinet index</p>
              <h2 id="category-heading">Document categories</h2>
            </div>
            <span className="panel-heading__count">{currentSnapshot.categoryCounts.length} kinds</span>
          </div>
          {refreshing ? <div className="skeleton-stack" aria-label="Refreshing categories"><span /><span /><span /></div> : currentSnapshot.categoryCounts.length ? (
            <ul className="category-list">
              {currentSnapshot.categoryCounts.map(({ category, count }) => <li key={category}><span>{category}</span><strong>{count}</strong></li>)}
            </ul>
          ) : <p className="empty-copy">Categories appear as records are indexed.</p>}
        </section>

        <section className="dashboard-panel" aria-labelledby="recent-heading">
          <div className="panel-heading">
            <div>
              <p className="eyebrow">Recently indexed</p>
              <h2 id="recent-heading">Document shelf</h2>
            </div>
          </div>
          {refreshing ? <div className="skeleton-stack" aria-label="Refreshing documents"><span /><span /><span /></div> : currentSnapshot.recentDocuments.length ? (
            <ul className="document-list">
              {currentSnapshot.recentDocuments.map((document) => (
                <li key={document.id}>
                  <div><strong>{document.title}</strong><span>{document.personName} · {document.category}</span></div>
                  {document.expiresOn ? <time dateTime={document.expiresOn}>{displayDate(document.expiresOn)}</time> : <StatusPill>Indexed</StatusPill>}
                </li>
              ))}
            </ul>
          ) : <p className="empty-copy">Your newest indexed records will collect here.</p>}
        </section>
      </div>
    </section>
  );
}
