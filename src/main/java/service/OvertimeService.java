package service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.sql.Time;
import java.time.DayOfWeek;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;

import model.DBcConnection;

/**
 * Overtime (OT) for employees.
 *
 * Flow
 *  1. The employee requests OT for a day (hours + reason)      -> PENDING
 *  2. The manager of the employee's team approves or rejects   -> APPROVED / REJECTED
 *     MANAGERS request OT the same way, but their request goes to the ADMIN,
 *     who approves / rejects it (decideAsAdmin). A manager's OT works exactly like
 *     an employee's: same check-out rule, same pay month, same salary slip.
 *  3. On approval the check-out of that day becomes
 *        AttendanceAutoCheckout.CUTOFF (6:10 PM) + approved hours
 *     (e.g. 2 h OT -> 8:10 PM) and the attendance status is worked out again.
 *     If the employee is still checked in today, nothing is written yet: the
 *     auto check-out (or the Check Out button) uses the OT time instead of 6:10 PM.
 *  4. When payroll is generated, all approved OT of that pay month is added to
 *     the gross salary automatically and printed on the salary slip
 *     (hours, rate and amount).
 *
 * OT pay = approved hours x hourly rate
 * hourly rate = gross salary (basic + earnings) / (working days Mon-Fri x 8 h) x OT_MULTIPLIER
 *
 * Which pay month? The month of the OT day - unless the payroll of that month
 * is already generated / paid; then the OT is paid with the next payroll
 * (a paid salary slip is never changed afterwards).
 *
 * No foreign keys and no SQL joins on the ID columns, so it works whatever
 * collation the existing tables use.
 */
public final class OvertimeService {

    /** 1.0 = normal rate. Use 1.5 or 2.0 if the company pays extra for overtime. */
    public static final BigDecimal OT_MULTIPLIER = new BigDecimal("1.0");

    /** Standard working hours of one day (used for the hourly rate). */
    public static final int STANDARD_HOURS_PER_DAY = 8;

    /** One request can ask for at most this many hours (keeps check-out before midnight). */
    public static final double MAX_HOURS = 5;

    /** OT can be requested for today and this many days back. */
    public static final int MAX_DAYS_BACK = 7;

    private static volatile boolean schemaDone = false;

    private OvertimeService() { }

    // ------------------------------------------------------------------
    // Data holders
    // ------------------------------------------------------------------

    public static class OtRequest {
        public int id;
        public String employeeId;
        public String employeeName;
        public LocalDate otDate;
        public BigDecimal hours;
        public String reason;
        public String status;        // PENDING / APPROVED / REJECTED
        public String decidedBy;
        public String managerNote;
        public Integer payMonth;
        public Integer payYear;
        public Integer payrollId;
        public BigDecimal amount;    // filled when payroll has been generated
        public LocalTime checkOutTime; // CUTOFF + hours
    }

    /** OT of one payroll: total hours, rate, amount and a short description. */
    public static class OtSummary {
        public BigDecimal hours = BigDecimal.ZERO;
        public BigDecimal rate = BigDecimal.ZERO;
        public BigDecimal amount = BigDecimal.ZERO;
        public String detail = "";

        public boolean isEmpty() {
            return hours.signum() == 0;
        }
    }

    // ------------------------------------------------------------------
    // Schema
    // ------------------------------------------------------------------

