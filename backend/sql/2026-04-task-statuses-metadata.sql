-- Extend task_statuses with metadata
ALTER TABLE task_statuses
  ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS terminal BOOLEAN DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS allow_actions JSONB;

-- Seed / upsert statuses (compat: ids 0-3 existing; add 4=cancelled,5=expired)
INSERT INTO task_statuses (id, code, label, sort_order, terminal)
VALUES
  (0, 'open', 'Disponibil', 0, FALSE),
  (1, 'accepted', 'Acceptat', 1, FALSE),
  (2, 'in_progress', 'In desfasurare', 2, FALSE),
  (3, 'done', 'Finalizat', 3, TRUE),
  (4, 'cancelled', 'Anulat', 98, TRUE),
  (5, 'expired', 'Expirat', 99, TRUE)
ON CONFLICT (id) DO UPDATE
  SET code = EXCLUDED.code,
      label = EXCLUDED.label,
      sort_order = EXCLUDED.sort_order,
      terminal = EXCLUDED.terminal;

CREATE INDEX IF NOT EXISTS idx_task_statuses_sort ON task_statuses(sort_order);
