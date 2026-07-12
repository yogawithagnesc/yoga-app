DELETE FROM public.videos WHERE title IN ('Intro to Vinyasa Flow', 'Morning Energizer', 'Restorative Bedtime');

INSERT INTO public.videos (title, description, mux_playback_id, duration_seconds, is_published, teacher_id, studio_id, created_at)
VALUES
  ('Intro to Vinyasa Flow', 'A foundational Vinyasa class linking breath to movement. Build heat through a balanced sequence of standing poses, forward folds, and a grounding savasana.', 'QSq3Bgs005a0132Qb00AYgn7fyZggqHZWVZxoUrqx1Gzig', 1260, true, NULL, NULL, now()),
  ('Morning Energizer', 'Wake up your body and mind with this 15-minute sequence designed to build energy and focus for the day ahead.', 'test0001a000a132Qb00AYgn7fyZggqHZWVZxoUrqx1Gzig', 900, true, NULL, NULL, now()),
  ('Restorative Bedtime', 'Wind down in the evening with gentle stretches, breath work, and relaxation techniques. Perfect before sleep.', 'test0002a000a132Qb00AYgn7fyZggqHZWVZxoUrqx1Gzig', 720, true, NULL, NULL, now());
