import { apiClient } from './client';
import type { ApiResponse, Product } from './types';

export const productApi = {
  getAll: async (): Promise<Product[]> => {
    const { data } = await apiClient.get<ApiResponse<Product[]>>('/api/products');
    return data.data;
  },

  getById: async (id: string): Promise<Product> => {
    const { data } = await apiClient.get<ApiResponse<Product>>(`/api/products/${id}`);
    return data.data;
  },
};
