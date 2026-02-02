## Project Context

Read the architecture doc at `C:\Users\rashm\OneDrive\Desktop\DAEMON\ECS_191\Orbit\server_architecture.md` for the full structure.

## Tech Stack
- **Server**: Google App Engine (project ID in `app.yaml`)
- **Database**: Firestore in Datastore mode
- **Storage**: Google Cloud Storage (for profile photos)
- **Auth**: JWT tokens with student email verification via SendGrid (NOT Twilio/SMS)
- **Framework**: Flask with Blueprints
- **Entry point**: `main.py` → deployed to https://orbit-app-486204.wl.r.appspot.com/

## Create the following files

### API Layer (`api/`)
- `api/__init__.py`
- `api/auth.py` - Endpoints: send-code (to .edu email), verify-code, refresh-token, logout
- `api/users.py` - Endpoints: get profile, update profile, upload photo
- `api/crews.py` - Endpoints: create, join, leave, list crews
- `api/missions.py` - Endpoints: create, RSVP, list missions
- `api/discover.py` - Endpoints: suggested users, crews, missions

### Services Layer (`services/`)
- `services/__init__.py`
- `services/auth_service.py` - Email verification with SendGrid, JWT creation/validation
- `services/user_service.py` - Profile CRUD operations
- `services/crew_service.py` - Crew logic
- `services/mission_service.py` - Mission logic
- `services/matching_service.py` - Basic matching/suggestions
- `services/storage_service.py` - Cloud Storage uploads

### Models Layer (`models/`)
- `models/__init__.py`
- `models/models.py` - Datastore entities: User, Profile, Crew, CrewMember, Mission, MissionRSVP, RefreshToken, VerificationCode

### Utils (`utils/`)
- `utils/__init__.py`
- `utils/auth.py` - JWT helpers, @require_auth decorator
- `utils/responses.py` - success() and error() response formatters
- `utils/validators.py` - Input validation (email, profile data, etc.)

## Auth Requirements
- Only allow .edu emails (validate domain)
- SendGrid sends 6-digit verification code
- Codes expire in 10 minutes
- Return JWT access_token (15 min expiry) + refresh_token (7 days)
- Store refresh tokens in Datastore

## Update these existing files
- `main.py` - Register all blueprints
- `requirements.txt` - Add all dependencies
- `app.yaml` - Add env variables (PROJECT_ID, JWT_SECRET, SENDGRID_API_KEY, GCS_BUCKET_NAME)