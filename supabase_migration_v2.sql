-- ============================================================
-- MLB Phrase Book v2 — Triple Master マイグレーション SQL
-- Supabase Dashboard > SQL Editor に貼り付けて Run
-- ============================================================

-- スペイン語フレーズ・IPA カラムを追加
ALTER TABLE public.phrases
  ADD COLUMN IF NOT EXISTS phrase_es TEXT NOT NULL DEFAULT '',
  ADD COLUMN IF NOT EXISTS ipa_es    TEXT NOT NULL DEFAULT '';

COMMENT ON COLUMN public.phrases.phrase_es IS 'スペイン語フレーズ（自動翻訳 or 手入力）';
COMMENT ON COLUMN public.phrases.ipa_es    IS 'スペイン語 IPA 発音記号';

-- 全文検索インデックスを再作成（スペイン語を含める）
DROP INDEX IF EXISTS idx_phrases_fts;
CREATE INDEX idx_phrases_fts ON public.phrases
  USING GIN (to_tsvector('simple',
    phrase || ' ' || COALESCE(meaning, '') || ' ' || COALESCE(phrase_es, '')
  ));

-- 確認クエリ
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_name = 'phrases'
  AND column_name IN ('phrase_es', 'ipa_es');
