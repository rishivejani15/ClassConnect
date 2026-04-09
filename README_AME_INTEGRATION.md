# AME Integration README

## What this is
This document explains the recent Adaptive Mastery Engine (AME) integration work in ClassConnect.
The integration goal is to add AME intelligence in safe phases while keeping existing Firebase and Gemini flows fully usable as fallback.

## Scope of recent work
- Repository branch: ame-backend
- Integration target: https://rudraaaa76-ame-backend.hf.space
- Completed phases:
1. Phase 1: Dual-write student events
2. Phase 2: Dual-read student recommendation
3. Phase 3: Teacher analytics enrichment
- Not completed in this cycle:
1. Phase 4: Parent report enrichment

## Recent commits
1. c21a133 - feat(ame): phase 1 dual-write events with fail-open fallback
2. 274c14a - feat(ame): phase 2 dual-read focus recommendations with weakConcept fallback
3. cd068b0 - feat(ame-phase3): integrate teacher dashboard AME analytics with fail-open fallback

## Changes made by phase

## Phase 1: Dual-write only (no behavior break)
### Objective
Send learning events to AME in the background while preserving existing quiz, mastery, and weakConcept Firestore behavior.

### Files changed
1. demo/lib/services/ame_api_service.dart
2. demo/lib/screens/student/student_quiz_attempt_screen.dart
3. demo/lib/screens/student/student_practice_quiz_attempt_screen.dart
4. demo/lib/screens/student/concept_validation_screen.dart
5. demo/lib/screens/student/concept_video_validation_screen.dart

### What changed
1. Added AME client with retry, timeout, and fail-open behavior.
2. Sent assignment events after chapter quiz submission.
3. Sent practice events after concept practice quiz submission.
4. Sent explanation events after successful text and video validation.
5. AME writes are async and non-blocking.

### Fallback guarantee
If AME call fails, the app still completes quiz and validation flow using existing Firestore logic.

## Phase 2: Dual-read recommendation with fallback
### Objective
Use AME focus recommendation for concept ordering, while keeping weakConcept Firestore logic as default-safe path.

### Files changed
1. demo/lib/config/feature_flags.dart
2. demo/lib/screens/student/practice_concept_list_screen.dart
3. demo/lib/services/ame_api_service.dart

### What changed
1. Added feature flag AME_ENABLED with default false.
2. Practice concept screen optionally fetches focus recommendation from AME.
3. If AME payload is missing or invalid, screen falls back to existing weakConcept list.
4. No spinner loop dependency on AME.

### Fallback guarantee
When AME is disabled or unavailable, concept list still renders from Firestore weakConcepts.

## Phase 3: Teacher analytics enrichment with fallback
### Objective
Add AME-based weak concept, risk, and intervention analytics to teacher dashboard without breaking current dashboard rendering.

### Files changed
1. demo/lib/services/ame_api_service.dart
2. demo/lib/screens/teacher/teacher_dashboard_screen.dart

### What changed
1. Added AME class-level read methods:
   - getClassWeakConcepts
   - getClassRisk
   - getClassIntervention
2. Added robust JSON decode guards in AME client.
3. Teacher dashboard now:
   - builds fallback analytics first from Firestore data,
   - then performs background AME refresh if flag enabled,
   - merges AME analytics only when valid.
4. Added dashboard sections:
   - Risk Overview
   - Recommendation Panel
5. Added source labeling for analytics display:
   - Source: AME analytics
   - Source: Firestore fallback

### Fallback guarantee
Dashboard remains functional even when AME fails, times out, or returns invalid payload.

## Reliability policy implemented
AME network policy in app client:
1. Timeout: 6 seconds
2. Retries: 2 retries (3 total attempts)
3. Backoff: exponential from 400 ms
4. Behavior on failure: fail-open fallback (do not block student or teacher flow)

## Exact app flow now

## 1. App startup and routing
1. App initializes Firebase and Supabase.
2. Daily parent report scheduler is initialized.
3. Auth wrapper routes user to student or teacher area.

## 2. Student learning flow (with AME dual-write)
1. Student takes chapter quiz.
2. Firestore quiz attempt and weakConcepts are saved.
3. AME assignment events are sent in background.
4. Student practices weak concepts.
5. AME practice event is sent in background.
6. Student validates concept by text or video.
7. Firestore concept mastery is updated.
8. AME explanation event is sent in background.

## 3. Student recommendation flow (Phase 2)
1. Practice concept list loads Firestore weakConcepts.
2. If AME_ENABLED is true, app requests focus concept from AME.
3. If valid AME response exists, focus concept is highlighted and prioritized.
4. If AME fails or payload is invalid, weakConcept fallback remains active.

