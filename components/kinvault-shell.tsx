'use client';

import Image from 'next/image';
import type { ReactNode } from 'react';
import { Sidebar, type SectionKey } from './sidebar';
import { SpotlightSearch } from './spotlight-search';
import { StatusPill } from './status-pill';

export function KinVaultShell({ children, activeSection }: { children: ReactNode; activeSection: SectionKey }) {
  return (
    <div className="app-shell">
      <aside className="app-shell__sidebar">
        <a className="brand" href="/" aria-label="KinVault overview">
          <Image alt="" height={32} priority src="/kinvault-mark.svg" width={32} />
          <span>KinVault</span>
        </a>
        <Sidebar activeSection={activeSection} />
        <p className="sidebar-note">A local cabinet for the family records you choose to keep.</p>
      </aside>
      <div className="app-shell__workspace">
        <header className="topbar">
          <div className="topbar__identity">
            <p className="eyebrow">Family records</p>
            <StatusPill tone="local">Local only</StatusPill>
          </div>
          <SpotlightSearch onResult={() => undefined} />
        </header>
        <main className="app-shell__content">{children}</main>
      </div>
    </div>
  );
}
