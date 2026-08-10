'use client';

import Image from 'next/image';
import Link from 'next/link';
import { useState, type ReactNode } from 'react';
import type { SourceCitation } from '@/domain/types';
import { Sidebar, type SectionKey } from './sidebar';
import { SpotlightSearch } from './spotlight-search';
import { StatusPill } from './status-pill';
import { SourcePreview } from './source-preview';

export function KinVaultShell({ children, activeSection }: { children: ReactNode; activeSection: SectionKey }) {
  const [sourceCitation, setSourceCitation] = useState<SourceCitation | null>(null);
  return (
    <div className="app-shell">
      <aside className="app-shell__sidebar">
        <Link className="brand" href="/" aria-label="KinVault overview">
          <Image alt="" height={32} priority src="/kinvault-mark.svg" width={32} />
          <span>KinVault</span>
        </Link>
        <Sidebar activeSection={activeSection} />
        <p className="sidebar-note">A local cabinet for the family records you choose to keep.</p>
      </aside>
      <div className="app-shell__workspace">
        <header className="topbar">
          <div className="topbar__identity">
            <Link className="mobile-brand" href="/" aria-label="KinVault overview">
              <Image alt="" height={24} src="/kinvault-mark.svg" width={24} />
              <span>KinVault</span>
            </Link>
            <p className="eyebrow">Family records</p>
            <StatusPill tone="local">Local only</StatusPill>
          </div>
          <SpotlightSearch onOpenSource={setSourceCitation} onResult={() => undefined} />
        </header>
        <main className="app-shell__content">{children}</main>
      </div>
      {sourceCitation && <SourcePreview citation={sourceCitation} documentId={sourceCitation.documentId} onClose={() => setSourceCitation(null)} />}
    </div>
  );
}
