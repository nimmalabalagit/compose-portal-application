// Consistent envelope — matches what Spring Boot returns
// meta.pod tells you WHICH Kubernetes pod served this request
// Critical for debugging multi-replica deployments

export interface ApiMeta {
  timestamp: string;
  service: string;
  version: string;
  pod: string;           // Which K8s pod — the interview differentiator
  correlationId: string;
}

export interface ApiResponse<T> {
  data: T;
  meta: ApiMeta;
}

// User types
export type UserRole = 'BUYER' | 'SELLER' | 'ADMIN';

export interface User {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  role: UserRole;
  phoneNumber?: string;
  active: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface CreateUserRequest {
  firstName: string;
  lastName: string;
  email: string;
  role: UserRole;
  phoneNumber?: string;
  passwordHash: string;  // BCrypt — set to default on create
}

// Product types
export type PropertyType = 'APARTMENT' | 'VILLA' | 'COMMERCIAL' | 'LAND' | 'PLOT' | 'PENTHOUSE';
export type ProductStatus = 'AVAILABLE' | 'UNDER_OFFER' | 'SOLD' | 'WITHDRAWN';

export interface Product {
  id: string;
  title: string;
  description?: string;
  propertyType: PropertyType;
  priceAmount: number;
  priceCurrency: string;
  location: string;
  bedrooms?: number;
  bathrooms?: number;
  areaSqft?: number;
  status: ProductStatus;
  stockCount: number;
  tags?: string[];
  createdAt: string;
  updatedAt: string;
}

export interface CreateProductRequest {
  title: string;
  description?: string;
  propertyType: PropertyType;
  priceAmount: number;
  priceCurrency?: string;
  location: string;
  bedrooms?: number;
  bathrooms?: number;
  areaSqft?: number;
  status?: ProductStatus;
  stockCount?: number;
}

// Order types
export type OrderStatus = 'PENDING' | 'PROCESSING' | 'COMPLETED' | 'CANCELLED';

export interface Order {
  id: string;
  orderNumber: string;
  buyerUserId: string;
  productId: string;
  status: OrderStatus;
  amountTotal: number;
  currency: string;
  notes?: string;
  cancellationReason?: string;
  createdAt: string;
  updatedAt: string;
  completedAt?: string;
}

export interface CreateOrderRequest {
  buyerUserId: string;
  productId: string;
  amountTotal: number;
  currency?: string;
  notes?: string;
}

export interface UpdateOrderStatusRequest {
  status: OrderStatus;
  cancellationReason?: string;
  changedBy?: string;
}