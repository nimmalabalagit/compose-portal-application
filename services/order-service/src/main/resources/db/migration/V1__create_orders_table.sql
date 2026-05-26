CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- WHY auto-generated order number:
-- ORD-20260520-00001 is human-readable. UUID is not.
-- The function + trigger generates this automatically on INSERT.

CREATE SEQUENCE IF NOT EXISTS order_seq START 1;

CREATE TABLE IF NOT EXISTS orders (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    order_number TEXT UNIQUE NOT NULL,

    buyer_user_id UUID NOT NULL,

    product_id UUID NOT NULL,

    status TEXT NOT NULL DEFAULT 'PENDING'
    CHECK (
        status IN (
            'PENDING',
            'PROCESSING',
            'COMPLETED',
            'CANCELLED'
        )
    ),

    amount_total NUMERIC(12,2) NOT NULL
    CHECK (amount_total >= 0),

    currency TEXT NOT NULL DEFAULT 'INR',

    notes TEXT,

    cancellation_reason TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    completed_at TIMESTAMPTZ
);

-- =====================================================
-- GENERATE ORDER NUMBER
-- ORD-YYYYMMDD-XXXXX
-- =====================================================

CREATE OR REPLACE FUNCTION generate_order_number()
RETURNS TRIGGER AS $$
BEGIN

    NEW.order_number =
        'ORD-' ||
        TO_CHAR(NOW(), 'YYYYMMDD') ||
        '-' ||
        LPAD(nextval('order_seq')::text, 5, '0');

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_set_number
    BEFORE INSERT ON orders
    FOR EACH ROW
    EXECUTE FUNCTION generate_order_number();

-- =====================================================
-- AUTO UPDATE updated_at COLUMN
-- =====================================================

CREATE OR REPLACE FUNCTION update_orders_updated_at()
RETURNS TRIGGER AS $$
BEGIN

    NEW.updated_at = NOW();

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER orders_updated_at
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE FUNCTION update_orders_updated_at();

-- =====================================================
-- INDEXES
-- =====================================================

CREATE INDEX IF NOT EXISTS idx_orders_buyer_user_id
ON orders(buyer_user_id);

CREATE INDEX IF NOT EXISTS idx_orders_status
ON orders(status);

CREATE INDEX IF NOT EXISTS idx_orders_product_id
ON orders(product_id);
