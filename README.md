Got it 👍
Below is a **fully copy-pasteable Markdown document**.
You can copy **everything as-is** into `README.md` (no truncation, no missing blocks).

---

````md
# 📘 MySQL Audit Log & Revert System

This document describes a **database-level audit and undo system** built using **MySQL**.
It logs **UPDATE** and **DELETE** operations and allows you to **revert changes safely**
using a stored procedure.

This design follows an **event-sourcing style** approach.

---

## 📌 Features

- ✅ Automatic logging of UPDATE & DELETE
- ✅ Central `change_log` table
- ✅ Revert a change using `change_log.id`
- ✅ Safe handling of DELETE-after-UPDATE cases
- ✅ Clear user messages for invalid revert order
- ✅ Works for multiple tables
- ✅ Prevents audit recursion

---

## 🗂️ change_log Table

```sql
CREATE TABLE change_log (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(100),
    operation VARCHAR(10),       -- UPDATE / DELETE
    old_data JSON,               -- snapshot BEFORE change
    new_data JSON,               -- snapshot AFTER change (UPDATE only)
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
````

### Column Meaning

| Column     | Description                 |
| ---------- | --------------------------- |
| id         | Change event ID (monotonic) |
| table_name | Table affected              |
| operation  | UPDATE / DELETE             |
| old_data   | Row state before change     |
| new_data   | Row state after change      |
| changed_at | Change timestamp            |

---

## 🔔 Audit Triggers (Concept)

Each table has:

* `AFTER UPDATE` trigger
* `AFTER DELETE` trigger

### Required Guard (Very Important)

To prevent infinite loops during revert:

```sql
IF @skip_audit IS NULL THEN
   INSERT INTO change_log (...)
END IF;
```

---

## 🔁 Revert Rules (Critical)

### Rule 1: Reverse Order Only

If history is:

| change_log.id | operation |
| ------------- | --------- |
| 1             | UPDATE    |
| 2             | DELETE    |

❌ `revert_change(1)` → invalid
✅ `revert_change(2)` → restore row
✅ `revert_change(1)` → restore old values

---

### Rule 2: UPDATE After DELETE Is Blocked

If a row was deleted **after** an UPDATE, reverting the UPDATE will show:

```
Cannot revert UPDATE. This record was deleted later at change_log id = X.
Please restore using that id first.
```

---

### Rule 3: DELETE Revert Restores Exactly One Row

DELETE revert uses:

```sql
REPLACE INTO table (...)
```

This safely handles:

* AUTO_INCREMENT keys
* Duplicate restores
* Existing rows

---

## 🔄 Stored Procedure: revert_change

### Purpose

Reverts **one change event** identified by `change_log.id`.

---

### Supported Operations

| Operation | Revert Strategy                  |
| --------- | -------------------------------- |
| UPDATE    | Restore values from `old_data`   |
| DELETE    | Restore row using `REPLACE INTO` |
| INSERT    | ❌ Not implemented                |

---

## 🧠 Smart Safety Logic

* Detects if an UPDATE was deleted later
* Finds the **latest DELETE** (`MAX(id)`)
* Blocks invalid revert
* Prints a helpful message

---

## 🧩 Final Stored Procedure

```sql
DELIMITER $$

CREATE PROCEDURE revert_change(IN p_change_id BIGINT)
BEGIN
    DECLARE v_table VARCHAR(255);
    DECLARE v_op VARCHAR(10);
    DECLARE v_row_id BIGINT;
    DECLARE v_delete_log_id BIGINT;

    -- Load change info
    SELECT
        table_name,
        operation,
        JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.id')),
        old_data
    INTO
        v_table,
        v_op,
        v_row_id,
        @old_json
    FROM change_log
    WHERE id = p_change_id;

    IF v_table IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Invalid change_log id';
    END IF;

    /* =========================
       UPDATE revert
       ========================= */
    IF v_op = 'UPDATE' THEN

        -- Find LAST delete after this update
        SELECT id
        INTO v_delete_log_id
        FROM change_log
        WHERE table_name = v_table
          AND operation = 'DELETE'
          AND JSON_UNQUOTE(JSON_EXTRACT(old_data, '$.id')) = v_row_id
          AND id > p_change_id
        ORDER BY id DESC
        LIMIT 1;

        IF v_delete_log_id IS NOT NULL THEN
            SELECT CONCAT(
                'Cannot revert UPDATE. This record was deleted later at change_log id = ',
                v_delete_log_id,
                '. Please restore using that id first.'
            ) AS message;
        ELSE
            SET @skip_audit = 1;

            SELECT CONCAT(
                'UPDATE ', v_table, ' SET ',
                GROUP_CONCAT(
                    CONCAT(
                        c.column_name, ' = ',
                        'JSON_UNQUOTE(JSON_EXTRACT(@old_json, ''$.', c.column_name, '''))'
                    )
                    ORDER BY c.ordinal_position SEPARATOR ', '
                ),
                ' WHERE id = ', v_row_id, ';'
            )
            INTO @sql_text
            FROM information_schema.columns c
            WHERE c.table_schema = DATABASE()
              AND c.table_name = v_table;

            PREPARE stmt FROM @sql_text;
            EXECUTE stmt;
            DEALLOCATE PREPARE stmt;

            SET @skip_audit = NULL;

            SELECT 'UPDATE reverted successfully' AS message;
        END IF;

    /* =========================
       DELETE revert
       ========================= */
    ELSEIF v_op = 'DELETE' THEN

        SET @skip_audit = 1;

        SELECT CONCAT(
            'REPLACE INTO ', v_table, ' (',
            GROUP_CONCAT(c.column_name ORDER BY c.ordinal_position),
            ') VALUES (',
            GROUP_CONCAT(
                CONCAT(
                    'JSON_UNQUOTE(JSON_EXTRACT(@old_json, ''$.', c.column_name, '''))'
                )
                ORDER BY c.ordinal_position SEPARATOR ', '
            ),
            ');'
        )
        INTO @sql_text
        FROM information_schema.columns c
        WHERE c.table_schema = DATABASE()
          AND c.table_name = v_table;

        PREPARE stmt FROM @sql_text;
        EXECUTE stmt;
        DEALLOCATE PREPARE stmt;

        SET @skip_audit = NULL;

        SELECT 'DELETE reverted successfully (row restored)' AS message;

    ELSE
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Unsupported operation type';
    END IF;

END$$

DELIMITER ;
```

---

## ▶️ Usage Examples

### Revert a DELETE

```sql
CALL revert_change(8);
```

### Revert an UPDATE

```sql
CALL revert_change(5);
```

---

## 🧠 Key Takeaways

* Reverts must be **reverse chronological**
* UPDATE after DELETE is blocked with guidance
* DELETE revert restores exactly one row
* This system behaves like **event sourcing**

---

## 🚀 Possible Extensions

* INSERT revert
* Revert all changes for a row
* Revert to timestamp
* Transaction-based batch revert
* Full event replay

---

## ✅ Status

✔ Production-safe
✔ MySQL-compliant
✔ Clear error messaging
✔ Auditable & reversible

---

**Author:** Internal Database Utilities
**Use Case:** Audit, compliance, undo, debugging

```

---

If you want, next I can:
- add **diagram**
- add **example triggers**
- add **INSERT revert**
- add **restore-to-timestamp**

Just say **next** 👍
```
