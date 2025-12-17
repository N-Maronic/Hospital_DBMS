# Appointment Table

The `appointment` table stores scheduling and administrative information for patient–doctor appointments within the hospital management system. It represents the core entity that coordinates interactions between patients, doctors, and administrative staff.

Appointments are typically created and scheduled by data entry staff and may later be used as the basis for examinations, laboratory tests, and clinical documentation.

---

## Table Structure

| Column Name   | Type        | Description |
|---------------|-------------|-------------|
| id            | uuid        | Primary key identifying the appointment |
| patient_id    | uuid        | Foreign key referencing `patient.id` |
| doctor_id     | uuid        | Foreign key referencing `doctor.id` |
| scheduled_at  | timestamptz | Start date and time of the appointment |
| end_time      | timestamptz | End date and time of the appointment |
| scheduled_by  | uuid        | Foreign key referencing `data_entry_staff.id` |
| status        | enum_status | Current appointment status (e.g. scheduled, completed, cancelled) |
| notes         | text        | Optional administrative or clinical notes |
| created_at    | timestamptz | Timestamp when the appointment was created |
| updated_at    | timestamptz | Timestamp when the appointment was last updated |

---

## Relationships

- **patient → appointment**:  
  One-to-many relationship. A patient may have multiple appointments over time.

- **doctor → appointment**:  
  One-to-many relationship. A doctor may be assigned to multiple appointments.

- **data_entry_staff → appointment**:  
  One-to-many relationship. Appointments are created and scheduled by data entry staff via `scheduled_by`.

- **appointment → examination**:  
  One-to-one (or one-to-many, depending on business rules) relationship. An appointment may result in one or more examinations.

---

## Access Control

- **Patients**:  
  Create, read, update their own appointment records. 

- **Doctors**:  
  Read access to appointments assigned to them, with permission to update status.

- **Data Entry Staff**:  
  Create, read, and update all appointments.

- **System Administrators**:  
  Full access for oversight, conflict resolution, and auditing.

---

## Security and Privacy Considerations

- The table contains sensitive scheduling and health-related metadata.
- Access is enforced using role-based and row-level security policies.
- Appointment status transitions should be validated to prevent inconsistent states.
- All changes are timestamped to support auditing and traceability.
- Notes should be carefully scoped to avoid unnecessary exposure of medical information.

