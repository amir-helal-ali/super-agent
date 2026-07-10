'use client'

import { useState, useEffect, useRef, useCallback } from 'react'
import { Send, Sparkles, Plus, Trash2, Download, Settings, Cpu, Brain, MessageSquare, Calculator, Clock, Languages, Zap, Loader2, Server } from 'lucide-react'
import { agentApi, type SessionInfo, type Stats } from '@/lib/agent-api'

interface Message { role: 'user' | 'assistant'; content: string; tools?: string[]; timestamp: number }

export default function Home() {
  const [messages, setMessages] = useState<Message[]>([{ role: 'assistant', content: 'مرحبا! أنا Super Agent - وكيل ذكاء اصطناعي خارق مبني بلغة Zig. كيف يمكنني مساعدتك؟', timestamp: Date.now() }])
  const [input, setInput] = useState('')
  const [loading, setLoading] = useState(false)
  const [sessions, setSessions] = useState<SessionInfo[]>([])
  const [currentSession, setCurrentSession] = useState<string | null>(null)
  const [stats, setStats] = useState<Stats | null>(null)
  const [showPanel, setShowPanel] = useState(false)
  const [backendOnline, setBackendOnline] = useState(false)
  const scrollRef = useRef<HTMLDivElement>(null)

  const loadStats = useCallback(async () => {
    try { const s = await agentApi.getStats(); setStats(s); setBackendOnline(!s.error) } catch { setBackendOnline(false) }
  }, [])

  const loadSessions = useCallback(async () => {
    try { const data = await agentApi.listSessions(); setSessions(data.sessions || []) } catch {}
  }, [])

  useEffect(() => { loadStats(); loadSessions(); const i = setInterval(loadStats, 10000); return () => clearInterval(i) }, [loadStats, loadSessions])
  useEffect(() => { if (scrollRef.current) scrollRef.current.scrollTop = scrollRef.current.scrollHeight }, [messages])

  const sendMessage = async (text?: string) => {
    const msg = text || input; if (!msg.trim()) return
    setMessages(p => [...p, { role: 'user', content: msg, timestamp: Date.now() }])
    setInput(''); setLoading(true)
    try {
      const r = await agentApi.chat(msg, currentSession || undefined)
      setMessages(p => [...p, { role: 'assistant', content: r.answer || 'لا توجد إجابة', tools: r.tools, timestamp: Date.now() }])
      if (currentSession) loadSessions()
    } catch { setMessages(p => [...p, { role: 'assistant', content: 'عذراً، تعذر الاتصال بالخادم.', timestamp: Date.now() }]) }
    finally { setLoading(false); loadStats() }
  }

  const newSession = async () => {
    try { const d = await agentApi.createSession('محادثة جديدة'); setCurrentSession(d.session_id); setMessages([{ role: 'assistant', content: 'مرحبا! كيف يمكنني مساعدتك؟', timestamp: Date.now() }]); loadSessions() } catch {}
  }

  const loadSession = async (id: string) => {
    try { const s = await agentApi.getSession(id); setCurrentSession(id); const msgs: Message[] = (s.messages || []).map(m => ({ role: m.role as 'user' | 'assistant', content: m.content, timestamp: Date.now() })); setMessages(msgs.length > 0 ? msgs : [{ role: 'assistant', content: 'محادثة فارغة', timestamp: Date.now() }]); loadSessions() } catch {}
  }

  const deleteSession = async (id: string, e: React.MouseEvent) => {
    e.stopPropagation(); try { await agentApi.deleteSession(id); if (currentSession === id) { setCurrentSession(null); setMessages([{ role: 'assistant', content: 'مرحبا! كيف يمكنني مساعدتك؟', timestamp: Date.now() }]) } loadSessions() } catch {}
  }

  const quickActions = [
    { label: 'ترحيب', icon: MessageSquare, msg: 'مرحبا' },
    { label: 'معلومات', icon: Cpu, msg: 'من انت؟' },
    { label: 'حساب', icon: Calculator, msg: 'sqrt(25) + 10' },
    { label: 'وقت', icon: Clock, msg: 'كم الساعة' },
    { label: 'EN', icon: Languages, msg: 'ترجم للإنجليزية: مرحبا عالم' },
    { label: 'FR', icon: Languages, msg: 'ترجم للفرنسية: مرحبا عالم' },
  ]

  return (
    <div className="h-screen flex bg-zinc-950 text-zinc-100 overflow-hidden" dir="rtl">
      <aside className="w-80 border-l border-zinc-800 bg-zinc-900 flex flex-col">
        <div className="p-4 border-b border-zinc-800 flex items-center justify-between">
          <h2 className="text-lg font-semibold text-emerald-400">المحادثات</h2>
          <button onClick={newSession} className="px-3 py-1.5 text-sm bg-emerald-600 hover:bg-emerald-700 rounded-lg flex items-center gap-1 transition"><Plus className="w-4 h-4" /> جديد</button>
        </div>
        <div className="flex-1 overflow-y-auto p-2">
          {sessions.length > 0 ? sessions.map(s => (
            <div key={s.id} onClick={() => loadSession(s.id)} className={`p-3 mb-1 rounded-lg cursor-pointer transition group flex items-center justify-between ${currentSession === s.id ? 'bg-emerald-600 text-white' : 'hover:bg-zinc-800'}`}>
              <div className="flex-1 min-w-0"><div className="text-sm font-medium truncate">{s.title}</div><div className="text-xs mt-0.5 opacity-70">{s.message_count} رسائل</div></div>
              <button onClick={(e) => deleteSession(s.id, e)} className="opacity-0 group-hover:opacity-100 p-1 hover:bg-red-600 rounded"><Trash2 className="w-3 h-3" /></button>
            </div>
          )) : <div className="text-center text-zinc-500 text-sm p-8">لا توجد محادثات</div>}
        </div>
      </aside>

      <main className="flex-1 flex flex-col">
        <header className="border-b border-zinc-800 p-4 flex items-center justify-between bg-zinc-900">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-emerald-500 to-teal-600 flex items-center justify-center"><Sparkles className="w-5 h-5 text-white" /></div>
            <div><h1 className="text-xl font-bold bg-gradient-to-r from-emerald-400 to-teal-400 bg-clip-text text-transparent">Super Agent</h1><p className="text-xs text-zinc-500">وكيل ذكاء اصطناعي - Zig Edition</p></div>
          </div>
          <div className="flex items-center gap-2">
            {stats && (
              <div className="hidden md:flex items-center gap-2">
                <span className={`px-2 py-1 rounded-md text-xs flex items-center gap-1 ${backendOnline ? 'bg-emerald-600/20 text-emerald-400' : 'bg-red-600/20 text-red-400'}`}><Server className="w-3 h-3" />{backendOnline ? 'متصل' : 'غير متصل'}</span>
                <span className="px-2 py-1 rounded-md text-xs bg-zinc-800 flex items-center gap-1"><Brain className="w-3 h-3" />{stats.vocab_size}</span>
                <span className="px-2 py-1 rounded-md text-xs bg-zinc-800 flex items-center gap-1"><MessageSquare className="w-3 h-3" />{stats.sessions}</span>
              </div>
            )}
            <button onClick={() => setShowPanel(!showPanel)} className="p-2 rounded-lg border border-zinc-800 hover:bg-zinc-800 transition"><Settings className="w-4 h-4" /></button>
          </div>
        </header>

        <div ref={scrollRef} className="flex-1 overflow-y-auto p-6 space-y-4">
          {messages.map((msg, i) => (
            <div key={i} className={`flex ${msg.role === 'user' ? 'justify-start' : 'justify-end'}`}>
              <div className={`max-w-[80%] rounded-2xl p-4 ${msg.role === 'user' ? 'bg-emerald-600 text-white' : 'bg-zinc-900 border border-zinc-800'}`}>
                <p className="whitespace-pre-wrap break-words">{msg.content}</p>
                {msg.tools && msg.tools.length > 0 && <div className="mt-2 pt-2 border-t border-zinc-700/50 flex flex-wrap gap-1">{msg.tools.map((t, j) => <span key={j} className="text-xs px-2 py-0.5 rounded bg-zinc-800">{t}</span>)}</div>}
              </div>
            </div>
          ))}
          {loading && <div className="flex justify-end"><div className="bg-zinc-900 border border-zinc-800 rounded-2xl p-4 flex items-center gap-2"><Loader2 className="w-4 h-4 animate-spin" /><span className="text-sm text-zinc-500">جاري المعالجة...</span></div></div>}
        </div>

        <div className="px-4 py-2 border-t border-zinc-800 bg-zinc-900">
          <div className="flex flex-wrap gap-1.5 mb-2">
            {quickActions.map((a, i) => <button key={i} onClick={() => sendMessage(a.msg)} className="px-3 py-1.5 text-xs border border-zinc-800 rounded-lg hover:bg-zinc-800 transition flex items-center gap-1"><a.icon className="w-3 h-3" />{a.label}</button>)}
          </div>
        </div>

        <div className="p-4 border-t border-zinc-800 bg-zinc-900">
          <div className="flex gap-2">
            <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === 'Enter' && !loading && sendMessage()} placeholder="اكتب رسالتك..." disabled={loading} className="flex-1 px-4 py-3 bg-zinc-950 border border-zinc-800 rounded-lg text-zinc-100 focus:outline-none focus:border-emerald-500" />
            <button onClick={() => sendMessage()} disabled={loading || !input.trim()} className="px-6 py-3 bg-emerald-600 hover:bg-emerald-700 disabled:bg-zinc-800 rounded-lg transition">{loading ? <Loader2 className="w-4 h-4 animate-spin" /> : <Send className="w-4 h-4" />}</button>
          </div>
        </div>
      </main>

      {showPanel && (
        <aside className="w-80 border-r border-zinc-800 bg-zinc-900 overflow-y-auto p-4 space-y-4">
          <h3 className="font-semibold flex items-center gap-2"><Cpu className="w-4 h-4" /> معلومات النظام</h3>
          <div className="space-y-2 text-sm">
            <div className="flex justify-between"><span>حجم القاموس:</span><span className="font-mono">{stats?.vocab_size ?? '-'}</span></div>
            <div className="flex justify-between"><span>مدخلات الذاكرة:</span><span className="font-mono">{stats?.memory_entries ?? '-'}</span></div>
            <div className="flex justify-between"><span>النموذج محمّل:</span><span>{stats?.has_model ? '✅' : '❌'}</span></div>
            <div className="flex justify-between"><span>حالة الخادم:</span><span>{backendOnline ? '✅ متصل' : '❌ غير متصل'}</span></div>
          </div>
          <div className="text-xs space-y-1 text-zinc-500 pt-4 border-t border-zinc-800">
            <div>Backend: Zig 0.14 (port 8080)</div>
            <div>Frontend: Next.js + React</div>
            <div>RAM: 2GB, No GPU</div>
          </div>
        </aside>
      )}
    </div>
  )
}
