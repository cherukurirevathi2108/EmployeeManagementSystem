package service;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.time.Month;
import java.time.format.TextStyle;
import java.util.List;
import java.util.Locale;

import model.Payroll;
import model.PayrollPayment;
import model.SalaryComponent;
import model.SalaryStructure;

/**
 * Printable salary slip, written as a standalone HTML page by AdminServlet
 * (/admin?action=salarySlip&payrollId=..). No separate JSP is needed.
 * The totals always come from the stored (finalized) payroll record; the
 * breakdown lines are derived from the salary components of that month.
 */
public class SalarySlipHtml {

    public static final String COMPANY_NAME = "SmartOffice Technologies Pvt. Ltd.";

    private static String esc(Object v) {
        if (v == null) return "";
        return String.valueOf(v).replace("&", "&amp;").replace("<", "&lt;")
                .replace(">", "&gt;").replace("\"", "&quot;").replace("'", "&#39;");
    }

    /** Account number shown on the slip as XXXXXX1234 (only the last 4 digits). */
    public static String maskAccount(String account) {
        if (account == null) return "";
        String a = account.replaceAll("\\s", "");
        if (a.isEmpty()) return "";
        if (a.length() <= 4) return a;
        StringBuilder m = new StringBuilder();
        for (int i = 0; i < a.length() - 4; i++) m.append('X');
        return m.append(a.substring(a.length() - 4)).toString();
    }

    /**
     * Bank details of the salary structure that applies to this payroll month
     * (bank name, account number, IFSC, PAN), or null if there is none.
     */
    public static SalaryStructure bankFor(Payroll p) {
        try {
            DAO.SalaryStructureDAO dao = new DAO.SalaryStructureDAO();
            SalaryStructure st = dao.getStructureForPayroll(
                    p.getEmployeeId(),
                    java.sql.Date.valueOf(java.time.YearMonth.of(
                            p.getPayrollYear(), p.getPayrollMonth()).atEndOfMonth()));
            return st == null ? null : dao.getById(st.getId());
        } catch (Exception e) {
            return null; // the slip still works without the bank block
        }
    }

    private static void infoCell(StringBuilder h, String label, String value) {
        if (value == null || value.trim().isEmpty()) return;
        h.append("<div><b>").append(esc(label)).append("</b>").append(esc(value.trim())).append("</div>");
    }

    private static String money(BigDecimal v) {
        return "&#8377;" + String.format("%,.2f", v == null ? BigDecimal.ZERO : v);
    }

