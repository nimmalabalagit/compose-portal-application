import { apiClient } from './client'
import type { ApiResponse, User, CreateUserRequest } from './types'

export const userApi = {
  getAll: async (role?: string): Promise<User[]> => {
    const params = role ? { role } : {}
    const { data } = await apiClient.get<ApiResponse<User[]>>('/api/users', { params })
    return data.data
  },

  getById: async (id: string): Promise<User> => {
    const { data } = await apiClient.get<ApiResponse<User>>(`/api/users/${id}`)
    return data.data
  },

  create: async (body: CreateUserRequest): Promise<User> => {
    const { data } = await apiClient.post<ApiResponse<User>>('/api/users', body)
    return data.data
  },

  update: async (id: string, body: Partial<CreateUserRequest>): Promise<User> => {
    const { data } = await apiClient.put<ApiResponse<User>>(`/api/users/${id}`, body)
    return data.data
  },

  deactivate: async (id: string): Promise<void> => {
    await apiClient.patch(`/api/users/${id}/deactivate`)
  },

  // Returns the pod name from meta — shows which K8s pod served this request
  // In K8s with 3 replicas, refreshing shows different pod names → proves load balancing
  getPodInfo: async (): Promise<{ pod: string; service: string }> => {
    const { data } = await apiClient.get<ApiResponse<User[]>>('/api/users')
    const meta = (data as ApiResponse<User[]>).meta
    return { pod: meta?.pod ?? 'unknown', service: meta?.service ?? 'user-service' }
  },
}
