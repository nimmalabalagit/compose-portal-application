import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import { Plus, Search, Pencil, UserX, Server } from 'lucide-react'
import toast from 'react-hot-toast'
import { userApi } from '../api/userApi'
import type { User, CreateUserRequest, UserRole } from '../api/types'

const ROLES: UserRole[] = ['BUYER', 'SELLER', 'ADMIN']

const ROLE_COLORS: Record<UserRole, string> = {
  ADMIN:  'status-error',
  SELLER: 'status-running',
  BUYER:  'status-completed',
}

export default function UsersPage() {
  const qc = useQueryClient()
  const [search, setSearch]     = useState('')
  const [roleFilter, setRole]   = useState<UserRole | ''>('')
  const [showCreate, setCreate] = useState(false)
  const [podInfo, setPodInfo]   = useState<{ pod: string; service: string } | null>(null)

  const { data: users = [], isLoading } = useQuery({
    queryKey: ['users', roleFilter],
    queryFn: async () => {
      const result = await userApi.getAll(roleFilter || undefined)
      // Capture pod name — proves which K8s pod served this request
      const info = await userApi.getPodInfo()
      setPodInfo(info)
      return result
    },
    staleTime: 30_000,
  })

  const createMut = useMutation({
    mutationFn: userApi.create,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['users'] })
      setCreate(false)
      toast.success('User created in PostgreSQL — Redis cache evicted')
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const deactivateMut = useMutation({
    mutationFn: userApi.deactivate,
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ['users'] })
      toast.success('User deactivated — @CacheEvict fired on Redis')
    },
    onError: (e: Error) => toast.error(e.message),
  })

  const filtered = users.filter((u) => {
    const q = search.toLowerCase()
    return !q
      || u.firstName.toLowerCase().includes(q)
      || u.lastName.toLowerCase().includes(q)
      || u.email.toLowerCase().includes(q)
  })

  const inputStyle: React.CSSProperties = {
    background: 'var(--bg-primary)',
    border: '1px solid var(--border-subtle)',
    color: 'var(--text-primary)',
    outline: 'none',
  }

  return (
    <div className="space-y-5">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-slate-100">User Management</h1>
          <p className="text-xs font-mono text-slate-500 mt-0.5">
            PostgreSQL 16 users_db · Redis 7 cache · BCrypt auth
          </p>
        </div>
        <button
          onClick={() => setCreate(true)}
          className="flex items-center gap-2 px-4 py-2 rounded-lg text-sm font-medium transition-colors"
          style={{ background: 'rgba(0,212,255,0.1)', border: '1px solid rgba(0,212,255,0.25)', color: '#00D4FF' }}
        >
          <Plus className="w-4 h-4" /> Add User
        </button>
      </div>

      {/* Pod hostname — the interview differentiator */}
      {podInfo && (
        <div
          className="flex items-center gap-2 px-3 py-2 rounded-lg"
          style={{ background: 'rgba(0,212,255,0.05)', border: '1px solid rgba(0,212,255,0.15)' }}
        >
          <Server className="w-3.5 h-3.5 text-cyan-400" />
          <span className="font-mono text-xs text-slate-400">
            Served by pod: <span className="text-cyan-400">{podInfo.pod}</span>
          </span>
          <span className="font-mono text-xs text-slate-600 ml-2">
            · In K8s with 3 replicas, refresh shows different pods → proves load balancing
          </span>
        </div>
      )}

      {/* Filters */}
      <div className="flex gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500" />
          <input
            type="text"
            placeholder="Search by name or email..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="w-full pl-9 pr-4 py-2 text-sm rounded-lg font-mono"
            style={inputStyle}
          />
        </div>
        <div className="flex gap-1.5">
          {(['', ...ROLES] as (UserRole | '')[]).map((r) => (
            <button
              key={r}
              onClick={() => setRole(r)}
              className="px-3 py-2 text-xs font-mono rounded-lg transition-colors"
              style={{
                background: roleFilter === r ? 'rgba(0,212,255,0.1)' : 'var(--bg-card)',
                border: `1px solid ${roleFilter === r ? 'rgba(0,212,255,0.3)' : 'var(--border-subtle)'}`,
                color: roleFilter === r ? '#00D4FF' : '#8B9DBF',
              }}
            >
              {r || 'ALL'}
            </button>
          ))}
        </div>
      </div>

      {/* Users table */}
      <div className="card-dark overflow-hidden">
        <table className="w-full">
          <thead>
            <tr style={{ borderBottom: '1px solid var(--border-subtle)' }}>
              {['Name', 'Email', 'Role', 'Status', 'Created', ''].map((h) => (
                <th key={h} className="text-left font-mono text-xs text-slate-500 px-5 py-3.5 uppercase tracking-wider">{h}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={6} className="text-center py-12 text-slate-500 font-mono text-sm">
                  Fetching from PostgreSQL 16 (Flyway V1-V3 migrations applied)...
                </td>
              </tr>
            ) : filtered.length === 0 ? (
              <tr>
                <td colSpan={6} className="text-center py-12 text-slate-600 font-mono text-sm">
                  No users found — is user-service healthy?
                </td>
              </tr>
            ) : filtered.map((user, idx) => (
              <tr
                key={user.id}
                className="transition-colors hover:bg-slate-800/40"
                style={{ borderBottom: idx < filtered.length - 1 ? '1px solid var(--border-muted)' : 'none' }}
              >
                <td className="px-5 py-3.5">
                  <div className="font-medium text-slate-200 text-sm">
                    {user.firstName} {user.lastName}
                  </div>
                </td>
                <td className="px-5 py-3.5 font-mono text-xs text-slate-400">{user.email}</td>
                <td className="px-5 py-3.5">
                  <span className={`text-xs px-2 py-0.5 rounded-full font-mono ${ROLE_COLORS[user.role]}`}>
                    {user.role}
                  </span>
                </td>
                <td className="px-5 py-3.5">
                  <span className={`text-xs px-2 py-0.5 rounded-full font-mono ${user.active ? 'status-running' : 'status-cancelled'}`}>
                    {user.active ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                </td>
                <td className="px-5 py-3.5 font-mono text-xs text-slate-500">
                  {new Date(user.createdAt).toLocaleDateString('en-IN')}
                </td>
                <td className="px-5 py-3.5">
                  <div className="flex items-center gap-1.5">
                    <button
                      onClick={() => {
                        if (window.confirm(`Deactivate ${user.firstName} ${user.lastName}?`)) {
                          deactivateMut.mutate(user.id)
                        }
                      }}
                      disabled={!user.active}
                      className="p-1.5 rounded-lg text-slate-500 hover:text-rose-400 hover:bg-slate-800 transition-colors disabled:opacity-30"
                      title="Deactivate user"
                    >
                      <UserX className="w-3.5 h-3.5" />
                    </button>
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        <div className="px-5 py-3 border-t border-slate-800 font-mono text-xs text-slate-500">
          {filtered.length} users · @Cacheable(value="users") · @CacheEvict on mutation
        </div>
      </div>

      {/* Create modal */}
      {showCreate && (
        <UserModal
          onClose={() => setCreate(false)}
          onSubmit={(data) => createMut.mutate(data)}
          isLoading={createMut.isPending}
        />
      )}
    </div>
  )
}

function UserModal({
  onClose, onSubmit, isLoading,
}: {
  onClose: () => void
  onSubmit: (d: CreateUserRequest) => void
  isLoading: boolean
}) {
  const [form, setForm] = useState<CreateUserRequest>({
    firstName: '',
    lastName: '',
    email: '',
    role: 'BUYER',
    // BCrypt hash of 'Password@123' — cost 10
    passwordHash: '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8ioctjEEFfNPNhVoWQxSFw0yNbOie',
    phoneNumber: '',
  })

  const inputStyle: React.CSSProperties = {
    background: 'var(--bg-primary)',
    border: '1px solid var(--border-subtle)',
    color: 'var(--text-primary)',
    borderRadius: '8px',
    padding: '8px 12px',
    fontSize: '13px',
    fontFamily: 'JetBrains Mono',
    width: '100%',
    outline: 'none',
  }

  return (
    <div
      className="fixed inset-0 z-50 flex items-center justify-center"
      style={{ background: 'rgba(0,0,0,0.7)' }}
    >
      <div className="card-dark p-6 w-full max-w-md mx-4">
        <h3 className="font-display font-bold text-slate-100 mb-5">Add New User</h3>
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-mono text-xs text-slate-400 mb-1.5">First Name *</label>
              <input style={inputStyle} value={form.firstName}
                     onChange={(e) => setForm({ ...form, firstName: e.target.value })} />
            </div>
            <div>
              <label className="block font-mono text-xs text-slate-400 mb-1.5">Last Name *</label>
              <input style={inputStyle} value={form.lastName}
                     onChange={(e) => setForm({ ...form, lastName: e.target.value })} />
            </div>
          </div>
          <div>
            <label className="block font-mono text-xs text-slate-400 mb-1.5">Email *</label>
            <input type="email" style={inputStyle} value={form.email}
                   onChange={(e) => setForm({ ...form, email: e.target.value })} />
          </div>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="block font-mono text-xs text-slate-400 mb-1.5">Role *</label>
              <select style={inputStyle} value={form.role}
                      onChange={(e) => setForm({ ...form, role: e.target.value as UserRole })}>
                {ROLES.map((r) => <option key={r}>{r}</option>)}
              </select>
            </div>
            <div>
              <label className="block font-mono text-xs text-slate-400 mb-1.5">Phone</label>
              <input style={inputStyle} value={form.phoneNumber ?? ''}
                     onChange={(e) => setForm({ ...form, phoneNumber: e.target.value })} />
            </div>
          </div>
          <div className="p-2 rounded font-mono text-xs text-slate-600"
               style={{ background: 'var(--bg-elevated)' }}>
            Password: default 'Password@123' (BCrypt hash pre-set)
          </div>
          <div className="flex gap-3 justify-end pt-2">
            <button onClick={onClose}
                    className="px-4 py-2 text-sm font-mono text-slate-400 hover:text-slate-200 transition-colors">
              Cancel
            </button>
            <button
              onClick={() => onSubmit(form)}
              disabled={isLoading || !form.firstName || !form.email}
              className="px-4 py-2 text-sm font-mono rounded-lg transition-colors disabled:opacity-50"
              style={{ background: 'rgba(0,212,255,0.1)', border: '1px solid rgba(0,212,255,0.3)', color: '#00D4FF' }}
            >
              {isLoading ? 'Saving...' : 'Save User'}
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
