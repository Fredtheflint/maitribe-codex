-- MaiTribe context injection query
-- Parameter: $1 = user_id (uuid)

with user_data as (
  select
    u.name,
    u.display_name,
    u.language,
    u.timezone,
    u.subscription_tier,
    u.astrology_enabled,
    u.human_design_enabled,
    u.hd_type,
    u.hd_profile,
    u.sun_sign,
    u.rising_sign
  from public.users u
  where u.id = $1
),
active_identity as (
  select full_text, one_liner, sentences
  from public.identities
  where user_id = $1 and is_active = true
  limit 1
),
recent_checkins as (
  select body, mind, soul, energy, note, created_at
  from public.checkins
  where user_id = $1
  order by created_at desc
  limit 3
),
upcoming_events as (
  select title, description, event_time
  from public.events
  where user_id = $1
    and status = 'upcoming'
    and event_time > now()
  order by event_time asc
  limit 5
),
recent_topics as (
  select topics, summary
  from public.conversations
  where user_id = $1
    and topics is not null
  order by created_at desc
  limit 5
),
today_transits as (
  select daily_insight, hd_daily_gate, hd_gate_description
  from public.astro_transits
  where user_id = $1
    and transit_date = current_date
  limit 1
)
select
  json_build_object(
    'user', (select row_to_json(user_data) from user_data),
    'identity', (select row_to_json(active_identity) from active_identity),
    'recent_checkins', (select json_agg(row_to_json(recent_checkins)) from recent_checkins),
    'upcoming_events', (select json_agg(row_to_json(upcoming_events)) from upcoming_events),
    'recent_topics', (select json_agg(row_to_json(recent_topics)) from recent_topics),
    'today_transits', (select row_to_json(today_transits) from today_transits)
  ) as context;
