-- References user UUIDs from user-service V2 seed
-- and product UUIDs from product-service V2 seed

INSERT INTO orders (
    buyer_user_id,
    product_id,
    status,
    amount_total,
    notes
)
VALUES

(
    'a0000001-0000-0000-0000-000000000001',
    'b0000001-0000-0000-0000-000000000001',
    'COMPLETED',
    8500000.00,
    'Hitech City apartment — paid in full'
),

(
    'a0000001-0000-0000-0000-000000000002',
    'b0000001-0000-0000-0000-000000000006',
    'PROCESSING',
    9200000.00,
    'Whitefield apartment — loan disbursement pending'
),

(
    'a0000001-0000-0000-0000-000000000004',
    'b0000001-0000-0000-0000-000000000011',
    'PENDING',
    18500000.00,
    'Powai apartment — documentation in progress'
),

(
    'a0000001-0000-0000-0000-000000000006',
    'b0000001-0000-0000-0000-000000000005',
    'CANCELLED',
    2800000.00,
    'Plot — buyer withdrew after survey'
),

(
    'a0000001-0000-0000-0000-000000000008',
    'b0000001-0000-0000-0000-000000000012',
    'PENDING',
    120000000.00,
    'Worli sea-view — negotiating final terms'
),

(
    'a0000001-0000-0000-0000-000000000003',
    'b0000001-0000-0000-0000-000000000007',
    'PROCESSING',
    85000000.00,
    'Koramangala penthouse — stamp duty paid'
),

(
    'a0000001-0000-0000-0000-000000000005',
    'b0000001-0000-0000-0000-000000000009',
    'COMPLETED',
    18000000.00,
    'Indiranagar commercial — possession received'
),

(
    'a0000001-0000-0000-0000-000000000007',
    'b0000001-0000-0000-0000-000000000015',
    'PENDING',
    6200000.00,
    'Andheri studio — first-time buyer'
),

(
    'a0000001-0000-0000-0000-000000000009',
    'b0000001-0000-0000-0000-000000000004',
    'PROCESSING',
    25000000.00,
    'HITEC commercial — fit-out in progress'
),

(
    'a0000001-0000-0000-0000-000000000010',
    'b0000001-0000-0000-0000-000000000002',
    'PENDING',
    45000000.00,
    'Jubilee Hills villa — soil test report awaited'
)

ON CONFLICT DO NOTHING;
