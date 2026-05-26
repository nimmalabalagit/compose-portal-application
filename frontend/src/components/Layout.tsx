import { useState } from 'react'
import { NavLink, Outlet } from 'react-router-dom'
import {
  LayoutDashboard, Users, Package, ShoppingCart,
  Server, ChevronLeft, Zap,
} from 'lucide-react'

const NAV = [
  { to: '/',               icon: LayoutDashboard, label: 'Dashboard'      },
  { to: '/users',          icon: Users,           label: 'Users'          },
  { to: '/products',       icon: Package,         label: 'Properties'     },
  { to: '/orders',         icon: ShoppingCart,    label: 'Orders'         },
  { to: '/infrastructure', icon: Server,          label: 'Infrastructure' },
]

export default function Layout() {
  const [collapsed, setCollapsed] = useState(false)

  return (
    <div className="flex h-screen overflow-hidden" style={{ background: 'var(--bg-primary)' }}>

      {/* ── Sidebar ──────────────────────────────────────────────── */}
      <aside
        className="flex flex-col transition-all duration-300 relative scan-lines border-r border-slate-700"
        style={{
          background: 'var(--bg-card)',
          width: collapsed ? '64px' : '220px',
          minWidth: collapsed ? '64px' : '220px',
        }}
      >
        {/* Logo */}
        <div className={`flex items-center gap-2.5 px-4 h-14 border-b border-slate-700 ${collapsed ? 'justify-center' : ''}`}>
          <div
            className="w-7 h-7 rounded-lg bg-cyan-500 flex items-center justify-center flex-shrink-0"
            style={{ boxShadow: '0 0 12px rgba(0,212,255,0.4)' }}
          >
            <Zap className="w-4 h-4 text-slate-950" />
          </div>
          {!collapsed && (
            <span className="font-display font-bold text-sm text-slate-100 leading-tight">
              EstateFlow<br />
              <span style={{ color: 'var(--cyan)', fontSize: '10px' }} className="font-mono font-normal">
                AI COMPOSE PORTAL
              </span>
            </span>
          )}
        </div>

        {/* Cluster status */}
        {!collapsed && (
          <div
            className="mx-3 mt-3 mb-1 px-3 py-2 rounded-lg"
            style={{ background: 'rgba(0,212,255,0.06)', border: '1px solid rgba(0,212,255,0.15)' }}
          >
            <div className="flex items-center gap-1.5">
              <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              <span className="font-mono text-xs" style={{ color: 'var(--cyan)' }}>
                compose-portal-eks
              </span>
            </div>
            <div className="font-mono text-xs text-slate-500 mt-0.5">v1.32 · ap-south-1</div>
          </div>
        )}

        {/* Navigation */}
        <nav className="flex-1 px-2 py-3 space-y-0.5 overflow-y-auto">
          {NAV.map(({ to, icon: Icon, label }) => (
            <NavLink
              key={to}
              to={to}
              end={to === '/'}
              className={({ isActive }) =>
                `flex items-center gap-3 px-3 py-2.5 rounded-lg text-sm
                 transition-all duration-150 group relative
                 ${isActive
                   ? 'text-cyan-400 font-medium'
                   : 'text-slate-400 hover:text-slate-200 hover:bg-slate-800'
                 } ${collapsed ? 'justify-center' : ''}`
              }
              style={({ isActive }) => isActive ? {
                background: 'rgba(0,212,255,0.08)',
                border: '1px solid rgba(0,212,255,0.15)',
              } : {}}
            >
              {({ isActive }) => (
                <>
                  <Icon className={`w-4 h-4 flex-shrink-0 ${isActive ? 'text-cyan-400' : 'text-slate-500 group-hover:text-slate-300'}`} />
                  {!collapsed && <span className="flex-1">{label}</span>}
                  {!collapsed && label === 'Infrastructure' && (
                    <span className="k8s-badge">K8s</span>
                  )}
                  {collapsed && (
                    <div className="absolute left-full ml-2 px-2 py-1 rounded text-xs
                                    bg-slate-800 text-slate-200 border border-slate-700
                                    opacity-0 group-hover:opacity-100 transition-opacity
                                    whitespace-nowrap z-50 pointer-events-none">
                      {label}
                    </div>
                  )}
                </>
              )}
            </NavLink>
          ))}
        </nav>

        {/* Collapse toggle */}
        <div className="p-3 border-t border-slate-700">
          <button
            onClick={() => setCollapsed(!collapsed)}
            className="w-full flex items-center justify-center p-2 rounded-lg
                       text-slate-500 hover:text-slate-300 hover:bg-slate-800 transition-colors"
          >
            <ChevronLeft className={`w-4 h-4 transition-transform duration-300 ${collapsed ? 'rotate-180' : ''}`} />
          </button>
        </div>
      </aside>

      {/* ── Main content ─────────────────────────────────────────── */}
      <div className="flex-1 flex flex-col overflow-hidden">

        {/* Top bar */}
        <header
          className="h-14 flex items-center justify-between px-6 border-b border-slate-700"
          style={{ background: 'var(--bg-card)' }}
        >
          <div className="flex items-center gap-3">
            <span className="font-mono text-xs text-slate-500">371056712467 · ap-south-1</span>
            <span
              className="px-2 py-0.5 rounded text-xs font-mono"
              style={{ background: 'rgba(16,185,129,0.1)', border: '1px solid rgba(16,185,129,0.25)', color: '#10B981' }}
            >
              PROD
            </span>
          </div>
          <div className="flex items-center gap-3">
            <span className="text-sm text-slate-400 font-mono">Nimmala Balakrishna</span>
            <div className="w-7 h-7 rounded-full bg-cyan-900 border border-cyan-700 flex items-center justify-center">
              <span className="text-xs font-mono text-cyan-300">NB</span>
            </div>
          </div>
        </header>

        {/* Page outlet */}
        <main className="flex-1 overflow-y-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  )
}
