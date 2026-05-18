-- ============================================================
-- MLB Phrase Book v3 — words_es マイグレーション SQL
-- Supabase Dashboard > SQL Editor に貼り付けて Run
-- ============================================================

-- スペイン語単語解説カラムを追加
ALTER TABLE public.phrases
  ADD COLUMN IF NOT EXISTS words_es JSONB NOT NULL DEFAULT '[]';

COMMENT ON COLUMN public.phrases.words_es
  IS 'スペイン語単語解説 [{w, r, m, note}] 形式（自動生成 or 手入力）';

-- 確認クエリ
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'phrases'
  AND column_name = 'words_es';
