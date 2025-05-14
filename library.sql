-- =============================================
-- Library Management System Database Schema
-- Author: [DANIEL MUTUA]
-- =============================================


CREATE DATABASE library_management 

USE library_management;

-- =============================================
-- SECTION 1: SYSTEM CORE TABLES
-- =============================================

-- Stores application roles with hierarchical permissions
CREATE TABLE app_role (
    role_id INT AUTO_INCREMENT PRIMARY KEY,
    role_name VARCHAR(30) NOT NULL UNIQUE,
    role_description TEXT,
    is_system_role BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    updated_by INT
) ENGINE=InnoDB COMMENT 'System roles with hierarchical permissions';

-- Application users with authentication details
CREATE TABLE app_user (
    user_id INT AUTO_INCREMENT PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE COMMENT 'Unique login identifier',
    email VARCHAR(100) NOT NULL UNIQUE,
    email_verified_at TIMESTAMP NULL,
    password_hash VARCHAR(255) NOT NULL COMMENT 'BCrypt hashed password',
    password_reset_token VARCHAR(100),
    password_reset_expires TIMESTAMP NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    last_login_at TIMESTAMP NULL,
    last_login_ip VARCHAR(45),
    failed_login_attempts INT NOT NULL DEFAULT 0,
    account_locked_until TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_valid_email CHECK (email REGEXP '^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$')
) ENGINE=InnoDB COMMENT 'User authentication and basic profile';

-- User profile information (separate from auth)
CREATE TABLE user_profile (
    profile_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    avatar_url VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES app_user(user_id) ON DELETE CASCADE
) ENGINE=InnoDB COMMENT 'Extended user profile information';

-- =============================================
-- SECTION 2: LIBRARY CATALOG TABLES
-- =============================================

-- Book publishers information
CREATE TABLE publisher (
    publisher_id INT AUTO_INCREMENT PRIMARY KEY,
    publisher_name VARCHAR(100) NOT NULL UNIQUE,
    publisher_code VARCHAR(20) UNIQUE COMMENT 'Short publisher identifier',
    website_url VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB COMMENT 'Book publishers and imprints';

-- Book authors information
CREATE TABLE author (
    author_id INT AUTO_INCREMENT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    birth_date DATE,
    death_date DATE,
    biography TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT uc_author_name UNIQUE (first_name, last_name, birth_date)
) ENGINE=InnoDB COMMENT 'Book authors and contributors';

-- Book subject categories
CREATE TABLE subject_category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(50) NOT NULL UNIQUE,
    parent_category_id INT NULL,
    category_description TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_category_id) REFERENCES subject_category(category_id)
) ENGINE=InnoDB COMMENT 'Hierarchical subject classification';

-- Core book metadata
CREATE TABLE book (
    book_id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    subtitle VARCHAR(255),
    publisher_id INT NOT NULL,
    publication_date DATE,
    edition_number SMALLINT,
    page_count INT,
    summary TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (publisher_id) REFERENCES publisher(publisher_id),
    CONSTRAINT chk_page_count CHECK (page_count IS NULL OR page_count > 0)
) ENGINE=InnoDB COMMENT 'Core book metadata and descriptions';

-- Book identification numbers
CREATE TABLE book_identifier (
    identifier_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    id_type ENUM('ISBN-10', 'ISBN-13', 'OCLC', 'LCCN', 'OTHER') NOT NULL,
    id_value VARCHAR(20) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (book_id) REFERENCES book(book_id) ON DELETE CASCADE,
    CONSTRAINT uc_identifier UNIQUE (id_type, id_value)
) ENGINE=InnoDB COMMENT 'Standard book identifiers';

-- =============================================
-- SECTION 3: INVENTORY MANAGEMENT
-- =============================================

-- Physical book copies in inventory
CREATE TABLE book_copy (
    copy_id INT AUTO_INCREMENT PRIMARY KEY,
    book_id INT NOT NULL,
    barcode VARCHAR(50) NOT NULL UNIQUE,
    acquisition_date DATE NOT NULL,
    copy_status ENUM('AVAILABLE', 'CHECKED_OUT', 'LOST', 'DAMAGED', 'IN_REPAIR') NOT NULL DEFAULT 'AVAILABLE',
    current_location_id INT,
    notes TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (book_id) REFERENCES book(book_id)
   
) ENGINE=InnoDB COMMENT 'Physical copies of books in inventory';

