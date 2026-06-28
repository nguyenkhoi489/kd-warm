# 10 — Email Testing with Mailpit

This page explains how to use Mailpit, KTStack's built-in email testing tool, to capture and inspect emails sent from your local sites.

## What is Mailpit?

Mailpit is a fake SMTP server (a mail-catching service) that runs locally on your Mac as part of KTStack. Instead of actually sending emails to the internet, your local apps send mail to Mailpit, and you can view every message in KTStack's Mail section.

This is essential for development: you can test email features (password resets, notifications, confirmations) without sending real emails to real people.

## How email testing works

### The normal flow

When your local site sends an email (e.g., a "password reset" message):

1. Your PHP or Node app calls a mail function (e.g., `mail()` in PHP or `nodemailer` in Node).
2. Normally, that would send the email out to the internet via SMTP.
3. **With Mailpit**, instead of going to the internet, the email goes to a local SMTP service on your Mac (port 1025).
4. Mailpit **captures** the email and stores it.
5. You can then **open the Mail section** in KTStack and read every detail of the message: sender, recipient, subject, body, attachments, and more.

### Configuring your app

For your local site to send mail to Mailpit:

**PHP apps** (Laravel, WordPress, plain PHP):
- Make sure your `config/mail.php` or `.env` is set to use SMTP.
- Set the **SMTP host** to `127.0.0.1` (localhost).
- Set the **SMTP port** to `1025`.
- Leave **username** and **password** empty (Mailpit doesn't require authentication).

Example `.env` for Laravel:
```
MAIL_MAILER=smtp
MAIL_HOST=127.0.0.1
MAIL_PORT=1025
MAIL_USERNAME=
MAIL_PASSWORD=
```

**Node apps** (Express, Nest, etc.):
- Use a mail package like `nodemailer`.
- Configure it to connect to `127.0.0.1:1025`.

Example:
```javascript
const transporter = nodemailer.createTransport({
  host: '127.0.0.1',
  port: 1025,
  ignoreTLS: true,
});
```

Once configured, mail sent from your local app is captured by Mailpit automatically.

## Opening the Mail section

1. Click the KTStack menu-bar icon.
2. Click **Mail** in the dashboard (or look for a Mail tab).

You'll see:
- **Left sidebar**: A list of all captured emails (inbox).
- **Right panel**: The full details of the selected email.

If no emails have been sent yet, you see an empty inbox with a hint: "No messages yet. Send mail from a site to :1025."

![Mail section showing inbox list and message detail view](images/10-mail-section-overview.png)

## Reading your emails

### Email list (left sidebar)

Each email in the list shows:

| Information | Details |
|-------------|---------|
| **Subject** | The email's subject line. |
| **From** | The sender's address or name. |
| **Date** | When the email was sent (time or date). |
| **Preview** | A snippet of the email body (if plain text). |

Click an email to see its full details on the right.

### Email detail view (right panel)

When you click an email, the right panel shows:

#### Header section

At the top, you see:
- **Subject** — the email's subject line (large, bold).
- **From** — sender name and email address.
- **To** — recipient address(es).
- **Date** — full date and time the email was sent.
- A **Raw** button (shows the full email source code).
- A **Delete** button (trash icon).

#### Body section

The main content of the email. Depending on the email:

**Plain text emails** show the text exactly as sent.

**HTML emails** are rendered in the browser (links clickable, images visible).

#### Tabs for content type

If an email has both HTML and plain text versions, you'll see tabs:
- **Plain** — shows the plain text version.
- **HTML** — shows the HTML version rendered.

Click to switch between them.

![Email detail view with HTML and plain text tabs, showing formatted message](images/10-email-message-detail.png)

#### Attachments

If the email has attachments (PDFs, images, etc.), they're listed at the bottom with:
- File icon
- File name
- File size

You can click an attachment to open or download it.

## Common tasks

### Test a password reset email

1. In your local site, trigger a password reset (usually a form or link).
2. Go to the **Mail** section in KTStack.
3. You should see a new email in the inbox with the reset link.
4. Click the email to read it.
5. Copy the reset link and paste it into your browser to test the flow.

![Inbox showing captured password reset email with visible link](images/10-mailpit-inbox-example.png)

### Check email formatting

1. Send a test email from your app.
2. Click it in KTStack's Mail section.
3. Switch between **Plain** and **HTML** tabs to see both versions.
4. Verify that links, images, and styling are correct.

### Verify attachments

1. Send an email with an attachment (e.g., a PDF or CSV export).
2. Open the email in the Mail section.
3. Scroll to the **Attachments** section.
4. Click the attachment to download it and verify it's correct.

### Test multi-recipient emails

1. Send an email to multiple recipients.
2. Open it in KTStack's Mail section.
3. Check the **To** field — you'll see all recipients listed.
4. This is useful for testing "mail to list" features.

## Managing your inbox

### Clear all messages

If your inbox gets cluttered during testing:

1. Click the **Clear inbox** button (usually in the header).
2. A confirmation appears: "Clear all messages?"
3. Click **Clear** to confirm.
4. All emails are deleted. This cannot be undone.

### Delete a single message

1. Click an email in the list to select it.
2. Click the **Delete** button (trash icon) in the header.
3. The email is removed from your inbox.

Alternatively, right-click the email in the list and select **Delete**.

## Understanding Mailpit's role

### What Mailpit captures

- ✓ SMTP connections from your local apps.
- ✓ All email content (subject, body, headers).
- ✓ Attachments.
- ✓ Both plain text and HTML versions.
- ✓ Recipient and sender information.

### What Mailpit doesn't do

- ✗ Send emails to the internet (it catches them locally).
- ✗ Require authentication (no username/password needed).
- ✗ Require TLS or security (it's local only).
- ✗ Process or forward emails (it only stores and displays them).

### Storage

Captured emails are stored in memory and on disk at:
```
~/Library/Application Support/KTStack/mailpit/
```

They persist when you close and reopen KTStack, but are lost if you reset the Mailpit service (see [06 — Services](06-services.md)).

## Email header fields

When you open an email, you see detailed headers. Here's what they mean:

| Field | Meaning |
|-------|---------|
| **From** | The sender's email address or display name. |
| **To** | The recipient(s) of the email. |
| **Cc** | Addresses copied on the email (visible to all). |
| **Bcc** | Addresses blind-copied (not visible to others). |
| **Date** | When the email was sent. |
| **Subject** | The email's title. |
| **Reply-To** | The address replies should go to (if different from From). |

These fields help you verify that your app is sending emails correctly.

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No emails appear | Make sure your app is configured to send to `127.0.0.1:1025`. Check your `.env` or config file. Also, make sure Mailpit is running in the Services section. |
| Emails don't have the right sender | Check the `MAIL_FROM` or `from` field in your app's mail config. Your app sets the sender address. |
| HTML emails appear as plain text | Your app may not be sending the HTML version. In Laravel, make sure your mailable class uses `->html()` or the view is parsed as HTML. |
| Attachments are missing | Check that your app is properly attaching files. Some mail libraries require you to specify the file path correctly. |
| Can't see the email body | Click the email and check if there are tabs (Plain/HTML). If the body is empty, the email was sent with no content. |
| Mailpit is not running | Check the Services section and click the toggle next to Mailpit to start it. |
| Old emails disappeared | They may have been cleared. If you need to keep important test emails, take screenshots or export the message. |

## Tips and notes

- **Test receipts**: Always test the entire email flow, not just the sending. Click links, verify images, check that content is what you expect.
- **Bulk testing**: If you want to test sending 100 emails, go ahead — Mailpit will capture all of them. Use the search feature to find specific ones.
- **Real email in production**: Remember to change your mail config before deploying to production. You don't want test emails captured; you want them sent to real users.
- **Multiple developers**: If you're pair programming or sharing a Mac, the Mail inbox is shared. Clear it periodically.
- **Email templates**: Use the Mail section to verify that your email templates render correctly across plain text and HTML.

## Where to go next

Now you can test emails locally without sending anything to the internet. Next, head to [11 — Logs & dumps](11-logs-and-dumps.md) to learn how to watch your app's logs and capture debug output. Or skip to [12 — API Tester](12-api-tester.md) to test your app's API endpoints.
