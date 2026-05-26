import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { userApi } from '../api/userApi';
import type { CreateUserRequest, UserRole } from '../api/types';
import toast from 'react-hot-toast';

const ROLES: UserRole[] = ['BUYER', 'SELLER', 'AGENT', 'ADMIN', 'MANAGER', 'SUPPORT'];

const ROLE_COLORS: Record<string, string> = {
  ADMIN:   'bg-red-900/40 text-red-300 border-red-700',
  AGENT:   'bg-blue-900/40 text-blue-300 border-blue-700',
  BUYER:   'bg-green-900/40 text-green-300 border-green-700',
  SELLER:  'bg-yellow-900/40 text-yellow-300 border-yellow-700',
  MANAGER: 'bg-purple-900/40 text-purple-300 border-purple-700',
  SUPPORT: 'bg-slate-700/40 text-slate-300 border-slate-600',
};

// BCrypt hash for "password123" — pre-computed to avoid heavy client-side computation
const DEFAULT_HASH = '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8ioctjEEFfNPNhVoWQxSFw0yNbOie';

export default function UsersPage() {
  const qc = useQueryClient();
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({
    firstName: '', lastName: '', email: '',
    role: 'BUYER' as UserRole, phoneNumber: '', password: '',
  });

  const { data: users = [], isLoading, error } = useQuery({
    queryKey: ['users'],
    queryFn: () => userApi.getAll(),
    refetchInterval: 30_000,
  });

  const createMutation = useMutation({
    mutationFn: (req: CreateUserRequest) => userApi.create(req),
    onSuccess: (newUser) => {
      qc.invalidateQueries({ queryKey: ['users'] });
      toast.success(`✅ User ${newUser.firstName} ${newUser.lastName} created!`);
      setShowForm(false);
      setForm({ firstName: '', lastName: '', email: '', role: 'BUYER', phoneNumber: '', password: '' });
    },
    onError: () => toast.error('❌ Failed to create user'),
  });

  const handleSubmit = () => {
    if (!form.firstName || !form.email || !form.phoneNumber) {
      toast.error('Fill in all required fields');
      return;
    }
    createMutation.mutate({
      firstName: form.firstName,
      lastName: form.lastName,
      email: form.email,
      role: form.role,
      phoneNumber: form.phoneNumber,
      passwordHash: DEFAULT_HASH,
    });
  };

  if (isLoading) return (
    <div className="flex items-center justify-center h-64">
      <div className="text-cyan-400 font-mono animate-pulse">Loading users...</div>
    </div>
  );

  if (error) return (
    <div className="text-red-400 font-mono p-4 border border-red-700 rounded bg-red-900/20">
      ❌ Failed to load users — gateway circuit may be open
    </div>
  );

  return (
    <div>
      {/* Header */}
      <div className="flex items-center justify-between mb-6">
        <div>
          <h1 className="text-xl font-semibold text-slate-100">Users</h1>
          <p className="text-sm text-slate-400 font-mono mt-0.5">
            {users.length} registered · PostgreSQL + Redis cache
          </p>
        </div>
        <button
          onClick={() => setShowForm(!showForm)}
          className="px-4 py-2 rounded font-mono text-sm border transition-all"
          style={{
            background: showForm ? 'rgba(239,68,68,0.15)' : 'rgba(16,185,129,0.15)',
            borderColor: showForm ? '#ef4444' : '#10B981',
            color: showForm ? '#f87171' : '#10B981',
          }}
        >
          {showForm ? '✕ Cancel' : '+ Add User'}
        </button>
      </div>

      {/* Add User Form */}
      {showForm && (
        <div className="mb-6 p-5 rounded-lg border border-cyan-800/50 bg-slate-800/50">
          <h2 className="text-sm font-mono text-cyan-400 mb-4">NEW USER REGISTRATION</h2>
          <div className="grid grid-cols-2 gap-3">
            <div>
              <label className="text-xs font-mono text-slate-400 mb-1 block">First Name *</label>
              <input
                className="w-full bg-slate-900 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                value={form.firstName}
                onChange={e => setForm(f => ({ ...f, firstName: e.target.value }))}
                placeholder="Arjun"
              />
            </div>
            <div>
              <label className="text-xs font-mono text-slate-400 mb-1 block">Last Name</label>
              <input
                className="w-full bg-slate-900 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                value={form.lastName}
                onChange={e => setForm(f => ({ ...f, lastName: e.target.value }))}
                placeholder="Reddy"
              />
            </div>
            <div>
              <label className="text-xs font-mono text-slate-400 mb-1 block">Email *</label>
              <input
                className="w-full bg-slate-900 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                value={form.email}
                onChange={e => setForm(f => ({ ...f, email: e.target.value }))}
                placeholder="arjun@estateflowai.co"
                type="email"
              />
            </div>
            <div>
              <label className="text-xs font-mono text-slate-400 mb-1 block">Phone *</label>
              <input
                className="w-full bg-slate-900 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                value={form.phoneNumber}
                onChange={e => setForm(f => ({ ...f, phoneNumber: e.target.value }))}
                placeholder="+91-9876543210"
              />
            </div>
            <div>
              <label className="text-xs font-mono text-slate-400 mb-1 block">Role</label>
              <select
                className="w-full bg-slate-900 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                value={form.role}
                onChange={e => setForm(f => ({ ...f, role: e.target.value as UserRole }))}
              >
                {ROLES.map(r => <option key={r} value={r}>{r}</option>)}
              </select>
            </div>
            <div>
              <label className="text-xs font-mono text-slate-400 mb-1 block">
                Password <span className="text-slate-500">(default: password123)</span>
              </label>
              <input
                className="w-full bg-slate-900 border border-slate-600 rounded px-3 py-2 text-sm text-slate-100 font-mono focus:border-cyan-500 outline-none"
                value={form.password}
                onChange={e => setForm(f => ({ ...f, password: e.target.value }))}
                placeholder="password123"
                type="password"
              />
            </div>
          </div>
          <button
            onClick={handleSubmit}
            disabled={createMutation.isPending}
            className="mt-4 px-6 py-2 rounded font-mono text-sm font-medium transition-all disabled:opacity-50"
            style={{ background: '#10B981', color: '#0a0f1e' }}
          >
            {createMutation.isPending ? 'Creating...' : 'Create User →'}
          </button>
        </div>
      )}

      {/* Users Table */}
      <div className="rounded-lg border border-slate-700 overflow-hidden">
        <table className="w-full text-sm font-mono">
          <thead>
            <tr className="border-b border-slate-700" style={{ background: 'rgba(15,22,41,0.8)' }}>
              <th className="text-left px-4 py-3 text-slate-400 font-medium">Name</th>
              <th className="text-left px-4 py-3 text-slate-400 font-medium">Email</th>
              <th className="text-left px-4 py-3 text-slate-400 font-medium">Role</th>
              <th className="text-left px-4 py-3 text-slate-400 font-medium">Phone</th>
              <th className="text-left px-4 py-3 text-slate-400 font-medium">Status</th>
              <th className="text-left px-4 py-3 text-slate-400 font-medium">Created</th>
            </tr>
          </thead>
          <tbody>
            {users.map((user, i) => (
              <tr
                key={user.id}
                className="border-b border-slate-800 hover:bg-slate-800/30 transition-colors"
                style={{ background: i % 2 === 0 ? 'transparent' : 'rgba(15,22,41,0.3)' }}
              >
                <td className="px-4 py-3 text-slate-100">
                  {user.firstName} {user.lastName}
                </td>
                <td className="px-4 py-3 text-cyan-400">{user.email}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded text-xs border ${ROLE_COLORS[user.role] || ROLE_COLORS.SUPPORT}`}>
                    {user.role}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-300">{user.phoneNumber}</td>
                <td className="px-4 py-3">
                  <span className={`px-2 py-0.5 rounded text-xs border ${
                    user.active
                      ? 'bg-green-900/40 text-green-300 border-green-700'
                      : 'bg-red-900/40 text-red-300 border-red-700'
                  }`}>
                    {user.active ? 'ACTIVE' : 'INACTIVE'}
                  </span>
                </td>
                <td className="px-4 py-3 text-slate-500">
                  {new Date(user.createdAt).toLocaleDateString()}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
