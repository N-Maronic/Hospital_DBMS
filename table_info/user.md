# User Table

The `user` table stores core personal and authentication-related information for all individuals registered in the hospital management system. It serves as the central entity that represents a system user, regardless of their specific role (e.g. patient, doctor, laboratory staff, or data entry staff).

Other role-specific tables (such as `doctor`, `lab_staff`, or `data_entry_staff`) extend this table via one-to-one relationships, enabling a clean separation between shared user data and role-dependent attributes.

Each user record is linked to Supabase authentication (`auth.users`) to ensure secure identity management and access control.

---

## Table Structure

| Column Name   | Type        | Description |
|--------------|-------------|-------------|
| id           | uuid        | Primary key; also references `auth.users.id` |
| name         | text        | Full name of the user |
| email        | text        | Email address associated with the user account |
| phone_number | text        | User’s contact phone number |
| address      | text        | Residential address of the user |
| gender       | text        | Gender of the user |
| id_type      | text        | Type of identification document (e.g. passport, national ID) |
| id_number    | text        | Identification document number |
| role         | enum_role   | Role assigned to the user (e.g. patient, doctor, staff) |
| created_at   | timestamptz | Timestamp when the record was created |
| updated_at   | timestamptz | Timestamp when the record was last updated |

---

## Relationships

- **auth.users → user**:  
  One-to-one relationship. Each user record corresponds to exactly one authenticated Supabase user.

- **user → patient / doctor / lab_staff / data_entry_staff**:  
  One-to-one relationships. The `user` table acts as the parent entity for all role-specific tables.

---

## Access Control

- **Authenticated Users**:  
  Read access to their own user profile.

- **Data Entry Staff**:  
  Create and read patient records. Update administrative fields only.

- **System Administrators**:  
  Full access for user management, role assignment, and auditing.

---

## Security and Privacy Considerations

- The table contains personally identifiable information (PII).
- Access is enforced using Supabase Row Level Security (RLS) policies.
- The `role` column is critical for authorization and must only be modified by trusted system components.
- All changes are timestamped to support auditing and traceability.
- Direct exposure of sensitive fields is minimized to ensure compliance with data protection regulations.
