package service;

import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Month;
import java.time.YearMonth;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import DAO.PayrollDAO;
import DAO.PayrollPaymentDAO;
import DAO.SalaryComponentDAO;
import DAO.SalaryStructureDAO;
import model.DBcConnection;
import model.Payroll;
import model.PayrollPayment;
import model.SalaryComponent;
import model.SalaryStructure;

/**
 * Emails the salary slip to the employee / manager as soon as their payroll
 * becomes PAID.
 *
 *  - sendAsync(payrollId) is called from PayrollDAO / PayrollPaymentDAO right
 *    after the PAID status is committed. It runs on a background thread, so a
 *    slow or failing mail server can never block or break the payroll run.
 *  - Each payroll is emailed only once (payroll.slip_emailed_at is stamped),
 *    so re-running the monthly job never sends duplicates.
 *  - HR can re-send a slip manually with send(payrollId, true).
 *
 * The recipient is the email saved for that person in the managers / employees
 * table (manager record wins if the same ID exists in both, like the payroll
 * screens do).
 */
public final class SalarySlipMailer {

    /** Result of one send attempt, shown to HR when they press "Resend". */
    public static final class Result {
        public final boolean sent;
        public final String message;

        Result(boolean sent, String message) {
            this.sent = sent;
            this.message = message;
        }
    }

    private static final ExecutorService POOL =
            Executors.newSingleThreadExecutor(r -> {
                Thread t = new Thread(r, "payslip-mailer");
                t.setDaemon(true);
                return t;
            });

    private static volatile boolean schemaReady = false;

    private SalarySlipMailer() { }

    // ------------------------------------------------------------------
    // Entry points
    // ------------------------------------------------------------------

    /** Fire-and-forget: used by the automatic payroll flow. */
    public static void sendAsync(final int payrollId) {
        POOL.submit(() -> {
            try {
                Result r = send(payrollId, false);
                System.out.println("[payslip] payroll " + payrollId + ": " + r.message);
                if (!r.sent) {
                    FAILED_AT.put(payrollId, System.currentTimeMillis());
                }
            } catch (Throwable t) {
                FAILED_AT.put(payrollId, System.currentTimeMillis());
                t.printStackTrace(); // never let the mailer thread die
            }
        });
    }

    /**
     * Builds and emails the slip for one PAID payroll.
     *
     * @param force true = send even if it was already emailed (HR "Resend")
     */
    public static Result send(int payrollId, boolean force) throws Exception {

        ensureSchema();

        PayrollDAO payrollDAO = new PayrollDAO();
        Payroll p = payrollDAO.getPayrollDetailById(payrollId);

        if (p == null) {
            return new Result(false, "Payroll record not found.");
        }

        if (!"PAID".equalsIgnoreCase(p.getStatus() == null ? "" : p.getStatus().trim())) {
            return new Result(false, "Salary slip is emailed only after the salary is paid.");
        }

        if (!force && alreadyEmailed(payrollId)) {
            return new Result(true, "Already emailed earlier - skipped.");
        }

        String toEmail = findEmail(p.getEmployeeId());

        if (toEmail == null || toEmail.trim().isEmpty()) {
            return new Result(false,
                    "No email address saved for " + p.getEmployeeId() + " - slip not sent.");
        }

        // ---- ONE slip per person per month ----
        // The slip is "claimed" (slip_emailed_at is stamped) BEFORE it is sent, inside a
        // lock, so the automatic trigger, the catch-up job and a duplicate payroll row can
        // never mail the same month twice. If the send fails the claim is released again.
        boolean claimed = false;

        if (!force) {
            synchronized (CLAIM_LOCK) {
                if (alreadyEmailed(payrollId)) {
                    return new Result(true, "Already emailed earlier - skipped.");
                }
                if (monthAlreadyEmailed(p)) {
                    markEmailed(payrollId); // so the catch-up job stops picking this row
                    return new Result(true,
                            "The salary slip for this month was already emailed - skipped.");
                }
                markEmailed(payrollId);
                claimed = true;
            }
        }

        try {

            // ---- same inputs the "Slip" page uses ----
            SalaryStructure structure = new SalaryStructureDAO().getStructureForPayroll(
                    p.getEmployeeId(),
                    Date.valueOf(YearMonth.of(p.getPayrollYear(), p.getPayrollMonth()).atEndOfMonth()));

            List<SalaryComponent> components = structure == null
                    ? new ArrayList<SalaryComponent>()
                    : new SalaryComponentDAO().getComponentsByStructureId(structure.getId());

            // bank name / account number / IFSC / PAN are saved in the salary structure
            SalaryStructure bank = null;
            if (structure != null) {
                try {
                    bank = new SalaryStructureDAO().getById(structure.getId());
                } catch (Exception ignored) {
                    // slip still works without the bank block
                }
            }

            PayrollService.AttendanceSummary attendance = null;
            try {
                attendance = new PayrollService().getAttendanceSummary(
                        p.getEmployeeId(), p.getPayrollMonth(), p.getPayrollYear());
            } catch (Exception ignored) {
                // slip still works without the attendance block
            }

            List<PayrollPayment> payments = new PayrollPaymentDAO().getPaymentsByPayrollId(payrollId);

            // the slip is attached to the email as a real PDF file
            byte[] slipPdf = SalarySlipPdf.render(p, bank, components, attendance, payments);

            String period = Month.of(p.getPayrollMonth())
                    .getDisplayName(TextStyle.FULL, Locale.ENGLISH) + " " + p.getPayrollYear();

            String fileName = "salary_slip_" + p.getEmployeeId() + "_" + p.getPayrollYear() + "_"
                    + (p.getPayrollMonth() < 10 ? "0" : "") + p.getPayrollMonth() + ".pdf";

            boolean ok = EmailService.sendSalarySlip(
                    toEmail.trim(),
                    p.getEmployeeName(),
                    period,
                    p.getNetSalary(),
                    slipPdf,
                    fileName);

            if (!ok) {
                if (claimed) {
                    clearEmailed(payrollId);
                }
                return new Result(false, "Email failed: " + EmailService.getLastError());
            }

            if (!claimed) {
                markEmailed(payrollId); // manual re-send: refresh the stamp
            }

            return new Result(true, "Salary slip for " + period + " emailed to " + toEmail.trim() + ".");

        } catch (Exception e) {
            if (claimed) {
                clearEmailed(payrollId); // release, so the catch-up job can try again later
            }
            throw e;
        }
    }

