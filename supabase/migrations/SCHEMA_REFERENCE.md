# Aqura Database Schema Reference

## Overview
Total Tables: **88**
Database: Supabase PostgreSQL

## Migration Files Created
All table schemas have been created as individual migration files in the `supabase/migrations` folder for easy reference and management.

---

## Core Business Tables

### 001. approval_permissions
User approval permissions for requisitions and bills with amount limits

### 022. offers
Promotional offers with types, dates, and usage limits

### 023. orders
Customer orders with status tracking and delivery information

### 024. order_items
Line items within orders with pricing and discounts

### 025. products
Product catalog with pricing, stock, and variations

---

## User & Access Control

### 026. users
System users with authentication and access levels

### 006. button_permissions
User permissions for sidebar button access

### 042. interface_permissions
User access control to application interfaces

### 043. non_approved_payment_scheduler
Payments awaiting manager approval

---

## HR & Employees

### 027. hr_employees
Employee records with hiring information

### 031. hr_departments
Department definitions

### 032. hr_employee_contacts
Contact information for employees

### 033. hr_employee_documents
Employee documents (passports, IDs, health cards)

### 034. hr_levels
Employee position level classifications

### 037. hr_position_assignments
Current position assignments

### 038. hr_position_reporting_template
Reporting structure definitions

### 039. hr_positions
Job position definitions

### 040. hr_salary_components
Salary component definitions

### 041. hr_salary_wages
Employee wage records

### 019. employee_fine_payments
Fine payment records

---

## Orders & Fulfillment

### 005. button_main_sections
Main sidebar button section groupings

### 007. button_sub_sections
Sub-sections under main sections

### 074. sidebar_buttons
Navigation buttons in the sidebar

### 053. order_audit_logs
Audit trail of order modifications

---

## Inventory & Receiving

### 031. receiving_records
Purchase order receiving records

### 068. receiving_task_templates
Templates for receiving task workflows

### 069. receiving_tasks
Individual receiving task assignments

### 087. vendors
Vendor/supplier information

### 086. vendor_payment_schedule
Payment schedules for vendors

---

## Offers & Promotions

### 048. offer_bundles
Bundle discount definitions

### 049. offer_cart_tiers
Cart-based tiered discounts

### 050. offer_products
Products participating in offers

### 051. offer_usage_logs
Log of offer usage and performance

### 003. bogo_offer_rules
Buy One Get One offer rules

### 021. flyer_offer_products
Products in promotional flyers

### 029. flyer_offers
Flyer promotion definitions

### 030. flyer_templates
Email flyer templates

---

## Coupons & Promotions

### 008. coupon_campaigns
Coupon campaign definitions

### 009. coupon_claims
Customer coupon redemptions

### 010. coupon_eligible_customers
Eligible customers for coupons

### 011. coupon_products
Products available in coupons

---

## Customers & Access

### 015. customers
Customer profiles with location data

### 012. customer_access_code_history
History of customer access code changes

### 013. customer_app_media
Media content for customer app

### 014. customer_recovery_requests
Account recovery request handling

---

## Notifications & Communication

### 047. notifications
System notification messages

### 044. notification_attachments
Files attached to notifications

### 045. notification_read_states
Read status tracking for notifications

### 046. notification_recipients
Notification recipient tracking

---

## Tasks & Assignments

### 028. tasks
Task definitions

### 075. task_assignments
Task assignments to users

### 076. task_completions
Task completion records

### 077. task_images
Images/files attached to tasks

### 078. task_reminder_logs
Notification reminder logs

### 061. quick_task_assignments
Quick task assignments

### 062. quick_task_comments
Comments on quick tasks

### 063. quick_task_completions
Quick task completion records

### 064. quick_task_files
Files uploaded for quick tasks

### 065. quick_task_user_preferences
User preferences for quick tasks

### 066. quick_tasks
Quick task definitions

### 070. recurring_assignment_schedules
Recurring task schedules

### 071. recurring_schedule_check_log
Log of schedule check executions

---

## Expense Management

### 024. expense_parent_categories
Top-level expense categories

### 027. expense_sub_categories
Sub-categories under parent categories

### 030. expense_requisitions
Employee expense requests

### 026. expense_scheduler
Scheduled expense payments

---

## Configuration & Settings

### 004. branches
Business branch locations with hours

### 017. delivery_fee_tiers
Delivery cost tiers based on order

### 018. delivery_service_settings
Global delivery configuration

### 002. biometric_connections
Biometric device connections

### 022. erp_connections
ERP system connection details

### 023. erp_daily_sales
Daily sales summaries from ERP

### 058. product_categories
Product category classifications

### 059. product_units
Product measurement units

### 056. privilege_cards_branch
Branch-specific privilege cards

### 057. privilege_cards_master
Master privilege card records

---

## Product Management

### 016. deleted_bundle_offers
Archive of deleted bundle offers

### 085. variation_audit_log
Audit log for product variations

### 073. shelf_paper_templates
Shelf label print templates

---

## User Sessions & Security

### 081. user_device_sessions
Device session tracking

### 082. user_password_history
Password change history

### 083. user_sessions
User login sessions

### 080. user_audit_logs
User action audit trail

---

## Other Tables

### 031. requesters
External requester profiles

### 072. requesters
External requester information (requesters)

---

## Database Statistics

**Total Tables: 88**
- Core Business: 5 tables
- User & Access: 4 tables
- HR & Employees: 14 tables
- Orders & Fulfillment: 4 tables
- Inventory: 5 tables
- Offers & Promotions: 7 tables
- Coupons: 4 tables
- Customers: 4 tables
- Notifications: 4 tables
- Tasks: 10 tables
- Expenses: 4 tables
- Configuration: 11 tables
- Security & Audit: 4 tables
- Other: 4 tables

---

## Key Relationships

### Foreign Key Relationships:
- **orders** → customers
- **order_items** → orders, products, offers
- **offers** → offer_products, offer_bundles, offer_cart_tiers
- **task_assignments** → tasks, users
- **expense_requisitions** → branches, users
- **receiving_records** → vendors, branches, users
- **notifications** → notification_recipients, notification_attachments

---

## Migration File Organization

Migration files are numbered sequentially (001-031+) for reference:
- **000** - TABLE_INDEX.sql (this file)
- **001-020** - Approvals, connections, offers
- **021-030** - Flyers, orders, users, employees, expenses
- **031+** - Receiving, vendors, and specialized tables

Each file contains a complete schema definition with all columns, data types, and defaults.
