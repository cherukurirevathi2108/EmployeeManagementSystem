package service;

import java.io.ByteArrayOutputStream;
import java.math.BigDecimal;
import java.math.RoundingMode;
import java.nio.charset.StandardCharsets;
import java.time.Month;
import java.time.format.TextStyle;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

import model.Payroll;
import model.PayrollPayment;
import model.SalaryComponent;
import model.SalaryStructure;

/**
 * Builds the salary slip as a real PDF file (A4) with NO external library:
 * it writes the PDF directly using the standard Helvetica fonts that every
 * PDF viewer already has. The content is the same as the HTML slip
 * (SalarySlipHtml): company, employee info, attendance, earnings, deductions,
 * net salary and payment details.
 *
 * The standard PDF fonts have no rupee sign, so amounts are written as "Rs.".
 */
public final class SalarySlipPdf {

    // ---- page geometry (points, A4) ----
    private static final double W = 595, H = 842, M = 40;
    private static final double CONTENT_W = W - 2 * M;
    private static final double BOTTOM = H - 55;      // keep space for the footer

    // ---- colours ----
    private static final int BLUE = 0x1D4ED8;
    private static final int DARK = 0x0F172A;
    private static final int GRAY = 0x64748B;
    private static final int HEAD_BG = 0xF1F5F9;
    private static final int FOOT_BG = 0xF8FAFC;
    private static final int LINE = 0xE5E7EB;
    private static final int GREEN = 0x166534;
    private static final int GREEN_BG = 0xECFDF5;
    private static final int GREEN_BORDER = 0xBBF7D0;
    private static final int BLUE_BG = 0xDBEAFE;
    private static final int BOX_BG = 0xF8FAFC;
    private static final int BOX_BORDER = 0xE2E8F0;

    // ---- Helvetica / Helvetica-Bold glyph widths for ASCII 32..126 ----
    private static final int[] WIDTH_REG = {
        278, 278, 355, 556, 556, 889, 667, 191, 333, 333, 389, 584, 278, 333, 278, 278,
        556, 556, 556, 556, 556, 556, 556, 556, 556, 556,
        278, 278, 584, 584, 584, 556, 1015,
        667, 667, 722, 722, 667, 611, 778, 722, 278, 500, 667, 556, 833, 722, 778, 667,
        778, 722, 667, 611, 722, 667, 944, 667, 667, 611,
        278, 278, 278, 469, 556, 333,
        556, 556, 500, 556, 556, 278, 556, 556, 222, 222, 500, 222, 833, 556, 556, 556,
        556, 333, 500, 278, 556, 500, 722, 500, 500, 500,
        334, 260, 334, 584 };

    private static final int[] WIDTH_BOLD = {
        278, 333, 474, 556, 556, 889, 722, 238, 333, 333, 389, 584, 278, 333, 278, 278,
        556, 556, 556, 556, 556, 556, 556, 556, 556, 556,
        333, 333, 584, 584, 584, 611, 975,
        722, 722, 722, 722, 667, 611, 778, 722, 278, 556, 722, 611, 833, 722, 778, 667,
        778, 722, 667, 611, 722, 667, 944, 667, 667, 611,
        333, 278, 333, 584, 556, 333,
        556, 611, 556, 611, 556, 333, 611, 611, 278, 278, 556, 278, 889, 611, 611, 611,
        611, 389, 556, 333, 611, 556, 778, 556, 556, 500,
        389, 280, 389, 584 };

    private final List<StringBuilder> pages = new ArrayList<StringBuilder>();
    private StringBuilder cur;
    private double y;   // cursor, measured from the TOP of the page

    private SalarySlipPdf() { }

    // ==================================================================
    // Public entry point
    // ==================================================================

    /** Returns the salary slip as PDF bytes. */
    public static byte[] render(Payroll p,
                                List<SalaryComponent> components,
                                PayrollService.AttendanceSummary att,
                                List<PayrollPayment> payments) {
        return render(p, SalarySlipHtml.bankFor(p), components, att, payments);
    }

