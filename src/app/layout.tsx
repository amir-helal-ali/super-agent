import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'Super Agent - وكيل ذكاء اصطناعي خارق',
  description: 'وكيل ذكاء اصطناعي خفيف الوزن مبني بلغة Zig',
}

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="ar" dir="rtl" suppressHydrationWarning>
      <body className="antialiased bg-zinc-950 text-zinc-100">{children}</body>
    </html>
  )
}
