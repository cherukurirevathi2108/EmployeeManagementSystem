package service;

import java.util.Properties;

import jakarta.activation.CommandInfo;
import jakarta.activation.CommandMap;
import jakarta.activation.DataContentHandler;
import jakarta.activation.DataHandler;
import jakarta.activation.DataSource;
import jakarta.mail.Authenticator;
import jakarta.mail.Message;
import jakarta.mail.PasswordAuthentication;
import jakarta.mail.Session;
import jakarta.mail.Transport;
import jakarta.mail.internet.InternetAddress;
import jakarta.mail.internet.MimeBodyPart;
import jakarta.mail.internet.MimeMessage;
import jakarta.mail.internet.MimeMultipart;
import jakarta.mail.util.ByteArrayDataSource;

public class EmailService {

    // =====================================================
    // MAIL CONTENT HANDLERS (needed for emails with attachments)
    //
    // WEB-INF/lib has the Jakarta Activation API jar but not its
    // implementation, so Jakarta Mail cannot find the handler that writes
    // "multipart/mixed" (body + attachment) and fails with
    // "no object DCH for MIME type multipart/mixed". The handler classes are
    // inside jakarta.mail-2.0.3.jar, so this small CommandMap hands them out
    // directly. (Adding angus-activation.jar to WEB-INF/lib would do the same.)
    // =====================================================
    private static final class HandlerCommandMap extends CommandMap {

        private final CommandMap previous;

        HandlerCommandMap(CommandMap previous) {
            this.previous = previous;
        }

        @Override
        public DataContentHandler createDataContentHandler(String mimeType) {
            if (mimeType != null) {
                String t = mimeType.toLowerCase(java.util.Locale.ROOT);
                int semi = t.indexOf(';');
                if (semi >= 0) t = t.substring(0, semi).trim();

                if (t.startsWith("multipart/"))
                    return new org.eclipse.angus.mail.handlers.multipart_mixed();
                if (t.equals("text/html"))
                    return new org.eclipse.angus.mail.handlers.text_html();
                if (t.equals("text/plain"))
                    return new org.eclipse.angus.mail.handlers.text_plain();
                if (t.equals("message/rfc822"))
                    return new org.eclipse.angus.mail.handlers.message_rfc822();
            }
            try {
                return previous == null ? null : previous.createDataContentHandler(mimeType);
            } catch (Throwable ignored) {
                return null;
            }
        }

        @Override
        public DataContentHandler createDataContentHandler(String mimeType, DataSource ds) {
            return createDataContentHandler(mimeType);
        }

        @Override
        public CommandInfo[] getPreferredCommands(String mimeType) {
            return new CommandInfo[0];
        }

        @Override
        public CommandInfo[] getAllCommands(String mimeType) {
            return new CommandInfo[0];
        }

        @Override
        public CommandInfo getCommand(String mimeType, String cmdName) {
            return null;
        }
    }

    static {
        try {
            CommandMap current = null;
            try {
                current = CommandMap.getDefaultCommandMap();
            } catch (Throwable ignored) {
                // no usable default map - our own handlers are enough
            }
            CommandMap.setDefaultCommandMap(new HandlerCommandMap(current));
        } catch (Throwable t) {
            t.printStackTrace();
        }
    }

    // =====================================================
    // YOUR GMAIL
    // =====================================================

    private static final String FROM_EMAIL =
            "cherukurirevathi5@gmail.com";

    // =====================================================
    // CHANGE THIS WITH YOUR GMAIL APP PASSWORD
    // =====================================================

    private static final String APP_PASSWORD =
            "knds eorh reyx kzuh";


    // =====================================================
    // SEND LOGIN CREDENTIALS
    // =====================================================

    /** Reason of the last failed send on THIS thread (shown to HR on the page). */
    private static final ThreadLocal<String> LAST_ERROR = new ThreadLocal<String>();

    public static String getLastError() {
        String e = LAST_ERROR.get();
        return e == null ? "" : e;
    }