    /** bank = the employee's salary structure (bank name, account, IFSC, PAN); may be null. */
    public static byte[] render(Payroll p,
                                SalaryStructure bank,
                                List<SalaryComponent> components,
                                PayrollService.AttendanceSummary att,
                                List<PayrollPayment> payments) {
        return new SalarySlipPdf().build(p, bank, components, att, payments);
    }

    // ==================================================================
    // Slip layout
    // ==================================================================

    private byte[] build(Payroll p,
                         SalaryStructure bank,
                         List<SalaryComponent> components,
                         PayrollService.AttendanceSummary att,
                         List<PayrollPayment> payments) {

        BigDecimal basic = nz(p.getBasicSalary());
        BigDecimal gross = nz(p.getGrossSalary());
        BigDecimal totalDed = nz(p.getTotalDeductions());
        BigDecimal paid = nz(p.getPaidAmount());
        String status = p.getStatus() == null ? "" : p.getStatus().trim().toUpperCase(Locale.ENGLISH);

        String period = Month.of(p.getPayrollMonth())
                .getDisplayName(TextStyle.FULL, Locale.ENGLISH) + " " + p.getPayrollYear();

        // ---- earnings / deductions rows (same rules as SalarySlipHtml) ----
        List<String[]> earnings = new ArrayList<String[]>();
        List<String[]> deductions = new ArrayList<String[]>();

        earnings.add(new String[] { "Basic Salary", "", money(basic) });

        BigDecimal earningSum = BigDecimal.ZERO;
        BigDecimal deductionSum = BigDecimal.ZERO;

        if (components != null) {
            for (SalaryComponent c : components) {
                BigDecimal amt = componentAmount(c, basic);
                boolean pct = "PERCENTAGE".equalsIgnoreCase(c.getCalculationType());
                String detail = pct && c.getAmount() != null
                        ? "(" + c.getAmount().stripTrailingZeros().toPlainString() + "% of basic)" : "";

                if ("EARNING".equalsIgnoreCase(c.getComponentType())) {
                    earnings.add(new String[] { c.getComponentName(), detail, money(amt) });
                    earningSum = earningSum.add(amt);
                } else {
                    deductions.add(new String[] { c.getComponentName(), detail, money(amt) });
                    deductionSum = deductionSum.add(amt);
                }
            }
        }

        // overtime approved by the manager and paid with this salary
        OvertimeService.OtSummary ot = OvertimeService.forPayroll(p.getId());
        if (!ot.isEmpty()) {
            earnings.add(new String[] { "Overtime",
                    "(" + ot.hours.stripTrailingZeros().toPlainString() + " hrs x "
                            + money(ot.rate) + "/hr)",
                    money(ot.amount) });
            earningSum = earningSum.add(ot.amount);
        }

        BigDecimal otherEarn = gross.subtract(basic).subtract(earningSum);
        if (otherEarn.signum() != 0) {
            earnings.add(new String[] { "Other adjustments", "", money(otherEarn) });
        }

        BigDecimal lop = totalDed.subtract(deductionSum);
        if (lop.signum() > 0) {
            String detail = att != null && att.lopDays > 0
                    ? "(" + String.format(Locale.ENGLISH, "%.1f", att.lopDays) + " unpaid leave day(s))" : "";
            deductions.add(new String[] { "Unpaid leave deduction", detail, money(lop) });
        }

        // ================= HEADER =================
        newPage();

        text(M, y + 16, 17, true, BLUE, SalarySlipHtml.COMPANY_NAME);
        text(M, y + 33, 10, false, GRAY, "Salary Slip for " + period);

        boolean isPaid = "PAID".equals(status);
        double bw = width(status, 9, true) + 24;
        rect(W - M - bw, y, bw, 20, isPaid ? 0xDCFCE7 : BLUE_BG);
        text(W - M - bw + 12, y + 14, 9, true, isPaid ? GREEN : BLUE, status);

        y += 46;
        hline(M, W - M, y, 1.6, BLUE);
        y += 18;

        // ================= INFO GRID (3 x 2) =================
        String attendanceText = att == null ? "" :
                String.format(Locale.ENGLISH, "%.1f", att.presentDays) + " present / "
                + att.workingDays + " working days";

        List<String[]> info = new ArrayList<String[]>();
        info.add(new String[] { "EMPLOYEE", p.getEmployeeName() });
        info.add(new String[] { "EMPLOYEE ID", p.getEmployeeId() });
        info.add(new String[] { "PAY PERIOD", period });
        info.add(new String[] { "DEPARTMENT", p.getDepartment() });
        info.add(new String[] { "DESIGNATION", p.getDesignation() });
        info.add(new String[] { "ATTENDANCE", attendanceText });

        // bank details come from the salary structure (blank values are not shown)
        if (bank != null) {
            addInfo(info, "BANK", bank.getBankName());
            addInfo(info, "ACCOUNT NO.", SalarySlipHtml.maskAccount(bank.getAccountNumber()));
            addInfo(info, "IFSC", bank.getIfscCode());
            addInfo(info, "PAN", bank.getPanNumber());
        }

        double colW = CONTENT_W / 3;
        for (int i = 0; i < info.size(); i++) {
            double x = M + (i % 3) * colW;
            double top = y + (i / 3) * 36;
            text(x, top + 8, 7.5, true, GRAY, info.get(i)[0]);
            text(x, top + 22, 10, false, DARK, fit(info.get(i)[1], 10, false, colW - 12));
        }
        y += ((info.size() + 2) / 3) * 36 + 4;

        // ================= LEAVES =================
        if (att != null) {
            double bwid = (CONTENT_W - 12) / 2;
            box(M, y, bwid, 40);
            box(M + bwid + 12, y, bwid, 40);

            text(M + 10, y + 13, 7.5, true, GRAY, "PAID LEAVES");
            text(M + 10, y + 28, 9, false, DARK,
                    String.format(Locale.ENGLISH, "%.0f", att.paidLeaveAllowance) + " per month - used "
                    + String.format(Locale.ENGLISH, "%.1f", att.paidLeaveUsed) + " (no salary deducted)");

            text(M + bwid + 22, y + 13, 7.5, true, GRAY, "UNPAID LEAVES");
            text(M + bwid + 22, y + 28, 9, false, DARK,
                    String.format(Locale.ENGLISH, "%.1f", att.unpaidLeaveDays) + " day(s) (deducted only for these)");

            y += 40 + 18;
        }

        // ================= OVERTIME =================
        {
            double bwid = (CONTENT_W - 12) / 2;
            ensure(40 + 18);
            box(M, y, bwid, 40);
            box(M + bwid + 12, y, bwid, 40);

            text(M + 10, y + 13, 7.5, true, GRAY, "OVERTIME HOURS");
            text(M + 10, y + 28, 9, false, DARK, fit(
                    String.format(Locale.ENGLISH, "%.2f", ot.hours) + " hrs"
                    + (ot.detail.isEmpty() ? "" : " (" + ot.detail + ")"), 9, false, bwid - 20));

            text(M + bwid + 22, y + 13, 7.5, true, GRAY, "OVERTIME PAY");
            text(M + bwid + 22, y + 28, 9, false, DARK, money(ot.amount)
                    + (ot.isEmpty() ? "" : " (included in gross salary)"));

            y += 40 + 18;
        }

        // ================= EARNINGS | DEDUCTIONS =================
        int maxRows = Math.max(Math.max(earnings.size(), deductions.size()), 1);
        ensure(22 + maxRows * 20 + 22);

        double tw = (CONTENT_W - 16) / 2;
        double h1 = amountTable(M, tw, "Earnings", earnings, "Gross Salary", money(gross), null);
        double h2 = amountTable(M + tw + 16, tw, "Deductions", deductions, "Total Deductions",
                money(totalDed), "No deductions");
        y += Math.max(h1, h2) + 18;

        // ================= NET SALARY =================
        ensure(50);
        rect(M, y, CONTENT_W, 40, GREEN_BG);
        box(M, y, CONTENT_W, 40, GREEN_BORDER);
        text(M + 14, y + 25, 13, true, GREEN, "Net Salary Payable");
        textRight(W - M - 14, y + 25, 13, true, GREEN, money(nz(p.getNetSalary())));
        y += 40 + 22;

        // ================= PAYMENT DETAILS =================
        ensure(60);
        text(M, y + 10, 11, true, DARK, "Payment details");
        y += 20;

        if (payments == null || payments.isEmpty()) {
            text(M, y + 10, 9, false, GRAY, "No payment has been recorded yet (payment pending).");
            y += 22;
        } else {
            paymentHeader();
            for (PayrollPayment pay : payments) {
                if (y + 20 > BOTTOM) {
                    newPage();
                    paymentHeader();
                }
                String method = pay.getPaymentMethod() == null ? "" : pay.getPaymentMethod().replace('_', ' ');
                text(M + 8, y + 14, 9, false, DARK, String.valueOf(pay.getPaymentDate() == null ? "" : pay.getPaymentDate()));
                text(M + 110, y + 14, 9, false, DARK, fit(method, 9, false, 130));
                text(M + 250, y + 14, 9, false, DARK, fit(pay.getReferenceNumber(), 9, false, 140));
                textRight(W - M - 8, y + 14, 9, false, DARK, money(pay.getAmountPaid()));
                hline(M, W - M, y + 20, 0.5, LINE);
                y += 20;
            }
            if (y + 22 > BOTTOM) {
                newPage();
            }
            rect(M, y, CONTENT_W, 22, FOOT_BG);
            text(M + 8, y + 15, 9, true, DARK, "Total paid");
            textRight(W - M - 8, y + 15, 9, true, DARK, money(paid));
            y += 22;
        }

        // ================= NOTE =================
        y += 16;
        if (y + 14 > BOTTOM) {
            newPage();
        }
        text(M, y + 8, 8, false, GRAY,
                "This is a system generated salary slip based on the finalized payroll record.");

        // ================= FOOTER (page numbers) =================
        for (int i = 0; i < pages.size(); i++) {
            StringBuilder sb = pages.get(i);
            String label = "Page " + (i + 1) + " of " + pages.size();
            double x = (W - width(label, 8, false)) / 2;
            sb.append(textOp(x, H - 28, 8, false, GRAY, label));
        }

        return toPdf();
    }

