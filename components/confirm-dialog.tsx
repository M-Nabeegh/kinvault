'use client';

import { useEffect, useId, useState } from 'react';

export function ConfirmDialog({ open, title, description, requiredPhrase, confirmLabel, tone = 'danger', onCancel, onConfirm }: {
  open: boolean;
  title: string;
  description: string;
  requiredPhrase: string;
  confirmLabel: string;
  tone?: 'danger' | 'neutral';
  onCancel: () => void;
  onConfirm: () => Promise<void> | void;
}) {
  const descriptionId = useId();
  const [typedConfirmation, setTypedConfirmation] = useState('');
  const [working, setWorking] = useState(false);
  useEffect(() => { if (open) setTypedConfirmation(''); }, [open]);
  if (!open) return null;

  async function confirm() {
    setWorking(true);
    try { await onConfirm(); } finally { setWorking(false); }
  }

  return (
    <div aria-describedby={descriptionId} aria-modal="true" className="confirm-dialog__backdrop" role="alertdialog">
      <section className="confirm-dialog">
        <p className="eyebrow">Explicit confirmation</p>
        <h2>{title}</h2>
        <p id={descriptionId}>{description}</p>
        <label>
          Type <code>{requiredPhrase}</code> to continue
          <input autoComplete="off" autoFocus onChange={(event) => setTypedConfirmation(event.target.value)} value={typedConfirmation} />
        </label>
        <footer>
          <button className="quiet-button" disabled={working} onClick={onCancel} type="button">Cancel</button>
          <button className={tone === 'danger' ? 'danger-button' : 'secondary-button'} disabled={typedConfirmation !== requiredPhrase || working} onClick={() => void confirm()} type="button">
            {working ? 'Removing…' : confirmLabel}
          </button>
        </footer>
      </section>
    </div>
  );
}