    public static boolean sendCredentials(
            String toEmail,
            String name,
            String employeeId,
            String password,
            String role) {

        LAST_ERROR.remove();

        // System Settings > Email notifications = Off stops system emails
        if (!SystemSettingsService.getBool("notify_email", true)) {
            LAST_ERROR.set("Email notifications are switched off in System Settings.");
            return false;
        }

        try {

            // =================================================
            // GMAIL SMTP SETTINGS
            // =================================================

            Properties props =
                    new Properties();

            props.put(
                    "mail.smtp.auth",
                    "true"
            );

            props.put(
                    "mail.smtp.starttls.enable",
                    "true"
            );

            props.put(
                    "mail.smtp.host",
                    "smtp.gmail.com"
            );

            props.put(
                    "mail.smtp.port",
                    "587"
            );

            // Fail fast instead of hanging the request, and use modern TLS
            props.put("mail.smtp.connectiontimeout", "10000");
            props.put("mail.smtp.timeout", "15000");
            props.put("mail.smtp.writetimeout", "15000");
            props.put("mail.smtp.ssl.protocols", "TLSv1.2 TLSv1.3");
            props.put("mail.smtp.ssl.trust", "smtp.gmail.com");


            // =================================================
            // MAIL SESSION
            // =================================================

            Session session =
                    Session.getInstance(
                            props,
                            new Authenticator() {

                                @Override
                                protected PasswordAuthentication
                                getPasswordAuthentication() {

                                    return new PasswordAuthentication(
                                            FROM_EMAIL,
                                            APP_PASSWORD
                                    );
                                }
                            }
                    );


            // =================================================
            // CREATE MESSAGE
            // =================================================

            MimeMessage message =
                    new MimeMessage(session);


            message.setFrom(
                    new InternetAddress(
                            FROM_EMAIL
                    )
            );


            message.setRecipients(
                    Message.RecipientType.TO,
                    InternetAddress.parse(
                            toEmail
                    )
            );


            // =================================================
            // SUBJECT
            // =================================================

            message.setSubject(
                    (role == null || role.trim().isEmpty() ? "Employee" : role.trim()) + " Login Credentials - "
                    + employeeId
            );


            // =================================================
            // LOGIN LINK
            // =================================================

            String loginLink =
                    "http://localhost:8080/"
                    + "EmployeeManagementSystem2/"
                    + "login.html";


            // =================================================
            // HTML EMAIL
            // =================================================

            String emailBody =

                    "<html>"
                    + "<body style='margin:0;"
                    + "padding:30px;"
                    + "background:#f4f6f8;"
                    + "font-family:Arial,sans-serif;'>"

                    + "<div style='max-width:600px;"
                    + "margin:auto;"
                    + "background:white;"
                    + "padding:30px;"
                    + "border-radius:12px;"
                    + "box-shadow:0 4px 15px "
                    + "rgba(0,0,0,0.10);'>"


                    // =========================================
                    // TITLE
                    // =========================================

                    + "<h2 style='color:#4f46e5;"
                    + "margin-bottom:10px;'>"
                    + "Welcome " + name + "!"
                    + "</h2>"


                    + "<p style='font-size:15px;"
                    + "color:#333;'>"
                    + "Your employee account has been "
                    + "created successfully."
                    + "</p>"


                    // =========================================
                    // CREDENTIALS
                    // =========================================

                    + "<div style='background:#f8fafc;"
                    + "padding:20px;"
                    + "border-radius:8px;"
                    + "margin-top:20px;'>"

                    + "<p>"
                    + "<b>Employee ID:</b> "
                    + employeeId
                    + "</p>"

                    + "<p>"
                    + "<b>Email:</b> "
                    + toEmail
                    + "</p>"

                    + "<p>"
                    + "<b>Password:</b> "
                    + password
                    + "</p>"

                    + "<p>"
                    + "<b>Role:</b> "
                    + role
                    + "</p>"

                    + "</div>"


                    // =========================================
                    // LOGIN TEXT
                    // =========================================

                    + "<p style='margin-top:25px;'>"
                    + "Click the button below to login "
                    + "to the Employee Management System:"
                    + "</p>"


                    // =========================================
                    // LOGIN BUTTON
                    // =========================================

                    + "<div style='text-align:center;"
                    + "margin:25px 0;'>"

                    + "<a href='" + loginLink + "' "
                    + "style='display:inline-block;"
                    + "background:#4f46e5;"
                    + "color:#ffffff;"
                    + "padding:14px 28px;"
                    + "text-decoration:none;"
                    + "border-radius:7px;"
                    + "font-size:16px;"
                    + "font-weight:bold;'>"

                    + "Login to Employee Portal"

                    + "</a>"

                    + "</div>"


                    // =========================================
                    // LINK
                    // =========================================

                    + "<p style='font-size:13px;"
                    + "color:#666;'>"
                    + "If the button does not work, "
                    + "copy and paste this link into your browser:"
                    + "</p>"

                    + "<p style='font-size:13px;"
                    + "word-break:break-all;'>"

                    + "<a href='" + loginLink + "'>"
                    + loginLink
                    + "</a>"

                    + "</p>"


                    // =========================================
                    // FOOTER
                    // =========================================

                    + "<hr style='border:none;"
                    + "border-top:1px solid #ddd;"
                    + "margin-top:30px;'>"

                    + "<p style='font-size:13px;"
                    + "color:#777;'>"
                    + "Regards,<br>"
                    + "<b>HR Team</b>"
                    + "</p>"


                    + "</div>"
                    + "</body>"
                    + "</html>";


            // =================================================
            // SET HTML CONTENT
            // =================================================

            message.setContent(
                    emailBody,
                    "text/html; charset=UTF-8"
            );


            // =================================================
            // SEND EMAIL
            // =================================================

            Transport.send(message);


            System.out.println(
                    "Login credentials email sent to: "
                    + toEmail
            );

            return true;


        } catch (Exception e) {

            e.printStackTrace();

            Throwable root = e;
            while (root.getCause() != null && root.getCause() != root) {
                root = root.getCause();
            }
            String why = root.getMessage() == null
                    ? root.getClass().getSimpleName()
                    : root.getMessage().replaceAll("\\s+", " ").trim();
            if (why.length() > 160) why = why.substring(0, 160);
            LAST_ERROR.set(why);

            System.out.println(
                    "Failed to send email to: "
                    + toEmail
            );

            return false;
        }
    }
    // =====================================================
    // SEND SALARY SLIP (called automatically when salary is paid)
    // =====================================================