    // ------------------------------------------------------------------
    // Layout helpers
    // ------------------------------------------------------------------

    /** Draws Earnings / Deductions table at the current y; returns its height. */
    private double amountTable(double x, double w, String title, List<String[]> rows,
                               String totalLabel, String totalValue, String emptyText) {

        double top = y;

        rect(x, top, w, 22, HEAD_BG);
        text(x + 8, top + 15, 8.5, true, DARK, title);
        textRight(x + w - 8, top + 15, 8.5, true, DARK, "Amount");

        double cy = top + 22;

        if (rows.isEmpty() && emptyText != null) {
            text(x + 8, cy + 14, 8.5, false, GRAY, emptyText);
            hline(x, x + w, cy + 20, 0.5, LINE);
            cy += 20;
        }

        for (String[] r : rows) {
            String label = fit(r[0], 9, false, w - 100);
            text(x + 8, cy + 14, 9, false, DARK, label);

            if (r[1] != null && !r[1].isEmpty()) {
                double lx = x + 8 + width(label, 9, false) + 4;
                double room = x + w - 8 - width(r[2], 9, false) - 6 - lx;
                if (room > 30) {
                    text(lx, cy + 14, 7, false, GRAY, fit(r[1], 7, false, room));
                }
            }

            textRight(x + w - 8, cy + 14, 9, false, DARK, r[2]);
            hline(x, x + w, cy + 20, 0.5, LINE);
            cy += 20;
        }

        rect(x, cy, w, 22, FOOT_BG);
        text(x + 8, cy + 15, 9, true, DARK, totalLabel);
        textRight(x + w - 8, cy + 15, 9, true, DARK, totalValue);
        cy += 22;

        return cy - top;
    }

