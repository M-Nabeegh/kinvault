import type { DashboardSnapshot } from '@/data/repository';
import { dashboardExpiryCopy } from './dashboard-view-model';

export function ExpiryCard({ snapshot }: { snapshot: DashboardSnapshot }) {
  const expiry = dashboardExpiryCopy(snapshot, new Date().toISOString().slice(0, 10));

  return (
    <article className={`expiry-card expiry-card--${expiry.tone}`} aria-labelledby="expiry-heading">
      <div>
        <p className="eyebrow">Expiry radar</p>
        <h2 id="expiry-heading">{expiry.message}</h2>
      </div>
      {snapshot.nextExpiry ? (
        <p className="expiry-card__detail">
          Next: <strong>{snapshot.nextExpiry.title}</strong>
          <span>{snapshot.nextExpiry.expiresOn}</span>
        </p>
      ) : (
        <p className="expiry-card__detail">Add an expiry date to keep renewal work visible here.</p>
      )}
    </article>
  );
}