## 4. Teacher dashboard flow (Phase 3)
1. Dashboard loads base metrics from Firestore.
2. Dashboard builds fallback risk and intervention from existing data.
3. If AME_ENABLED is true, background AME class analytics fetch starts.
4. If AME returns valid data, weak concepts, risk cards, and recommendation panel are enriched.
5. If AME fails, fallback data remains visible and stable.

## 5. Parent report flow (current state)
1. Daily scheduler triggers report generation.
2. Student report is generated from Firestore attendance, quiz, weakConcept, PBL, and community data.
3. Report PDF is built and emailed to parent.
4. This flow is currently independent of AME.

## How to verify API is working

## A. Basic endpoint availability
Check root endpoint:
1. GET https://rudraaaa76-ame-backend.hf.space/
2. Expected: HTTP 200 and health payload

## B. Core AME endpoint checks
Check these endpoints with valid IDs and payloads:
1. POST /ame/update-event
2. GET /ame/student/{student_id}/focus/{class_id}
3. GET /ame/class/{class_id}/concepts/weak
4. GET /ame/class/{class_id}/risk
5. GET /ame/class/{class_id}/intervention

Success criteria:
1. HTTP 2xx responses
2. JSON response shape matches app expectations

## C. In-app evidence of AME working
1. Console logs include AME success lines from AmeApiService.
2. Practice screen shows AME recommendation card when enabled and valid.
3. Teacher dashboard shows AME source label in recommendation panel.

## D. Current observed status during last check
1. Root endpoint returned 200.
2. Core endpoints tested with demo IDs returned 500.
3. App still works due fail-open fallback behavior.

## How to verify app is fully working

## 1. Static and tests
1. Run flutter analyze in demo.
2. Run flutter test in demo.
3. Track pre-existing vs newly introduced failures.

## 2. Functional smoke checks
1. Student chapter quiz submit works even if AME is unavailable.
2. Student practice and validation complete normally.
3. Practice concept list renders with Firestore fallback when AME fails.
4. Teacher dashboard loads with fallback risk and recommendation sections.
5. Parent report generation and email pipeline continue to work.

## 3. Feature-flag checks
1. AME_ENABLED=false:
   - AME reads are off.
   - Existing behavior remains.
2. AME_ENABLED=true:
   - AME reads are attempted.
   - Fallback remains active on failure.

## How AME works technically

## 1. Event ingestion and mastery update
1. App sends event payload: student_id, concept_id, class_id, event_type, score, timestamp.
2. Backend loads current mastery record for student-concept-class.
3. If missing, backend initializes default mastery state.
4. Backend applies weighted mastery update using event type weight.
5. Backend applies IRT update and BKT probability update.
6. Backend computes hybrid mastery:
   - 70 percent weighted mastery
   - 30 percent BKT mastery (BKT probability x 100)
7. Backend updates trend and confidence.
8. Backend upserts record in SQL table with ON CONFLICT update.

## 2. Student focus recommendation
1. Backend ranks concepts by priority:
   - lower mastery means higher priority,
   - lower confidence means higher priority,
   - low attendance adds penalty.
2. Top concept becomes focus_concept.
3. Recommendation action is selected based on mastery, confidence, trend, and attendance.

## 3. Class-level analytics
1. Weak concepts endpoint aggregates average mastery and count below threshold.
2. Risk endpoint computes per student-concept severity and summary buckets.
3. Intervention endpoint identifies weakest concepts and suggests intervention type:
   - reteach
   - group_activity
   - peer_instruction

## File inventory by phase

## Core app files touched
1. demo/lib/services/ame_api_service.dart
2. demo/lib/config/feature_flags.dart
3. demo/lib/screens/student/student_quiz_attempt_screen.dart
4. demo/lib/screens/student/student_practice_quiz_attempt_screen.dart
5. demo/lib/screens/student/concept_validation_screen.dart
6. demo/lib/screens/student/concept_video_validation_screen.dart
7. demo/lib/screens/student/practice_concept_list_screen.dart
8. demo/lib/screens/teacher/teacher_dashboard_screen.dart

## Backend files touched in AME branch
1. ame/ame/app/main.py and mirrored ame/app/main.py
2. ame/ame/app/logic.py and mirrored ame/app/logic.py
3. ame/ame/app/storage.py and mirrored ame/app/storage.py
4. ame/ame/app/schemas.py and mirrored ame/app/schemas.py
5. ame/ame/app/priority.py and mirrored ame/app/priority.py
6. Related model and db support files under ame/ame/app and ame/app

## Pending work
1. Phase 4 parent report enrichment:
   - optional AME mastery summary
   - optional confidence trend
   - keep existing parent report fields unchanged
   - keep report generation fail-open when AME is unavailable
