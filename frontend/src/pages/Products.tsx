import { useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Package, MapPin, Bed, Bath, Maximize2 } from 'lucide-react'
import { productApi } from '../api/productApi'
import type { PropertyType, ProductStatus } from '../api/types'

const PROPERTY_TYPES: PropertyType[] = ['APARTMENT', 'VILLA', 'COMMERCIAL', 'LAND', 'PLOT', 'PENTHOUSE']
const STATUSES: ProductStatus[] = ['AVAILABLE', 'UNDER_OFFER', 'SOLD', 'WITHDRAWN']

const STATUS_COLORS: Record<ProductStatus, string> = {
  AVAILABLE:   'status-running',
  UNDER_OFFER: 'status-pending',
  SOLD:        'status-completed',
  WITHDRAWN:   'status-cancelled',
}

const TYPE_EMOJI: Record<PropertyType, string> = {
  APARTMENT:  '🏢',
  VILLA:      '🏡',
  COMMERCIAL: '🏬',
  LAND:       '🌱',
  PLOT:       '📐',
  PENTHOUSE:  '🏙️',
}

function formatPrice(amount: number) {
  if (amount >= 1_00_00_000) return `₹${(amount / 1_00_00_000).toFixed(1)}Cr`
  if (amount >= 1_00_000)    return `₹${(amount / 1_00_000).toFixed(1)}L`
  return `₹${amount.toLocaleString('en-IN')}`
}

