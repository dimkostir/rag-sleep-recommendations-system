from fastapi_mail import ConnectionConfig

conf = ConnectionConfig(
    MAIL_USERNAME="dkaisleepapp@gmail.com",
    MAIL_PASSWORD="shyrtrktvlffxdna",  # Gmail app password
    MAIL_FROM="dkaisleepapp@gmail.com",
    MAIL_FROM_NAME="AI Sleep App notification",
    MAIL_PORT=587,
    MAIL_SERVER="smtp.gmail.com",
    MAIL_STARTTLS=True,
    MAIL_SSL_TLS=False,
    USE_CREDENTIALS=True
)