-- =============================================
-- SECTION 4: CIRCULATION MANAGEMENT
-- =============================================

-- Loan policy definitions
CREATE TABLE loan_policy (
    policy_id INT AUTO_INCREMENT PRIMARY KEY,
    policy_name VARCHAR(50) NOT NULL UNIQUE,
    loan_period_days INT NOT NULL,
    renewal_count INT NOT NULL DEFAULT 0,
    daily_fine_amount DECIMAL(8,2) NOT NULL DEFAULT 0.25,
    applies_to_role_id INT,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (applies_to_role_id) REFERENCES app_role(role_id)
) ENGINE=InnoDB COMMENT 'Rules governing book loans';

-- Active book loans
CREATE TABLE book_loan (
    loan_id INT AUTO_INCREMENT PRIMARY KEY,
    copy_id INT NOT NULL,
    user_id INT NOT NULL,
    policy_id INT NOT NULL,
    loan_date DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    due_date DATETIME NOT NULL,
    return_date DATETIME NULL,
    renewed_count INT NOT NULL DEFAULT 0,
    loan_status ENUM('ACTIVE', 'RETURNED', 'OVERDUE', 'LOST') NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (copy_id) REFERENCES book_copy(copy_id),
    FOREIGN KEY (user_id) REFERENCES app_user(user_id),
    FOREIGN KEY (policy_id) REFERENCES loan_policy(policy_id),
    CONSTRAINT chk_loan_dates CHECK (due_date > loan_date AND (return_date IS NULL OR return_date >= loan_date))
) ENGINE=InnoDB COMMENT 'Active and historical book loans';

-- =============================================
-- SECTION 5: FINANCIAL TRANSACTIONS
-- =============================================

-- Fine records for overdue/lost items
CREATE TABLE fine (
    fine_id INT AUTO_INCREMENT PRIMARY KEY,
    loan_id INT NULL,
    user_id INT NOT NULL,
    fine_amount DECIMAL(8,2) NOT NULL,
    fine_reason ENUM('LATE_RETURN', 'DAMAGE', 'LOST') NOT NULL,
    fine_status ENUM('OUTSTANDING', 'PAID', 'WAIVED') NOT NULL DEFAULT 'OUTSTANDING',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (loan_id) REFERENCES book_loan(loan_id),
    FOREIGN KEY (user_id) REFERENCES app_user(user_id)
) ENGINE=InnoDB COMMENT 'Fines assessed to users';

-- =============================================
-- SECTION 6: SYSTEM AUDITING
-- =============================================

-- System event logging
CREATE TABLE audit_log (
    log_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NULL,
    action_type VARCHAR(50) NOT NULL,
    table_name VARCHAR(50) NOT NULL,
    record_id INT NOT NULL,
    old_values JSON,
    new_values JSON,
    ip_address VARCHAR(45),
    user_agent VARCHAR(255),
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_audit_user (user_id),
    INDEX idx_audit_table (table_name, record_id),
    INDEX idx_audit_timestamp (created_at)
) ENGINE=InnoDB COMMENT 'System audit trail for all changes';

-- =============================================
-- SECTION 7: INDEXES AND PERFORMANCE OPTIMIZATION
-- =============================================

-- Book search optimization
CREATE FULLTEXT INDEX idx_book_search ON book(title, subtitle, summary);

-- Loan performance indexes
CREATE INDEX idx_loan_user ON book_loan(user_id, loan_status);
CREATE INDEX idx_loan_dates ON book_loan(due_date, return_date);

-- Fine lookup optimization
CREATE INDEX idx_fine_user ON fine(user_id, fine_status);

-- =============================================
-- SECTION 8: INITIAL DATA LOAD
-- =============================================

-- Insert system roles
INSERT INTO app_role (role_name, role_description, is_system_role) VALUES
('ADMIN', 'System administrator with full privileges', TRUE),
('LIBRARIAN', 'Library staff with circulation privileges', TRUE),
('MEMBER', 'Regular library member', TRUE);

-- Insert default loan policies
INSERT INTO loan_policy (policy_name, loan_period_days, renewal_count, daily_fine_amount, applies_to_role_id) VALUES
('STANDARD', 21, 2, 0.25, NULL),
('STAFF', 28, 3, 0.10, 2);