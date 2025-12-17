# Data Entry Staff Table

The `data_entry_staff` table stores role-specific information for administrative personnel responsible for entering, updating, and maintaining records within the hospital management system. It extends the core user profile stored in the `user` table and captures attributes relevant to non-clinical staff involved in data management and scheduling.

Each data entry staff member is linked to exactly one user account, enabling role-based access control and ensuring secure access to administrative system functionality.

---

## Table Structure

| Column Name | Type        | Description |
|------------|-------------|-------------|
| id         | uuid        | Primary key identifying the data entry staff member |
| user_id    | uuid        | Foreign key referencing `user.id` |
| department | text        | Department or administrative unit assignment |
| position   | text        | Job position or title |
| created_at | timestamptz | Timestamp when the record was created |
| updated_at | timestamptz | Timestamp when the record was last updated |

---

## Relationships

- **user → data_entry_staff**:  
  One-to-one relationship. Each data entry staff record is linked to a single user account via `user_id`.

- **data_entry_staff → appointment**:  
  One-to-many relationship. Data entry staff can create and schedule multiple appointments.  
  This relationship is represented by `appointment.scheduled_by`, which references `data_entry_staff.id`.

- **data_entry_staff → patients / doctors / lab_staff**:  
  Logical relationships. Data entry staff manage and maintain records across multiple domain-specific tables.

---

## Access Control

- **Data Entry Staff**:  
  Read access to their own data entry staff profile.  
  Create and update access for appointments they schedule.

- **System Administrators**:  
  Full access for staff management, appointment oversight, role assignment, and auditing.

---

## Security and Privacy Considerations

- The table contains organizational and employment-related information.
- Access is restricted using role-based and row-level security policies.
- Appointment scheduling privileges must be carefully scoped to prevent unauthorized modifications.
- All modifications are timestamped to ensure traceability and accountability.
- Data exposure is limited to the minimum necessary to perform administrative and scheduling duties.
