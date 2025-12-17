# Patients Table

The `patient` table stores medical and administrative information specific to patients registered in the hospital management system. It extends the general user information stored in the `user` table and is used to link patients to appointments, examinations, and laboratory tests.

Each patient entry is associated with exactly one user account, enabling role-based access control and ensuring that patients can only access their own medical data.

---

## Table Structure

| Column Name          | Type        | Description |
|---------------------|-------------|-------------|
| id                  | uuid        | Primary key identifying the patient |
| user_id             | uuid        | Foreign key referencing `user.id` |
| date_of_birth       | date        | Patient’s date of birth |
| insurance_provider  | text        | Name of the patient’s insurance provider |
| insurance_number    | text        | Insurance identification number |
| created_at          | timestamptz | Timestamp when the record was created |
| updated_at          | timestamptz | Timestamp when the record was last updated |

---

## Relationships

- **user → patient**:  
  One-to-one relationship. Each patient record is linked to a single user account via `user_id`.

---

## Access Control

- **Patients**:  
  Read-only access to their own patient record.

- **Data Entry Staff**:  
  Create and update patient records.

- **Doctors and Laboratory Staff**:  
  Read access for patient identification and medical context.

- **System Administrators**:  
  Full access for management and auditing purposes.

---

## Security and Privacy Considerations

- The table contains personally identifiable and sensitive medical information.
- Access is strictly controlled using role-based policies.
- All modifications are timestamped to support auditing and traceability.
- Data exposure is limited to the minimum necessary for each role to ensure confidentiality and compliance with data protection regulations.
