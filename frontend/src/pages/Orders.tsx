import { useState } from 'react'
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'
import {
  DndContext, DragEndEvent, DragOverlay, DragStartEvent,
  closestCenter, useSensor, useSensors, PointerSensor,
  useDroppable, useDraggable,
} from '@dnd-kit/core'
import toast from 'react-hot-toast'
import { GripVertical } from 'lucide-react'
import { orderApi } from '../api/orderApi'
import type { Order, OrderStatus } from '../api/types'

const COLUMNS: { id: OrderStatus; label: string; color: string }[] = [
  { id: 'PENDING',    label: 'Pending',    color: '#F59E0B' },
  { id: 'PROCESSING', label: 'Processing', color: '#00D4FF' },
  { id: 'COMPLETED',  label: 'Completed',  color: '#10B981' },
  { id: 'CANCELLED',  label: 'Cancelled',  color: '#6B7280' },
]

// STATE MACHINE: mirrors OrderService.java VALID_TRANSITIONS exactly
// Interview Q: "How does your UI prevent illegal state transitions?"
// Answer: Same state machine encoded in TypeScript — UI and server both validate.
// Drag guard shows toast; server-side Java also throws IllegalStateException.
const VALID_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PENDING:    ['PROCESSING', 'CANCELLED'],
  PROCESSING: ['COMPLETED',  'CANCELLED'],
  COMPLETED:  [],   // Terminal — drag disabled, no outbound transitions
  CANCELLED:  [],   // Terminal — drag disabled, no outbound transitions
}

function KanbanCard({ order }: { order: Order }) {
  const isTerminal = order.status === 'COMPLETED' || order.status === 'CANCELLED'
  const { attributes, listeners, setNodeRef, transform } = useDraggable({ id: order.id })

  const style: React.CSSProperties = transform
    ? { transform: `translate3d(${transform.x}px, ${transform.y}px, 0)` }
    : {}

  return (
    <div
      ref={setNodeRef}
      style={{ ...style, cursor: isTerminal ? 'not-allowed' : 'grab' }}
      {...(isTerminal ? {} : { ...attributes, ...listeners })}
      className="card-dark p-3.5 mb-2 select-none hover:border-slate-600 transition-colors"
    >
      <div className="flex items-start justify-between mb-2">
        <span className="font-mono text-xs text-cyan-400">
          {order.orderNumber || order.id.slice(0, 8).toUpperCase()}
        </span>
        {!isTerminal && <GripVertical className="w-3.5 h-3.5 text-slate-600 flex-shrink-0" />}
      </div>
      <div className="font-mono text-sm font-bold mb-1" style={{ color: '#00D4FF' }}>
        ₹{(order.amountTotal / 100000).toFixed(1)}L
      </div>
      {order.notes && (
        <div className="text-xs text-slate-500 line-clamp-2 leading-relaxed">{order.notes}</div>
      )}
      <div className="mt-2 font-mono text-xs text-slate-600">
        {new Date(order.createdAt).toLocaleDateString('en-IN')}
      </div>
      {isTerminal && (
        <div className="mt-1 text-xs text-slate-700 font-mono">⟳ terminal — no transitions</div>
      )}
    </div>
  )
}

function KanbanColumn({ column, orders }: { column: typeof COLUMNS[0]; orders: Order[] }) {
  const { isOver, setNodeRef } = useDroppable({ id: column.id })

  return (
    <div
      ref={setNodeRef}
      className="flex-1 min-w-[200px] rounded-xl p-3 transition-all duration-150"
      style={{
        background: isOver ? `${column.color}08` : 'var(--bg-card)',
        border: `1px solid ${isOver ? `${column.color}35` : 'var(--border-subtle)'}`,
        minHeight: '420px',
        boxShadow: isOver ? `0 0 0 1px ${column.color}20` : 'none',
      }}
    >
      <div className="flex items-center justify-between mb-3">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 rounded-full" style={{ background: column.color }} />
          <span className="font-mono text-xs font-medium text-slate-300">{column.label}</span>
        </div>
        <span
          className="font-mono text-xs px-1.5 py-0.5 rounded"
          style={{ background: `${column.color}18`, color: column.color }}
        >
          {orders.length}
        </span>
      </div>
      {orders.map((order) => (
        <KanbanCard key={order.id} order={order} />
      ))}
    </div>
  )
}

