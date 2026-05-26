INSERT INTO users (id, first_name, last_name, email, password_hash, role, phone_number) VALUES
('a0000001-0000-0000-0000-000000000001','Arjun','Reddy',
 'arjun.reddy@estateflowai.co',
 '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8ioctjEEFfNPNhVoWQxSFw0yNbOie',
 'BUYER','+91-9876543201'),

('a0000001-0000-0000-0000-000000000002','Priya','Sharma',
 'priya.sharma@estateflowai.co',
 '$2a$10$N.zmdr9k7uOCQb376NoUnuTJ8ioctjEEFfNPNhVoWQxSFw0yNbOie',
 'SELLER','+91-9876543202')
ON CONFLICT (email) DO NOTHING;
