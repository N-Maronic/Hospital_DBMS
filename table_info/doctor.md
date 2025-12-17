# Doctor Table

The `doctor` table stores professional and organizational information specific to doctors working within the hospital management system. It extends the general user profile stored in the `user` table and contains attributes relevant to medical staff only.

Each doctor entry is associated with exactly one user account, allowing role-based access control and ensuring that doctors can securely access system features related to patient care, appointments, and medical records.

---

## Table Structure

| Column Name     | Type        | Description |
|-----------------|-------------|-------------|
| id              | uuid        | Primary key identifying the doctor |
| user_id         | uuid        | Foreign key referencing `user.id` |
| specialization  | text        | Medical specialization of the doctor (e.g. cardiology, pediatrics) |
| department      | text        | Department where the doctor is assigned |
| room_number     | text        | Assigned consultation or office room number |
| license_number  | text        | Official medical license number |
| created_at      | timestamptz | Timestamp when the record was created |
| updated_at      | timestamptz | Timestamp when the record was last updated |

---

## Relationships

- **user → doctor**:  
  One-to-one relationship. Each doctor record is linked to a single user account via `user_id`.

- **doctor → patient / appointments / medical records**:  
  Logical relationships. Doctors interact with patients and related medical data through other domain-specific tables.

---

## Access Control

- **Doctors**:  
  Read access to their own doctor profile.

- **Data Entry Staff**:  
  Create and update doctor records for administrative purposes.

- **System Administrators**:  
  Full access for management, verification of credentials, and auditing.

---

## Security and Privacy Considerations

- The table contains sensitive professional and regulatory information.
- Access is restricted using role-based and row-level security policies.
- The `license_number` field must be protected against unauthorized disclosure or modification.
- All updates are timestamped to ensure traceability and support auditing.
- Data exposure is limited to the minimum required for operational and compliance needs.
