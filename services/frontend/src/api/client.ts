import axios, { type AxiosInstance, type AxiosError } from 'axios'
import toast from 'react-hot-toast'

// WHY correlation ID on every request:
// Gateway injects X-Correlation-ID if missing, then propagates to all downstream services.
// In Grafana Loki: filter {correlationId="abc-123"} shows the full chain across
// gateway → user-service → product-service → order-service in one view.

function generateCorrelationId(): string {
  return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`
}

export function createApiClient(baseURL: string): AxiosInstance {
  const client = axios.create({
    baseURL,
    timeout: 10_000,
    headers: { 'Content-Type': 'application/json' },
  })

  // Request interceptor: inject correlation ID
  client.interceptors.request.use((config) => {
    config.headers['X-Correlation-ID'] = generateCorrelationId()
    return config
  })

  // Response interceptor: surface errors as toasts
  client.interceptors.response.use(
    (response) => response,
    (error: AxiosError) => {
      if (error.response?.status === 503) {
        toast.error('Service unavailable — circuit breaker OPEN (retries in 30s)', {
          duration: 5000,
          icon: '⚡',
        })
      } else if (error.response?.status === 400 || error.response?.status === 422) {
        const data = error.response.data as Record<string, unknown>
        const msg = (data?.error as Record<string, string>)?.message || 'Validation failed'
        toast.error(msg, { duration: 4000 })
      } else if (error.code === 'ECONNREFUSED' || error.code === 'ERR_NETWORK') {
        toast.error('Cannot reach API — check service health', { duration: 6000, icon: '🔌' })
      }
      return Promise.reject(error)
    }
  )

  return client
}

// All API calls go through gateway-service at :8080
// Gateway routes: /api/users/* → user-service:8081
//                 /api/products/* → product-service:8082
//                 /api/orders/* → order-service:8083
const GATEWAY_URL = (import.meta.env as Record<string, string>).VITE_GATEWAY_URL ?? 'http://localhost:8080'
export const apiClient = createApiClient(GATEWAY_URL)
