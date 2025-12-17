# Examination Table

The `examination` table stores clinical findings and observations resulting from a patient’s appointment with a doctor. It represents the medical assessment phase of the care process and serves as a bridge between appointments and downstream laboratory testing.

Each examination is associated with a specific appointment, ensuring that clinical data is always contextualized within a scheduled patient–doctor interaction.

---

## Table Structure

| Column Name     | Type        | Description |
|-----------------|-------------|-------------|
| id              | uuid        | Primary key identifying the examination |
| appointment_id  | uuid        | Foreign key referencing `appointment.id` |
| diagnosis       | text        | Clinical diagnosis made during the examination |
| notes           | text        | Additional examination notes or observations |
| created_at      | timestamptz | Timestamp when the examination record was created |
| updated_at      | timestamptz | Timestamp when the examination record was last updated |

---

## Relationships

- **appointment → examination**:  
  One-to-one relationship (or one-to-many, depending on medical workflow). Each examination is linked to a specific appointment.

- **examination → lab_test**:  
  One-to-many relationship. An examination may result in multiple laboratory tests being ordered.

---

## Access Control

- **Doctors**:  
  Read-only access to examinations associated with their own appointments.

- **Laboratory Staff**:  
  Create, read and update access for examinations relevant to assigned laboratory tests.

- **Patients**:  
  Read-only access to finalized examination results and diagnoses.

- **System Administrators**:  
  Full access for clinical oversight, quality control, and auditing.

---

## Security and Privacy Considerations

- The table contains sensitive medical and diagnostic information.
- Access is enforced using strict role-based and row-level security policies.
- Examination records should be immutable after finalization, except by authorized administrators.
- All modifications are timestamped to support clinical traceability and auditing.
- Data exposure is minimized to ensure compliance with medical data protection regulations.