    public static synchronized void ensureSchema() {

        if (schemaDone) {
            return;
        }

        String ddl =
                "CREATE TABLE IF NOT EXISTS ot_requests ("
                + "id INT AUTO_INCREMENT PRIMARY KEY,"
                + "employee_id VARCHAR(20) NOT NULL,"
                + "ot_date DATE NOT NULL,"
                + "ot_hours DECIMAL(4,2) NOT NULL,"
                + "reason VARCHAR(500) NOT NULL,"
                + "status VARCHAR(15) NOT NULL DEFAULT 'PENDING',"
                + "requested_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,"
                + "decided_by VARCHAR(20) NULL,"
                + "decided_at TIMESTAMP NULL,"
                + "manager_note VARCHAR(300) NULL,"
                + "pay_month INT NULL,"
                + "pay_year INT NULL,"
                + "payroll_id INT NULL,"
                + "amount DECIMAL(12,2) NULL,"
                + "KEY idx_ot_emp (employee_id, ot_date),"
                + "KEY idx_ot_pay (employee_id, pay_month, pay_year, status),"
                + "KEY idx_ot_payroll (payroll_id))";

        try (Connection con = DBcConnection.getConnection();
             Statement st = con.createStatement()) {

            st.executeUpdate(ddl);
            schemaDone = true;

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // ------------------------------------------------------------------
    // Employee: request
    // ------------------------------------------------------------------

    /**
     * Creates a PENDING request. Throws IllegalArgumentException with a message
     * that can be shown to the employee.
     */
    public static void request(String employeeId, LocalDate otDate,
                               double hours, String reason) throws SQLException {

        ensureSchema();

        reason = reason == null ? "" : reason.trim();

        if (otDate == null) {
            throw new IllegalArgumentException("Select the overtime date.");
        }
        if (hours < 0.5 || hours > MAX_HOURS || (hours * 2) != Math.rint(hours * 2)) {
            throw new IllegalArgumentException("Overtime must be between 0.5 and "
                    + (int) MAX_HOURS + " hours, in steps of 0.5.");
        }
        if (reason.isEmpty()) {
            throw new IllegalArgumentException("Enter the reason for the overtime.");
        }
        if (reason.length() > 500) {
            throw new IllegalArgumentException("Reason is too long (max 500 characters).");
        }

        try (Connection con = DBcConnection.getConnection()) {

            if (con == null) {
                throw new SQLException("Database connection unavailable.");
            }

            LocalDate today = dbToday(con);

            if (otDate.isAfter(today)) {
                throw new IllegalArgumentException("Overtime cannot be requested for a future date.");
            }
            if (otDate.isBefore(today.minusDays(MAX_DAYS_BACK))) {
                throw new IllegalArgumentException("Overtime can be requested only for the last "
                        + MAX_DAYS_BACK + " days.");
            }

            // must have been at work that day
            Time in = null;
            Time out = null;
            boolean found = false;

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT check_in_time, check_out_time FROM attendance "
                    + "WHERE employee_id = ? AND date = ?")) {
                ps.setString(1, employeeId);
                ps.setDate(2, Date.valueOf(otDate));
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        found = true;
                        in = rs.getTime(1);
                        out = rs.getTime(2);
                    }
                }
            }

            if (!found || in == null) {
                throw new IllegalArgumentException("You have no check-in on " + otDate
                        + ", so overtime cannot be requested for that day.");
            }
            if (out != null && out.toLocalTime().isBefore(AttendanceAutoCheckout.CUTOFF)) {
                throw new IllegalArgumentException("You checked out before "
                        + AttendanceAutoCheckout.CUTOFF + " on " + otDate
                        + ", so overtime cannot be requested for that day.");
            }