export default function ProductsPage() {
  const [typeFilter, setTypeFilter] = useState<PropertyType | ''>('')
  const [statusFilter, setStatus]   = useState<ProductStatus | ''>('')
  const [cacheHit, setCacheHit]     = useState(false)
  const [fetchCount, setFetchCount] = useState(0)

  const { data: products = [], isLoading } = useQuery({
    queryKey: ['products'],
    queryFn: async () => {
      const startMs = Date.now()
      const result = await productApi.getAll()
      const elapsed = Date.now() - startMs
      // < 5ms response time indicates Redis cache hit (vs ~15ms PostgreSQL)
      setCacheHit(elapsed < 5)
      setFetchCount((c) => c + 1)
      return result
    },
    staleTime: 5 * 60_000, // 5 min — matches Redis TTL
  })

  const filtered = products.filter((p) => {
    if (typeFilter   && p.propertyType !== typeFilter) return false
    if (statusFilter && p.status       !== statusFilter) return false
    return true
  })

  return (
    <div className="space-y-5">

      {/* Header */}
      <div className="flex items-center justify-between">
        <div>
          <h1 className="font-display text-2xl font-bold text-slate-100">Property Listings</h1>
          <p className="text-xs font-mono text-slate-500 mt-0.5">
            PostgreSQL 16 products_db · NUMERIC(12,2) pricing · Redis 5min cache
          </p>
        </div>
        {/* Redis cache status badge */}
        <div
          className="flex items-center gap-2 px-3 py-2 rounded-lg font-mono text-xs"
          style={{
            background: cacheHit && fetchCount > 1
              ? 'rgba(16,185,129,0.08)' : 'rgba(0,212,255,0.06)',
            border: `1px solid ${cacheHit && fetchCount > 1 ? 'rgba(16,185,129,0.25)' : 'rgba(0,212,255,0.15)'}`,
          }}
        >
          <div
            className="w-1.5 h-1.5 rounded-full"
            style={{ background: cacheHit && fetchCount > 1 ? '#10B981' : '#00D4FF' }}
          />
          <span style={{ color: cacheHit && fetchCount > 1 ? '#10B981' : '#00D4FF' }}>
            {cacheHit && fetchCount > 1 ? 'Redis HIT (~0.3ms)' : 'PostgreSQL (~15ms)'}
          </span>
        </div>
      </div>

      {/* Filters */}
      <div className="space-y-2">
        <div className="flex flex-wrap gap-1.5">
          <button
            onClick={() => setTypeFilter('')}
            className="px-3 py-1.5 text-xs font-mono rounded-lg transition-colors"
            style={{
              background: typeFilter === '' ? 'rgba(0,212,255,0.1)' : 'var(--bg-card)',
              border: `1px solid ${typeFilter === '' ? 'rgba(0,212,255,0.3)' : 'var(--border-subtle)'}`,
              color: typeFilter === '' ? '#00D4FF' : '#8B9DBF',
            }}
          >
            ALL TYPES
          </button>
          {PROPERTY_TYPES.map((t) => (
            <button
              key={t}
              onClick={() => setTypeFilter(t)}
              className="px-3 py-1.5 text-xs font-mono rounded-lg transition-colors"
              style={{
                background: typeFilter === t ? 'rgba(0,212,255,0.1)' : 'var(--bg-card)',
                border: `1px solid ${typeFilter === t ? 'rgba(0,212,255,0.3)' : 'var(--border-subtle)'}`,
                color: typeFilter === t ? '#00D4FF' : '#8B9DBF',
              }}
            >
              {TYPE_EMOJI[t]} {t}
            </button>
          ))}
        </div>
        <div className="flex flex-wrap gap-1.5">
          <button
            onClick={() => setStatus('')}
            className="px-3 py-1.5 text-xs font-mono rounded-lg transition-colors"
            style={{
              background: statusFilter === '' ? 'rgba(0,212,255,0.1)' : 'var(--bg-card)',
              border: `1px solid ${statusFilter === '' ? 'rgba(0,212,255,0.3)' : 'var(--border-subtle)'}`,
              color: statusFilter === '' ? '#00D4FF' : '#8B9DBF',
            }}
          >
            ALL STATUS
          </button>
          {STATUSES.map((s) => (
            <button
              key={s}
              onClick={() => setStatus(s)}
              className="px-3 py-1.5 text-xs font-mono rounded-lg transition-colors"
              style={{
                background: statusFilter === s ? 'rgba(0,212,255,0.1)' : 'var(--bg-card)',
                border: `1px solid ${statusFilter === s ? 'rgba(0,212,255,0.3)' : 'var(--border-subtle)'}`,
                color: statusFilter === s ? '#00D4FF' : '#8B9DBF',
              }}
            >
              {s}
            </button>
          ))}
        </div>
      </div>

      {/* Cards grid */}
      {isLoading ? (
        <div className="text-center py-16 font-mono text-sm text-slate-500">
          Fetching from PostgreSQL 16 products_db...
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4">
          {filtered.map((product) => (
            <div key={product.id} className="card-dark p-5 hover:border-slate-600 transition-colors">
              <div className="flex items-start justify-between mb-3">
                <div className="flex items-center gap-2">
                  <span className="text-xl">{TYPE_EMOJI[product.propertyType as PropertyType]}</span>
                  <span
                    className="font-mono text-xs px-1.5 py-0.5 rounded"
                    style={{ background: 'rgba(0,212,255,0.08)', color: '#00D4FF', fontSize: '10px' }}
                  >
                    {product.propertyType}
                  </span>
                </div>
                <span className={`text-xs px-2 py-0.5 rounded-full font-mono ${STATUS_COLORS[product.status as ProductStatus]}`}>
                  {product.status}
                </span>
              </div>

              <h3 className="font-medium text-slate-200 text-sm mb-1 line-clamp-2 leading-snug">
                {product.title}
              </h3>

              {product.description && (
                <p className="text-xs text-slate-500 mb-3 line-clamp-2">{product.description}</p>
              )}

              {/* Price — WHY font-mono: NUMERIC(12,2) exact decimal, monospace aligns digits */}
              <div className="metric-number text-xl font-bold mb-3">
                {formatPrice(product.priceAmount)}
                <span className="text-xs font-mono text-slate-500 ml-1 font-normal">{product.priceCurrency}</span>
              </div>

              <div className="flex items-center gap-1 text-slate-500 text-xs font-mono mb-3">
                <MapPin className="w-3 h-3" />
                <span className="truncate">{product.location}</span>
              </div>

              {/* Property details */}
              {(product.bedrooms || product.bathrooms || product.areaSqft) && (
                <div className="flex items-center gap-3 text-xs font-mono text-slate-500">
                  {product.bedrooms && (
                    <span className="flex items-center gap-1">
                      <Bed className="w-3 h-3" /> {product.bedrooms}BHK
                    </span>
                  )}
                  {product.bathrooms && (
                    <span className="flex items-center gap-1">
                      <Bath className="w-3 h-3" /> {product.bathrooms}
                    </span>
                  )}
                  {product.areaSqft && (
                    <span className="flex items-center gap-1">
                      <Maximize2 className="w-3 h-3" /> {product.areaSqft.toLocaleString()}sqft
                    </span>
                  )}
                </div>
              )}
            </div>
          ))}
        </div>
      )}

      <div className="font-mono text-xs text-slate-600 text-center">
        {filtered.length} of {products.length} listings · staleTime=5min matches Redis TTL
      </div>
    </div>
  )
}