    // ------------------------------------------------------------------
    // Catch-up: emails every PAID slip (this month and last month) that has
    // not been emailed yet - salaries paid before this feature existed, and
    // sends that failed earlier (e.g. SMTP down). Called every minute by
    // PayrollScheduler. A failed slip is retried after 30 minutes.
    // ------------------------------------------------------------------

    private static final Map<Integer, Long> FAILED_AT = new ConcurrentHashMap<Integer, Long>();
    private static final long RETRY_AFTER_MS = 30L * 60 * 1000;

    public static synchronized void sendPending(int limit) {

        try {
            ensureSchema();

            YearMonth now = YearMonth.now();
            YearMonth prev = now.minusMonths(1);

            List<Integer> ids = new ArrayList<Integer>();

            try (Connection con = DBcConnection.getConnection();
                 PreparedStatement ps = con.prepareStatement(
                         "SELECT id FROM payroll WHERE UPPER(status) = 'PAID' "
                         + "AND slip_emailed_at IS NULL "
                         + "AND (payroll_year * 100 + payroll_month) >= ? "
                         + "ORDER BY id LIMIT ?")) {

                ps.setInt(1, prev.getYear() * 100 + prev.getMonthValue());
                ps.setInt(2, limit);

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        ids.add(rs.getInt(1));
                    }
                }
            }

            for (int id : ids) {

                Long failed = FAILED_AT.get(id);
                if (failed != null && System.currentTimeMillis() - failed < RETRY_AFTER_MS) {
                    continue;
                }

                try {
                    Result r = send(id, false);
                    System.out.println("[payslip] payroll " + id + ": " + r.message);
                    if (r.sent) {
                        FAILED_AT.remove(id);
                    } else {
                        FAILED_AT.put(id, System.currentTimeMillis());
                    }
                } catch (Exception e) {
                    FAILED_AT.put(id, System.currentTimeMillis());
                    e.printStackTrace();
                }
            }

        } catch (Throwable t) {
            t.printStackTrace();
        }
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------

    /** Manager record first (same rule as the payroll screens), then employee. */
    private static String findEmail(String employeeId) throws Exception {

        String[] tables = {"managers", "employees"};

        for (String table : tables) {
            try (Connection con = DBcConnection.getConnection();
                 PreparedStatement ps = con.prepareStatement(
                         "SELECT email FROM " + table + " WHERE employee_id = ?")) {

                ps.setString(1, employeeId);

                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        String email = rs.getString("email");
                        if (email != null && !email.trim().isEmpty()) {
                            return email;
                        }
                    }
                }
            }
        }

        return null;
    }

    /** Guards "check, then claim" so two threads can never both send the same slip. */
    private static final Object CLAIM_LOCK = new Object();

    /** Another payroll row of the same person and month was already emailed. */
    private static boolean monthAlreadyEmailed(Payroll p) throws Exception {
        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "SELECT COUNT(*) FROM payroll WHERE employee_id = ? AND payroll_month = ? "
                     + "AND payroll_year = ? AND id <> ? AND slip_emailed_at IS NOT NULL")) {

            ps.setString(1, p.getEmployeeId());
            ps.setInt(2, p.getPayrollMonth());
            ps.setInt(3, p.getPayrollYear());
            ps.setInt(4, p.getId());

            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getInt(1) > 0;
            }
        }
    }

    private static void clearEmailed(int payrollId) {
        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "UPDATE payroll SET slip_emailed_at = NULL WHERE id = ?")) {

            ps.setInt(1, payrollId);
            ps.executeUpdate();

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private static boolean alreadyEmailed(int payrollId) throws Exception {
        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "SELECT slip_emailed_at FROM payroll WHERE id = ?")) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {
                return rs.next() && rs.getTimestamp(1) != null;
            }
        }
    }

    private static void markEmailed(int payrollId) throws Exception {
        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "UPDATE payroll SET slip_emailed_at = CURRENT_TIMESTAMP WHERE id = ?")) {

            ps.setInt(1, payrollId);
            ps.executeUpdate();
        }
    }

    /** Adds payroll.slip_emailed_at once (MySQL has no ADD COLUMN IF NOT EXISTS). */
    private static synchronized void ensureSchema() throws Exception {

        if (schemaReady) {
            return;
        }

        try (Connection con = DBcConnection.getConnection()) {

            boolean exists;

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS "
                    + "WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'payroll' "
                    + "AND COLUMN_NAME = 'slip_emailed_at'");
                 ResultSet rs = ps.executeQuery()) {

                rs.next();
                exists = rs.getInt(1) > 0;
            }

            if (!exists) {
                try (Statement st = con.createStatement()) {
                    st.executeUpdate("ALTER TABLE payroll ADD COLUMN slip_emailed_at DATETIME NULL");
                }
            }
        }

        schemaReady = true;
    }
}