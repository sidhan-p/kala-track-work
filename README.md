# KalaTrack

**Celebrate Art. Organize Smart.**

KalaTrack is a responsive arts-festival management MVP. It includes a distinctive public landing page and an interactive organizer workspace with an overview, live timeline, team standings, event search, and event creation.

## Run locally

```bash
npm install
npm run dev
```

## Included modules

- Public festival experience and live-event callout
- Organizer dashboard with responsive navigation
- Event registry, search, and event creation
- Participant, scheduling, judging/results, reporting, and settings module shells
- Reusable design system using orange, black, blue, and yellow
- TypeScript-ready data models for backend wiring

## Recommended production backend

Connect Supabase for Authentication, Postgres data, Row Level Security, Realtime results, and Storage. Suggested roles: super admin, fest admin, event manager, judge, team manager, participant, and public viewer.

## Next implementation phases

1. Supabase schema and authentication
2. Registration approvals and participant ID cards
3. Drag-and-drop scheduling and conflict detection
4. Judge-specific scoring console
5. Automatic rankings, ties, appeals, and publication controls
6. PDF/Excel exports and certificates
7. Multi-fest SaaS billing and organization management
