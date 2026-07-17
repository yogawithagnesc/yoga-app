# Account Deletion Setup

## Overview

Lumen's two-stage account deletion requires two pieces:

1. **RPC Function** (`schema_phase21_account_deletion_rpc.sql`): Deletes the user's profile and cascades to all associated data (logs, focus areas, etc.)
2. **Vercel API Function** (`/api/delete-user.js`): Calls Supabase Admin API to delete the auth.users record, making the email/password combination completely unusable for login.

## Configuration

### Step 1: Get the Supabase Service Role Key

1. Go to your Supabase project dashboard: https://app.supabase.com
2. Navigate to **Settings** → **API**
3. Look for **Service Role Key** (labeled "secret" key, not the anon key)
4. Copy the key (it will be a long string starting with `eyJ...` or similar)

### Step 2: Set Vercel Environment Variable

1. Go to your Vercel project: https://vercel.com/yogawithagnesc/yoga-app
2. Click **Settings** (top navigation)
3. Click **Environment Variables** (left sidebar)
4. Add a new variable:
   - **Name:** `SUPABASE_SERVICE_ROLE_KEY`
   - **Value:** [Paste the service role key from Step 1]
5. Click **Save**

### Step 3: Redeploy

Push a new commit to trigger a redeployment, or manually redeploy:
1. Go to **Deployments** tab in Vercel
2. Click on the latest deployment
3. Click **Redeploy** button

The API function will now have access to the service role key and can delete auth.users records.

## Testing

### Test Deletion Workflow

1. Log in as a test user (teacher or student account)
2. Navigate to **Profile** → scroll to bottom
3. Click **Delete Account**
4. Stage 1: Review warning, click **Continue**
5. Stage 2: Type `DELETE`, click **Delete Account**
6. Confirm: User is signed out and redirected to login

### Verify Email/Password is Unusable

1. After deletion, attempt to log in with the same email and password
2. Expected result: **Login fails** with "Invalid login credentials" or similar error
3. User must create a completely new account (sign up again)

### Verify Data is Deleted

Check Supabase dashboard:
- **auth_users** table: User record is gone
- **profiles** table: User row is gone
- **practice_logs** table: User's logs are gone (via cascade)
- **practice_categories** table: User's custom categories are gone

## Troubleshooting

**Symptom:** "Server not configured for account deletion" error in UI

**Solution:** Verify the `SUPABASE_SERVICE_ROLE_KEY` environment variable is set in Vercel and the deployment was redeployed after setting it.

---

**Service Role Key Security Note:** The service role key is secret and must never be exposed to the client. It is stored only in Vercel environment variables (server-side). The `/api/delete-user.js` function validates the user's JWT before calling the Admin API, ensuring only authenticated users can delete their own accounts.