export default function OrdersPage() {
  const qc = useQueryClient()
  const [activeOrder, setActiveOrder] = useState<Order | null>(null)

  const { data: orders = [], isLoading } = useQuery({
    queryKey: ['orders'],
    queryFn: () => orderApi.getAll(),
    staleTime: 10_000,
    refetchInterval: 30_000, // Poll every 30s — orders change frequently
  })

  const updateMut = useMutation({
    mutationFn: ({ id, status, cancellationReason }: {
      id: string; status: OrderStatus; cancellationReason?: string
    }) => orderApi.updateStatus(id, { status, cancellationReason, changedBy: 'ui-kanban' }),
    onSuccess: (_, vars) => {
      qc.invalidateQueries({ queryKey: ['orders'] })
      toast.success(
        `Order → ${vars.status}\n↳ PostgreSQL updated · MongoDB audit log · RabbitMQ event`,
        { duration: 4000, icon: '✓' }
      )
    },
    onError: (e: Error) => toast.error(`Server rejected: ${e.message}`, { duration: 5000 }),
  })

  const sensors = useSensors(
    useSensor(PointerSensor, { activationConstraint: { distance: 8 } })
  )

  function handleDragStart(e: DragStartEvent) {
    const order = orders.find((o) => o.id === e.active.id)
    if (order) setActiveOrder(order)
  }

  function handleDragEnd(e: DragEndEvent) {
    setActiveOrder(null)
    const { active, over } = e
    if (!over) return

    const order = orders.find((o) => o.id === active.id)
    if (!order) return

    const newStatus = over.id as OrderStatus
    if (newStatus === order.status) return

    // State machine guard — mirrors Java OrderService.VALID_TRANSITIONS
    const allowed = VALID_TRANSITIONS[order.status]
    if (!allowed.includes(newStatus)) {
      toast.error(
        `Cannot move: ${order.status} → ${newStatus}\n` +
        `Allowed from ${order.status}: ${allowed.length ? allowed.join(', ') : 'none (terminal state)'}`,
        { duration: 5000, icon: '🚫' }
      )
      return
    }

    const cancellationReason =
      newStatus === 'CANCELLED'
        ? (window.prompt('Cancellation reason:') ?? 'Cancelled via UI')
        : undefined

    updateMut.mutate({ id: order.id, status: newStatus, cancellationReason })
  }

  const byStatus = (status: OrderStatus) => orders.filter((o) => o.status === status)

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-slate-100">Transaction Board</h1>
          <p className="text-xs font-mono text-slate-500 mt-0.5">
            Drag cards to update status · State machine guard · MongoDB audit · RabbitMQ events
          </p>
        </div>
        <div className="font-mono text-xs text-slate-500">
          {orders.length} total orders
        </div>
      </div>

      {/* State machine reference */}
      <div
        className="flex flex-wrap items-center gap-2 px-4 py-2.5 rounded-lg font-mono text-xs"
        style={{ background: 'var(--bg-card)', border: '1px solid var(--border-subtle)' }}
      >
        <span className="text-slate-500">State machine:</span>
        <span className="text-amber-400">PENDING</span>
        <span className="text-slate-600">→</span>
        <span className="text-cyan-400">PROCESSING</span>
        <span className="text-slate-600">→</span>
        <span className="text-emerald-400">COMPLETED</span>
        <span className="text-slate-600 mx-1">|</span>
        <span className="text-slate-400">PENDING/PROCESSING</span>
        <span className="text-slate-600">→</span>
        <span className="text-slate-400">CANCELLED</span>
        <span className="text-slate-600 mx-1">|</span>
        <span className="text-rose-400">COMPLETED/CANCELLED = terminal (no drag)</span>
      </div>

      {isLoading ? (
        <div className="text-center py-16 font-mono text-sm text-slate-500">
          Loading orders from PostgreSQL 16 orders_db...
        </div>
      ) : (
        <DndContext
          sensors={sensors}
          collisionDetection={closestCenter}
          onDragStart={handleDragStart}
          onDragEnd={handleDragEnd}
        >
          <div className="flex gap-4 overflow-x-auto pb-4">
            {COLUMNS.map((col) => (
              <KanbanColumn key={col.id} column={col} orders={byStatus(col.id)} />
            ))}
          </div>

          <DragOverlay>
            {activeOrder && (
              <div
                className="card-dark p-3.5 rotate-2 shadow-2xl opacity-90"
                style={{ width: '200px' }}
              >
                <div className="font-mono text-xs text-cyan-400 mb-1">
                  {activeOrder.orderNumber || activeOrder.id.slice(0, 8).toUpperCase()}
                </div>
                <div className="font-mono text-sm font-bold" style={{ color: '#00D4FF' }}>
                  ₹{(activeOrder.amountTotal / 100000).toFixed(1)}L
                </div>
              </div>
            )}
          </DragOverlay>
        </DndContext>
      )}

      <div className="font-mono text-xs text-slate-600 text-center">
        On status change: PostgreSQL updated → @Async MongoDB audit log → RabbitMQ order.status.changed
      </div>
    </div>
  )
}