    private static BigDecimal componentAmount(SalaryComponent c, BigDecimal basic) {
        BigDecimal amount = c.getAmount() == null ? BigDecimal.ZERO : c.getAmount();
        if ("PERCENTAGE".equalsIgnoreCase(c.getCalculationType())) {
            return basic.multiply(amount)
                    .divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP)
                    .setScale(2, RoundingMode.HALF_UP);
        }
        return amount.setScale(2, RoundingMode.HALF_UP);
    }

    private static void line(StringBuilder h, String label, String detail, BigDecimal amount) {
        h.append("<tr><td>").append(esc(label));
        if (detail != null && !detail.isEmpty()) {
            h.append(" <small>").append(esc(detail)).append("</small>");
        }
        h.append("</td><td class=\"r\">").append(money(amount)).append("</td></tr>");
    }

    /** Same slip; the bank details are looked up from the employee's salary structure. */
    public static String render(Payroll p,
                                List<SalaryComponent> components,
                                PayrollService.AttendanceSummary att,
                                List<PayrollPayment> payments) {
        return render(p, bankFor(p), components, att, payments);
    }

    public static String render(Payroll p,
                                SalaryStructure bank,
                                List<SalaryComponent> components,
                                PayrollService.AttendanceSummary att,
                                List<PayrollPayment> payments) {

        BigDecimal basic = p.getBasicSalary() == null ? BigDecimal.ZERO : p.getBasicSalary();
        String period = Month.of(p.getPayrollMonth())
                .getDisplayName(TextStyle.FULL, Locale.ENGLISH) + " " + p.getPayrollYear();

        StringBuilder earnings = new StringBuilder();
        StringBuilder deductions = new StringBuilder();

        line(earnings, "Basic Salary", "", basic);
        BigDecimal earningSum = BigDecimal.ZERO;
        BigDecimal deductionSum = BigDecimal.ZERO;

        for (SalaryComponent c : components) {
            BigDecimal amt = componentAmount(c, basic);
            String detail = "PERCENTAGE".equalsIgnoreCase(c.getCalculationType())
                    ? "(" + c.getAmount().stripTrailingZeros().toPlainString() + "% of basic)" : "";
            if ("EARNING".equalsIgnoreCase(c.getComponentType())) {
                line(earnings, c.getComponentName(), detail, amt);
                earningSum = earningSum.add(amt);
            } else {
                line(deductions, c.getComponentName(), detail, amt);
                deductionSum = deductionSum.add(amt);
            }
        }

        BigDecimal gross = p.getGrossSalary() == null ? BigDecimal.ZERO : p.getGrossSalary();
        BigDecimal totalDed = p.getTotalDeductions() == null ? BigDecimal.ZERO : p.getTotalDeductions();

        // overtime approved by the manager and paid with this salary
        OvertimeService.OtSummary ot = OvertimeService.forPayroll(p.getId());
        if (!ot.isEmpty()) {
            line(earnings, "Overtime",
                    "(" + ot.hours.stripTrailingZeros().toPlainString() + " hrs x "
                            + "Rs. " + String.format("%,.2f", ot.rate) + "/hr)",
                    ot.amount);
            earningSum = earningSum.add(ot.amount);
        }

        // anything not explained by the components (attendance / later changes)
        BigDecimal otherEarn = gross.subtract(basic).subtract(earningSum);
        if (otherEarn.signum() != 0) {
            line(earnings, "Other adjustments", "", otherEarn);
        }
        BigDecimal lop = totalDed.subtract(deductionSum);
        if (lop.signum() > 0) {
            String detail = att != null && att.lopDays > 0
                    ? "(" + String.format("%.1f", att.lopDays) + " unpaid leave day(s))" : "";
            line(deductions, "Unpaid leave deduction", detail, lop);
        }

        BigDecimal paid = p.getPaidAmount() == null ? BigDecimal.ZERO : p.getPaidAmount();
        String status = p.getStatus() == null ? "" : p.getStatus().toUpperCase();

        StringBuilder h = new StringBuilder();
        h.append("<!DOCTYPE html><html><head><meta charset=\"UTF-8\">")
         .append("<meta name=\"viewport\" content=\"width=device-width,initial-scale=1\">")
         .append("<title>Salary Slip - ").append(esc(p.getEmployeeName())).append(" - ").append(esc(period)).append("</title>")
         .append("<style>")
         .append("*{box-sizing:border-box}body{margin:0;background:#eef2f7;font-family:Segoe UI,Arial,sans-serif;color:#0f172a}")
         .append(".bar{max-width:820px;margin:18px auto 0;display:flex;justify-content:flex-end;gap:8px;padding:0 12px}")
         .append(".bar button{border:0;background:#2563eb;color:#fff;padding:9px 16px;border-radius:8px;font-weight:600;cursor:pointer}")
         .append(".slip{max-width:820px;margin:12px auto 30px;background:#fff;border:1px solid #dbe3ee;border-radius:12px;padding:30px}")
         .append(".top{display:flex;justify-content:space-between;gap:12px;flex-wrap:wrap;border-bottom:2px solid #2563eb;padding-bottom:14px;margin-bottom:18px}")
         .append(".top h1{margin:0;font-size:22px;color:#1d4ed8}.top p{margin:4px 0 0;color:#64748b;font-size:13px}")
         .append(".badge{display:inline-block;padding:4px 12px;border-radius:20px;font-size:12px;font-weight:700;background:#dbeafe;color:#1d4ed8}")
         .append(".badge.paid{background:#dcfce7;color:#166534}")
         .append(".info{display:grid;grid-template-columns:repeat(3,1fr);gap:12px;margin-bottom:20px}")
         .append(".info div{font-size:13px}.info b{display:block;font-size:11px;color:#64748b;text-transform:uppercase;margin-bottom:2px}")
         .append(".cols{display:grid;grid-template-columns:1fr 1fr;gap:18px}")
         .append("table{width:100%;border-collapse:collapse}th{background:#f1f5f9;text-align:left;font-size:12px;padding:9px 10px}")
         .append("td{padding:9px 10px;border-bottom:1px solid #e5e7eb;font-size:13px}.r{text-align:right;white-space:nowrap}small{color:#64748b}")
         .append("tfoot td{font-weight:700;background:#f8fafc}")
         .append(".net{margin-top:18px;padding:16px;border-radius:10px;background:#ecfdf5;border:1px solid #bbf7d0;display:flex;justify-content:space-between;font-size:18px;font-weight:700;color:#166534}")
         .append(".leaves{display:grid;grid-template-columns:1fr 1fr;gap:12px;margin-bottom:18px}")
         .append(".leaves div{background:#f8fafc;border:1px solid #e2e8f0;border-radius:8px;padding:10px 12px;font-size:13px}")
         .append(".leaves b{display:block;font-size:11px;color:#64748b;text-transform:uppercase;margin-bottom:2px}")
         .append("h3{font-size:14px;margin:22px 0 8px}.note{margin-top:20px;font-size:11px;color:#64748b}")
         .append("@media(max-width:640px){.info,.cols,.leaves{grid-template-columns:1fr}}")
         .append("@media print{body{background:#fff}.bar{display:none}.slip{border:0;margin:0;max-width:none}}")
         .append("</style></head><body>")
         .append("<div class=\"bar\"><button onclick=\"window.print()\">Print / Save as PDF</button></div>")
         .append("<div class=\"slip\">")
         .append("<div class=\"top\"><div><h1>").append(esc(COMPANY_NAME)).append("</h1><p>Salary Slip for ")
         .append(esc(period)).append("</p></div><div><span class=\"badge")
         .append("PAID".equals(status) ? " paid" : "").append("\">").append(esc(status)).append("</span></div></div>")
         .append("<div class=\"info\">")
         .append("<div><b>Employee</b>").append(esc(p.getEmployeeName())).append("</div>")
         .append("<div><b>Employee ID</b>").append(esc(p.getEmployeeId())).append("</div>")
         .append("<div><b>Pay Period</b>").append(esc(period)).append("</div>")
         .append("<div><b>Department</b>").append(esc(p.getDepartment())).append("</div>")
         .append("<div><b>Designation</b>").append(esc(p.getDesignation())).append("</div>");

        if (att != null) {
            h.append("<div><b>Attendance</b>")
             .append(String.format("%.1f", att.presentDays)).append(" present / ")
             .append(att.workingDays).append(" working days</div>");
        } else {
            h.append("<div></div>");
        }

        if (bank != null) {
            infoCell(h, "Bank", bank.getBankName());
            infoCell(h, "Account No.", maskAccount(bank.getAccountNumber()));
            infoCell(h, "IFSC", bank.getIfscCode());
            infoCell(h, "PAN", bank.getPanNumber());
        }

        h.append("</div>");
        if (att != null) {
            h.append("<div class=\"leaves\">")
             .append("<div><b>Paid leaves</b>")
             .append(String.format("%.0f", att.paidLeaveAllowance)).append(" per month &middot; used ")
             .append(String.format("%.1f", att.paidLeaveUsed))
             .append(" <small>(no salary deducted)</small></div>")
             .append("<div><b>Unpaid leaves</b>")
             .append(String.format("%.1f", att.unpaidLeaveDays))
             .append(" day(s) <small>(salary deducted only for these)</small></div></div>");
        }
        h.append("<div class=\"leaves\">")
         .append("<div><b>Overtime hours</b>")
         .append(String.format("%.2f", ot.hours)).append(" hrs")
         .append(ot.detail.isEmpty() ? "" : " <small>(" + esc(ot.detail) + ")</small>")
         .append("</div><div><b>Overtime pay</b>")
         .append(money(ot.amount))
         .append(ot.isEmpty() ? "" : " <small>(included in gross salary)</small>")
         .append("</div></div>");
        h.append("<div class=\"cols\">")
         .append("<table><thead><tr><th>Earnings</th><th class=\"r\">Amount</th></tr></thead><tbody>")
         .append(earnings).append("</tbody><tfoot><tr><td>Gross Salary</td><td class=\"r\">")
         .append(money(gross)).append("</td></tr></tfoot></table>")
         .append("<table><thead><tr><th>Deductions</th><th class=\"r\">Amount</th></tr></thead><tbody>");

        if (deductions.length() == 0) {
            h.append("<tr><td colspan=\"2\"><small>No deductions</small></td></tr>");
        } else {
            h.append(deductions);
        }

        h.append("</tbody><tfoot><tr><td>Total Deductions</td><td class=\"r\">")
         .append(money(totalDed)).append("</td></tr></tfoot></table></div>")
         .append("<div class=\"net\"><span>Net Salary Payable</span><span>").append(money(p.getNetSalary())).append("</span></div>");

        h.append("<h3>Payment details</h3>");
        if (payments == null || payments.isEmpty()) {
            h.append("<p style=\"font-size:13px;color:#64748b\">No payment has been recorded yet (payment pending).</p>");
        } else {
            h.append("<table><thead><tr><th>Date</th><th>Method</th><th>Reference</th><th class=\"r\">Amount</th></tr></thead><tbody>");
            for (PayrollPayment pay : payments) {
                h.append("<tr><td>").append(esc(pay.getPaymentDate())).append("</td><td>")
                 .append(esc(pay.getPaymentMethod() == null ? "" : pay.getPaymentMethod().replace('_', ' ')))
                 .append("</td><td>").append(esc(pay.getReferenceNumber())).append("</td><td class=\"r\">")
                 .append(money(pay.getAmountPaid())).append("</td></tr>");
            }
            h.append("</tbody><tfoot><tr><td colspan=\"3\">Total paid</td><td class=\"r\">")
             .append(money(paid)).append("</td></tr></tfoot></table>");
        }

        h.append("<p class=\"note\">This is a system generated salary slip based on the finalized payroll record.</p>")
         .append("</div></body></html>");

        return h.toString();
    }
}