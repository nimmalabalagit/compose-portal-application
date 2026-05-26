INSERT INTO products (
    id,
    title,
    description,
    property_type,
    price_amount,
    location,
    bedrooms,
    bathrooms,
    area_sqft,
    status,
    tags
)
VALUES
(
    'b0000001-0000-0000-0000-000000000001',
    '3BHK Premium Apartment — Hitech City',
    'Floor-to-ceiling glass, EV charging, infinity pool. RERA approved.',
    'APARTMENT',
    8500000.00,
    'Hitech City, Hyderabad',
    3,
    2,
    1650.00,
    'AVAILABLE',
    '["gated","gym","pool","rera-approved"]'::jsonb
),

(
    'b0000001-0000-0000-0000-000000000002',
    '4BHK Villa — Jubilee Hills',
    'Private garden, home theatre, 3-car garage.',
    'VILLA',
    45000000.00,
    'Jubilee Hills, Hyderabad',
    4,
    4,
    4200.00,
    'AVAILABLE',
    '["private-garden","garage"]'::jsonb
)

ON CONFLICT (id) DO NOTHING;
