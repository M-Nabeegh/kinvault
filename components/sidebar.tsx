export type SectionKey = 'overview' | 'documents' | 'people' | 'review' | 'privacy';

const sections: Array<{ key: SectionKey; label: string; href: string }> = [
  { key: 'overview', label: 'Overview', href: '/' },
  { key: 'documents', label: 'Documents', href: '/documents' },
  { key: 'people', label: 'People', href: '/people' },
  { key: 'review', label: 'Needs review', href: '/review' },
  { key: 'privacy', label: 'Privacy', href: '/privacy' },
];

export function Sidebar({ activeSection }: { activeSection: SectionKey }) {
  return (
    <nav className="section-nav" aria-label="KinVault sections">
      {sections.map((section) => (
        <a
          aria-current={section.key === activeSection ? 'page' : undefined}
          className={section.key === activeSection ? 'section-nav__link section-nav__link--active' : 'section-nav__link'}
          href={section.href}
          key={section.key}
        >
          <span aria-hidden="true" className="section-nav__marker" />
          {section.label}
        </a>
      ))}
    </nav>
  );
}
