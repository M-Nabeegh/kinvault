import type { Metadata } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'KinVault — Local family records',
  description: 'A local-first vault for synthetic family document records.',
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return <html lang="en"><body>{children}</body></html>;
}
