import { KinVaultShell } from '../../components/kinvault-shell';
import { PrivacyPanel } from '../../components/privacy-panel';
import { demoRepository } from '@/services/demo-vault';

export const dynamic = 'force-dynamic';

export default function PrivacyPage() {
  return <KinVaultShell activeSection="privacy"><PrivacyPanel documents={demoRepository().listDocuments()} /></KinVaultShell>;
}
