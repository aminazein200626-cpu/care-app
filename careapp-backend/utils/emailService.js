const nodemailer = require('nodemailer');

async function sendEmail(to, subject, text) {
  try {
    const transporter = nodemailer.createTransport({
      host: "smtp.gmail.com",
      port: 587,
      secure: false,
      auth: {
        user: process.env.EMAIL_USER,
        pass: process.env.EMAIL_PASS,
      },
    });

    const info = await transporter.sendMail({
      from: `"CareApp Support" <${process.env.EMAIL_USER}>`,
      to: to,
      subject: subject,
      text: text,
    });
    console.log(`✅ Email sent to ${to}: ${info.messageId}`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send email to ${to}:`, error.message);
    return false;
  }
}

module.exports = sendEmail;