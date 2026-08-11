type StatusTone = 'local' | 'review' | 'attention' | 'quiet' | 'scheduled';

export function StatusPill({ children, tone = 'quiet' }: { children: React.ReactNode; tone?: StatusTone }) {
  return <span className={`status-pill status-pill--${tone}`}>{children}</span>;
}