    private static void addInfo(List<String[]> info, String label, String value) {
        if (value != null && !value.trim().isEmpty()) {
            info.add(new String[] { label, value.trim() });
        }
    }

    private void paymentHeader() {
        rect(M, y, CONTENT_W, 22, HEAD_BG);
        text(M + 8, y + 15, 8.5, true, DARK, "Date");
        text(M + 110, y + 15, 8.5, true, DARK, "Method");
        text(M + 250, y + 15, 8.5, true, DARK, "Reference");
        textRight(W - M - 8, y + 15, 8.5, true, DARK, "Amount");
        y += 22;
    }

    private void ensure(double needed) {
        if (y + needed > BOTTOM) {
            newPage();
        }
    }

    private void newPage() {
        cur = new StringBuilder();
        pages.add(cur);
        y = M;
    }

    // ------------------------------------------------------------------
    // Drawing primitives (top-based coordinates)
    // ------------------------------------------------------------------

    private void rect(double x, double top, double w, double h, int rgb) {
        cur.append("q ").append(color(rgb)).append(" rg ")
           .append(n(x)).append(' ').append(n(H - top - h)).append(' ')
           .append(n(w)).append(' ').append(n(h)).append(" re f Q\n");
    }

    private void box(double x, double top, double w, double h) {
        rect(x, top, w, h, BOX_BG);
        box(x, top, w, h, BOX_BORDER);
    }

