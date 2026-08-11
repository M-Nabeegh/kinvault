import { KinVaultShell } from '../../components/kinvault-shell';
import { ReviewQueue } from '../../components/review-queue';
import { demoRepository } from '@/services/demo-vault';

export default function ReviewPage() {
  return <KinVaultShell activeSection="review"><ReviewQueue initialItems={demoRepository().listReviewItems()} /></KinVaultShell>;
}