            // one active request per day
            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT COUNT(*) FROM ot_requests WHERE employee_id = ? AND ot_date = ? "
                    + "AND status IN ('PENDING','APPROVED')")) {
                ps.setString(1, employeeId);
                ps.setDate(2, Date.valueOf(otDate));
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next() && rs.getInt(1) > 0) {
                        throw new IllegalArgumentException(
                                "You already have a pending or approved overtime request for " + otDate + ".");
                    }
                }
            }

            try (PreparedStatement ps = con.prepareStatement(
                    "INSERT INTO ot_requests (employee_id, ot_date, ot_hours, reason, status) "
                    + "VALUES (?, ?, ?, ?, 'PENDING')")) {
                ps.setString(1, employeeId);
                ps.setDate(2, Date.valueOf(otDate));
                ps.setBigDecimal(3, BigDecimal.valueOf(hours).setScale(2, RoundingMode.HALF_UP));
                ps.setString(4, reason);
                ps.executeUpdate();
            }
        }
    }

    // ------------------------------------------------------------------
    // Manager: approve / reject
    // ------------------------------------------------------------------

    /** IDs of the active employees in the active teams of this manager. */
    public static List<String> teamEmployeeIds(String managerId) throws SQLException {

        List<String> ids = new ArrayList<String>();

        String sql = "SELECT DISTINCT tm.employee_id FROM team_members tm "
                + "JOIN teams t ON t.team_id = tm.team_id "
                + "WHERE t.manager_id = ? AND t.status = 'ACTIVE' AND tm.status = 'ACTIVE'";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, managerId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    ids.add(rs.getString(1));
                }
            }
        }

        return ids;
    }

    /**
     * Approves or rejects a request of one of the manager's team members.
     * On approval the check-out time of that day is changed (see class comment).
     *
     * @return a message for the manager
     */
    public static String decide(int requestId, String managerId,
                                boolean approve, String note) throws SQLException {
        return decideInternal(requestId, managerId, managerId, approve, note);
    }

    /**
     * Approves or rejects the OT request of a MANAGER (admin only).
     *
     * @param adminId stored in decided_by (max 20 characters)
     */
    public static String decideAsAdmin(int requestId, String adminId,
                                       boolean approve, String note) throws SQLException {
        return decideInternal(requestId, adminId, null, approve, note);
    }

    /**
     * @param decidedBy       who is deciding (manager id or admin id)
     * @param teamManagerId   the deciding manager (team check) or null when the ADMIN decides
     */
    private static String decideInternal(int requestId, String decidedBy, String teamManagerId,
                                         boolean approve, String note) throws SQLException {

        ensureSchema();

        if (decidedBy == null || decidedBy.trim().isEmpty()) {
            decidedBy = "ADMIN";
        }
        if (decidedBy.length() > 20) {
            decidedBy = decidedBy.substring(0, 20);
        }

        note = note == null ? "" : note.trim();
        if (note.length() > 300) {
            note = note.substring(0, 300);
        }

        try (Connection con = DBcConnection.getConnection()) {

            if (con == null) {
                throw new SQLException("Database connection unavailable.");
            }

            String employeeId;
            LocalDate otDate;
            BigDecimal hours;
            String status;

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT employee_id, ot_date, ot_hours, status FROM ot_requests WHERE id = ?")) {
                ps.setInt(1, requestId);
                try (ResultSet rs = ps.executeQuery()) {
                    if (!rs.next()) {
                        throw new IllegalArgumentException("Overtime request not found.");
                    }
                    employeeId = rs.getString(1);
                    otDate = rs.getDate(2).toLocalDate();
                    hours = rs.getBigDecimal(3);
                    status = rs.getString(4);
                }
            }

            if (!"PENDING".equalsIgnoreCase(status)) {
                throw new IllegalArgumentException("This request has already been " + status.toLowerCase() + ".");
            }

            boolean requesterIsManager = managerIds(con).contains(employeeId);

            if (teamManagerId == null) {
                // admin: only manager requests
                if (!requesterIsManager) {
                    throw new IllegalArgumentException(
                            "Only manager overtime requests are approved by the admin.");
                }
            } else {
                // manager: only team members, never another manager (incl. himself)
                if (requesterIsManager) {
                    throw new IllegalArgumentException(
                            "Manager overtime has to be approved by the admin.");
                }
                if (!teamEmployeeIds(teamManagerId).contains(employeeId)) {
                    throw new IllegalArgumentException("This employee is not in one of your teams.");
                }
            }

            if (!approve) {
                try (PreparedStatement ps = con.prepareStatement(
                        "UPDATE ot_requests SET status = 'REJECTED', decided_by = ?, "
                        + "decided_at = CURRENT_TIMESTAMP, manager_note = ? "
                        + "WHERE id = ? AND status = 'PENDING'")) {
                    ps.setString(1, decidedBy);
                    ps.setString(2, note);
                    ps.setInt(3, requestId);
                    ps.executeUpdate();
                }
                return "Overtime request rejected.";
            }

            YearMonth pay = payMonthFor(con, employeeId, otDate);

            int changed;

            try (PreparedStatement ps = con.prepareStatement(
                    "UPDATE ot_requests SET status = 'APPROVED', decided_by = ?, "
                    + "decided_at = CURRENT_TIMESTAMP, manager_note = ?, "
                    + "pay_month = ?, pay_year = ? "
                    + "WHERE id = ? AND status = 'PENDING'")) {
                ps.setString(1, decidedBy);
                ps.setString(2, note);
                ps.setInt(3, pay.getMonthValue());
                ps.setInt(4, pay.getYear());
                ps.setInt(5, requestId);
                changed = ps.executeUpdate();
            }

            if (changed == 0) {
                throw new IllegalArgumentException("This request has already been decided.");
            }

            // check-out becomes 6:10 PM + OT hours
            boolean applied = applyToAttendance(con, employeeId, otDate, hours);

            LocalTime newOut = checkOutFor(hours);

            return "Overtime approved. Check-out of " + otDate + " "
                    + (applied ? "changed to " : "will be set to ") + newOut
                    + " and the OT pay goes into the " + pay.getMonth() + " " + pay.getYear()
                    + " salary.";
        }
    }

    // ------------------------------------------------------------------
    // Attendance
    // ------------------------------------------------------------------

    /** Check-out time for an approved OT: CUTOFF + hours. */
    public static LocalTime checkOutFor(BigDecimal hours) {
        long minutes = hours.multiply(new BigDecimal("60")).setScale(0, RoundingMode.HALF_UP).longValue();
        return AttendanceAutoCheckout.CUTOFF.plusMinutes(minutes);
    }

    /**
     * Writes the OT check-out of a day. The check-out time is only written when
     * the employee is already checked out (or the day is over); an employee who
     * is still working today is closed later by the auto check-out / Check Out
     * button using the OT time.
     *
     * @return true if the attendance row was changed
     */
    private static boolean applyToAttendance(Connection con, String employeeId,
                                             LocalDate day, BigDecimal hours) throws SQLException {

        LocalTime newOut = checkOutFor(hours);
        Time checkIn = null;
        Time checkOut = null;

        try (PreparedStatement ps = con.prepareStatement(
                "SELECT check_in_time, check_out_time FROM attendance "
                + "WHERE employee_id = ? AND date = ?")) {
            ps.setString(1, employeeId);
            ps.setDate(2, Date.valueOf(day));
            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    checkIn = rs.getTime(1);
                    checkOut = rs.getTime(2);
                }
            }
        }

        if (checkIn == null) {
            return false;
        }

        boolean today = day.equals(dbToday(con));

        if (checkOut == null && today) {
            return false; // still working: closed later with the OT time
        }

        return writeCheckOut(con, employeeId, day, checkIn.toLocalTime(), newOut);
    }

    /** Sets check_out_time + status and ends a break that is still running. */
    static boolean writeCheckOut(Connection con, String employeeId, LocalDate day,
                                 LocalTime checkIn, LocalTime newOut) throws SQLException {

        int changed;

        try (PreparedStatement ps = con.prepareStatement(
                "UPDATE attendance SET check_out_time = ?, status = ? "
                + "WHERE employee_id = ? AND date = ?")) {
            ps.setTime(1, Time.valueOf(newOut));
            ps.setString(2, AttendanceAutoCheckout.statusFor(checkIn, newOut));
            ps.setString(3, employeeId);
            ps.setDate(4, Date.valueOf(day));
            changed = ps.executeUpdate();
        }

        if (changed > 0) {
            try (PreparedStatement ps = con.prepareStatement(
                    "UPDATE breaks SET break_end = ? "
                    + "WHERE employee_id = ? AND break_date = ? "
                    + "AND break_end IS NULL AND break_start <= ?")) {
                ps.setTime(1, Time.valueOf(newOut));
                ps.setString(2, employeeId);
                ps.setDate(3, Date.valueOf(day));
                ps.setTime(4, Time.valueOf(newOut));
                ps.executeUpdate();
            }
        }

        return changed > 0;
    }

    /**
     * Called right after an employee pressed Check Out: if today has an approved
     * OT and the employee stayed beyond 6:10 PM, the check-out becomes 6:10 PM +
     * the approved OT hours. Never throws.
     */
    public static void applyApprovedForToday(String employeeId) {

        try {
            ensureSchema();

            try (Connection con = DBcConnection.getConnection()) {

                if (con == null) {
                    return;
                }

                LocalDate today = dbToday(con);

                BigDecimal hours = null;

                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT ot_hours FROM ot_requests WHERE employee_id = ? "
                        + "AND ot_date = ? AND status = 'APPROVED'")) {
                    ps.setString(1, employeeId);
                    ps.setDate(2, Date.valueOf(today));
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            hours = rs.getBigDecimal(1);
                        }
                    }
                }

                if (hours == null) {
                    return;
                }

                Time checkIn = null;
                Time checkOut = null;

                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT check_in_time, check_out_time FROM attendance "
                        + "WHERE employee_id = ? AND date = ?")) {
                    ps.setString(1, employeeId);
                    ps.setDate(2, Date.valueOf(today));
                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            checkIn = rs.getTime(1);
                            checkOut = rs.getTime(2);
                        }
                    }
                }

                // left before 6:10 PM: no overtime was worked
                if (checkIn == null || checkOut == null
                        || checkOut.toLocalTime().isBefore(AttendanceAutoCheckout.CUTOFF)) {
                    return;
                }

                writeCheckOut(con, employeeId, today, checkIn.toLocalTime(), checkOutFor(hours));
            }

        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    // ------------------------------------------------------------------
    // Queries for the OT page
    // ------------------------------------------------------------------

    /** Own requests, newest first. */
    public static List<OtRequest> forEmployee(String employeeId) throws SQLException {
        ensureSchema();
        return query("WHERE employee_id = ? ORDER BY ot_date DESC, id DESC", employeeId);
    }

    /** Requests of the manager's team members with the given status ("" = all). */
    public static List<OtRequest> forManager(String managerId, String status) throws SQLException {

        ensureSchema();

        List<String> ids = teamEmployeeIds(managerId);

        if (ids.isEmpty()) {
            return new ArrayList<OtRequest>();
        }

        StringBuilder in = new StringBuilder();
        for (int i = 0; i < ids.size(); i++) {
            in.append(i == 0 ? "?" : ",?");
        }

        List<Object> params = new ArrayList<Object>(ids);
        String where = "WHERE employee_id IN (" + in + ") ";

        if (status != null && !status.isEmpty()) {
            where += "AND status = ? ";
            params.add(status);
        }

        return query(where + "ORDER BY ot_date DESC, id DESC", params.toArray());
    }

    /** IDs of all managers (their OT requests are decided by the admin). */
    static List<String> managerIds(Connection con) throws SQLException {

        List<String> ids = new ArrayList<String>();

        try (Statement st = con.createStatement();
             ResultSet rs = st.executeQuery("SELECT employee_id FROM managers")) {
            while (rs.next()) {
                ids.add(rs.getString(1));
            }
        }

        return ids;
    }

    /** Requests made by managers with the given status ("" = all) - for the admin. */
    public static List<OtRequest> forAdmin(String status) throws SQLException {

        ensureSchema();

        List<String> ids;

        try (Connection con = DBcConnection.getConnection()) {
            ids = managerIds(con);
        }

        if (ids.isEmpty()) {
            return new ArrayList<OtRequest>();
        }

        StringBuilder in = new StringBuilder();
        for (int i = 0; i < ids.size(); i++) {
            in.append(i == 0 ? "?" : ",?");
        }

        List<Object> params = new ArrayList<Object>(ids);
        String where = "WHERE employee_id IN (" + in + ") ";

        if (status != null && !status.isEmpty()) {
            where += "AND status = ? ";
            params.add(status);
        }

        return query(where + "ORDER BY ot_date DESC, id DESC", params.toArray());
    }

    private static List<OtRequest> query(String tail, Object... params) throws SQLException {

        List<OtRequest> list = new ArrayList<OtRequest>();

        String sql = "SELECT id, employee_id, ot_date, ot_hours, reason, status, decided_by, "
                + "manager_note, pay_month, pay_year, payroll_id, amount FROM ot_requests " + tail;

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            for (int i = 0; i < params.length; i++) {
                ps.setObject(i + 1, params[i]);
            }

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    OtRequest r = new OtRequest();
                    r.id = rs.getInt(1);
                    r.employeeId = rs.getString(2);
                    r.otDate = rs.getDate(3).toLocalDate();
                    r.hours = rs.getBigDecimal(4);
                    r.reason = rs.getString(5);
                    r.status = rs.getString(6);
                    r.decidedBy = rs.getString(7);
                    r.managerNote = rs.getString(8);
                    int pm = rs.getInt(9);
                    r.payMonth = rs.wasNull() ? null : pm;
                    int py = rs.getInt(10);
                    r.payYear = rs.wasNull() ? null : py;
                    int pid = rs.getInt(11);
                    r.payrollId = rs.wasNull() ? null : pid;
                    r.amount = rs.getBigDecimal(12);
                    r.checkOutTime = checkOutFor(r.hours);
                    list.add(r);
                }
            }

            // names (separate lookups: no join on the ID columns)
            java.util.Map<String, String> names = new java.util.HashMap<String, String>();

            for (OtRequest r : list) {
                if (!names.containsKey(r.employeeId)) {
                    names.put(r.employeeId, nameOf(con, r.employeeId));
                }
                r.employeeName = names.get(r.employeeId);
            }
        }

        return list;
    }

    private static String nameOf(Connection con, String id) {
        for (String table : new String[] { "employees", "managers" }) {
            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT name FROM " + table + " WHERE employee_id = ?")) {
                ps.setString(1, id);
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next() && rs.getString(1) != null) {
                        return rs.getString(1);
                    }
                }
            } catch (Exception ignored) {
                // try the next table
            }
        }
        return id;
    }

    // ------------------------------------------------------------------
    // Payroll
    // ------------------------------------------------------------------

    /** Hourly OT rate for a gross salary in the given pay month. */
    public static BigDecimal hourlyRate(BigDecimal gross, int month, int year) {

        if (gross == null || gross.signum() <= 0) {
            return BigDecimal.ZERO;
        }

        YearMonth ym = YearMonth.of(year, month);
        int weekdays = 0;

        for (int d = 1; d <= ym.lengthOfMonth(); d++) {
            DayOfWeek dow = ym.atDay(d).getDayOfWeek();
            if (dow != DayOfWeek.SATURDAY && dow != DayOfWeek.SUNDAY) {
                weekdays++;
            }
        }

        BigDecimal hoursInMonth = BigDecimal.valueOf((long) weekdays * STANDARD_HOURS_PER_DAY);

        return gross.multiply(OT_MULTIPLIER)
                .divide(hoursInMonth, 2, RoundingMode.HALF_UP);
    }

    /**
     * Approved OT that belongs to the payroll of this month, valued with the
     * hourly rate of the given gross salary. Used while the payroll is calculated.
     */
    public static OtSummary summaryFor(String employeeId, int month, int year,
                                       BigDecimal baseGross) throws SQLException {

        ensureSchema();

        OtSummary s = new OtSummary();
        s.rate = hourlyRate(baseGross, month, year);

        StringBuilder detail = new StringBuilder();

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "SELECT ot_date, ot_hours FROM ot_requests WHERE employee_id = ? "
                     + "AND status = 'APPROVED' AND pay_month = ? AND pay_year = ? "
                     + "ORDER BY ot_date")) {

            ps.setString(1, employeeId);
            ps.setInt(2, month);
            ps.setInt(3, year);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    BigDecimal h = rs.getBigDecimal(2);
                    s.hours = s.hours.add(h);
                    s.amount = s.amount.add(h.multiply(s.rate).setScale(2, RoundingMode.HALF_UP));
                    if (detail.length() > 0) detail.append(", ");
                    detail.append(rs.getDate(1).toLocalDate().getDayOfMonth()).append('/')
                          .append(month).append(" ").append(h.stripTrailingZeros().toPlainString()).append("h");
                }
            }
        }

        s.detail = detail.toString();
        return s;
    }

    /** Estimated OT pay of one request (for the OT page); null if no salary structure. */
    public static BigDecimal estimateAmount(String employeeId, int payMonth, int payYear,
                                            BigDecimal hours) {
        try {
            DAO.SalaryStructureDAO sDao = new DAO.SalaryStructureDAO();
            model.SalaryStructure st = sDao.getStructureForPayroll(
                    employeeId, Date.valueOf(YearMonth.of(payYear, payMonth).atEndOfMonth()));

            if (st == null) {
                return null;
            }

            List<model.SalaryComponent> comps =
                    new DAO.SalaryComponentDAO().getComponentsByStructureId(st.getId());

            util.PayrollCalculator.PayrollCalculation base =
                    util.PayrollCalculator.calculate(st, comps, BigDecimal.ZERO);

            return hours.multiply(hourlyRate(base.getGrossSalary(), payMonth, payYear))
                    .setScale(2, RoundingMode.HALF_UP);

        } catch (Exception e) {
            return null;
        }
    }

    /**
     * Links the approved OT of the pay month to the generated payroll and stores
     * each request's amount, so the salary slip can show it later.
     */
    public static void attachToPayroll(int payrollId, String employeeId, int month, int year,
                                       BigDecimal rate) throws SQLException {

        ensureSchema();

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "UPDATE ot_requests SET payroll_id = ?, amount = ROUND(ot_hours * ?, 2) "
                     + "WHERE employee_id = ? AND status = 'APPROVED' "
                     + "AND pay_month = ? AND pay_year = ?")) {

            ps.setInt(1, payrollId);
            ps.setBigDecimal(2, rate);
            ps.setString(3, employeeId);
            ps.setInt(4, month);
            ps.setInt(5, year);
            ps.executeUpdate();
        }
    }

    /** OT printed on the salary slip of this payroll (empty summary if none). */
    public static OtSummary forPayroll(int payrollId) {

        OtSummary s = new OtSummary();

        try {
            ensureSchema();

            StringBuilder detail = new StringBuilder();

            try (Connection con = DBcConnection.getConnection();
                 PreparedStatement ps = con.prepareStatement(
                         "SELECT ot_date, ot_hours, amount FROM ot_requests "
                         + "WHERE payroll_id = ? AND status = 'APPROVED' ORDER BY ot_date")) {

                ps.setInt(1, payrollId);

                try (ResultSet rs = ps.executeQuery()) {
                    while (rs.next()) {
                        BigDecimal h = rs.getBigDecimal(2);
                        BigDecimal a = rs.getBigDecimal(3);
                        s.hours = s.hours.add(h);
                        s.amount = s.amount.add(a == null ? BigDecimal.ZERO : a);
                        if (detail.length() > 0) detail.append(", ");
                        LocalDate d = rs.getDate(1).toLocalDate();
                        detail.append(d.getDayOfMonth()).append('/').append(d.getMonthValue())
                              .append(" ").append(h.stripTrailingZeros().toPlainString()).append("h");
                    }
                }
            }

            if (s.hours.signum() > 0) {
                s.rate = s.amount.divide(s.hours, 2, RoundingMode.HALF_UP);
            }
            s.detail = detail.toString();

        } catch (Exception e) {
            e.printStackTrace();
        }

        return s;
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------

    /** Pay month = month of the OT day, or the next free month if that payroll is already final. */
    private static YearMonth payMonthFor(Connection con, String employeeId, LocalDate otDate)
            throws SQLException {

        YearMonth ym = YearMonth.from(otDate);

        for (int i = 0; i < 24; i++) {

            String status = null;

            try (PreparedStatement ps = con.prepareStatement(
                    "SELECT status FROM payroll WHERE employee_id = ? "
                    + "AND payroll_month = ? AND payroll_year = ?")) {
                ps.setString(1, employeeId);
                ps.setInt(2, ym.getMonthValue());
                ps.setInt(3, ym.getYear());
                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        status = rs.getString(1);
                    }
                }
            }

            if (status == null || "DRAFT".equalsIgnoreCase(status)) {
                return ym;
            }

            ym = ym.plusMonths(1); // that salary is already generated / paid
        }

        return ym;
    }

    private static LocalDate dbToday(Connection con) throws SQLException {
        try (Statement st = con.createStatement();
             ResultSet rs = st.executeQuery("SELECT CURDATE()")) {
            if (rs.next()) {
                return rs.getDate(1).toLocalDate();
            }
        }
        return LocalDate.now();
    }
}