    private void box(double x, double top, double w, double h, int borderRgb) {
        cur.append("q ").append(color(borderRgb)).append(" RG 0.8 w ")
           .append(n(x)).append(' ').append(n(H - top - h)).append(' ')
           .append(n(w)).append(' ').append(n(h)).append(" re S Q\n");
    }

    private void hline(double x1, double x2, double top, double lineWidth, int rgb) {
        cur.append("q ").append(color(rgb)).append(" RG ").append(n(lineWidth)).append(" w ")
           .append(n(x1)).append(' ').append(n(H - top)).append(" m ")
           .append(n(x2)).append(' ').append(n(H - top)).append(" l S Q\n");
    }

    /** baseline = distance of the text baseline from the top of the page. */
    private void text(double x, double baseline, double size, boolean bold, int rgb, String s) {
        cur.append(textOp(x, baseline, size, bold, rgb, s));
    }

    private void textRight(double xRight, double baseline, double size, boolean bold, int rgb, String s) {
        text(xRight - width(s, size, bold), baseline, size, bold, rgb, s);
    }

    private static String textOp(double x, double baseline, double size, boolean bold, int rgb, String s) {
        return "BT /" + (bold ? "F2" : "F1") + " " + n(size) + " Tf " + color(rgb) + " rg "
                + n(x) + " " + n(H - baseline) + " Td (" + pdfEscape(clean(s)) + ") Tj ET\n";
    }

    // ------------------------------------------------------------------
    // Text helpers
    // ------------------------------------------------------------------

