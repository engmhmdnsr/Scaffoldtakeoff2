# Supabase Backend Setup for Scaffold Takeoff

This guide explains how to connect Scaffold Takeoff with Supabase for email and password authentication and isolated per-user project storage.

## 1. Create a Supabase Project

1. Go to [https://supabase.com](https://supabase.com) and sign in.
2. Click **New Project**.
3. Choose your organization, set a project name (such as `scaffold-takeoff`), and set a database password.
4. Select your preferred region and click **Create new project**.

## 2. Execute the Database Schema

1. In your Supabase dashboard, navigate to the **SQL Editor** tab (terminal icon on the left menu).
2. Click **New query**.
3. Copy the entire contents of `supabase/schema.sql` and paste it into the editor.
4. Click **Run** to execute the query.

This creates:
* `public.profiles`: Stores user profile metadata linked to `auth.users`.
* `public.projects`: Stores scaffold configuration JSON and bill of materials rows for each user.
* `public.project_files`: Tracks exported project files and attachments.
* Automatic trigger: Copies newly registered users from `auth.users` into `public.profiles`.
* Updated-at trigger: Updates `updated_at` timestamps on project modifications.
* Row Level Security (RLS): Restricts all SELECT, INSERT, UPDATE, and DELETE actions so users can only access rows where `user_id = auth.uid()`.
* Storage bucket `project-exports`: Configured with folder-level RLS (`user_id/*`).

## 3. Retrieve API Keys

1. In your Supabase project dashboard, navigate to **Project Settings** (gear icon) -> **API**.
2. Find the following values:
   * **Project URL**: e.g., `https://xyzcompany.supabase.co`
   * **Project API keys** -> `anon` / `public`: e.g., `eyJhbGciOiJIUzI1Ni...`

## 4. Configure the Web Client

You can configure your Supabase connection in two ways:

### Method A: Browser UI (Works with file:// offline testing)
1. Open `web/index.html` in your browser.
2. In the authentication screen, click **Supabase Configuration**.
3. Paste your **Project URL** and **Anon Key**, then click **Save and Connect**.
4. The credentials are stored in your browser `localStorage` under `sb_url` and `sb_anon_key`.

### Method B: Environment File
1. Copy `web/.env.example` to `web/.env`.
2. Fill in your project credentials:
   ```env
   VITE_SUPABASE_URL=https://your-project-id.supabase.co
   VITE_SUPABASE_ANON_KEY=your-anon-key-here
   ```

## 5. Authentication Configuration

* **Email and Password only**: Scaffold Takeoff uses email and password authentication. No OAuth or Google login is required.
* **Email Confirmations**:
  * For local testing or rapid evaluation: Go to **Authentication** -> **Providers** -> **Email** and toggle off **Confirm email**. Users will be logged in immediately upon registration.
  * For production: Keep **Confirm email** turned on. Supabase will send a verification link to the user before first login.

## 6. Security and Per-User Isolation Verification

Row Level Security guarantees that no account can inspect or alter data belonging to another account.

### How to verify:
1. Register Account A (`user_a@test.com`), log in, and create a project named `Tower A`.
2. Click **Sign Out** in the sidebar.
3. Register Account B (`user_b@test.com`) and log in.
4. Inspect the **My Projects** dashboard: the list will be completely empty. Account B cannot see `Tower A`.
5. Create a project named `Platform B` under Account B.
6. Sign out and log back in as Account A.
7. Only `Tower A` is visible in Account A dashboard.
