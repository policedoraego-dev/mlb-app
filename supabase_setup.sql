-- ============================================================
-- MLB Phrase Book — Supabase セットアップ SQL
-- 実行方法: Supabase Dashboard > SQL Editor に貼り付けて Run
-- ============================================================

-- ── 0. UUID 拡張を有効化 ──────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ── 1. phrases テーブル ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.phrases (
  id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  phrase      TEXT          NOT NULL,
  ipa         TEXT          NOT NULL DEFAULT '',
  reading     TEXT          NOT NULL DEFAULT '',
  meaning     TEXT          NOT NULL DEFAULT '',
  category    TEXT          NOT NULL DEFAULT 'treatment',
  example     TEXT          NOT NULL DEFAULT '',
  tags        TEXT[]        NOT NULL DEFAULT '{}',
  starred     BOOLEAN       NOT NULL DEFAULT FALSE,
  words       JSONB         NOT NULL DEFAULT '[]',
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
  updated_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.phrases             IS 'MLB マッサージセラピスト向け英語フレーズ帳';
COMMENT ON COLUMN public.phrases.ipa         IS '発音記号（IPA）例: /wɛr dʌz ɪt hɜːrt/';
COMMENT ON COLUMN public.phrases.reading     IS 'カタカナ読み';
COMMENT ON COLUMN public.phrases.words       IS '[{w, r, m, note}] 形式の単語解説リスト';
COMMENT ON COLUMN public.phrases.tags        IS '検索用タグ配列';


-- ── 2. categories テーブル ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.categories (
  id          UUID          PRIMARY KEY DEFAULT uuid_generate_v4(),
  key         TEXT          NOT NULL UNIQUE,
  label       TEXT          NOT NULL,
  palette_idx INTEGER       NOT NULL DEFAULT 0 CHECK (palette_idx BETWEEN 0 AND 7),
  built_in    BOOLEAN       NOT NULL DEFAULT FALSE,
  sort_order  INTEGER       NOT NULL DEFAULT 100,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE  public.categories              IS 'フレーズのグループ（カテゴリ）';
COMMENT ON COLUMN public.categories.key          IS 'アプリ内部キー（英数字・ハイフンのみ）';
COMMENT ON COLUMN public.categories.palette_idx  IS 'カラーパレットインデックス 0-7';
COMMENT ON COLUMN public.categories.built_in     IS 'TRUE = 削除不可のシステムカテゴリ';


-- ── 3. updated_at 自動更新トリガー ───────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_phrases_updated_at ON public.phrases;
CREATE TRIGGER trg_phrases_updated_at
  BEFORE UPDATE ON public.phrases
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();


-- ── 4. インデックス ───────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_phrases_category   ON public.phrases (category);
CREATE INDEX IF NOT EXISTS idx_phrases_starred    ON public.phrases (starred) WHERE starred = TRUE;
CREATE INDEX IF NOT EXISTS idx_phrases_created_at ON public.phrases (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_categories_order   ON public.categories (sort_order, built_in);
-- 全文検索用（日本語の意味 + 英語フレーズ）
CREATE INDEX IF NOT EXISTS idx_phrases_fts ON public.phrases
  USING GIN (to_tsvector('english', phrase || ' ' || COALESCE(meaning, '')));


-- ── 5. Row Level Security (RLS) ──────────────────────────────
--
--  現在の設定: 認証なし・パブリックアクセス（個人利用向け）
--  ※ 複数ユーザー対応が必要になったら下の「将来の拡張」セクションを参照
--
ALTER TABLE public.phrases     ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories  ENABLE ROW LEVEL SECURITY;

-- phrases: 全操作を anon / authenticated に許可
DROP POLICY IF EXISTS "phrases_select" ON public.phrases;
DROP POLICY IF EXISTS "phrases_insert" ON public.phrases;
DROP POLICY IF EXISTS "phrases_update" ON public.phrases;
DROP POLICY IF EXISTS "phrases_delete" ON public.phrases;

CREATE POLICY "phrases_select" ON public.phrases FOR SELECT USING (true);
CREATE POLICY "phrases_insert" ON public.phrases FOR INSERT WITH CHECK (true);
CREATE POLICY "phrases_update" ON public.phrases FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "phrases_delete" ON public.phrases FOR DELETE USING (true);

-- categories: 全操作を許可（built_in=TRUE の行は DELETE を制限）
DROP POLICY IF EXISTS "categories_select" ON public.categories;
DROP POLICY IF EXISTS "categories_insert" ON public.categories;
DROP POLICY IF EXISTS "categories_update" ON public.categories;
DROP POLICY IF EXISTS "categories_delete" ON public.categories;

CREATE POLICY "categories_select" ON public.categories FOR SELECT USING (true);
CREATE POLICY "categories_insert" ON public.categories FOR INSERT WITH CHECK (true);
CREATE POLICY "categories_update" ON public.categories FOR UPDATE USING (true) WITH CHECK (true);
CREATE POLICY "categories_delete" ON public.categories FOR DELETE USING (NOT built_in);


-- ── 6. デフォルトカテゴリのシードデータ ─────────────────────
INSERT INTO public.categories (key, label, palette_idx, built_in, sort_order) VALUES
  ('treatment', '🩺 治療',        0, TRUE, 10),
  ('clubhouse',  '🏟 クラブハウス', 1, TRUE, 20),
  ('game-day',   '⚾ ゲームデー',  2, TRUE, 30),
  ('recovery',   '🧊 リカバリー',  3, TRUE, 40),
  ('injury',     '🚨 インジャリー', 4, TRUE, 50)
ON CONFLICT (key) DO UPDATE SET
  label       = EXCLUDED.label,
  palette_idx = EXCLUDED.palette_idx,
  built_in    = EXCLUDED.built_in,
  sort_order  = EXCLUDED.sort_order;


-- ── 7. 動作確認クエリ ─────────────────────────────────────────
-- 下記を実行してテーブルと RLS が正しく設定されているか確認してください
SELECT 'phrases テーブル'    AS table_name, count(*) AS rows FROM public.phrases
UNION ALL
SELECT 'categories テーブル' AS table_name, count(*) AS rows FROM public.categories;


-- ============================================================
-- 【将来の拡張】マルチユーザー対応（認証ありの RLS）
-- 必要になったときにこちらのポリシーに切り替えてください
-- ============================================================
/*
-- phrases テーブルに user_id を追加
ALTER TABLE public.phrases ADD COLUMN IF NOT EXISTS
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;

-- RLS を認証ユーザーのみに制限
DROP POLICY IF EXISTS "phrases_select" ON public.phrases;
DROP POLICY IF EXISTS "phrases_insert" ON public.phrases;
DROP POLICY IF EXISTS "phrases_update" ON public.phrases;
DROP POLICY IF EXISTS "phrases_delete" ON public.phrases;

CREATE POLICY "phrases_select" ON public.phrases FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "phrases_insert" ON public.phrases FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "phrases_update" ON public.phrases FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "phrases_delete" ON public.phrases FOR DELETE USING (auth.uid() = user_id);
*/
