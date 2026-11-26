
package DAO;

import java.sql.Connection;
import java.sql.DatabaseMetaData;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;

import model.DBcConnection;
import model.SalaryStructure;

public class SalaryStructureDAO {

    private static volatile boolean bankColumnsChecked = false;

    /**
     * Bank details live in the salary_structures table. The four columns are
     * added automatically the first time they are needed, so no manual SQL is
     * required.
     */
    private static synchronized void ensureBankColumns() {

        if (bankColumnsChecked) {
            return;
        }

        String[][] columns = {
                {"bank_name", "VARCHAR(100)"},
                {"account_number", "VARCHAR(30)"},
                {"ifsc_code", "VARCHAR(15)"},
                {"pan_number", "VARCHAR(15)"}
        };

        try (Connection con = DBcConnection.getConnection()) {

            DatabaseMetaData meta = con.getMetaData();

            for (String[] column : columns) {

                boolean exists;

                try (ResultSet rs = meta.getColumns(
                        con.getCatalog(), null, "salary_structures", column[0])) {
                    exists = rs.next();
                }

                if (!exists) {
                    try (Statement st = con.createStatement()) {
                        st.executeUpdate("ALTER TABLE salary_structures ADD COLUMN "
                                + column[0] + " " + column[1] + " NULL");
                    }
                }
            }

            bankColumnsChecked = true;

        } catch (SQLException e) {
            e.printStackTrace();
        }
    }

    public int addSalaryStructure(SalaryStructure salary)
            throws SQLException {

        if (salary == null
                || salary.getEmployeeId() == null
                || salary.getEmployeeId().trim().isEmpty()
                || salary.getBasicSalary() == null
                || salary.getBasicSalary().signum() < 0
                || salary.getEffectiveFrom() == null) {
            throw new IllegalArgumentException(
                    "Valid employee, salary and effective date are required.");
        }

        if (salary.getEffectiveTo() != null
                && salary.getEffectiveTo()
                         .isBefore(salary.getEffectiveFrom())) {
            throw new IllegalArgumentException(
                    "Effective end date cannot be before start date.");
        }

        String overlapSql =
                "SELECT id FROM salary_structures " +
                "WHERE employee_id = ? " +
                "AND effective_from <= COALESCE(?, '9999-12-31') " +
                "AND COALESCE(effective_to, '9999-12-31') >= ?";

        String insertSql =
                "INSERT INTO salary_structures " +
                "(employee_id, basic_salary, effective_from, effective_to) " +
                "VALUES (?, ?, ?, ?)";

        try (Connection con = DBcConnection.getConnection()) {

            try (PreparedStatement check =
                         con.prepareStatement(overlapSql)) {

                check.setString(1, salary.getEmployeeId());

                if (salary.getEffectiveTo() == null) {
                    check.setNull(2, java.sql.Types.DATE);
                } else {
                    check.setDate(
                            2, Date.valueOf(salary.getEffectiveTo()));
                }

                check.setDate(
                        3, Date.valueOf(salary.getEffectiveFrom()));

                try (ResultSet rs = check.executeQuery()) {
                    if (rs.next()) {
                        throw new SQLException(
                                "Salary dates overlap an existing structure.");
                    }
                }
            }

            try (PreparedStatement ps = con.prepareStatement(
                    insertSql,
                    PreparedStatement.RETURN_GENERATED_KEYS)) {

                ps.setString(1, salary.getEmployeeId());
                ps.setBigDecimal(2, salary.getBasicSalary());
                ps.setDate(
                        3, Date.valueOf(salary.getEffectiveFrom()));

                if (salary.getEffectiveTo() == null) {
                    ps.setNull(4, java.sql.Types.DATE);
                } else {
                    ps.setDate(
                            4, Date.valueOf(salary.getEffectiveTo()));
                }

                if (ps.executeUpdate() == 0) {
                    throw new SQLException(
                            "Unable to save salary structure.");
                }

                try (ResultSet keys = ps.getGeneratedKeys()) {
                    if (keys.next()) {
                        return keys.getInt(1);
                    }
                }
            }
        }

        throw new SQLException("Unable to retrieve salary structure ID.");
    }

