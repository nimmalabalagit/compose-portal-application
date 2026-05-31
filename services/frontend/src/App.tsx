import { BrowserRouter, Routes, Route } from 'react-router-dom'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { Toaster } from 'react-hot-toast'
import Layout from './components/Layout'
import Dashboard from './pages/Dashboard'
import UsersPage from './pages/Users'
import ProductsPage from './pages/Products'
import OrdersPage from './pages/Orders'
import InfrastructurePage from './pages/Infrastructure'

// WHY staleTime 30s:
// Without staleTime, React Query refetches on every component mount → noisy API traffic.
// With staleTime:30s, cached data stays "fresh" for 30s matching Redis TTL strategy.
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      staleTime: 30_000,
      retry: 1,
      refetchOnWindowFocus: false,
    },
  },
})

export default function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <BrowserRouter>
        <Routes>
          <Route element={<Layout />}>
            <Route index                element={<Dashboard />} />
            <Route path="users"         element={<UsersPage />} />
            <Route path="products"      element={<ProductsPage />} />
            <Route path="orders"        element={<OrdersPage />} />
            <Route path="infrastructure" element={<InfrastructurePage />} />
          </Route>
        </Routes>
      </BrowserRouter>

      <Toaster
        position="top-right"
        toastOptions={{
          style: {
            background: '#0F1629',
            border: '1px solid #243047',
            color: '#E2E8F0',
            fontFamily: 'JetBrains Mono',
            fontSize: '12px',
            maxWidth: '420px',
          },
          success: { iconTheme: { primary: '#10B981', secondary: '#0F1629' } },
          error:   { iconTheme: { primary: '#F43F5E', secondary: '#0F1629' } },
        }}
      />
    </QueryClientProvider>
  )
}
