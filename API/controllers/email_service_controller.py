import os
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart

GMAIL_USER = os.environ["GMAIL_USER"]
GMAIL_APP_PASSWORD = os.environ["GMAIL_APP_PASSWORD"]

forgot_otp_store = {}
signup_otp_store = {}


def send_otp_email(to_email: str, otp: str):
    msg = MIMEMultipart("alternative")
    msg["Subject"] = "Your Verification Code - Table.com"
    msg["From"] = GMAIL_USER
    msg["To"] = to_email

    html = f"""
    <html>
      <body style="font-family: Arial, sans-serif; background-color: #f4f4f4; padding: 20px;">
        <div style="max-width: 400px; margin: auto; background: white; border-radius: 12px; padding: 30px; box-shadow: 0 2px 8px rgba(0,0,0,0.1);">
          <h2 style="color: #B63D3D; text-align: center;">Table.com</h2>
          <p style="color: #333; font-size: 16px;">Your verification code is:</p>
          <div style="text-align: center; margin: 20px 0;">
            <span style="font-size: 40px; font-weight: bold; letter-spacing: 10px; color: #751B1B;">
              {otp}
            </span>
          </div>
          <p style="color: #888; font-size: 13px;">This code expires in 10 minutes. Do not share it with anyone.</p>
        </div>
      </body>
    </html>
    """

    msg.attach(MIMEText(html, "html"))

    with smtplib.SMTP_SSL("smtp.gmail.com", 465) as server:
        server.login(GMAIL_USER, GMAIL_APP_PASSWORD)
        server.sendmail(GMAIL_USER, to_email, msg.as_string())