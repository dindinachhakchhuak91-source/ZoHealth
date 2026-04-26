# Guide

## 1. How to create a new email for admin

1. Open your Supabase project dashboard.
2. In the left menu, click `Authentication`.
3. Open the `Users` tab.
4. Click `Add user`.
5. Enter the new admin email address.
6. Enter a password for that account.
7. Click `Create user`.
8. In the left menu, click `SQL Editor`.
9. Click `New query`.
10. Run this SQL, replacing the email with the one you just created:

```sql
UPDATE profiles
SET role = 'admin'
WHERE email = 'newadmin@example.com';
```

11. Confirm the user was updated in the `profiles` table.
12. Log in to the app with that new email and password.
13. If the role update does not work, first make sure the user has a row in `profiles`.

## Note

This app does not use a hardcoded admin login. A user becomes admin only when their `role` in the Supabase `profiles` table is set to `admin`.
