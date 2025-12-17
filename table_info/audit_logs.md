# Audit Logs Table

The `audit_logs` table records security-relevant and operational events within the hospital management system. It provides an immutable audit trail of user actions performed on critical system objects, supporting accountability, forensic analysis, and compliance with regulatory requirements.

Audit logs are generated automatically by the system whenever sensitive operations are performed, such as creating, updating, or deleting domain entities.

---

## Table Structure

| Column Name  | Type              | Description |
|--------------|-------------------|-------------|
| id           | uuid              | Primary key identifying the audit log entry |
| user_id      | uuid              | Foreign key referencing `user.id` of the acting user |
| action       | text              | Action performed (e.g. create, update, delete, view) |
| object_type  | audit_object_type | Type of object affected (e.g. appointment, examination, lab_test) |
| object_id    | uuid              | Identifier of the affected object |
| IP_address   | text              | IP address from which the action was performed |
| created_at   | timestamptz       | Timestamp when the audit event was recorded |

---

## Relationships

- **user → audit_logs**:  
  One-to-many relationship. A user may generate multiple audit log entries.

- **audit_logs → domain objects**:  
  Polymorphic relationship. Each audit entry references a specific object via (`object_type`, `object_id`).

---

## Access Control

- **System Administrators**:  
  Read-only access to all audit log entries for monitoring, investigation, and compliance.

- **Auditors / Compliance Officers**:  
  Read-only access for security reviews and regulatory audits.

- **All Other Roles**:  
  No direct access.

---

## Security and Privacy Considerations

- Audit logs are append-only and must never be
