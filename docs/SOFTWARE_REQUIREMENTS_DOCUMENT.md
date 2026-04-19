# Software Requirements Document (SRD)
## Al-Mohaffez - Quran Learning Platform

**Document Version:** 1.0  
**Date:** April 19, 2026  
**Project:** Mohaffez Finder App  
**Platform:** Flutter (Mobile - Android/iOS/Web)  
**Backend:** Firebase (Firestore, Auth, Storage, Cloud Functions)  

---

# Table of Contents

1. [Introduction](#1-introduction)
2. [System Overview](#2-system-overview)
3. [User Roles and Permissions](#3-user-roles-and-permissions)
4. [Functional Requirements](#4-functional-requirements)
5. [Non-Functional Requirements](#5-non-functional-requirements)
6. [Technical Architecture](#6-technical-architecture)
7. [Data Models](#7-data-models)
8. [API and Integration Requirements](#8-api-and-integration-requirements)
9. [Security Requirements](#9-security-requirements)
10. [Testing Requirements](#10-testing-requirements)
11. [Deployment Requirements](#11-deployment-requirements)

---

# 1. Introduction

## 1.1 Purpose

This document defines the functional and non-functional requirements for the Al-Mohaffez (المحفظ) mobile application - a Quran learning platform that connects students with certified Quran teachers (Mohaffez) for in-person and online memorization (Hifz) and revision (Muraja) sessions.

## 1.2 Scope

The platform enables:
- Students to discover nearby Quran teachers based on location
- Teachers to manage their availability, pricing, and student relationships
- Administrators to oversee platform operations, user management, and financial tracking
- Secure payment processing through multiple payment gateways
- Comprehensive session management with performance tracking
- Interactive Quran mistake tracking and review system

## 1.3 Definitions and Acronyms

| Term | Definition |
|------|------------|
| Mohaffez | Certified Quran teacher |
| Hifz | Quran memorization |
| Muraja | Quran revision |
| Bundle | Pre-paid session package |
| Subscription | Recurring session package |
| Slot Lock | Temporary time slot reservation |
| FCM | Firebase Cloud Messaging |
| CF | Cloud Functions |

---

# 2. System Overview

## 2.1 System Objectives

- Provide a secure, user-friendly platform for Quran learning
- Enable location-based teacher discovery
- Facilitate seamless session booking and payment processing
- Track student progress and teacher performance
- Ensure data privacy and security for all users
- Support Arabic language interface with RTL layout

## 2.2 Target Users

1. **Students** - Individuals seeking Quran instruction
2. **Mohaffez (Teachers)** - Certified Quran instructors
3. **Administrators** - Platform management personnel

## 2.3 Platform Support

- **Primary:** Android and iOS mobile applications
- **Secondary:** Web application for admin functions
- **Language:** Arabic (primary), English (secondary)
- **Orientation:** RTL (Right-to-Left) for Arabic content

---

# 3. User Roles and Permissions

## 3.1 Student

### Capabilities
- Register and authenticate using email/password
- Complete one-time account setup with profile information
- Search for nearby Mohaffez using geolocation
- View Mohaffez profiles including credentials, ratings, and pricing
- Book sessions through multiple payment paths:
  - Path A: Use existing bundle credits
  - Path B: Purchase new bundle/subscription
  - Path C: Direct single-session payment
- View upcoming and completed sessions
- Track assignments and performance ratings
- Review Quran recitation mistakes marked by teachers
- Manage active subscriptions
- Rate completed sessions
- Receive push notifications

### Restrictions
- Cannot access teacher-specific features
- Cannot view other students' information
- Cannot modify pricing or availability settings
- Cannot access admin dashboard

## 3.2 Mohaffez (Teacher)

### Capabilities
- Register and authenticate using email/password
- Complete teacher certification verification process
- Upload credentials and certifications
- Set availability schedules (time slots)
- Define pricing plans (single, bundle, subscription)
- Manage student requests (accept/reject)
- View upcoming and completed sessions
- Mark student performance and assign homework
- Track Quran recitation mistakes using interactive Mushaf
- View commission earnings and payment history
- Manage wallet settings for receiving payments
- Receive push notifications

### Restrictions
- Cannot access student accounts
- Cannot modify platform-wide settings
- Cannot access admin dashboard
- Cannot view other teachers' financial data

## 3.3 Administrator

### Capabilities
- Full access to all user accounts
- Approve/reject teacher certification requests
- Manage user accounts (suspend/unsuspend)
- View platform analytics and statistics
- Manage promo codes and discounts
- Configure system settings and maintenance mode
- Broadcast notifications to all users
- Monitor payment transactions and commissions
- View audit logs of system operations
- Manage failed operations and errors
- Configure wallet numbers for platform payments

### Restrictions
- None (full system access)

---

# 4. Functional Requirements

## 4.1 Authentication and Account Management

### 4.1.1 User Registration
- **REQ-AUTH-001:** System shall allow new users to register with email and password
- **REQ-AUTH-002:** System shall require role selection during registration (Student/Mohaffez)
- **REQ-AUTH-003:** System shall validate email format and password strength (minimum 8 characters)
- **REQ-AUTH-004:** System shall create corresponding Firestore user document upon registration
- **REQ-AUTH-005:** System shall prevent duplicate email registrations
- **REQ-AUTH-006:** System shall delete Firebase Auth account if Firestore document creation fails

### 4.1.2 User Login
- **REQ-AUTH-007:** System shall authenticate users using email and password
- **REQ-AUTH-008:** System shall implement exponential backoff for failed login attempts
- **REQ-AUTH-009:** System shall check user suspension status before allowing login
- **REQ-AUTH-010:** System shall cache user session data locally for offline access
- **REQ-AUTH-011:** System shall refresh Firebase ID token on login for immediate claim propagation

### 4.1.3 Password Recovery
- **REQ-AUTH-012:** System shall allow password reset via email
- **REQ-AUTH-013:** System shall send password reset email through Firebase Auth
- **REQ-AUTH-014:** System shall validate reset token expiration

### 4.1.4 Account Setup
- **REQ-AUTH-015:** System shall require one-time account setup for new users
- **REQ-AUTH-016:** System shall collect date of birth, city, and contact information
- **REQ-AUTH-017:** System shall administer Quran knowledge exam for teacher candidates
- **REQ-AUTH-018:** System shall enforce exam retry limits (maximum 3 attempts)
- **REQ-AUTH-019:** System shall track exam score and pass/fail status

### 4.1.5 Session Management
- **REQ-AUTH-020:** System shall automatically sign out users after 30 days of inactivity
- **REQ-AUTH-021:** System shall clear local cache on logout
- **REQ-AUTH-022:** System shall invalidate stale cache data on login

## 4.2 User Profile Management

### 4.2.1 Profile Information
- **REQ-PROFILE-001:** System shall allow users to update name, bio, and profile photo
- **REQ-PROFILE-002:** System shall support profile photo upload to Firebase Storage
- **REQ-PROFILE-003:** System shall compress uploaded images before storage
- **REQ-PROFILE-004:** System shall allow users to set location (address with coordinates)
- **REQ-PROFILE-005:** System shall validate latitude/longitude coordinates
- **REQ-PROFILE-006:** System shall allow users to add YouTube video URL for introduction

### 4.2.2 Teacher Credentials
- **REQ-PROFILE-007:** System shall allow teachers to upload certification documents
- **REQ-PROFILE-008:** System shall support image cropping for credential uploads
- **REQ-PROFILE-009:** System shall require admin approval for teacher credentials
- **REQ-PROFILE-010:** System shall display teacher specialization field
- **REQ-PROFILE-011:** System shall allow teachers to set phone number for contact

### 4.2.3 Privacy Settings
- **REQ-PROFILE-012:** System shall allow users to control profile visibility
- **REQ-PROFILE-013:** System shall allow users to manage notification preferences
- **REQ-PROFILE-014:** System shall allow users to delete their account

## 4.3 Location-Based Discovery

### 4.3.1 Geolocation Services
- **REQ-LOCATION-001:** System shall request location permissions from users
- **REQ-LOCATION-002:** System shall use device GPS for current location
- **REQ-LOCATION-003:** System shall allow manual location selection via map
- **REQ-LOCATION-004:** System shall use Google Places API for address search
- **REQ-LOCATION-005:** System shall cache last known location for offline use

### 4.3.2 Nearby Teacher Search
- **REQ-LOCATION-006:** System shall search for teachers within 50km radius
- **REQ-LOCATION-007:** System shall calculate distance using Haversine formula
- **REQ-LOCATION-008:** System shall display distance in kilometers
- **REQ-LOCATION-009:** System shall filter teachers by specialization
- **REQ-LOCATION-010:** System shall sort results by distance and rating

### 4.3.3 Map Integration
- **REQ-LOCATION-011:** System shall display teacher locations on Google Maps
- **REQ-LOCATION-012:** System shall show teacher markers with profile preview
- **REQ-LOCATION-013:** System shall support map zoom and pan interactions
- **REQ-LOCATION-014:** System shall open Google Maps for navigation directions

## 4.4 Teacher Availability Management

### 4.4.1 Schedule Configuration
- **REQ-AVAIL-001:** System shall allow teachers to set weekly availability
- **REQ-AVAIL-002:** System shall support time slot creation (start/end times)
- **REQ-AVAIL-003:** System shall allow teachers to set session type per slot (Hifz/Muraja)
- **REQ-AVAIL-004:** System shall allow teachers to set session mode per slot (Online/Home/Mosque)
- **REQ-AVAIL-005:** System shall prevent duplicate time slot creation
- **REQ-AVAIL-006:** System shall allow teachers to delete availability slots

### 4.4.2 Slot Locking
- **REQ-AVAIL-007:** System shall implement 24-hour slot lock mechanism
- **REQ-AVAIL-008:** System shall create slotLock document when student initiates booking
- **REQ-AVAIL-009:** System shall prevent multiple students from locking same slot
- **REQ-AVAIL-010:** System shall automatically release expired slot locks
- **REQ-AVAIL-011:** System shall release slot locks when booking is cancelled

### 4.4.3 Calendar View
- **REQ-AVAIL-012:** System shall display monthly calendar for teachers
- **REQ-AVAIL-013:** System shall show booked, available, and locked slots
- **REQ-AVAIL-014:** System shall support calendar navigation between months
- **REQ-AVAIL-015:** System shall indicate today's date on calendar

## 4.5 Pricing and Plans

### 4.5.1 Plan Types
- **REQ-PRICING-001:** System shall support three plan types:
  - Single session
  - Bundle (pre-paid package)
  - Subscription (recurring package)
- **REQ-PRICING-002:** System shall allow teachers to set price in EGP
- **REQ-PRICING-003:** System shall allow teachers to set session count for bundles
- **REQ-PRICING-004:** System shall allow teachers to set validity period for bundles (days)
- **REQ-PRICING-005:** System shall allow teachers to set sessions per week for subscriptions

### 4.5.2 Plan Management
- **REQ-PRICING-006:** System shall allow teachers to create, update, and delete plans
- **REQ-PRICING-007:** System shall prevent deletion of active plans
- **REQ-PRICING-008:** System shall display plan type badge on pricing cards
- **REQ-PRICING-009:** System shall show plan mode (Online/Home/Mosque) when set
- **REQ-PRICING-010:** System shall validate plan data before saving

## 4.6 Booking System

### 4.6.1 Booking Path Selection
- **REQ-BOOKING-001:** System shall present three booking options based on availability:
  - Path A: Use existing bundle
  - Path B: Purchase new bundle
  - Path C: Direct single-session request
- **REQ-BOOKING-002:** System shall check for active bundles matching (studentId, mohaffezId, sessionType)
- **REQ-BOOKING-003:** System shall disable Path A if no active bundle exists
- **REQ-BOOKING-004:** System shall display remaining session count for existing bundles

### 4.6.2 Path A: Use Existing Bundle
- **REQ-BOOKING-005:** System shall consume 1 session credit from bundle
- **REQ-BOOKING-006:** System shall create sessionRequest with subscriptionId
- **REQ-BOOKING-007:** System shall set requiresPaymentOnAcceptance to false
- **REQ-BOOKING-008:** System shall allow immediate teacher acceptance without payment
- **REQ-BOOKING-009:** System shall decrement remainingSessions on session confirmation

### 4.6.3 Path B: Purchase New Bundle
- **REQ-BOOKING-010:** System shall display available bundle/subscription plans
- **REQ-BOOKING-011:** System shall require teacher approval before payment
- **REQ-BOOKING-012:** System shall create sessionRequest with plan details
- **REQ-BOOKING-013:** System shall create slotLock upon student payment initiation
- **REQ-BOOKING-014:** System shall create directPaymentRequest document
- **REQ-BOOKING-015:** System shall create subscription document on teacher payment confirmation
- **REQ-BOOKING-016:** System shall create first hafizSession atomically with subscription
- **REQ-BOOKING-017:** System shall enforce one-active-bundle rule per (student, teacher, sessionType)

### 4.6.4 Path C: Direct Single-Session Request
- **REQ-BOOKING-018:** System shall allow single-session booking without bundle
- **REQ-BOOKING-019:** System shall require teacher approval before payment
- **REQ-BOOKING-020:** System shall create sessionRequest with single session type
- **REQ-BOOKING-021:** System shall require student to mark payment after teacher acceptance
- **REQ-BOOKING-022:** System shall require teacher to confirm payment
- **REQ-BOOKING-023:** System shall create hafizSession after payment confirmation

### 4.6.5 Request Status Flow
- **REQ-BOOKING-024:** System shall support request statuses:
  - pending
  - awaiting_payment
  - awaiting_direct_payment_confirmation
  - accepted
  - rejected
  - cancelled
- **REQ-BOOKING-025:** System shall prevent status transitions that violate business rules
- **REQ-BOOKING-026:** System shall notify users on status changes
- **REQ-BOOKING-027:** System shall allow teachers to reject requests with reason

## 4.7 Payment Processing

### 4.7.1 Payment Gateways
- **REQ-PAYMENT-001:** System shall integrate Paymob payment gateway
- **REQ-PAYMENT-002:** System shall support Fawry payment method
- **REQ-PAYMENT-003:** System shall support wallet payments (Vodafone Cash, etisalat cash)
- **REQ-PAYMENT-004:** System shall support bank transfer option
- **REQ-PAYMENT-005:** System shall support card payments (Visa, Mastercard)

### 4.7.2 Payment Flow
- **REQ-PAYMENT-006:** System shall generate unique payment ID for each transaction
- **REQ-PAYMENT-007:** System shall redirect to payment gateway WebView
- **REQ-PAYMENT-008:** System shall handle payment success callback
- **REQ-PAYMENT-009:** System shall handle payment failure and retry
- **REQ-PAYMENT-010:** System shall record payment status in Firestore
- **REQ-PAYMENT-011:** System shall support promo code application
- **REQ-PAYMENT-012:** System shall validate promo code before application

### 4.7.3 Payment Status
- **REQ-PAYMENT-013:** System shall track payment statuses:
  - pending
  - processing
  - completed
  - failed
  - refunded
- **REQ-PAYMENT-014:** System shall store transaction reference from gateway
- **REQ-PAYMENT-015:** System shall store gateway order ID
- **REQ-PAYMENT-016:** System shall log failure reasons for debugging

### 4.7.4 Commission Calculation
- **REQ-PAYMENT-017:** System shall calculate 5% platform commission on all payments
- **REQ-PAYMENT-018:** System shall calculate weekly commission totals per teacher
- **REQ-PAYMENT-019:** System shall track commission payment status
- **REQ-PAYMENT-020:** System shall display commission dashboard for admins
- **REQ-PAYMENT-021:** System shall display individual teacher commission breakdown

## 4.8 Session Management

### 4.8.1 Session Creation
- **REQ-SESSION-001:** System shall create hafizSession document upon booking confirmation
- **REQ-SESSION-002:** System shall store session date, time, and location
- **REQ-SESSION-003:** System shall store student and teacher information
- **REQ-SESSION-004:** System shall link session to subscription if applicable
- **REQ-SESSION-005:** System shall store session type (Hifz/Muraja)
- **REQ-SESSION-006:** System shall store session mode (Online/Home/Mosque)

### 4.8.2 Session Completion
- **REQ-SESSION-007:** System shall allow teachers to mark sessions as completed
- **REQ-SESSION-008:** System shall require teachers to provide performance notes
- **REQ-SESSION-009:** System shall require teachers to rate student performance (1-10)
- **REQ-SESSION-010:** System shall require teachers to assign homework (Hifz/Muraja content)
- **REQ-SESSION-011:** System shall store completion timestamp
- **REQ-SESSION-012:** System shall notify student of session completion

### 4.8.3 Session Rating
- **REQ-SESSION-013:** System shall allow students to rate completed sessions (1-5 stars)
- **REQ-SESSION-014:** System shall allow students to provide written feedback
- **REQ-SESSION-015:** System shall update teacher rating average
- **REQ-SESSION-016:** System shall increment teacher review count
- **REQ-SESSION-017:** System shall prevent duplicate ratings for same session

## 4.9 Quran Mistake Tracking

### 4.9.1 Mistake Marking
- **REQ-MISTAKE-001:** System shall allow teachers to mark mistakes on interactive Quran pages
- **REQ-MISTAKE-002:** System shall support mistake types:
  - Tajweed (تجويد)
  - Pronunciation (نطق)
  - Reading (قراءة)
  - Skip (تخطي)
  - Addition (زيادة)
  - Other (أخرى)
- **REQ-MISTAKE-003:** System shall store mistake location (page number, coordinates)
- **REQ-MISTAKE-004:** System shall allow teachers to add correction notes
- **REQ-MISTAKE-005:** System shall store mistake timestamp

### 4.9.2 Mistake Review
- **REQ-MISTAKE-006:** System shall allow students to view marked mistakes
- **REQ-MISTAKE-007:** System shall group mistakes by type
- **REQ-MISTAKE-008:** System shall display mistake counts per type
- **REQ-MISTAKE-009:** System shall provide interactive Mushaf view for mistake locations
- **REQ-MISTAKE-010:** System shall prevent students from editing mistakes (read-only)

### 4.9.3 Mistake Statistics
- **REQ-MISTAKE-011:** System shall calculate total mistakes per session
- **REQ-MISTAKE-012:** System shall track mistakes by page
- **REQ-MISTAKE-013:** System shall identify most common mistake type
- **REQ-MISTAKE-014:** System shall display mistake statistics to students

## 4.10 Student Assignments and Performance

### 4.10.1 Assignment Viewing
- **REQ-ASSIGN-001:** System shall display completed sessions list to students
- **REQ-ASSIGN-002:** System shall show previous assignment completion status
- **REQ-ASSIGN-003:** System shall display previous performance ratings (Hifz/Muraja)
- **REQ-ASSIGN-004:** System shall show teacher performance notes
- **REQ-ASSIGN-005:** System shall display new homework assignments
- **REQ-ASSIGN-006:** System shall show session rating and notes from teacher

### 4.10.2 Performance Tracking
- **REQ-ASSIGN-007:** System shall track Hifz completion status per session
- **REQ-ASSIGN-008:** System shall track Muraja completion status per session
- **REQ-ASSIGN-009:** System shall store performance ratings (0-10 scale)
- **REQ-ASSIGN-010:** System shall display performance trends over time
- **REQ-ASSIGN-011:** System shall calculate average performance metrics

## 4.11 Notification System

### 4.11.1 Push Notifications
- **REQ-NOTIF-001:** System shall send push notifications via FCM
- **REQ-NOTIF-002:** System shall request notification permissions on app launch
- **REQ-NOTIF-003:** System shall handle background message reception
- **REQ-NOTIF-004:** System shall refresh FCM token on app resume
- **REQ-NOTIF-005:** System shall store FCM token in user document

### 4.11.2 Notification Types
- **REQ-NOTIF-006:** System shall notify students on request status changes
- **REQ-NOTIF-007:** System shall notify teachers on new booking requests
- **REQ-NOTIF-008:** System shall notify users on payment confirmations
- **REQ-NOTIF-009:** System shall send session reminders (24 hours before)
- **REQ-NOTIF-010:** System shall send payment deadline reminders
- **REQ-NOTIF-011:** System shall support admin broadcast notifications

### 4.11.3 In-App Notifications
- **REQ-NOTIF-012:** System shall maintain notification center in app
- **REQ-NOTIF-013:** System shall display notification list with timestamps
- **REQ-NOTIF-014:** System shall allow users to mark notifications as read
- **REQ-NOTIF-015:** System shall show unread notification count badge

## 4.12 Admin Features

### 4.12.1 User Management
- **REQ-ADMIN-001:** System shall display list of all users
- **REQ-ADMIN-002:** System shall allow admins to view user details
- **REQ-ADMIN-003:** System shall allow admins to suspend user accounts
- **REQ-ADMIN-004:** System shall allow admins to unsuspend user accounts
- **REQ-ADMIN-005:** System shall prevent suspended users from accessing app
- **REQ-ADMIN-006:** System shall log all admin actions in audit log

### 4.12.2 Teacher Certification
- **REQ-ADMIN-007:** System shall display pending teacher requests
- **REQ-ADMIN-008:** System shall allow admins to view uploaded credentials
- **REQ-ADMIN-009:** System shall allow admins to approve teacher applications
- **REQ-ADMIN-010:** System shall allow admins to reject teacher applications
- **REQ-ADMIN-011:** System shall update user status to pending_approval/rejected

### 4.12.3 Credential Verification
- **REQ-ADMIN-012:** System shall display pending credential uploads
- **REQ-ADMIN-013:** System shall allow admins to review credential documents
- **REQ-ADMIN-014:** System shall allow admins to approve/reject credentials
- **REQ-ADMIN-015:** System shall notify teachers of credential status

### 4.12.4 System Settings
- **REQ-ADMIN-016:** System shall allow admins to enable maintenance mode
- **REQ-ADMIN-017:** System shall display maintenance message to users
- **REQ-ADMIN-018:** System shall allow admins to configure app version requirements
- **REQ-ADMIN-019:** System shall force app update if version is below minimum
- **REQ-ADMIN-020:** System shall allow admins to enable dev mode for testing

### 4.12.5 Financial Management
- **REQ-ADMIN-021:** System shall display payment transaction log
- **REQ-ADMIN-022:** System shall show platform commission totals
- **REQ-ADMIN-023:** System shall display individual teacher commissions
- **REQ-ADMIN-024:** System shall allow admins to manage platform wallet numbers
- **REQ-ADMIN-025:** System shall allow admins to create and manage promo codes
- **REQ-ADMIN-026:** System shall support promo code expiration dates

### 4.12.6 Monitoring and Debugging
- **REQ-ADMIN-027:** System shall display failed operations log
- **REQ-ADMIN-028:** System shall show operation details and error messages
- **REQ-ADMIN-029:** System shall display slot locks management screen
- **REQ-ADMIN-030:** System shall allow admins to manually release stuck slot locks
- **REQ-ADMIN-031:** System shall display audit log of all system changes

## 4.13 Subscription Management

### 4.13.1 Subscription Creation
- **REQ-SUB-001:** System shall create subscription document on bundle purchase
- **REQ-SUB-002:** System shall store student, teacher, and plan information
- **REQ-SUB-003:** System shall store total and remaining session counts
- **REQ-SUB-004:** System shall set subscription status to active
- **REQ-SUB-005:** System shall set expiry date based on validityDays

### 4.13.2 Subscription Usage
- **REQ-SUB-006:** System shall decrement remainingSessions on each session booking
- **REQ-SUB-007:** System shall prevent booking if remainingSessions is 0
- **REQ-SUB-008:** System shall check expiry date before allowing session use
- **REQ-SUB-009:** System shall set status to expired when validity period ends
- **REQ-SUB-010:** System shall set status to depleted when sessions exhausted

### 4.13.3 Subscription Display
- **REQ-SUB-011:** System shall display active subscriptions to students
- **REQ-SUB-012:** System shall show remaining session count
- **REQ-SUB-013:** System shall show expiry date
- **REQ-SUB-014:** System shall display subscription progress (used/total)
- **REQ-SUB-015:** System shall show plan title and teacher name

---

# 5. Non-Functional Requirements

## 5.1 Performance Requirements

- **REQ-NFR-001:** App startup time shall not exceed 3 seconds on modern devices
- **REQ-NFR-002:** Screen transitions shall complete within 500ms
- **REQ-NFR-003:** API calls shall complete within 5 seconds under normal network conditions
- **REQ-NFR-004:** Image loading shall display placeholder within 200ms
- **REQ-NFR-005:** List scrolling shall maintain 60fps
- **REQ-NFR-006:** Firebase queries shall use appropriate indexes to avoid full collection scans
- **REQ-NFR-007:** Pagination shall limit initial load to 20 items

## 5.2 Reliability Requirements

- **REQ-NFR-008:** System shall maintain 99.5% uptime during business hours
- **REQ-NFR-009:** System shall implement automatic retry for failed network requests
- **REQ-NFR-010:** System shall handle offline mode gracefully
- **REQ-NFR-011:** System shall cache critical data for offline access
- **REQ-NFR-012:** System shall synchronize data when connection restored
- **REQ-NFR-013:** System shall implement exponential backoff for retries

## 5.3 Security Requirements

- **REQ-NFR-014:** System shall use Firebase App Check in production
- **REQ-NFR-015:** System shall validate all user inputs on client and server
- **REQ-NFR-016:** System shall use Firestore security rules for access control
- **REQ-NFR-017:** System shall never store sensitive data in local storage
- **REQ-NFR-018:** System shall use HTTPS for all network communications
- **REQ-NFR-019:** System shall implement Firebase Auth token refresh
- **REQ-NFR-020:** System shall log out users on token expiration
- **REQ-NFR-021:** System shall sanitize user-generated content to prevent XSS

## 5.4 Usability Requirements

- **REQ-NFR-022:** App shall support Arabic language with RTL layout
- **REQ-NFR-023:** All text shall be localized to Arabic
- **REQ-NFR-024:** App shall use Cairo font family for Arabic text
- **REQ-NFR-025:** Touch targets shall be minimum 44x44 pixels
- **REQ-NFR-026:** App shall support system font size scaling
- **REQ-NFR-027:** App shall provide clear error messages in Arabic
- **REQ-NFR-028:** App shall support dark mode (future enhancement)

## 5.5 Scalability Requirements

- **REQ-NFR-029:** System shall support 10,000 concurrent users
- **REQ-NFR-030:** System shall handle 1,000 booking requests per hour
- **REQ-NFR-031:** System shall use Firestore pagination for large datasets
- **REQ-NFR-032:** System shall implement data archiving for old records
- **REQ-NFR-033:** System shall monitor Firestore read/write quotas

## 5.6 Compatibility Requirements

- **REQ-NFR-034:** App shall support Android 5.0 (API 21) and above
- **REQ-NFR-035:** App shall support iOS 12.0 and above
- **REQ-NFR-036:** App shall support different screen sizes (phones and tablets)
- **REQ-NFR-037:** App shall support portrait orientation only
- **REQ-NFR-038:** App shall support both 32-bit and 64-bit architectures

## 5.7 Maintainability Requirements

- **REQ-NFR-039:** Code shall follow Flutter/Dart style guidelines
- **REQ-NFR-040:** Code shall include inline documentation
- **REQ-NFR-041:** System shall use provider pattern for state management
- **REQ-NFR-042:** System shall separate business logic from UI
- **REQ-NFR-043:** System shall use repository pattern for data access
- **REQ-NFR-044:** System shall implement comprehensive error logging

---

# 6. Technical Architecture

## 6.1 Frontend Architecture

### 6.1.1 Framework
- **Framework:** Flutter 3.0+
- **Language:** Dart 3.0+
- **State Management:** Riverpod + Provider
- **Routing:** GoRouter
- **Dependency Injection:** Riverpod providers

### 6.1.2 Architecture Pattern
- **Pattern:** Clean Architecture with Repository Pattern
- **Layers:**
  - UI Layer (Screens, Widgets)
  - Provider Layer (State Management)
  - Repository Layer (Data Access)
  - Service Layer (Business Logic)
  - Model Layer (Data Models)

### 6.1.3 Key Libraries
- **Firebase:** firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_messaging, cloud_functions
- **State:** flutter_riverpod, provider
- **Routing:** go_router
- **Networking:** http, dio
- **Maps:** google_maps_flutter, google_places_flutter, geolocator, geocoding
- **UI:** cached_network_image, shimmer, table_calendar
- **Storage:** shared_preferences, hive
- **Payment:** webview_flutter
- **Code Generation:** freezed, json_serializable, build_runner

## 6.2 Backend Architecture

### 6.2.1 Firebase Services
- **Authentication:** Firebase Auth
- **Database:** Cloud Firestore
- **Storage:** Firebase Storage
- **Messaging:** Firebase Cloud Messaging (FCM)
- **Server Logic:** Firebase Cloud Functions (TypeScript)
- **App Security:** Firebase App Check

### 6.2.2 Cloud Functions Structure
- **Runtime:** Node.js 18+
- **Language:** TypeScript
- **Triggers:** Firestore triggers, HTTP triggers, Scheduled functions
- **Services:**
  - Booking management
  - Payment processing
  - Notification delivery
  - Commission calculation
  - Slot lock management
  - Admin operations

### 6.2.3 Database Schema
- **Collections:**
  - users
  - credentials (subcollection of users)
  - availability (subcollection of users)
  - pricingPlans
  - sessionRequests
  - hafizSessions
  - subscriptions
  - payments
  - slotLocks
  - directPaymentRequests
  - userSuspensions
  - notifications
  - promoCodes
  - systemConfig
  - auditLog
  - failedOperations
  - paymentEvents
  - teacherCommissions

## 6.3 Security Architecture

### 6.3.1 Authentication
- **Primary:** Firebase Auth (Email/Password)
- **Token Management:** Automatic ID token refresh
- **Session Management:** Local cache with validation
- **Role-Based Access:** Custom claims for admin role

### 6.3.2 Authorization
- **Firestore Rules:** Role-based document access
- **Guard System:** Route guards in Flutter app
- **Suspension System:** Dual-check (user status + suspension document)
- **App Check:** Production app verification

### 6.3.3 Data Protection
- **Encryption:** Firebase provides encryption at rest
- **Transmission:** HTTPS/TLS for all communications
- **Input Validation:** Client and server-side validation
- **Sanitization:** XSS prevention for user content

---

# 7. Data Models

## 7.1 User Model

```dart
class UserModel {
  String uid;
  String name;
  String email;
  String role; // student, mohaffez, admin
  String status; // active, suspended, pending_approval, rejected
  String? photoUrl;
  String? bio;
  String? youtubeVideoUrl;
  String? specialization;
  String? phoneNumber;
  int followerCount;
  int followingCount;
  double rating;
  int reviewCount;
  String? addressText;
  double? addressLat;
  double? addressLng;
  DateTime? createdAt;
  
  // Setup fields
  bool setupCompleted;
  DateTime? dateOfBirth;
  String? city;
  double? examScore;
  DateTime? examTakenAt;
  int examRetryCount;
  bool examPassed;
  DateTime? examNextRetryAt;
}
```

## 7.2 Session Model

```dart
class SessionModel {
  String? id;
  String mohaffezId;
  String studentId;
  String mohaffezName;
  String studentName;
  String sessionType; // hifz, muraja
  String location;
  String? mohaffezPhone;
  double? imamAddressLat;
  double? imamAddressLng;
  String? preferredTimeSlot;
  int juzCount;
  String? hifzAssignment;
  String? murajaAssignment;
  bool? previousHifzCompleted;
  int previousHifzRating;
  bool? previousMurajaCompleted;
  int previousMurajaRating;
  String? performanceNotes;
  int sessionRating;
  int teacherRating;
  String? sessionNotes;
  DateTime? sessionDate;
  DateTime? slotStart;
  DateTime? slotEnd;
  DateTime? createdAt;
  DateTime? completedAt;
  String? status; // scheduled, completed, cancelled
  
  // Payment fields
  bool isPaid;
  String? paymentId;
  String? subscriptionId;
  String? paymentType; // bundle, subscription, direct
  double? sessionPrice;
  
  // Online session fields
  String? meetingLink;
  String? meetingId;
  String? meetingPassword;
  bool isMeetingLinkSent;
  DateTime? meetingScheduledAt;
  
  // Quran mistake tracking
  List<QuranMistake> mistakes;
  List<int> pagesRead;
  int? currentPage;
  int tajweedMistakesCount;
  int pronunciationMistakesCount;
  int readingMistakesCount;
  int skipMistakesCount;
  int additionMistakesCount;
  int otherMistakesCount;
}
```

## 7.3 Subscription Model

```dart
class SubscriptionModel {
  String? id;
  String studentId;
  String studentName;
  String mohaffezId;
  String mohaffezName;
  String planId;
  String planTitle;
  PlanType planType; // single, bundle, subscription
  int totalSessions;
  int remainingSessions;
  double totalPaid;
  String paymentTransactionId;
  SubscriptionStatus status; // active, expired, depleted, cancelled
  DateTime? startDate;
  DateTime? expiryDate;
  DateTime? lastUsedAt;
  DateTime? createdAt;
}
```

## 7.4 Payment Model

```dart
class PaymentModel {
  String? id;
  String studentId;
  String studentName;
  String studentEmail;
  String studentPhone;
  String mohaffezId;
  String mohaffezName;
  String planId;
  String planTitle;
  PlanType? planType;
  double amount;
  String currency;
  PaymentMethod method; // card, wallet, cash, bank_transfer
  PaymentStatus status; // pending, processing, completed, failed, refunded
  PaymentGateway? gateway; // paymob, fawry, stripe, manual
  String? subscriptionId;
  String? sessionId;
  String? transactionReference;
  String? gatewayOrderId;
  String? gatewayTransactionId;
  String? failureReason;
  Map<String, dynamic>? metadata;
  DateTime? paidAt;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

## 7.5 Pricing Plan Model

```dart
class PricingPlanModel {
  String? id;
  String mohaffezId;
  String title;
  PlanType type; // single, bundle, subscription
  SessionMode? mode; // online, home, mosque
  double priceEGP;
  int sessionsCount;
  int? validityDays;
  int? sessionsPerWeek;
  bool isActive;
  bool isFreeTrialAvailable;
  String? description;
  DateTime? createdAt;
  DateTime? updatedAt;
}
```

## 7.6 Quran Mistake Model

```dart
class QuranMistake {
  String id;
  int pageNumber;
  int surahNumber;
  int ayahNumber;
  double xPosition; // Normalized 0-1
  double yPosition; // Normalized 0-1
  MistakeType type; // tajweed, pronunciation, reading, skip, addition, other
  String? wordText;
  String? correctionNote;
  DateTime? markedAt;
}
```

---

# 8. API and Integration Requirements

## 8.1 Firebase Cloud Functions

### 8.1.1 Booking Functions
- **createSessionRequest:** Creates new session request with slot locking
- **confirmFreeSession:** Confirms free trial sessions
- **confirmBundleDirectPayment:** Confirms bundle payment and creates subscription
- **confirmSubscriptionSession:** Consumes bundle credit for session booking
- **studentMarkedDirectPayment:** Processes student payment initiation
- **mohaffezConfirmDirectPayment:** Confirms teacher payment receipt

### 8.1.2 Payment Functions
- **directPayment:** Handles direct payment flow
- **confirmBundleDirectPayment:** Atomic bundle activation
- **confirmSubscriptionSession:** Subscription credit consumption
- **expiredPayments:** Handles payment timeout cleanup
- **commissions:** Calculates weekly teacher commissions
- **paymobWebhook:** Processes Paymob payment callbacks

### 8.1.3 Notification Functions
- **sendNotification:** Sends FCM notification
- **sessionReminders:** Sends session reminder notifications
- **paymentDeadlineReminders:** Sends payment deadline alerts
- **triggers:** Firestore triggers for notification delivery

### 8.1.4 Admin Functions
- **setAdminClaim:** Sets admin custom claim
- **onUserSuspended:** Handles user suspension triggers
- **onUserUnsuspended:** Handles user unsuspension triggers
- **appVersionCheck:** Validates app version requirements
- **maintenanceCheck:** Enforces maintenance mode
- **adminActions:** Administrative operations

### 8.1.5 Cleanup Functions
- **releaseExpiredSlotLocks:** Releases expired slot reservations

## 8.2 Third-Party Integrations

### 8.2.1 Google Maps API
- **Purpose:** Location search, map display, directions
- **Endpoints:** Places API, Geocoding API, Maps SDK
- **Authentication:** API Key

### 8.2.2 Paymob Payment Gateway
- **Purpose:** Payment processing
- **Endpoints:** Payment API, Webhook callbacks
- **Authentication:** API Key
- **Supported Methods:** Card, Wallet, Bank Transfer

### 8.2.3 Firebase Services
- **Authentication:** Email/Password auth
- **Firestore:** NoSQL database
- **Storage:** File storage
- **FCM:** Push notifications
- **App Check:** App verification

---

# 9. Security Requirements

## 9.1 Authentication Security

- **REQ-SEC-001:** System shall use Firebase Auth for authentication
- **REQ-SEC-002:** System shall implement password strength requirements
- **REQ-SEC-003:** System shall use secure token storage (Keychain/Keystore)
- **REQ-SEC-004:** System shall refresh ID tokens automatically
- **REQ-SEC-005:** System shall invalidate tokens on logout
- **REQ-SEC-006:** System shall implement session timeout after 30 days

## 9.2 Authorization Security

- **REQ-SEC-007:** System shall implement Firestore security rules
- **REQ-SEC-008:** System shall validate user role on every request
- **REQ-SEC-009:** System shall prevent unauthorized data access
- **REQ-SEC-010:** System shall implement route guards in Flutter app
- **REQ-SEC-011:** System shall check suspension status on app launch
- **REQ-SEC-012:** System shall use custom claims for admin role

## 9.3 Data Security

- **REQ-SEC-013:** System shall encrypt data at rest (Firebase default)
- **REQ-SEC-014:** System shall use HTTPS for all communications
- **REQ-SEC-015:** System shall validate all user inputs
- **REQ-SEC-016:** System shall sanitize user-generated content
- **REQ-SEC-017:** System shall never log sensitive information
- **REQ-SEC-018:** System shall implement secure file upload validation

## 9.4 Payment Security

- **REQ-SEC-019:** System shall use PCI-compliant payment gateway
- **REQ-SEC-020:** System shall never store full card numbers
- **REQ-SEC-021:** System shall validate payment amounts server-side
- **REQ-SEC-022:** System shall implement payment idempotency
- **REQ-SEC-023:** System shall verify payment webhook signatures
- **REQ-SEC-024:** System shall log all payment transactions

## 9.5 App Security

- **REQ-SEC-025:** System shall use Firebase App Check in production
- **REQ-SEC-026:** System shall implement certificate pinning (optional)
- **REQ-SEC-027:** System shall obfuscate release builds
- **REQ-SEC-028:** System shall prevent screenshot in sensitive screens (optional)
- **REQ-SEC-029:** System shall detect and prevent rooted/jailbroken devices (optional)
- **REQ-SEC-030:** System shall implement code integrity checks (optional)

---

# 10. Testing Requirements

## 10.1 Unit Testing

- **REQ-TEST-001:** System shall have unit tests for all business logic
- **REQ-TEST-002:** System shall have unit tests for data models
- **REQ-TEST-003:** System shall have unit tests for repositories
- **REQ-TEST-004:** System shall have unit tests for providers
- **REQ-TEST-005:** Unit test coverage shall be minimum 70%

## 10.2 Integration Testing

- **REQ-TEST-006:** System shall have integration tests for Firebase operations
- **REQ-TEST-007:** System shall have integration tests for Cloud Functions
- **REQ-TEST-008:** System shall have integration tests for payment flows
- **REQ-TEST-009:** System shall have integration tests for notification delivery

## 10.3 UI Testing

- **REQ-TEST-010:** System shall have widget tests for key screens
- **REQ-TEST-011:** System shall have widget tests for custom widgets
- **REQ-TEST-012:** System shall have integration tests for user flows
- **REQ-TEST-013:** System shall have E2E tests for critical paths

## 10.4 Performance Testing

- **REQ-TEST-014:** System shall test app startup performance
- **REQ-TEST-015:** System shall test list scrolling performance
- **REQ-TEST-016:** System shall test API response times
- **REQ-TEST-017:** System shall test memory usage under load

## 10.5 Security Testing

- **REQ-TEST-018:** System shall test authentication flows
- **REQ-TEST-019:** System shall test authorization rules
- **REQ-TEST-020:** System shall test input validation
- **REQ-TEST-021:** System shall test payment security
- **REQ-TEST-022:** System shall conduct penetration testing before release

---

# 11. Deployment Requirements

## 11.1 Build Requirements

### 11.1.1 Android
- **REQ-DEPLOY-001:** System shall generate APK for testing
- **REQ-DEPLOY-002:** System shall generate AAB for Play Store release
- **REQ-DEPLOY-003:** System shall sign release builds with production keystore
- **REQ-DEPLOY-004:** System shall support Android 5.0 (API 21) minimum
- **REQ-DEPLOY-005:** System shall support 64-bit architectures (ARM64-v8a)

### 11.1.2 iOS
- **REQ-DEPLOY-006:** System shall generate IPA for TestFlight
- **REQ-DEPLOY-007:** System shall generate IPA for App Store release
- **REQ-DEPLOY-008:** System shall sign with Apple developer certificate
- **REQ-DEPLOY-009:** System shall support iOS 12.0 minimum
- **REQ-DEPLOY-010:** System shall support both iPhone and iPad

## 11.2 Firebase Deployment

- **REQ-DEPLOY-011:** System shall deploy Firestore security rules
- **REQ-DEPLOY-012:** System shall deploy Firestore indexes
- **REQ-DEPLOY-013:** System shall deploy Cloud Functions
- **REQ-DEPLOY-014:** System shall deploy Storage rules
- **REQ-DEPLOY-015:** System shall configure Firebase Hosting (web admin)

## 11.3 Environment Configuration

### 11.3.1 Development
- Firebase project: Development project
- App Check: Debug provider
- API Keys: Development keys
- Logging: Debug logging enabled

### 11.3.2 Staging
- Firebase project: Staging project
- App Check: Debug provider
- API Keys: Staging keys
- Logging: Warning level

### 11.3.3 Production
- Firebase project: Production project (mohaffez-ba2ec)
- App Check: Play Integrity (Android), Device Check (iOS)
- API Keys: Production keys
- Logging: Error level only

## 11.4 Release Process

- **REQ-DEPLOY-016:** System shall follow semantic versioning (MAJOR.MINOR.PATCH)
- **REQ-DEPLOY-017:** System shall maintain changelog for each release
- **REQ-DEPLOY-018:** System shall conduct code review before merge
- **REQ-DEPLOY-019:** System shall run automated tests on CI/CD
- **REQ-DEPLOY-020:** System shall use feature flags for gradual rollout

## 11.5 Monitoring and Logging

- **REQ-DEPLOY-021:** System shall implement Firebase Crashlytics
- **REQ-DEPLOY-022:** System shall implement Firebase Analytics
- **REQ-DEPLOY-023:** System shall monitor Cloud Functions logs
- **REQ-DEPLOY-024:** System shall set up alerts for critical errors
- **REQ-DEPLOY-025:** System shall monitor Firestore usage quotas

---

# Appendix A: Glossary

| Term | Definition |
|------|------------|
| Mohaffez | Certified Quran teacher |
| Hifz | Quran memorization |
| Muraja | Quran revision |
| Bundle | Pre-paid session package with fixed session count |
| Subscription | Recurring session package with validity period |
| Slot Lock | Temporary 24-hour reservation of a time slot |
| FCM | Firebase Cloud Messaging - Push notification service |
| CF | Cloud Functions - Server-side logic |
| RTL | Right-to-Left text direction for Arabic |
| Firestore | NoSQL database by Firebase |
| App Check | Firebase app security service |
| Riverpod | Flutter state management library |
| GoRouter | Flutter routing library |

---

# Appendix B: Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | April 19, 2026 | System Architect | Initial requirements document |

---

# Appendix C: References

1. Flutter Documentation: https://flutter.dev/docs
2. Firebase Documentation: https://firebase.google.com/docs
3. Riverpod Documentation: https://riverpod.dev
4. GoRouter Documentation: https://gorouter.dev
5. Paymob Documentation: https://docs.paymob.com

---

**End of Document**