    public SalaryStructure getCurrentSalaryStructure(String employeeId)
            throws SQLException {

        String sql =
                "SELECT id, employee_id, basic_salary, " +
                "effective_from, effective_to " +
                "FROM salary_structures " +
                "WHERE employee_id = ? " +
                "AND effective_from <= CURDATE() " +
                "AND (effective_to IS NULL OR effective_to >= CURDATE()) " +
                "ORDER BY effective_from DESC LIMIT 1";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapSalaryStructure(rs);
                }
            }
        }

        return null;
    }

    public SalaryStructure getSalaryStructureForDate(
            String employeeId, Date applicableDate) throws SQLException {

        String sql =
                "SELECT id, employee_id, basic_salary, " +
                "effective_from, effective_to " +
                "FROM salary_structures " +
                "WHERE employee_id = ? " +
                "AND effective_from <= ? " +
                "AND (effective_to IS NULL OR effective_to >= ?) " +
                "ORDER BY effective_from DESC LIMIT 1";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);
            ps.setDate(2, applicableDate);
            ps.setDate(3, applicableDate);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapSalaryStructure(rs);
                }
            }
        }

        return null;
    }

    /**
     * Structure to use for a payroll month (pass the LAST day of the month).
     *
     * A salary structure is entered ONCE. It then carries forward to every later
     * month automatically, until a newer structure is added:
     *   1. the structure that covers the date, or
     *   2. otherwise the latest structure that started on or before the date.
     * Months before the first structure return null.
     */
    public SalaryStructure getStructureForPayroll(String employeeId, Date periodEnd)
            throws SQLException {

        SalaryStructure covering = getSalaryStructureForDate(employeeId, periodEnd);

        if (covering != null) {
            return covering;
        }

        String sql =
                "SELECT id, employee_id, basic_salary, " +
                "effective_from, effective_to " +
                "FROM salary_structures " +
                "WHERE employee_id = ? AND effective_from <= ? " +
                "ORDER BY effective_from DESC LIMIT 1";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);
            ps.setDate(2, periodEnd);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return mapSalaryStructure(rs);
                }
            }
        }

        return null;
    }

    public List<SalaryStructure> getSalaryHistory(String employeeId)
            throws SQLException {

        List<SalaryStructure> list = new ArrayList<>();

        String sql =
                "SELECT id, employee_id, basic_salary, " +
                "effective_from, effective_to " +
                "FROM salary_structures " +
                "WHERE employee_id = ? " +
                "ORDER BY effective_from DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setString(1, employeeId);

            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    list.add(mapSalaryStructure(rs));
                }
            }
        }

        return list;
    }

    /**
     * Creates a salary revision and its allowance/deduction components in ONE
     * transaction. An earlier open-ended structure of the same employee is closed
     * the day before the new one starts, so history is kept (never overwritten).
     */
    public int addWithComponents(SalaryStructure salary,
                                 List<model.SalaryComponent> components)
            throws SQLException {

        if (salary == null
                || salary.getEmployeeId() == null
                || salary.getEmployeeId().trim().isEmpty()
                || salary.getBasicSalary() == null
                || salary.getBasicSalary().signum() <= 0
                || salary.getEffectiveFrom() == null) {
            throw new IllegalArgumentException(
                    "Valid employee, salary and effective date are required.");
        }

        if (salary.getEffectiveTo() != null
                && salary.getEffectiveTo().isBefore(salary.getEffectiveFrom())) {
            throw new IllegalArgumentException(
                    "Effective end date cannot be before start date.");
        }

        ensureBankColumns();

        Connection con = DBcConnection.getConnection();

        if (con == null) {
            throw new SQLException("Database connection unavailable.");
        }

        try (con) {
            con.setAutoCommit(false);

            try {
                // ONE salary structure per employee: no duplicates (use Edit to change it)
                try (PreparedStatement dup = con.prepareStatement(
                        "SELECT id FROM salary_structures WHERE employee_id = ? LIMIT 1")) {
                    dup.setString(1, salary.getEmployeeId());
                    try (ResultSet rs = dup.executeQuery()) {
                        if (rs.next()) {
                            throw new IllegalArgumentException(
                                    "This employee already has a salary structure. "
                                    + "Use Edit to change it - a second one is not allowed.");
                        }
                    }
                }

                // close the previous open-ended structure
                try (PreparedStatement close = con.prepareStatement(
                        "UPDATE salary_structures SET effective_to = ? " +
                        "WHERE employee_id = ? AND effective_to IS NULL " +
                        "AND effective_from < ?")) {
                    close.setDate(1, Date.valueOf(
                            salary.getEffectiveFrom().minusDays(1)));
                    close.setString(2, salary.getEmployeeId());
                    close.setDate(3, Date.valueOf(salary.getEffectiveFrom()));
                    close.executeUpdate();
                }

                try (PreparedStatement check = con.prepareStatement(
                        "SELECT id FROM salary_structures WHERE employee_id = ? " +
                        "AND effective_from <= COALESCE(?, '9999-12-31') " +
                        "AND COALESCE(effective_to, '9999-12-31') >= ?")) {
                    check.setString(1, salary.getEmployeeId());
                    if (salary.getEffectiveTo() == null) {
                        check.setNull(2, java.sql.Types.DATE);
                    } else {
                        check.setDate(2, Date.valueOf(salary.getEffectiveTo()));
                    }
                    check.setDate(3, Date.valueOf(salary.getEffectiveFrom()));

                    try (ResultSet rs = check.executeQuery()) {
                        if (rs.next()) {
                            throw new IllegalArgumentException(
                                    "Salary dates overlap an existing structure.");
                        }
                    }
                }

                int structureId;

                try (PreparedStatement ps = con.prepareStatement(
                        "INSERT INTO salary_structures " +
                        "(employee_id, basic_salary, effective_from, effective_to, " +
                        "bank_name, account_number, ifsc_code, pan_number) " +
                        "VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
                        PreparedStatement.RETURN_GENERATED_KEYS)) {
                    ps.setString(1, salary.getEmployeeId());
                    ps.setBigDecimal(2, salary.getBasicSalary());
                    ps.setDate(3, Date.valueOf(salary.getEffectiveFrom()));
                    if (salary.getEffectiveTo() == null) {
                        ps.setNull(4, java.sql.Types.DATE);
                    } else {
                        ps.setDate(4, Date.valueOf(salary.getEffectiveTo()));
                    }
                    ps.setString(5, salary.getBankName());
                    ps.setString(6, salary.getAccountNumber());
                    ps.setString(7, salary.getIfscCode());
                    ps.setString(8, salary.getPanNumber());
                    ps.executeUpdate();

                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        if (!keys.next()) {
                            throw new SQLException(
                                    "Unable to retrieve salary structure ID.");
                        }
                        structureId = keys.getInt(1);
                    }
                }

                SalaryComponentDAO componentDAO = new SalaryComponentDAO();

                if (components != null) {
                    for (model.SalaryComponent component : components) {
                        component.setSalaryStructureId(structureId);
                        componentDAO.addComponent(con, component);
                    }
                }

                con.commit();
                return structureId;

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
                throw new SQLException("Unable to save salary structure.", e);
            }
        }
    }

    /**
     * Edit a salary structure in place: employee, effective month, basic salary,
     * bank details and the whole list of earnings / deductions are replaced in
     * ONE transaction.
     */
    public void updateWithComponents(int structureId, SalaryStructure salary,
                                     List<model.SalaryComponent> components)
            throws SQLException {

        if (structureId <= 0 || salary == null
                || salary.getBasicSalary() == null
                || salary.getBasicSalary().signum() <= 0) {
            throw new IllegalArgumentException(
                    "Valid salary structure and basic salary are required.");
        }

        ensureBankColumns();

        Connection con = DBcConnection.getConnection();

        if (con == null) {
            throw new SQLException("Database connection unavailable.");
        }

        try (con) {
            con.setAutoCommit(false);

            try {
                // Editing the same employee's structure is always allowed (even if old
                // duplicate rows exist). The "already has a structure" check applies only
                // when the structure is being moved to a DIFFERENT employee.
                String currentEmployee = null;
                try (PreparedStatement cur = con.prepareStatement(
                        "SELECT employee_id FROM salary_structures WHERE id = ?")) {
                    cur.setInt(1, structureId);
                    try (ResultSet rs = cur.executeQuery()) {
                        if (rs.next()) {
                            currentEmployee = rs.getString(1);
                        }
                    }
                }

                if (currentEmployee == null) {
                    throw new IllegalArgumentException("Salary structure not found.");
                }

                if (!currentEmployee.equals(salary.getEmployeeId())) {
                    try (PreparedStatement dup = con.prepareStatement(
                            "SELECT id FROM salary_structures WHERE employee_id = ? AND id <> ? LIMIT 1")) {
                        dup.setString(1, salary.getEmployeeId());
                        dup.setInt(2, structureId);
                        try (ResultSet rs = dup.executeQuery()) {
                            if (rs.next()) {
                                throw new IllegalArgumentException(
                                        "That employee already has a salary structure.");
                            }
                        }
                    }
                }

                try (PreparedStatement ps = con.prepareStatement(
                        "UPDATE salary_structures SET employee_id = ?, effective_from = ?, " +
                        "effective_to = NULL, basic_salary = ?, bank_name = ?, " +
                        "account_number = ?, ifsc_code = ?, pan_number = ? WHERE id = ?")) {
                    ps.setString(1, salary.getEmployeeId());
                    ps.setDate(2, Date.valueOf(salary.getEffectiveFrom()));
                    ps.setBigDecimal(3, salary.getBasicSalary());
                    ps.setString(4, salary.getBankName());
                    ps.setString(5, salary.getAccountNumber());
                    ps.setString(6, salary.getIfscCode());
                    ps.setString(7, salary.getPanNumber());
                    ps.setInt(8, structureId);

                    if (ps.executeUpdate() == 0) {
                        throw new IllegalArgumentException("Salary structure not found.");
                    }
                }

                try (PreparedStatement del = con.prepareStatement(
                        "DELETE FROM salary_components WHERE salary_structure_id = ?")) {
                    del.setInt(1, structureId);
                    del.executeUpdate();
                }

                SalaryComponentDAO componentDAO = new SalaryComponentDAO();

                if (components != null) {
                    for (model.SalaryComponent component : components) {
                        component.setSalaryStructureId(structureId);
                        componentDAO.addComponent(con, component);
                    }
                }

                con.commit();

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
                throw new SQLException("Unable to update salary structure.", e);
            }
        }
    }

    /** One structure (with bank details) by id, or null. */
    public SalaryStructure getById(int structureId) throws SQLException {

        ensureBankColumns();

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(
                     "SELECT id, employee_id, basic_salary, effective_from, effective_to, " +
                     "bank_name, account_number, ifsc_code, pan_number " +
                     "FROM salary_structures WHERE id = ?")) {

            ps.setInt(1, structureId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    SalaryStructure s = mapSalaryStructure(rs);
                    s.setBankName(rs.getString("bank_name"));
                    s.setAccountNumber(rs.getString("account_number"));
                    s.setIfscCode(rs.getString("ifsc_code"));
                    s.setPanNumber(rs.getString("pan_number"));
                    return s;
                }
            }
        }

        return null;
    }

    /** All salary structures (current first) with employee name and department. */
    public List<SalaryStructure> getStructureOverview() throws SQLException {

        List<SalaryStructure> list = new ArrayList<>();

        ensureBankColumns();

        String sql =
                "SELECT s.id, s.employee_id, s.basic_salary, s.effective_from, " +
                "s.effective_to, s.bank_name, s.account_number, s.ifsc_code, " +
                "s.pan_number, COALESCE(m.name, e.name, '') AS employee_name, " +
                "COALESCE(m.department, e.department, '') AS department " +
                "FROM salary_structures s " +
                "LEFT JOIN employees e ON e.employee_id = s.employee_id " +
                "LEFT JOIN managers m ON m.employee_id = s.employee_id " +
                "ORDER BY (s.effective_to IS NULL OR s.effective_to >= CURDATE()) DESC, " +
                "s.employee_id, s.effective_from DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            while (rs.next()) {
                SalaryStructure s = mapSalaryStructure(rs);
                s.setEmployeeName(rs.getString("employee_name"));
                s.setDepartment(rs.getString("department"));
                s.setBankName(rs.getString("bank_name"));
                s.setAccountNumber(rs.getString("account_number"));
                s.setIfscCode(rs.getString("ifsc_code"));
                s.setPanNumber(rs.getString("pan_number"));
                list.add(s);
            }
        }

        return list;
    }

    /** Employees and managers (active) that have a salary structure in effect today. */
    public int countActiveStructures() throws SQLException {

        String sql =
                "SELECT COUNT(DISTINCT s.employee_id) FROM salary_structures s " +
                "LEFT JOIN employees e ON e.employee_id = s.employee_id " +
                "LEFT JOIN managers m ON m.employee_id = s.employee_id " +
                "WHERE (UPPER(COALESCE(e.status, '')) = 'ACTIVE' " +
                "OR UPPER(COALESCE(m.status, '')) = 'ACTIVE') " +
                "AND s.effective_from <= CURDATE() " +
                "AND (s.effective_to IS NULL OR s.effective_to >= CURDATE())";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql);
             ResultSet rs = ps.executeQuery()) {

            return rs.next() ? rs.getInt(1) : 0;
        }
    }

    private SalaryStructure mapSalaryStructure(ResultSet rs)
            throws SQLException {

        SalaryStructure salary = new SalaryStructure();

        salary.setId(rs.getInt("id"));
        salary.setEmployeeId(rs.getString("employee_id"));
        salary.setBasicSalary(rs.getBigDecimal("basic_salary"));

        Date from = rs.getDate("effective_from");
        Date to = rs.getDate("effective_to");

        if (from != null) {
            salary.setEffectiveFrom(from.toLocalDate());
        }

        if (to != null) {
            salary.setEffectiveTo(to.toLocalDate());
        }

        return salary;
    }
}