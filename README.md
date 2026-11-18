# CMC Airport Ride Buddies
React + Vite frontend with Supabase Google login and Postgres RLS. Independent of the preview host; deploy `dist` on Cloudflare Pages or Vercel.

## Review the demo
Without environment variables, the app offers a clearly labeled local demo. Sample contacts use fictional numbers and example.com email addresses. Text and email actions do not launch messaging in demo. Demo state stays in the browser under `cmc-demo-v1`.

## Connect live login and data
1. Create a Supabase project. Run `supabase/schema.sql` once in SQL Editor.
2. Enable Google under Authentication → Sign In / Providers. Disable email/password, anonymous, and other providers. Leave email confirmation enabled. Do not enable unverified Google email sign-ins.
3. In Google Cloud Console, configure an OAuth web client requesting only openid, email, profile. Use Supabase's displayed callback URL as an authorized redirect URI. Configure the consent screen for your actual audience; testing mode only allows explicitly added test users. CMC Workspace administrators may restrict external apps.
4. Enter that client ID and secret in Supabase's Google provider settings. Never put the Google secret or Supabase service-role key in frontend environment variables.
5. Under Supabase URL configuration set the production Site URL and exact allowed redirect URLs. Add a localhost URL only if developing locally.
6. Set `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` in the build host. See `.env.example`. Rebuild after changes; Vite variables are embedded at build time.
7. Test a real student account. SQL checks Google identity, email_verified, confirmed email, and the exact student email domain. Supabase may omit Google's hd claim, so that field is not required. Checks use auth.identities, not editable user_metadata. Existing projects with the original hd check should run supabase/migrations/20261117_fix_cmc_validation.sql. Domain hint is only account-selection convenience.
8. Test a non-CMC Google account, signed-out database requests, and attempts to edit another person's ride. They must not access data. Verify new students cannot read peer listings before setup and returning students can return without duplicating records.

## Development and deployment
`npm install`, `npm run dev`, `npm test`, `npm run build`.
Build command: `npm run build`. Output: `dist`. The website is a single page with query-parameter trip links, so no special nested-route rewrite is required.
The private ChatGPT-hosted preview is a design review, not the student rollout. Move the source to your GitHub repository and connect it to your chosen host to serve students without a ChatGPT access gate.

## Implemented behavior
- Onboarding with contact info and one or both flight legs; no school/luggage/terminal question.
- Returning-user My rides; default inbound starting Nov 25, 2026 Pacific, outbound before.
- Independently editable/cancelable/restorable trips and three availability options.
- Same airport/direction, ±5 flight hours across midnight, ordered by difference. Broaden to all upcoming times. Past/full/canceled rides excluded. Available peer listings refresh every 30 seconds and on window focus.
- Clickable US-formatted phone numbers open text drafts with relevant flight details and a login-protected trip-management link. A separate copy icon copies the formatted number. Sender reviews and sends manually.
- Database prevents editing others' records. Once setup is completed, users retain browsing eligibility even if they cancel both listings. Suggested time-window filtering is a UX filter, not an additional confidentiality boundary between eligible students.

## Before launch
Live authentication, SQL policies, email delivery avoidance, and CMC administrator restrictions require a configured Supabase/Google project to verify. No credentials or real student data are included. Test messaging links on iOS, Android, and desktop: sms draft body handling varies by device. Confirm both legs, midnight matches, contact edits, full/canceled status, and cross-account access. Supabase Free may pause after inactivity; restore before the next event.

## Later events
Update the event title/copy, default form dates and default-tab boundary in `src/main.jsx`. This version intentionally has one record per student per direction; use a fresh project or archive/reset event records before another break.

## Add SNA and BUR to an existing database
Supported airports: LAX, ONT, SNA (John Wayne Airport), and BUR (Hollywood Burbank Airport).

For an existing Supabase project, run `supabase/migrations/20261118_add_sna_bur_airports.sql` in SQL Editor. It only expands the airport CHECK constraint; it does not update or delete ride rows, profiles, policies, or workflow. Do not rerun the full setup schema. New projects can use the updated `supabase/schema.sql`.
