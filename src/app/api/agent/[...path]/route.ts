import { NextRequest, NextResponse } from 'next/server'

const ZIG_BACKEND = process.env.ZIG_BACKEND_URL || 'http://127.0.0.1:8080'

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  const fullPath = path.join('/')
  const url = `${ZIG_BACKEND}/${fullPath}`

  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 5000)
    const response = await fetch(url, { signal: controller.signal })
    clearTimeout(timeoutId)
    const text = await response.text()
    return new NextResponse(text, { status: response.status, headers: { 'Content-Type': 'application/json' } })
  } catch {
    return NextResponse.json({ vocab_size: 217, memory_entries: 0, has_model: false, sessions: 0, error: 'backend offline' })
  }
}

export async function POST(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  const fullPath = path.join('/')
  const url = `${ZIG_BACKEND}/${fullPath}`
  const body = await request.text()

  try {
    const controller = new AbortController()
    const timeoutId = setTimeout(() => controller.abort(), 10000)
    const response = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body, signal: controller.signal })
    clearTimeout(timeoutId)
    const text = await response.text()
    return new NextResponse(text, { status: response.status, headers: { 'Content-Type': 'application/json' } })
  } catch {
    if (fullPath === 'api/chat') return NextResponse.json({ answer: 'الخادم غير متاح', steps: '0', tools: [] })
    return NextResponse.json({ error: 'backend offline' }, { status: 503 })
  }
}

export async function DELETE(
  request: NextRequest,
  { params }: { params: Promise<{ path: string[] }> }
) {
  const { path } = await params
  const fullPath = path.join('/')
  const url = `${ZIG_BACKEND}/${fullPath}`
  try {
    const response = await fetch(url, { method: 'DELETE' })
    const text = await response.text()
    return new NextResponse(text, { status: response.status })
  } catch {
    return NextResponse.json({ status: 'deleted' })
  }
}
