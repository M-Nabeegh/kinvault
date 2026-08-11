'use client';

import { FormEvent, useEffect, useRef, useState } from 'react';
import type { AnswerResult } from '@/domain/types';
import type { SearchResult } from '@/services/answer-service';
import { StatusPill } from './status-pill';

export type SearchResponse = { result: AnswerResult; results: SearchResult[] };

export function SpotlightSearch({ onResult }: { onResult: (result: SearchResponse) => void }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [query, setQuery] = useState('');
  const [response, setResponse] = useState<SearchResponse | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const focusSpotlight = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'k') {
        event.preventDefault();
        inputRef.current?.focus();
      }
      if (event.key === 'Escape') inputRef.current?.blur();
    };
    window.addEventListener('keydown', focusSpotlight);
    return () => window.removeEventListener('keydown', focusSpotlight);
  }, []);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const trimmedQuery = query.trim();
    if (!trimmedQuery) return;

    setLoading(true);
    setError(null);
    try {
      const request = await fetch(`/api/search?q=${encodeURIComponent(trimmedQuery)}`, { cache: 'no-store' });
      if (!request.ok) throw new Error('Search is unavailable right now.');
      const result = await request.json() as SearchResponse;
      setResponse(result);
      onResult(result);
    } catch (caught) {
      setResponse(null);
      setError(caught instanceof Error ? caught.message : 'Search is unavailable right now.');
    } finally {
      setLoading(false);
    }
  }

  const citation = response?.result.citations[0];

  return (
    <div className="spotlight">
      <form className="spotlight__form" onSubmit={submit} role="search">
        <label className="sr-only" htmlFor="vault-search">Search your local vault</label>
        <span aria-hidden="true" className="spotlight__symbol">⌕</span>
        <input
          id="vault-search"
          onChange={(event) => setQuery(event.target.value)}
          placeholder="Search documents or ask a vault question"
          ref={inputRef}
          value={query}
        />
        <kbd aria-label="Command or Control K">⌘K</kbd>
        <button disabled={loading || !query.trim()} type="submit">{loading ? 'Searching…' : 'Search'}</button>
      </form>

      {(loading || error || response) && (
        <section aria-live="polite" className="search-popover">
          {loading && <p className="search-popover__loading">Searching the local index…</p>}
          {error && <p className="search-popover__error">{error}</p>}
          {response && !loading && (
            <>
              <div className="search-popover__answer">
                <StatusPill tone={response.result.status === 'answered' ? 'local' : 'review'}>{response.result.confidence}</StatusPill>
                <p>{response.result.answer}</p>
              </div>
              {citation ? (
                <div className="source-result">
                  <div>
                    <p className="eyebrow">Source result</p>
                    <strong>{citation.documentTitle}</strong>
                    <p>Page {citation.page} · {citation.field}: {citation.value}</p>
                  </div>
                  <button className="text-button" type="button">Open source <span aria-hidden="true">↗</span></button>
                </div>
              ) : (
                <p className="search-popover__hint">{response.result.followUp ?? 'Try a document title, person, or supported expiry question.'}</p>
              )}
            </>
          )}
        </section>
      )}
    </div>
  );
}
