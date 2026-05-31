import { apiClient } from './client'
import type { ApiResponse, Order, CreateOrderRequest, UpdateOrderStatusRequest } from './types'

export const orderApi = {
  getAll: async (status?: string): Promise<Order[]> => {
    const params = status ? { status } : {}
    const { data } = await apiClient.get<ApiResponse<Order[]>>('/api/orders', { params })
    return data.data
  },

  getById: async (id: string): Promise<Order> => {
    const { data } = await apiClient.get<ApiResponse<Order>>(`/api/orders/${id}`)
    return data.data
  },

  create: async (body: CreateOrderRequest): Promise<Order> => {
    const { data } = await apiClient.post<ApiResponse<Order>>('/api/orders', body)
    return data.data
  },

  updateStatus: async (id: string, body: UpdateOrderStatusRequest): Promise<Order> => {
    const { data } = await apiClient.patch<ApiResponse<Order>>(
      `/api/orders/${id}/status`,
      body
    )
    return data.data
  },
}
