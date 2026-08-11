import { DocumentTable } from '../../components/document-table';
import { KinVaultShell } from '../../components/kinvault-shell';
import { demoRepository } from '@/services/demo-vault';

export default function DocumentsPage() {
  const repository = demoRepository();
  return <KinVaultShell activeSection="documents"><DocumentTable initialDocuments={repository.listDocuments()} people={repository.listPeople()} /></KinVaultShell>;
}