    private static double width(String raw, double size, boolean bold) {
        String s = clean(raw);
        int[] table = bold ? WIDTH_BOLD : WIDTH_REG;
        double total = 0;
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            total += (c >= 32 && c <= 126) ? table[c - 32] : 556;
        }
        return total * size / 1000.0;
    }

    /** Cuts text with "..." so it never runs outside its column. */
    private static String fit(String raw, double size, boolean bold, double maxWidth) {
        String s = clean(raw);
        if (width(s, size, bold) <= maxWidth) {
            return s;
        }
        while (s.length() > 1 && width(s + "...", size, bold) > maxWidth) {
            s = s.substring(0, s.length() - 1);
        }
        return s + "...";
    }

    /** Keeps only characters the standard WinAnsi fonts can show. */
    private static String clean(String s) {
        if (s == null) return "";
        StringBuilder b = new StringBuilder(s.length());
        for (int i = 0; i < s.length(); i++) {
            char c = s.charAt(i);
            if (c == '\u20B9') b.append("Rs.");
            else if (c == '\u2013' || c == '\u2014') b.append('-');
            else if (c == '\u2018' || c == '\u2019') b.append('\'');
            else if (c == '\u201C' || c == '\u201D') b.append('"');
            else if (c < 32) b.append(' ');
            else if (c <= 126 || (c >= 160 && c <= 255)) b.append(c);
            else b.append('?');
        }
        return b.toString();
    }

    private static String pdfEscape(String s) {
        return s.replace("\\", "\\\\").replace("(", "\\(").replace(")", "\\)");
    }

    private static String n(double v) {
        return String.format(Locale.ROOT, "%.2f", v);
    }

    private static String color(int rgb) {
        return String.format(Locale.ROOT, "%.3f %.3f %.3f",
                ((rgb >> 16) & 0xFF) / 255.0, ((rgb >> 8) & 0xFF) / 255.0, (rgb & 0xFF) / 255.0);
    }

    // ------------------------------------------------------------------
    // Money helpers
    // ------------------------------------------------------------------

    private static BigDecimal nz(BigDecimal v) {
        return v == null ? BigDecimal.ZERO : v;
    }

    private static String money(BigDecimal v) {
        return "Rs. " + String.format(Locale.ENGLISH, "%,.2f", nz(v));
    }

    private static BigDecimal componentAmount(SalaryComponent c, BigDecimal basic) {
        BigDecimal amount = nz(c.getAmount());
        if ("PERCENTAGE".equalsIgnoreCase(c.getCalculationType())) {
            return basic.multiply(amount)
                    .divide(new BigDecimal("100"), 4, RoundingMode.HALF_UP)
                    .setScale(2, RoundingMode.HALF_UP);
        }
        return amount.setScale(2, RoundingMode.HALF_UP);
    }

    // ------------------------------------------------------------------
    // PDF file writer
    // ------------------------------------------------------------------

    private byte[] toPdf() {

        int pageCount = pages.size();
        // 1 catalog, 2 page tree, 3 Helvetica, 4 Helvetica-Bold, then (page, content) pairs
        int totalObjects = 4 + pageCount * 2;

        ByteArrayOutputStream out = new ByteArrayOutputStream();
        int[] offsets = new int[totalObjects + 1];

        write(out, "%PDF-1.4\n%\u00e2\u00e3\u00cf\u00d3\n");  // 2nd line marks the file as binary

        offsets[1] = out.size();
        write(out, "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n");

        StringBuilder kids = new StringBuilder();
        for (int i = 0; i < pageCount; i++) {
            kids.append(5 + i * 2).append(" 0 R ");
        }
        offsets[2] = out.size();
        write(out, "2 0 obj\n<< /Type /Pages /Kids [ " + kids + "] /Count " + pageCount + " >>\nendobj\n");

        offsets[3] = out.size();
        write(out, "3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica "
                + "/Encoding /WinAnsiEncoding >>\nendobj\n");

        offsets[4] = out.size();
        write(out, "4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold "
                + "/Encoding /WinAnsiEncoding >>\nendobj\n");

        for (int i = 0; i < pageCount; i++) {
            int pageObj = 5 + i * 2;
            int contentObj = pageObj + 1;

            offsets[pageObj] = out.size();
            write(out, pageObj + " 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] "
                    + "/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> /Contents "
                    + contentObj + " 0 R >>\nendobj\n");

            byte[] content = pages.get(i).toString().getBytes(StandardCharsets.ISO_8859_1);

            offsets[contentObj] = out.size();
            write(out, contentObj + " 0 obj\n<< /Length " + content.length + " >>\nstream\n");
            out.write(content, 0, content.length);
            write(out, "\nendstream\nendobj\n");
        }

        int xref = out.size();
        StringBuilder x = new StringBuilder();
        x.append("xref\n0 ").append(totalObjects + 1).append("\n");
        x.append("0000000000 65535 f \n");
        for (int i = 1; i <= totalObjects; i++) {
            x.append(String.format(Locale.ROOT, "%010d 00000 n \n", offsets[i]));
        }
        x.append("trailer\n<< /Size ").append(totalObjects + 1).append(" /Root 1 0 R >>\n")
         .append("startxref\n").append(xref).append("\n%%EOF\n");
        write(out, x.toString());

        return out.toByteArray();
    }

    private static void write(ByteArrayOutputStream out, String s) {
        byte[] b = s.getBytes(StandardCharsets.ISO_8859_1);
        out.write(b, 0, b.length);
    }
}