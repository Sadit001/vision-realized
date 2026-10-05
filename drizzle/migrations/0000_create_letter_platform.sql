CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY,
  email text NOT NULL,
  phone text,
  unique_slug text NOT NULL UNIQUE DEFAULT (lower(encode(extensions.gen_random_bytes(8), 'hex'))),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
GRANT SELECT, INSERT, UPDATE ON public.profiles TO authenticated;
GRANT ALL ON public.profiles TO service_role;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own profile" ON public.profiles FOR SELECT TO authenticated USING (auth.uid() = id);
CREATE POLICY "Users insert own profile" ON public.profiles FOR INSERT TO authenticated WITH CHECK (auth.uid() = id);
CREATE POLICY "Users update own profile" ON public.profiles FOR UPDATE TO authenticated USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

CREATE TABLE public.messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL,
  message_body text NOT NULL,
  is_read boolean NOT NULL DEFAULT false,
  status text NOT NULL DEFAULT 'delivered',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT message_length CHECK (char_length(message_body) BETWEEN 1 AND 1200)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON public.messages TO authenticated;
GRANT INSERT ON public.messages TO anon;
GRANT ALL ON public.messages TO service_role;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Recipients read own letters" ON public.messages FOR SELECT TO authenticated USING (auth.uid() = recipient_id);
CREATE POLICY "Recipients update own letters" ON public.messages FOR UPDATE TO authenticated USING (auth.uid() = recipient_id) WITH CHECK (auth.uid() = recipient_id);
CREATE POLICY "Recipients delete own letters" ON public.messages FOR DELETE TO authenticated USING (auth.uid() = recipient_id);

CREATE OR REPLACE FUNCTION public.recipient_exists(_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT EXISTS (SELECT 1 FROM public.profiles WHERE id = _id) $$;
GRANT EXECUTE ON FUNCTION public.recipient_exists(uuid) TO anon, authenticated;

CREATE POLICY "Anyone sends a valid anonymous letter" ON public.messages FOR INSERT TO anon, authenticated WITH CHECK (
  status = 'delivered' AND is_read = false AND public.recipient_exists(recipient_id)
);

CREATE INDEX messages_recipient_created_idx ON public.messages (recipient_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, email, phone)
  VALUES (NEW.id, COALESCE(NEW.email, ''), NEW.raw_user_meta_data ->> 'phone')
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.resolve_letter_recipient(slug_input text)
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$ SELECT id FROM public.profiles WHERE unique_slug = slug_input LIMIT 1 $$;
GRANT EXECUTE ON FUNCTION public.resolve_letter_recipient(text) TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.touch_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public
AS $$ BEGIN NEW.updated_at = now(); RETURN NEW; END; $$;
CREATE TRIGGER profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();
CREATE TRIGGER messages_updated_at BEFORE UPDATE ON public.messages FOR EACH ROW EXECUTE FUNCTION public.touch_updated_at();

ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;