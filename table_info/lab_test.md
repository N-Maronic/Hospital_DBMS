# Lab Test Table

The `lab_test` table stores information about laboratory tests ordered as part of a patient’s medical examination. It represents individual diagnostic tests requested by doctors and processed by laboratory staff, forming a critical link between clinical assessments and measurable test outcomes.

Each lab test is associated with a specific examination and is assigned to laboratory staff responsible for processing and tracking its status.

---

## Table Structure

| Column Name      | Type          | Description |
|------------------|---------------|-------------|
| id               | uuid          | Primary key identifying the laboratory test |
| examination_id   | uuid          | Foreign key referencing `examination.id` |
| lab_staff_id     | uuid          | Foreign key referencing `lab_staff.id` |
| test_type        | text          | Type of laboratory test (e.g. blood test, urine analysis) |
| status           | enum_lab      | Current status of the lab test (e.g. pending, in_progress, completed) |
| priority         | enum_priority | Priority level of the test (e.g. low, normal, high, urgent) |
| created_at       | timestamptz   | Timestamp when the test was created |
| updated_at       | timestamptz   | Timestamp when the test was last updated |

---

## Relationships

- **examination → lab_test**:  
  One-to-many relationship. An examination may result in multiple laboratory tests.

- **lab_staff → lab_test**:  
  One-to-many relationship. Laboratory staff may be assigned to multiple lab tests.

- **lab_test → lab_result**:  
  One-to-one relationship. Each lab test produces a single laboratory result.

---

## Access Control

- **Laboratory Staff**:  
  Read access to lab tests assigned to them, and additional right to update status only.

- **Doctors**:  
  Create lab tests related to examinations they conducted.

- **Patients**:  
  Read-only access to their own completed lab test information and results.

- **System Administrators**:  
  Full access for operational oversight, reassignment, and auditing.

---

## Security and Privacy Considerations

- The table contains sensitive diagnostic and operational data.
- Access is enforced using role-based and row-level security policies.
- Status and priority changes should be validated to prevent inconsistent or unsafe workflows.
- All updates are timestamped to support traceability and compliance.
- Data visibility is limited to roles directly involved in testing and care delivery.
