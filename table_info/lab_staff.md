# Lab Staff Table

The `lab_staff` table stores role-specific information for laboratory personnel within the hospital management system. It extends the core user profile stored in the `user` table and captures attributes relevant to staff responsible for laboratory testing, sample analysis, and reporting.

Each laboratory staff member is linked to exactly one user account, enabling role-based access control and ensuring secure access to laboratory-related system functionality.

---

## Table Structure

| Column Name | Type        | Description |
|------------|-------------|-------------|
| id         | uuid        | Primary key identifying the laboratory staff member |
| user_id    | uuid        | Foreign key referencing `user.id` |
| department | text        | Laboratory department or unit assignment |
| position   | text        | Job position or title within the laboratory |
| shift      | text        | Assigned work shift (e.g. day, night, rotating) |
| created_at | timestamptz | Timestamp when the record was created |
| updated_at | timestamptz | Timestamp when the record was last updated |

---

## Relationships

- **user → lab_staff**:  
  One-to-one relationship. Each lab staff record is linked to a single user account via `user_id`.

- **lab_staff → lab_test**:  
  Logical relationships. Laboratory staff are responsible for conducting tests and managing test results stored in related tables.

---

## Access Control

- **Laboratory Staff**:  
  Read access to their own lab staff profile.

- **Data Entry Staff**:  
  Create and update lab staff records for administrative purposes.

- **System Administrators**:  
  Full access for staff management, shift assignment, and auditing.

---

## Security and Privacy Considerations

- The table contains organizational and employment-related information.
- Access is enforced using role-based and row-level security policies.
- Shift and position data must be protected against unauthorized changes.
- All modifications are timestamped to support auditing and operational traceability.
- Data exposure is limited to what is necessary for laboratory operations.
