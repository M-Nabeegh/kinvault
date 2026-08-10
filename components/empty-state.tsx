export function EmptyState({ title, children }: { title: string; children: React.ReactNode }) {
  return <div className="empty-state"><strong>{title}</strong><p>{children}</p></div>;
}
