import { Dashboard } from '../components/dashboard';
import { KinVaultShell } from '../components/kinvault-shell';
import { demoRepository } from '@/services/demo-vault';
import { DashboardService } from '@/services/dashboard-service';

export default function HomePage() {
  const snapshot = new DashboardService(demoRepository()).snapshot();

  return <KinVaultShell activeSection="overview"><Dashboard snapshot={snapshot} /></KinVaultShell>;
}
