export type UserRole = 'ADMIN' | 'AGENT' | 'BUYER' | 'SELLER' | 'MANAGER' | 'SUPPORT';
export type OrderStatus = 'PENDING' | 'PROCESSING' | 'SHIPPED' | 'DELIVERED' | 'CANCELLED' | 'COMPLETED';
export type PropertyType = 'APARTMENT' | 'VILLA' | 'PLOT' | 'COMMERCIAL' | 'PENTHOUSE' | 'STUDIO';
export type ProductStatus = 'AVAILABLE' | 'SOLD' | 'RESERVED' | 'PENDING_APPROVAL';

export interface ApiResponse<T> {
  data: T;
  meta: {
    service: string;
    pod: string;
    timestamp: string;
    version: string;
    correlationId: string;
  };
}

export interface User {
  id: string;
  firstName: string;
  lastName: string;
  email: string;
  role: UserRole;
  phoneNumber: string;
  active: boolean;
  costCenter: string;
  environment: string;
  createdAt: string;
  updatedAt: string;
}

export interface CreateUserRequest {
  firstName: string;
  lastName: string;
  email: string;
  role: UserRole;
  phoneNumber: string;
  passwordHash: string;
}

export interface Product {
  id: string;
  title: string;
  description: string;
  propertyType: PropertyType;
  priceAmount: number;
  priceCurrency: string;
  location: string;
  bedrooms: number;
  bathrooms: number;
  areaSqft: number;
  status: ProductStatus;
  stockCount: number;
  tags: string;
  createdAt: string;
  updatedAt: string;
}

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
  currency: string;
  notes?: string;
}

export interface UpdateOrderStatusRequest {
  status: OrderStatus;
  cancellationReason?: string;
  changedBy?: string;
}
