# Website contact form

The website posts JSON to `/telemetry/contact`. The same-origin proxy forwards it to the bridge's `/contact` endpoint.

The bridge uses the configured recipient list and a verified sender. The visitor's validated email address is used as Reply-To. A success response means the SMTP provider accepted the message for every configured recipient.

Configure these values in the bridge's existing private environment when the team is ready to enable delivery:

```
CONTACT_ORIGIN=https://project.example
CONTACT_RECIPIENTS=<comma-separated recipient addresses>
CONTACT_FROM=<verified sending email address>
CONTACT_SMTP_HOST=<SMTP provider host>
CONTACT_SMTP_PORT=587
CONTACT_SMTP_USER=<SMTP username>
CONTACT_SMTP_PASSWORD=<SMTP password or app password>
```

`CONTACT_ORIGIN` falls back to `AUTH_ORIGIN`. Port 587 requires STARTTLS; port 465 uses TLS immediately. Credentials and recipients are never sent to the browser. The route validates body sizes, names, email addresses, and message lengths, requires a matching Origin and JSON content type, and limits each direct peer to five attempts per fifteen minutes. Behind the current Apache proxy, this is a conservative shared limit for the proxy peer; untrusted forwarding headers are not used as identity.

The form returns 503 until a sender, SMTP host, and valid recipient list are configured. Tests use an injected mail transport.

SMTP configuration follows [Nodemailer's transport documentation](https://nodemailer.com/smtp).
