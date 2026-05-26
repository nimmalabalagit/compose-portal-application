CREATE EXTENSION IF NOT EXISTS "pgcrypto";

CREATE TABLE IF NOT EXISTS products (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    title TEXT NOT NULL,

    description TEXT,

    property_type TEXT NOT NULL
    CHECK (
        property_type IN (
            'APARTMENT',
            'VILLA',
            'COMMERCIAL',
            'LAND',
            'PLOT',
            'PENTHOUSE'
        )
    ),

    price_amount NUMERIC(12,2) NOT NULL
    CHECK (price_amount >= 0),

    price_currency TEXT NOT NULL DEFAULT 'INR',

    location TEXT NOT NULL,

    bedrooms INTEGER,

    bathrooms INTEGER,

    area_sqft NUMERIC(10,2),

    status TEXT NOT NULL DEFAULT 'AVAILABLE'
    CHECK (
        status IN (
            'AVAILABLE',
            'UNDER_OFFER',
            'SOLD',
            'WITHDRAWN'
        )
    ),

    listed_by_user_id UUID,

    stock_count INTEGER NOT NULL DEFAULT 1
    CHECK (stock_count >= 0),

    tags JSONB,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION update_products_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER products_updated_at
    BEFORE UPDATE ON products
    FOR EACH ROW
    EXECUTE FUNCTION update_products_updated_at();
