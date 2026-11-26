
package DAO;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import model.DBcConnection;
import model.Payroll;

public class PayrollDAO {

    public int createDraft(Payroll payroll) throws SQLException {

        validatePeriod(payroll);

        if (payroll.getBasicSalary() == null
                || payroll.getBasicSalary().signum() < 0) {
            throw new IllegalArgumentException(
                    "Basic salary must be zero or greater.");
        }

        String sql =
                "INSERT INTO payroll " +
                "(employee_id, payroll_month, payroll_year, " +
                "basic_salary, gross_salary, total_deductions, " +
                "net_salary, status) " +
                "VALUES (?, ?, ?, ?, 0.00, 0.00, 0.00, 'DRAFT')";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     sql, PreparedStatement.RETURN_GENERATED_KEYS)) {

            ps.setString(1, payroll.getEmployeeId());
            ps.setInt(2, payroll.getPayrollMonth());
            ps.setInt(3, payroll.getPayrollYear());
            ps.setBigDecimal(4, payroll.getBasicSalary());

            ps.executeUpdate();

            try (ResultSet keys = ps.getGeneratedKeys()) {
                if (keys.next()) {
                    return keys.getInt(1);
                }
            }
        }

        throw new SQLException("Unable to create payroll draft.");
    }

    public Payroll getPayrollById(int payrollId) throws SQLException {

        String sql = "SELECT * FROM payroll WHERE id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapPayroll(rs);
                }
            }
        }

        return null;
    }

    public Payroll getPayrollForPeriod(
            String employeeId, int month, int year) throws SQLException {

        String sql =
                "SELECT * FROM payroll " +
                "WHERE employee_id = ? " +
                "AND payroll_month = ? AND payroll_year = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);
            ps.setInt(2, month);
            ps.setInt(3, year);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapPayroll(rs);
                }
            }
        }

        return null;
    }

    public boolean updateDraftAmounts(Payroll payroll)
            throws SQLException {

        if (payroll == null || payroll.getId() <= 0) {
            throw new IllegalArgumentException("Invalid payroll record.");
        }

        validateAmounts(
                payroll.getBasicSalary(),
                payroll.getGrossSalary(),
                payroll.getTotalDeductions(),
                payroll.getNetSalary()
        );

        String sql =
                "UPDATE payroll SET " +
                "basic_salary = ?, " +
                "gross_salary = ?, " +
                "total_deductions = ?, " +
                "net_salary = ? " +
                "WHERE id = ? AND status = 'DRAFT'";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setBigDecimal(1, payroll.getBasicSalary());
            ps.setBigDecimal(2, payroll.getGrossSalary());
            ps.setBigDecimal(3, payroll.getTotalDeductions());
            ps.setBigDecimal(4, payroll.getNetSalary());
            ps.setInt(5, payroll.getId());

            return ps.executeUpdate() > 0;
        }
    }

    public boolean updateDraftAmounts(
            int payrollId,
            BigDecimal basicSalary,
            BigDecimal grossSalary,
            BigDecimal deductions,
            BigDecimal netSalary) throws SQLException {

        validateAmounts(
                basicSalary, grossSalary, deductions, netSalary);

        String sql =
                "UPDATE payroll SET basic_salary = ?, " +
                "gross_salary = ?, total_deductions = ?, net_salary = ? " +
                "WHERE id = ? AND status = 'DRAFT'";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setBigDecimal(1, basicSalary);
            ps.setBigDecimal(2, grossSalary);
            ps.setBigDecimal(3, deductions);
            ps.setBigDecimal(4, netSalary);
            ps.setInt(5, payrollId);

            return ps.executeUpdate() > 0;
        }
    }

    public boolean finalizePayroll(
            int payrollId, String administratorId) throws SQLException {

        if (payrollId <= 0
                || administratorId == null
                || administratorId.trim().isEmpty()) {
            throw new IllegalArgumentException(
                    "Valid payroll and administrator are required.");
        }

        String sql =
                "UPDATE payroll SET status = 'PROCESSED', " +
                "processed_by = ?, processed_at = CURRENT_TIMESTAMP " +
                "WHERE id = ? AND status = 'DRAFT'";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, administratorId);
            ps.setInt(2, payrollId);

            return ps.executeUpdate() > 0;
        }
    }

    public List<Payroll> getEmployeePayrollHistory(String employeeId)
            throws SQLException {

        List<Payroll> list = new ArrayList<>();

        String sql =
                "SELECT * FROM payroll WHERE employee_id = ? " +
                "ORDER BY payroll_year DESC, payroll_month DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapPayroll(rs));
                }
            }
        }

        return list;
    }

    public List<Payroll> getPayrollByPeriod(int month, int year)
            throws SQLException {

        List<Payroll> list = new ArrayList<>();

        String sql =
                "SELECT * FROM payroll " +
                "WHERE payroll_month = ? AND payroll_year = ? " +
                "ORDER BY employee_id";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, month);
            ps.setInt(2, year);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapPayroll(rs));
                }
            }
        }

        return list;
    }

    /*
     * When the same ID exists in both tables, use the manager's
     * name, department and designation for payroll display.
     */
    private static final String DETAIL_SELECT =
            "SELECT p.*, " +
            "COALESCE(m.name, e.name, '') AS employee_name, " +
            "COALESCE(m.department, e.department, '') AS department, " +
            "COALESCE(m.designation, e.designation, '') AS designation, " +
            "(CASE WHEN m.employee_id IS NOT NULL THEN 'MANAGER' " +
            "WHEN e.employee_id IS NOT NULL THEN 'EMPLOYEE' ELSE '' END) " +
            "AS person_type, " +
            "COALESCE((SELECT SUM(pp.amount_paid) " +
            "FROM payroll_payments pp WHERE pp.payroll_id = p.id), 0) " +
            "AS paid_amount " +
            "FROM payroll p " +
            "LEFT JOIN managers m ON m.employee_id = p.employee_id " +
            "LEFT JOIN employees e ON e.employee_id = p.employee_id ";

    private Payroll mapDetailed(ResultSet rs) throws SQLException {

        Payroll payroll = mapPayroll(rs);
        payroll.setEmployeeName(rs.getString("employee_name"));
        payroll.setDepartment(rs.getString("department"));
        payroll.setDesignation(rs.getString("designation"));
        payroll.setPaidAmount(rs.getBigDecimal("paid_amount"));
        payroll.setPersonType(rs.getString("person_type"));

        return payroll;
    }

    public List<Payroll> getPayrollRowsByPeriod(int month, int year)
            throws SQLException {

        return searchPayroll(month, year, "", "", "");
    }

    /*
     * Filtered payroll list.
     * Month/year = 0 means all; blank text means no filter.
     */
    public List<Payroll> searchPayroll(
            int month, int year, String department,
            String status, String employeeId) throws SQLException {

        return searchPayroll(month, year, department, status, employeeId, "ALL");
    }

    /** Normalises a person-type filter to ALL, EMPLOYEE or MANAGER. */
    public static String normalizeType(String personType) {

        String t = personType == null ? "" : personType.trim().toUpperCase();

        if ("EMPLOYEE".equals(t) || "MANAGER".equals(t)) {
            return t;
        }

        return "ALL";
    }

    /** personType: ALL, EMPLOYEE or MANAGER. */
    public List<Payroll> searchPayroll(
            int month, int year, String department,
            String status, String employeeId, String personType)
            throws SQLException {

        List<Payroll> list = new ArrayList<>();

        String type = normalizeType(personType);
        String typeFilter = "ALL".equals(type) ? "" : type;

        String dept = department == null ? "" : department.trim();
        String st = status == null ? "" : status.trim().toUpperCase();
        String emp = employeeId == null ? "" : employeeId.trim();

        String sql = DETAIL_SELECT +
                "WHERE (? = 0 OR p.payroll_month = ?) " +
                "AND (? = 0 OR p.payroll_year = ?) " +
                "AND (? = '' OR COALESCE(m.department, e.department) = ?) " +
                "AND (? = '' OR p.status = ?) " +
                "AND (? = '' OR p.employee_id = ?) " +
                "AND (? = '' OR (CASE WHEN m.employee_id IS NOT NULL THEN 'MANAGER' " +
                "WHEN e.employee_id IS NOT NULL THEN 'EMPLOYEE' ELSE '' END) = ?) " +
                "ORDER BY p.payroll_year DESC, p.payroll_month DESC, " +
                "p.employee_id";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            int i = 1;

            ps.setInt(i++, month);
            ps.setInt(i++, month);
            ps.setInt(i++, year);
            ps.setInt(i++, year);
            ps.setString(i++, dept);
            ps.setString(i++, dept);
            ps.setString(i++, st);
            ps.setString(i++, st);
            ps.setString(i++, emp);
            ps.setString(i++, emp);
            ps.setString(i++, typeFilter);
            ps.setString(i++, typeFilter);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapDetailed(rs));
                }
            }
        }

        return list;
    }

    public Payroll getPayrollDetailById(int payrollId)
            throws SQLException {

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     DETAIL_SELECT + "WHERE p.id = ?")) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapDetailed(rs);
                }
            }
        }

        return null;
    }

    /*
     * Returns active employees and active managers.
     * Manager IDs are collected first. Employees with the same IDs
     * are skipped, so a duplicate employee record is not added.
     *
     * Each row:
     * { employee_id, name, department, designation, type }
     */
    public List<String[]> getEligibleEmployees() throws SQLException {

        List<String[]> list = new ArrayList<>();
        Set<String> managerIds = new HashSet<>();

        String managerSql =
                "SELECT employee_id, name, department, designation " +
                "FROM managers " +
                "WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' " +
                "ORDER BY name";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(managerSql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {

                String id = rs.getString("employee_id");

                if (id == null || id.trim().isEmpty()) {
                    continue;
                }

                id = id.trim();
                managerIds.add(id);

                list.add(new String[]{
                        id,
                        rs.getString("name") == null
                                ? "" : rs.getString("name"),
                        rs.getString("department") == null
                                ? "" : rs.getString("department"),
                        rs.getString("designation") == null
                                ? "" : rs.getString("designation"),
                        "MANAGER"
                });
            }
        }

        String employeeSql =
                "SELECT employee_id, name, department, designation " +
                "FROM employees " +
                "WHERE UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE' " +
                "ORDER BY name";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(employeeSql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {

                String id = rs.getString("employee_id");

                if (id == null || id.trim().isEmpty()) {
                    continue;
                }

                id = id.trim();

                // Skip employee record if a manager has the same ID.
                if (managerIds.contains(id)) {
                    continue;
                }

                list.add(new String[]{
                        id,
                        rs.getString("name") == null
                                ? "" : rs.getString("name"),
                        rs.getString("department") == null
                                ? "" : rs.getString("department"),
                        rs.getString("designation") == null
                                ? "" : rs.getString("designation"),
                        "EMPLOYEE"
                });
            }
        }

        list.sort((a, b) -> a[1].compareToIgnoreCase(b[1]));

        return list;
    }

    /** personType: ALL, EMPLOYEE or MANAGER. Row: {id, name, dept, designation, type}. */
    public List<String[]> getEligibleEmployees(String personType)
            throws SQLException {

        String type = normalizeType(personType);

        if ("ALL".equals(type)) {
            return getEligibleEmployees();
        }

        List<String[]> filtered = new ArrayList<>();

        for (String[] row : getEligibleEmployees()) {
            if (type.equals(row[4])) {
                filtered.add(row);
            }
        }

        return filtered;
    }

    /** Latest payroll period that exists: {year, month}, or null if none yet. */
    public int[] getLatestPayrollPeriod() throws SQLException {

        String sql =
                "SELECT payroll_year, payroll_month FROM payroll " +
                "ORDER BY payroll_year DESC, payroll_month DESC LIMIT 1";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            return rs.next()
                    ? new int[]{rs.getInt(1), rs.getInt(2)} : null;
        }
    }

    /**
     * Marks a DRAFT / PROCESSED payroll as PAID in one transaction and records
     * the full (remaining) net salary as a bank-transfer payment, so the paid
     * amount in the history is correct. Returns false if the payroll was
     * already PAID or cancelled.
     */
    public boolean markPaid(int payrollId, String paidBy) throws SQLException {

        if (payrollId <= 0) {
            throw new IllegalArgumentException("Invalid payroll ID.");
        }

        Connection con = DBcConnection.getConnection();

        if (con == null) {
            throw new SQLException("Database connection unavailable.");
        }

        try (con) {
            con.setAutoCommit(false);

            try {
                BigDecimal net;
                String status;

                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT net_salary, status FROM payroll " +
                        "WHERE id = ? FOR UPDATE")) {

                    ps.setInt(1, payrollId);

                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) {
                            throw new SQLException("Payroll record not found.");
                        }
                        net = rs.getBigDecimal("net_salary");
                        status = rs.getString("status");
                    }
                }

                if (!("DRAFT".equalsIgnoreCase(status)
                        || "PROCESSED".equalsIgnoreCase(status))) {
                    con.rollback();
                    return false;
                }

                try (PreparedStatement ps = con.prepareStatement(
                        "UPDATE payroll SET status = 'PAID', " +
                        "processed_by = COALESCE(processed_by, ?), " +
                        "processed_at = COALESCE(processed_at, CURRENT_TIMESTAMP) " +
                        "WHERE id = ?")) {

                    ps.setString(1, paidBy == null || paidBy.trim().isEmpty()
                            ? "SYSTEM" : paidBy.trim());
                    ps.setInt(2, payrollId);
                    ps.executeUpdate();
                }

                BigDecimal alreadyPaid = BigDecimal.ZERO;

                try (PreparedStatement ps = con.prepareStatement(
                        "SELECT COALESCE(SUM(amount_paid), 0) " +
                        "FROM payroll_payments WHERE payroll_id = ?")) {

                    ps.setInt(1, payrollId);

                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            alreadyPaid = rs.getBigDecimal(1);
                        }
                    }
                }

                BigDecimal remaining = (net == null ? BigDecimal.ZERO : net)
                        .subtract(alreadyPaid);

                if (remaining.signum() > 0) {
                    try (PreparedStatement ps = con.prepareStatement(
                            "INSERT INTO payroll_payments " +
                            "(payroll_id, payment_date, payment_method, " +
                            "reference_number, amount_paid) " +
                            "VALUES (?, CURDATE(), 'BANK_TRANSFER', 'AUTO', ?)")) {

                        ps.setInt(1, payrollId);
                        ps.setBigDecimal(2, remaining);
                        ps.executeUpdate();
                    }
                }

                con.commit();

                // salary is now PAID: email the salary slip in the background
                service.SalarySlipMailer.sendAsync(payrollId);

                return true;

            } catch (Exception e) {
                try {
                    con.rollback();
                } catch (SQLException rollbackError) {
                    e.addSuppressed(rollbackError);
                }

                if (e instanceof SQLException) {
                    throw (SQLException) e;
                }
                if (e instanceof RuntimeException) {
                    throw (RuntimeException) e;
                }
                throw new SQLException("Unable to mark payroll as paid.", e);
            }
        }
    }

    public List<String> getDepartments() throws SQLException {

        java.util.TreeSet<String> set =
                new java.util.TreeSet<>(String.CASE_INSENSITIVE_ORDER);

        for (String table : new String[]{"employees", "managers"}) {

            String sql =
                    "SELECT DISTINCT department FROM " + table +
                    " WHERE department IS NOT NULL AND department <> ''";

            try (Connection con = DBcConnection.getConnection();
                 PreparedStatement ps = con.prepareStatement(sql);
                 ResultSet rs = ps.executeQuery()) {

                while (rs.next()) {
                    set.add(rs.getString(1));
                }
            }
        }

        return new ArrayList<>(set);
    }

    /*
     * Checks whether the ID belongs to an active employee or manager.
     */
    public boolean isActiveEmployee(String employeeId)
            throws SQLException {

        if (employeeId == null || employeeId.trim().isEmpty()) {
            return false;
        }

        /*
         * Manager is checked first. This method returns only a boolean,
         * so it does not return a person's identity.
         */
        for (String table : new String[]{"managers", "employees"}) {

            String sql =
                    "SELECT 1 FROM " + table +
                    " WHERE employee_id = ? " +
                    "AND UPPER(COALESCE(status, 'ACTIVE')) = 'ACTIVE'";

            try (Connection con = DBcConnection.getConnection();
                 PreparedStatement ps = con.prepareStatement(sql)) {

                ps.setString(1, employeeId.trim());

                try (ResultSet rs = ps.executeQuery()) {
                    if (rs.next()) {
                        return true;
                    }
                }
            }
        }

        return false;
    }

    // Attendance data used for payroll calculations.
    public java.util.Map<java.time.LocalDate, String> getAttendanceStatuses(
            String employeeId,
            java.time.LocalDate from,
            java.time.LocalDate to) throws SQLException {

        java.util.Map<java.time.LocalDate, String> map =
                new java.util.HashMap<>();

        String sql =
                "SELECT date, status FROM attendance " +
                "WHERE employee_id = ? AND date BETWEEN ? AND ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);
            ps.setDate(2, java.sql.Date.valueOf(from));
            ps.setDate(3, java.sql.Date.valueOf(to));

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {

                    java.sql.Date d = rs.getDate(1);

                    if (d != null) {
                        map.put(
                                d.toLocalDate(),
                                rs.getString(2) == null
                                        ? "" : rs.getString(2)
                        );
                    }
                }
            }
        }

        return map;
    }

    /*
     * Approved leave overlapping the date range:
     * { fromDate, toDate, leaveType }
     */
    public List<Object[]> getApprovedLeaves(
            String employeeId,
            java.time.LocalDate from,
            java.time.LocalDate to) throws SQLException {

        List<Object[]> list = new ArrayList<>();

        String sql =
                "SELECT from_date, to_date, leave_type " +
                "FROM leave_requests " +
                "WHERE employee_id = ? AND UPPER(status) = 'APPROVED' " +
                "AND from_date <= ? AND to_date >= ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);
            ps.setDate(2, java.sql.Date.valueOf(to));
            ps.setDate(3, java.sql.Date.valueOf(from));

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    java.sql.Date fromDate = rs.getDate(1);
                    java.sql.Date toDate = rs.getDate(2);

                    list.add(new Object[]{
                            fromDate == null ? null : fromDate.toLocalDate(),
                            toDate == null ? null : toDate.toLocalDate(),
                            rs.getString(3) == null ? "" : rs.getString(3)
                    });
                }
            }
        }

        return list;
    }

    private Payroll mapPayroll(ResultSet rs) throws SQLException {

        Payroll payroll = new Payroll();

        payroll.setId(rs.getInt("id"));
        payroll.setEmployeeId(rs.getString("employee_id"));
        payroll.setPayrollMonth(rs.getInt("payroll_month"));
        payroll.setPayrollYear(rs.getInt("payroll_year"));
        payroll.setBasicSalary(rs.getBigDecimal("basic_salary"));
        payroll.setGrossSalary(rs.getBigDecimal("gross_salary"));
        payroll.setTotalDeductions(rs.getBigDecimal("total_deductions"));
        payroll.setNetSalary(rs.getBigDecimal("net_salary"));
        payroll.setStatus(rs.getString("status"));
        payroll.setProcessedBy(rs.getString("processed_by"));

        java.sql.Timestamp timestamp = rs.getTimestamp("processed_at");

        if (timestamp != null) {
            payroll.setProcessedAt(timestamp.toLocalDateTime());
        }

        return payroll;
    }

    private void validatePeriod(Payroll payroll) {

        if (payroll == null
                || payroll.getEmployeeId() == null
                || payroll.getEmployeeId().trim().isEmpty()
                || payroll.getPayrollMonth() < 1
                || payroll.getPayrollMonth() > 12
                || payroll.getPayrollYear() < 2000
                || payroll.getPayrollYear() > 9999) {

            throw new IllegalArgumentException(
                    "Invalid employee or payroll period.");
        }
    }

    private void validateAmounts(
            BigDecimal basic,
            BigDecimal gross,
            BigDecimal deductions,
            BigDecimal net) {

        if (basic == null || gross == null
                || deductions == null || net == null
                || basic.signum() < 0
                || gross.signum() < 0
                || deductions.signum() < 0
                || net.signum() < 0) {

            throw new IllegalArgumentException(
                    "Payroll amounts must be zero or greater.");
        }

        if (gross.subtract(deductions).compareTo(net) != 0) {
            throw new IllegalArgumentException(
                    "Net salary must equal gross salary minus deductions.");
        }
    }
}
