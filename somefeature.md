# Orbit — Current Features

## Authentication

First, users sign in with their `.edu` email address. The server sends a 6-digit verification code, and once confirmed, the app issues a JWT access token (15 min) and refresh token (7 days). Tokens are stored securely in the iOS Keychain. When the access token expires, the app automatically refreshes it behind the scenes — users stay logged in without interruption. If the refresh token is also expired, the app redirects back to the login screen.

## Profile Creation

New users go through a 5-step profile setup flow:

1. **Basics** — Name, age, city, state, and a short bio
2. **Personality** — Three sliders capturing where you fall on introvert/extrovert, spontaneous/planner, and active/relaxed scales
3. **Interests** — Pick from predefined tags or add your own (minimum 3, maximum 10)
4. **Social Preferences** — Preferred group size, how often you want to meet, and what times work best (weekends, evenings, etc.)
5. **Photos** — Upload up to 6 photos from your library

A profile is considered "complete" once it has a name, at least 3 interests, and at least one preferred time. Returning users can edit their profile at any time from the profile tab.

## Profile Display

Your profile is shown as a card with:

- A swipeable photo carousel
- Name, age, and location
- Bio text
- Interest tags
- Personality bars showing where you land on each scale
- Social preferences summary (group size, frequency, availability)

Other users see this same card when they discover you.

## Discovery Page

The discovery screen uses a space/solar system theme. You appear as a central planet labeled "YOU" with a star field background. Other users appear as orbiting planets around you — each one is a profile you might connect with.

- Tap any orbiting planet to view that person's full profile card
- Planets are color-coded and positioned in orbital rings
- The matching algorithm ranks suggestions by shared interest overlap — users with the most interests in common appear first
- The server returns up to 20 suggested profiles at a time
