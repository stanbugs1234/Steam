/// Public pages for the app, hosted on Firebase Hosting (see `public/`).
const privacyPolicyUrl = 'https://steam-club-app.web.app/privacy.html';
const termsOfUseUrl = 'https://steam-club-app.web.app/terms.html';
const supportUrl = 'https://steam-club-app.web.app/support.html';

/// The club address members can write to for help. Left empty until the club
/// picks one: while it is empty the app simply doesn't show a "Contact the
/// club" button (see [hasSupportEmail]).
const supportEmail = '';

bool get hasSupportEmail => supportEmail.isNotEmpty;
