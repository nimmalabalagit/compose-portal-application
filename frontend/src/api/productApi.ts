import { apiClient } from './client'
import type { ApiResponse, Product, CreateProductRequest } from './types'

export const productApi = {
  getAll: async (): Promise<Product[]> => {
    const { data } = await apiClient.get<ApiResponse<Product[]>>('/api/products')
    return data.data
  },

  getById: async (id: string): Promise<Product> => {
    const { data } = await apiClient.get<ApiResponse<Product>>(`/api/products/${id}`)
    return data.data
  },

  create: async (body: CreateProductRequest): Promise<Product> => {
    const { data } = await apiClient.post<ApiResponse<Product>>('/api/products', body)
    return data.data
  },

  update: async (id: string, body: Partial<CreateProductRequest>): Promise<Product> => {
    const { data } = await apiClient.put<ApiResponse<Product>>(`/api/products/${id}`, body)
    return data.data
  },
}
