-- Event Tracking System Database Schema

-- Course leaders table
CREATE TABLE course_leaders (
    leader_id VARCHAR2(64) PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    email VARCHAR2(255) UNIQUE NOT NULL,
    department VARCHAR2(50) NOT NULL
);

-- Visitors table with time-based partitioning
CREATE TABLE visitors (
    visitor_id VARCHAR2(64) PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    email VARCHAR2(255) UNIQUE NOT NULL,
    phone_number VARCHAR2(64) NOT NULL,
    registered_at TIMESTAMP DEFAULT SYSTIMESTAMP
) PARTITION BY RANGE (registered_at) (
    PARTITION p_old VALUES LESS THAN (TO_DATE('2023-01-01', 'YYYY-MM-DD')),
    PARTITION p_recent VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
    PARTITION p_current VALUES LESS THAN (MAXVALUE)
);

-- Events table with time-based partitioning
CREATE TABLE events (
    event_id VARCHAR2(64) PRIMARY KEY,
    event_name VARCHAR2(100) NOT NULL,
    location VARCHAR2(100),
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    description VARCHAR2(500),
    CONSTRAINT chk_event_times CHECK (end_time > start_time)
) PARTITION BY RANGE (start_time) (
    PARTITION p_past VALUES LESS THAN (TO_DATE('2023-01-01', 'YYYY-MM-DD')),
    PARTITION p_recent VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
    PARTITION p_upcoming VALUES LESS THAN (MAXVALUE)
);

-- QR codes table
CREATE TABLE qr_codes (
    qr_id VARCHAR2(64) PRIMARY KEY,
    location VARCHAR2(100),
    associated_event_id VARCHAR2(64) NOT NULL,
    scan_account VARCHAR2(50),
    CONSTRAINT fk_qr_event FOREIGN KEY (associated_event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

-- Visitor QR scans junction table
CREATE TABLE visitor_qr_scans (
    visitor_id VARCHAR2(64),
    qr_id VARCHAR2(64),
    scanned_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    PRIMARY KEY (visitor_id, qr_id),
    CONSTRAINT fk_vqs_visitor FOREIGN KEY (visitor_id) REFERENCES visitors(visitor_id) ON DELETE CASCADE,
    CONSTRAINT fk_vqs_qr FOREIGN KEY (qr_id) REFERENCES qr_codes(qr_id) ON DELETE CASCADE
);

-- Detailed scans table with time-based partitioning
CREATE TABLE scans (
    scan_id VARCHAR2(64) PRIMARY KEY,
    visitor_id VARCHAR2(64),
    qr_id VARCHAR2(64),
    leader_id VARCHAR2(64),
    scanned_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_scan_visitor FOREIGN KEY (visitor_id) REFERENCES visitors(visitor_id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_qr FOREIGN KEY (qr_id) REFERENCES qr_codes(qr_id) ON DELETE CASCADE,
    CONSTRAINT fk_scan_leader FOREIGN KEY (leader_id) REFERENCES course_leaders(leader_id) ON DELETE CASCADE
) PARTITION BY RANGE (scanned_at) (
    PARTITION p_old VALUES LESS THAN (TO_DATE('2023-01-01', 'YYYY-MM-DD')),
    PARTITION p_recent VALUES LESS THAN (TO_DATE('2024-01-01', 'YYYY-MM-DD')),
    PARTITION p_current VALUES LESS THAN (MAXVALUE)
);

-- Parking information table
CREATE TABLE parking_information (
    parking_id VARCHAR2(64) PRIMARY KEY,
    visitor_id VARCHAR2(64) UNIQUE,
    location VARCHAR2(100),
    availability VARCHAR2(20),
    updated_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    event_id VARCHAR2(64),
    CONSTRAINT fk_parking_visitor FOREIGN KEY (visitor_id) REFERENCES visitors(visitor_id) ON DELETE CASCADE,
    CONSTRAINT fk_parking_event FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE SET NULL
);

-- Visitor events junction table
CREATE TABLE visitor_events (
    visitor_id VARCHAR2(64),
    event_id VARCHAR2(64),
    registered_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    attended NUMBER(1) DEFAULT 0,
    PRIMARY KEY (visitor_id, event_id),
    CONSTRAINT fk_ve_visitor FOREIGN KEY (visitor_id) REFERENCES visitors(visitor_id) ON DELETE CASCADE,
    CONSTRAINT fk_ve_event FOREIGN KEY (event_id) REFERENCES events(event_id) ON DELETE CASCADE
);

-- Notifications table
CREATE TABLE notifications (
    notification_id VARCHAR2(64) PRIMARY KEY,
    visitor_id VARCHAR2(64),
    message VARCHAR2(500),
    sent_at TIMESTAMP DEFAULT SYSTIMESTAMP,
    CONSTRAINT fk_notification_visitor FOREIGN KEY (visitor_id) REFERENCES visitors(visitor_id) ON DELETE CASCADE
);

-- User roles table
CREATE TABLE roles (
    role_id VARCHAR2(64) PRIMARY KEY,
    role_name VARCHAR2(50) UNIQUE NOT NULL
);

-- Users table
CREATE TABLE users (
    user_id VARCHAR2(64) PRIMARY KEY,
    email VARCHAR2(255) UNIQUE NOT NULL,
    password_hash VARCHAR2(255) NOT NULL,
    role_id VARCHAR2(64),
    CONSTRAINT fk_user_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE SET NULL
);

-- Permissions table
CREATE TABLE permissions (
    permission_id VARCHAR2(64) PRIMARY KEY,
    permission_name VARCHAR2(100) UNIQUE NOT NULL
);

-- Role permissions junction table
CREATE TABLE role_permissions (
    role_id VARCHAR2(64),
    permission_id VARCHAR2(64),
    PRIMARY KEY (role_id, permission_id),
    CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles(role_id) ON DELETE CASCADE,
    CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions(permission_id) ON DELETE CASCADE
);

-- Materialized view for visitor check-ins
CREATE MATERIALIZED VIEW mv_visitor_checkins AS
    SELECT v.name, e.event_name, s.scanned_at
    FROM scans s
    JOIN visitors v ON s.visitor_id = v.visitor_id
    JOIN qr_codes q ON s.qr_id = q.qr_id
    JOIN events e ON q.associated_event_id = e.event_id;