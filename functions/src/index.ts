import * as nodemailer from 'nodemailer';

// Configure Gmail transporter
const transporter = nodemailer.createTransporter({
  service: 'gmail',
  auth: {
    user: functions.config().gmail?.user || process.env.GMAIL_USER,
    pass: functions.config().gmail?.password || process.env.GMAIL_APP_PASSWORD, // Use App Password!
  },
});

// In sendInvitationEmail function, replace sgMail.send with:
await transporter.sendMail({
  from: `"${FROM_NAME}" <${FROM_EMAIL}>`,
  to: invitation.email,
  subject: `دعوة للانضمام إلى ${companyName}`,
  text: emailText,
  html: emailHtml,
});
