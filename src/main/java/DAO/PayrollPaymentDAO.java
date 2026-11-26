package DAO;

import java.math.BigDecimal;
import java.sql.Connection;
import java.sql.Date;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

import model.DBcConnection;
import model.PayrollPayment;

public class PayrollPaymentDAO {

    public int addPayment(PayrollPayment payment)
            throws SQLException {

        if (payment == null
                || payment.getPayrollId() <= 0
                || payment.getPaymentDate() == null
                || payment.getPaymentMethod() == null
                || payment.getPaymentMethod().trim().isEmpty()
                || payment.getAmountPaid() == null
                || payment.getAmountPaid().signum() <= 0) {

            throw new IllegalArgumentException(
                    "Enter valid payroll payment details.");
        }

        Connection con = DBcConnection.getConnection();

        if (con == null) {
            throw new SQLException("Database connection unavailable.");
        }

        try (con) {
            con.setAutoCommit(false);

            try {
                BigDecimal netSalary;
                String status;

                String payrollSql =
                        "SELECT net_salary, status FROM payroll " +
                        "WHERE id = ? FOR UPDATE";

                try (PreparedStatement ps =
                             con.prepareStatement(payrollSql)) {

                    ps.setInt(1, payment.getPayrollId());

                    try (ResultSet rs = ps.executeQuery()) {
                        if (!rs.next()) {
                            throw new SQLException(
                                    "Payroll record not found.");
                        }

                        netSalary = rs.getBigDecimal("net_salary");
                        status = rs.getString("status");
                    }
                }

                if (!"PROCESSED".equalsIgnoreCase(status)) {
                    throw new SQLException(
                            "Only processed, unpaid payroll can receive payments.");
                }

                BigDecimal alreadyPaid = BigDecimal.ZERO;

                String totalSql =
                        "SELECT COALESCE(SUM(amount_paid), 0) AS total_paid " +
                        "FROM payroll_payments WHERE payroll_id = ?";

                try (PreparedStatement ps =
                             con.prepareStatement(totalSql)) {

                    ps.setInt(1, payment.getPayrollId());

                    try (ResultSet rs = ps.executeQuery()) {
                        if (rs.next()) {
                            alreadyPaid = rs.getBigDecimal("total_paid");
                        }
                    }
                }

                BigDecimal newTotal =
                        alreadyPaid.add(payment.getAmountPaid());

                if (newTotal.compareTo(netSalary) > 0) {
                    throw new SQLException(
                            "Payment exceeds the remaining net salary.");
                }

                String insertSql =
                        "INSERT INTO payroll_payments " +
                        "(payroll_id, payment_date, payment_method, " +
                        "reference_number, amount_paid) " +
                        "VALUES (?, ?, ?, ?, ?)";

                int paymentId;

                try (PreparedStatement ps = con.prepareStatement(
                        insertSql,
                        PreparedStatement.RETURN_GENERATED_KEYS)) {

                    ps.setInt(1, payment.getPayrollId());
                    ps.setDate(
                            2, Date.valueOf(payment.getPaymentDate()));
                    ps.setString(
                            3, payment.getPaymentMethod().trim());

                    if (payment.getReferenceNumber() == null
                            || payment.getReferenceNumber().trim().isEmpty()) {
                        ps.setNull(4, java.sql.Types.VARCHAR);
                    } else {
                        ps.setString(
                                4, payment.getReferenceNumber().trim());
                    }

                    ps.setBigDecimal(5, payment.getAmountPaid());

                    ps.executeUpdate();

                    try (ResultSet keys = ps.getGeneratedKeys()) {
                        if (!keys.next()) {
                            throw new SQLException(
                                    "Unable to retrieve payment ID.");
                        }

                        paymentId = keys.getInt(1);
                    }
                }

                if (newTotal.compareTo(netSalary) == 0) {

                    String updateSql =
                            "UPDATE payroll SET status = 'PAID' " +
                            "WHERE id = ? AND status = 'PROCESSED'";

                    try (PreparedStatement ps =
                                 con.prepareStatement(updateSql)) {

                        ps.setInt(1, payment.getPayrollId());

                        if (ps.executeUpdate() != 1) {
                            throw new SQLException(
                                    "Unable to update payroll payment status.");
                        }
                    }
                }

                con.commit();

                // last instalment paid -> payroll is PAID: email the salary slip
                if (newTotal.compareTo(netSalary) == 0) {
                    service.SalarySlipMailer.sendAsync(payment.getPayrollId());
                }

                return paymentId;

            } catch (Exception e) {

                try {
                    con.rollback();
                } catch (SQLException rollbackError) {
                    e.addSuppressed(rollbackError);
                }

                if (e instanceof SQLException) {
                    throw (SQLException) e;
                }

                throw new SQLException(
                        "Unable to record payroll payment.", e);
            }

        } catch (SQLException e) {
            throw e;
        }
    }

    public List<PayrollPayment> getPaymentsByPayrollId(int payrollId)
            throws SQLException {

        if (payrollId <= 0) {
            throw new IllegalArgumentException("Invalid payroll ID.");
        }

        List<PayrollPayment> list = new ArrayList<>();

        String sql =
                "SELECT id, payroll_id, payment_date, payment_method, " +
                "reference_number, amount_paid " +
                "FROM payroll_payments " +
                "WHERE payroll_id = ? ORDER BY payment_date DESC, id DESC";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {

                while (rs.next()) {

                    PayrollPayment payment = new PayrollPayment();

                    payment.setId(rs.getInt("id"));
                    payment.setPayrollId(rs.getInt("payroll_id"));

                    Date paymentDate = rs.getDate("payment_date");

                    if (paymentDate != null) {
                        payment.setPaymentDate(
                                paymentDate.toLocalDate());
                    }

                    payment.setPaymentMethod(
                            rs.getString("payment_method"));

                    payment.setReferenceNumber(
                            rs.getString("reference_number"));

                    payment.setAmountPaid(
                            rs.getBigDecimal("amount_paid"));

                    list.add(payment);
                }
            }
        }

        return list;
    }

    public BigDecimal getTotalPaid(int payrollId)
            throws SQLException {

        String sql =
                "SELECT COALESCE(SUM(amount_paid), 0) AS total_paid " +
                "FROM payroll_payments WHERE payroll_id = ?";

        try (Connection con = DBcConnection.getConnection();
             PreparedStatement ps = con.prepareStatement(sql)) {

            ps.setInt(1, payrollId);

            try (ResultSet rs = ps.executeQuery()) {
                if (rs.next()) {
                    return rs.getBigDecimal("total_paid");
                }
            }
        }
        return BigDecimal.ZERO;
    }
}