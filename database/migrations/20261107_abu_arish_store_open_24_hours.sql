-- Abu Arish store only. Delivery, pickup, human support and Al-Aridhah are unchanged.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '20s';

do $hours$
declare
  v_instructions text;
  v_line text;
  v_lines text[] := array[]::text[];
  v_skipping boolean := false;
  v_written boolean := false;
  v_hours text := $copy$## Store Opening Hours | ساعات عمل الفروع
- Abu Arish | أبو عريش: OPEN 24 HOURS every day, Saudi Arabia time (Asia/Riyadh).
- فرع أبو عريش مفتوح ٢٤ ساعة يوميًا، طوال أيام الأسبوع.
- Al Aridah | العارضة: 6:00 AM to 2:00 AM the following day daily, Saudi Arabia time (Asia/Riyadh).
- فرع العارضة يعمل يوميًا من الساعة ٦ صباحًا إلى ٢ صباحًا من اليوم التالي بتوقيت السعودية.
- Branch-specific schedules above take priority over shared account business hours. The shared account is available 24 hours because Abu Arish is open 24 hours; this does NOT mean Al Aridah is open 24 hours.
- If the branch is unspecified, explain the two different schedules. Do not repeat the obsolete claim that both branches close at 2 AM or that neither branch is open 24 hours.
- These are physical store opening hours. Human support remains 12:00 PM to 8:00 PM daily. Delivery and pickup ordering availability remain controlled by their separate existing settings and are currently unavailable.
- Use the current Saudi time when assessing whether Al Aridah is open; its 2:00 AM closing time is exclusive. Abu Arish is open throughout the day and night.
$copy$;
begin
  perform 1 from public.branches b where b.id=1 and b.location_en ilike '%Abu%Arish%' for update;
  if not found then raise exception 'Expected Abu Arish branch 1 was not found'; end if;
  select c.custom_instructions into strict v_instructions
    from public.wa_ai_bot_config c where c.id='00000000-0000-0000-0000-000000000001' for update;
  perform 1 from public.wa_settings s
    where s.id='dc4da415-957c-43b9-a00e-bcd9c2ef383d'
      and s.wa_account_id=(select c.wa_account_id from public.wa_ai_bot_config c where c.id='00000000-0000-0000-0000-000000000001')
    for update;
  if not found then raise exception 'Expected customer WhatsApp settings were not found'; end if;

  -- Replace only the store-hours section, preserving all other AI guidance.
  foreach v_line in array regexp_split_to_array(coalesce(v_instructions,''), E'\n') loop
    if v_line like '## Store Opening Hours%' then
      if not v_written then v_lines := array_append(v_lines,v_hours); v_written := true; end if;
      v_skipping := true;
    elsif v_skipping and v_line like '## %' then
      v_skipping := false;
      v_lines := array_append(v_lines,v_line);
    elsif not v_skipping then
      v_lines := array_append(v_lines,v_line);
    end if;
  end loop;
  if not v_written then v_lines := array_append(v_lines,E'\n' || v_hours); end if;

  update public.branches set is_24_hours=true, operating_start_time=null, operating_end_time=null where id=1;
  update public.wa_ai_bot_config set custom_instructions=array_to_string(v_lines,E'\n')
    where id='00000000-0000-0000-0000-000000000001';
  update public.wa_settings
    set business_hours=(select jsonb_object_agg(day,jsonb_build_object('open',true,'allDay',true,'start','00:00','end','23:59'))
      from unnest(array['sunday','monday','tuesday','wednesday','thursday','friday','saturday']) day),
      outside_hours_message='Abu Arish is open 24 hours every day. Al Aridah opens daily from 6:00 AM to 2:00 AM the following day, Saudi time. These are different branch schedules; the shared 24-hour account schedule must not be applied to Al Aridah. Automated chat remains available. Human support: 12:00 PM to 8:00 PM Saudi time. Delivery and pickup availability are separate.'
    where id='dc4da415-957c-43b9-a00e-bcd9c2ef383d';
end $hours$;

commit;
