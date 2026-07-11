const API_BASE = '/api/agent'

export interface Stats { vocab_size: number; memory_entries: number; has_model: boolean; sessions: number }
export interface ChatResponse { answer: string; steps: string; tools: string[] }
export interface SessionInfo { id: string; title: string; message_count: number; created_at: number; updated_at: number }

async function apiFetch<T>(path: string, options?: RequestInit): Promise<T> {
  const res = await fetch(`${API_BASE}${path}`, { headers: { 'Content-Type': 'application/json' }, ...options })
  return res.json()
}

export const agentApi = {
  getStats: () => apiFetch<Stats>('/api/stats'),
  chat: (message: string, sessionId?: string) => apiFetch<ChatResponse>('/api/chat', { method: 'POST', body: JSON.stringify({ message, session_id: sessionId }) }),
  learn: (text: string) => apiFetch<{ status: string }>('/api/learn', { method: 'POST', body: JSON.stringify({ text }) }),
  createSession: (title: string) => apiFetch<{ session_id: string }>('/api/sessions', { method: 'POST', body: JSON.stringify({ title }) }),
  listSessions: () => apiFetch<{ sessions: SessionInfo[] }>('/api/sessions'),
  getSession: (id: string) => apiFetch<{ messages: Array<{ role: string; content: string }> }>(`/api/sessions/${id}`),
  deleteSession: (id: string) => apiFetch(`/api/sessions/${id}`, { method: 'DELETE' }),
  train: (text: string) => apiFetch<{ status: string; loss: number }>('/api/train', { method: 'POST', body: JSON.stringify({ text }) }),
  getTools: () => apiFetch<{ tools: string[] }>('/api/tools'),
}