    private static String esc(String v) {
        if (v == null) return "";
        return v.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;");
    }

    /**
     * Emails the salary slip: a short HTML summary in the mail body and the
     * full slip attached as a PDF file the employee can open and download.
     */
    public static boolean sendSalarySlip(
            String toEmail,
            String name,
            String period,
            java.math.BigDecimal netSalary,
            byte[] slipPdf,
            String attachmentName) {

        LAST_ERROR.remove();

        // System Settings > Email notifications = Off stops system emails
        if (!SystemSettingsService.getBool("notify_email", true)) {
            LAST_ERROR.set("Email notifications are switched off in System Settings.");
            return false;
        }

        try {

            Properties props = new Properties();
            props.put("mail.smtp.auth", "true");
            props.put("mail.smtp.starttls.enable", "true");
            props.put("mail.smtp.host", "smtp.gmail.com");
            props.put("mail.smtp.port", "587");
            props.put("mail.smtp.connectiontimeout", "10000");
            props.put("mail.smtp.timeout", "15000");
            props.put("mail.smtp.writetimeout", "15000");
            props.put("mail.smtp.ssl.protocols", "TLSv1.2 TLSv1.3");
            props.put("mail.smtp.ssl.trust", "smtp.gmail.com");

            Session session = Session.getInstance(props, new Authenticator() {
                @Override
                protected PasswordAuthentication getPasswordAuthentication() {
                    return new PasswordAuthentication(FROM_EMAIL, APP_PASSWORD.replace(" ", ""));
                }
            });

            MimeMessage message = new MimeMessage(session);
            message.setFrom(new InternetAddress(FROM_EMAIL));
            message.setRecipients(Message.RecipientType.TO, InternetAddress.parse(toEmail));
            message.setSubject("Salary Slip - " + period, "UTF-8");

            String net = netSalary == null ? "-" : String.format("%,.2f", netSalary);

            String body =
                    "<html><body style='margin:0;padding:30px;background:#f4f6f8;font-family:Arial,sans-serif;'>"
                    + "<div style='max-width:600px;margin:auto;background:#fff;padding:30px;border-radius:12px;'>"
                    + "<h2 style='color:#4f46e5;margin:0 0 10px;'>Hi " + esc(name) + ",</h2>"
                    + "<p style='font-size:15px;color:#333;'>Your salary for <b>" + esc(period)
                    + "</b> has been paid.</p>"
                    + "<div style='background:#ecfdf5;border:1px solid #bbf7d0;border-radius:8px;"
                    + "padding:16px;margin:18px 0;font-size:18px;color:#166534;'>"
                    + "<b>Net salary: &#8377;" + net + "</b></div>"
                    + "<p style='font-size:14px;color:#333;'>Your detailed salary slip is attached to this email "
                    + "as a <b>PDF</b> (" + esc(attachmentName) + "). Open it to view, or download it to keep a copy.</p>"
                    + "<hr style='border:none;border-top:1px solid #ddd;margin-top:30px;'>"
                    + "<p style='font-size:13px;color:#777;'>Regards,<br><b>HR Team</b></p>"
                    + "</div></body></html>";

            MimeBodyPart bodyPart = new MimeBodyPart();
            bodyPart.setContent(body, "text/html; charset=UTF-8");

            MimeBodyPart attachment = new MimeBodyPart();
            attachment.setDataHandler(new DataHandler(new ByteArrayDataSource(slipPdf, "application/pdf")));
            attachment.setFileName(attachmentName);
            attachment.setDisposition(MimeBodyPart.ATTACHMENT);
            // always base64 for the PDF, so no mail server can alter its bytes
            attachment.setHeader("Content-Transfer-Encoding", "base64");

            MimeMultipart multipart = new MimeMultipart("mixed");
            multipart.addBodyPart(bodyPart);
            multipart.addBodyPart(attachment);
            message.setContent(multipart);

            Transport.send(message);

            System.out.println("Salary slip email sent to: " + toEmail);
            return true;

        } catch (Exception e) {

            e.printStackTrace();

            Throwable root = e;
            while (root.getCause() != null && root.getCause() != root) {
                root = root.getCause();
            }
            String why = root.getMessage() == null
                    ? root.getClass().getSimpleName()
                    : root.getMessage().replaceAll("\\s+", " ").trim();
            if (why.length() > 160) why = why.substring(0, 160);
            LAST_ERROR.set(why);

            System.out.println("Failed to send salary slip to: " + toEmail);
            return false;
        }
    }
}