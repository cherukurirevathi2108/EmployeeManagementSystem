
package servlet;

import java.io.IOException;
import java.math.BigDecimal;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;

import DAO.PayrollPaymentDAO;
import model.Payroll;
import model.PayrollPayment;
import model.SalaryComponent;
import service.PayrollService;

import jakarta.servlet.ServletException;
import jakarta.servlet.annotation.WebServlet;
import jakarta.servlet.http.HttpServlet;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import jakarta.servlet.http.HttpSession;

/**
 * Payroll actions only. There is NO separate payroll page: the Payroll Operations
 * Hub is rendered inside admin_dashbaord.jsp by AdminServlet (/admin?action=payroll).
 * Every action here validates the CSRF token, does the work and redirects back to
 * the dashboard's #payroll section.
 */
@WebServlet("/payroll")
public class PayrollServlet extends HttpServlet {

    private static final long serialVersionUID = 1L;
    private static final String CSRF_KEY = "payrollCsrfToken";

    private PayrollService payrollService;
    private PayrollPaymentDAO paymentDAO;

    @Override
    public void init() throws ServletException {
        payrollService = new PayrollService();
        paymentDAO = new PayrollPaymentDAO();
    }

    /** Token stored in the session; AdminServlet puts it into the payroll forms. */
    public static String csrfToken(HttpSession session) {
        Object existing = session.getAttribute(CSRF_KEY);
        if (existing != null) {
            return String.valueOf(existing);
        }
        byte[] bytes = new byte[24];
        new SecureRandom().nextBytes(bytes);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        session.setAttribute(CSRF_KEY, token);
        return token;
    }

    private boolean validCsrf(HttpServletRequest request, HttpSession session) {
        Object expected = session.getAttribute(CSRF_KEY);
        String provided = request.getParameter("csrf");
        if (expected == null || provided == null) {
            return false;
        }
        return MessageDigest.isEqual(
                String.valueOf(expected).getBytes(StandardCharsets.UTF_8),
                provided.getBytes(StandardCharsets.UTF_8));
    }

    /** Payroll screens are used by the Admin and by HR (the HR dashboard posts here too). */
    private boolean isAdmin(HttpSession session) {
        if (session == null) {
            return false;
        }
        String role = String.valueOf(session.getAttribute("role"));
        return "ADMIN".equalsIgnoreCase(role) || "HR".equalsIgnoreCase(role);
    }

    private boolean isHr(HttpServletRequest request) {
        HttpSession session = request.getSession(false);
        return session != null
                && "HR".equalsIgnoreCase(String.valueOf(session.getAttribute("role")));
    }

    private int intParam(HttpServletRequest request, String name,
                         int fallback, int min, int max) {
        try {
            String value = request.getParameter(name);
            if (value != null && !value.trim().isEmpty()) {
                int parsed = Integer.parseInt(value.trim());
                if (parsed >= min && parsed <= max) {
                    return parsed;
                }
            }
        } catch (NumberFormatException ignored) {
        }
        return fallback;
    }

    private BigDecimal decimal(String value, String label) {
        try {
            BigDecimal parsed = new BigDecimal(value == null ? "" : value.trim());
            if (parsed.signum() < 0 || parsed.scale() > 2) {
                throw new NumberFormatException();
            }
            return parsed;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException(
                    "Enter a valid " + label + " (zero or more, max 2 decimals).");
        }
    }

    /** Month picker value (yyyy-MM) -> first day of that month. */
    private LocalDate month(String value, String label) {
        if (value == null || value.trim().isEmpty()) {
            throw new IllegalArgumentException(label + " is required.");
        }
        try {
            return java.time.YearMonth.parse(value.trim()).atDay(1);
        } catch (Exception e) {
            try {
                return LocalDate.parse(value.trim()).withDayOfMonth(1);
            } catch (Exception e2) {
                throw new IllegalArgumentException("Invalid " + label + ".");
            }
        }
    }

    private LocalDate date(String value, String label, boolean required) {
        if (value == null || value.trim().isEmpty()) {
            if (required) {
                throw new IllegalArgumentException(label + " is required.");
            }
            return null;
        }
        try {
            return LocalDate.parse(value.trim());
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid " + label + ".");
        }
    }

    private String safeTab(String tab) {
        if ("structures".equals(tab) || "process".equals(tab)
                || "history".equals(tab)) {
            return tab;
        }
        return "process";
    }

    private void redirect(HttpServletRequest request, HttpServletResponse response,
                          String tab, int month, int year,
                          String paramName, String paramValue)
            throws IOException {

        StringBuilder url = new StringBuilder();
        url.append(request.getContextPath())
           .append(isHr(request) ? "/hr" : "/admin")
           .append("?action=payroll&tab=").append(safeTab(tab))
           .append("&month=").append(month)
           .append("&year=").append(year);

        if (paramName != null) {
            url.append("&").append(paramName).append("=")
               .append(URLEncoder.encode(paramValue, StandardCharsets.UTF_8));
        }

        url.append("#payroll");
        response.sendRedirect(url.toString());
    }

    // Opening /payroll directly just opens the dashboard's Payroll section.
    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        HttpSession session = request.getSession(false);

        if (!isAdmin(session)) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        LocalDate now = LocalDate.now();
        redirect(request, response, request.getParameter("tab"),
                intParam(request, "month", now.getMonthValue(), 1, 12),
                intParam(request, "year", now.getYear(), 2000, 9999),
                null, null);
    }

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response)
            throws ServletException, IOException {

        request.setCharacterEncoding("UTF-8");

        HttpSession session = request.getSession(false);

        if (!isAdmin(session)) {
            response.sendRedirect(request.getContextPath() + "/login.html");
            return;
        }

        LocalDate now = LocalDate.now();
        int month = intParam(request, "month", now.getMonthValue(), 1, 12);
        int year = intParam(request, "year", now.getYear(), 2000, 9999);
        String tab = request.getParameter("tab");
        String action = request.getParameter("action");

        if (!validCsrf(request, session)) {
            redirect(request, response, tab, month, year, "payrollError",
                    "Security check failed. Please reload the page and try again.");
            return;
        }

        try {
            String message;

            if ("saveStructure".equalsIgnoreCase(action)) {
                message = saveStructure(request);

            } else if ("saveSchedule".equalsIgnoreCase(action)) {
                new DAO.PayrollSettingsDAO().save(
                        request.getParameter("autoEnabled") != null,
                        intParam(request, "payDay", 1, 1, 31),
                        intParam(request, "runHour", 9, 0, 23));
                message = request.getParameter("autoEnabled") != null
                        ? "Automatic payroll schedule saved: salary is paid on day "
                            + intParam(request, "payDay", 1, 1, 31) + " of every month at "
                            + String.format("%02d:00", intParam(request, "runHour", 9, 0, 23)) + "."
                        : "Automatic payroll is switched OFF.";

            } else if ("updateStructure".equalsIgnoreCase(action)) {
                message = updateStructure(request);

            } else if ("generate".equalsIgnoreCase(action)) {
                String employeeId = request.getParameter("employeeId");
                if (employeeId == null || employeeId.trim().isEmpty()) {
                    throw new IllegalArgumentException("Employee ID is required.");
                }
                Payroll payroll = payrollService.generateDraft(
                        employeeId.trim(), month, year);
                if (payroll == null) {
                    throw new IllegalStateException(
                            "Payroll draft could not be generated.");
                }
                message = "Payroll generated and marked PAID for " + employeeId.trim() + ".";

            } else if ("runPayroll".equalsIgnoreCase(action)) {
                PayrollService.BatchResult r =
                        payrollService.generateAllDrafts(month, year);
                message = r.generated + " payroll(s) generated and marked PAID"
                        + (r.alreadyFinal > 0 ? ", " + r.alreadyFinal + " already processed (skipped)" : "")
                        + (r.noStructure > 0 ? ", " + r.noStructure + " without salary structure (skipped)" : "")
                        + (r.failed > 0 ? ", " + r.failed + " failed" : "")
                        + ". Later months are generated automatically.";

            } else if ("pay".equalsIgnoreCase(action)) {
                message = recordPayment(request);

            } else {
                throw new IllegalArgumentException("Invalid payroll action.");
            }

            redirect(request, response, tab, month, year, "payrollMsg", message);

        } catch (IllegalArgumentException | IllegalStateException e) {
            redirect(request, response, tab, month, year,
                    "payrollError", e.getMessage());

        } catch (Exception e) {
            getServletContext().log("Payroll operation failed.", e);
            redirect(request, response, tab, month, year, "payrollError",
                    "Payroll operation failed: " + e.getMessage());
        }
    }

    private int parseId(String value) {
        try {
            int id = Integer.parseInt(value == null ? "" : value.trim());
            if (id <= 0) {
                throw new NumberFormatException();
            }
            return id;
        } catch (NumberFormatException e) {
            throw new IllegalArgumentException("Invalid payroll ID.");
        }
    }

    private String adminId(HttpSession session) {
        Object id = session.getAttribute("adminId");
        if (id == null) {
            id = session.getAttribute("adminEmail");
        }
        if (id == null) {
            id = session.getAttribute("hrId");
        }
        if (id == null || String.valueOf(id).trim().isEmpty()) {
            throw new IllegalStateException(
                    "Admin ID or email was not found in the session.");
        }
        return String.valueOf(id);
    }

    private List<SalaryComponent> readComponents(HttpServletRequest request) {

        String[] names = request.getParameterValues("compName");
        String[] types = request.getParameterValues("compType");
        String[] calcs = request.getParameterValues("compCalc");
        String[] amounts = request.getParameterValues("compAmount");

        List<SalaryComponent> components = new ArrayList<>();

        if (names != null) {
            for (int i = 0; i < names.length; i++) {
                String name = names[i] == null ? "" : names[i].trim();
                String amountText = (amounts != null && i < amounts.length)
                        ? amounts[i] : "";

                if (name.isEmpty() && (amountText == null || amountText.trim().isEmpty())) {
                    continue; // empty row
                }

                if (name.isEmpty() || name.length() > 100) {
                    throw new IllegalArgumentException(
                            "Component name is required (max 100 characters).");
                }

                SalaryComponent component = new SalaryComponent();
                component.setComponentName(name);
                component.setComponentType(types != null && i < types.length ? types[i] : "");
                component.setCalculationType(calcs != null && i < calcs.length ? calcs[i] : "");
                component.setAmount(decimal(amountText, "amount for " + name));
                components.add(component);
            }
        }

        return components;
    }

    private String updateStructure(HttpServletRequest request) throws Exception {

        int structureId = parseId(request.getParameter("structureId"));
        BigDecimal basic = decimal(request.getParameter("basicSalary"), "basic salary");

        List<SalaryComponent> components = readComponents(request);

        payrollService.updateSalaryStructure(
                structureId,
                request.getParameter("employeeId"),
                month(request.getParameter("effectiveFrom"), "Effective-from month"),
                basic, components,
                request.getParameter("bankName"),
                request.getParameter("accountNumber"),
                request.getParameter("ifscCode"),
                request.getParameter("panNumber"));

        // show exactly what was saved, components included
        StringBuilder saved = new StringBuilder("Salary structure saved for ")
                .append(request.getParameter("employeeId"))
                .append(": basic Rs ").append(basic.toPlainString());
        for (SalaryComponent c : components) {
            boolean earn = "EARNING".equalsIgnoreCase(c.getComponentType());
            boolean pct = "PERCENTAGE".equalsIgnoreCase(c.getCalculationType());
            saved.append(" | ").append(earn ? "+" : "-").append(' ')
                 .append(c.getComponentName()).append(' ')
                 .append(pct ? c.getAmount().stripTrailingZeros().toPlainString() + "%"
                             : "Rs " + c.getAmount().toPlainString());
        }
        saved.append(" (").append(components.size()).append(" component(s)).");
        return saved.toString();
    }

    private String saveStructure(HttpServletRequest request) throws Exception {

        String employeeId = request.getParameter("employeeId");
        BigDecimal basic = decimal(request.getParameter("basicSalary"), "basic salary");
        LocalDate from = month(request.getParameter("effectiveFrom"), "Effective-from month");
        LocalDate to = null; // entered once: the structure stays valid until a newer one is saved
        String bankName = request.getParameter("bankName");
        String accountNumber = request.getParameter("accountNumber");
        String ifscCode = request.getParameter("ifscCode");
        String panNumber = request.getParameter("panNumber");

        String[] names = request.getParameterValues("compName");
        String[] types = request.getParameterValues("compType");
        String[] calcs = request.getParameterValues("compCalc");
        String[] amounts = request.getParameterValues("compAmount");

        List<SalaryComponent> components = new ArrayList<>();

        if (names != null) {
            for (int i = 0; i < names.length; i++) {
                String name = names[i] == null ? "" : names[i].trim();
                String amountText = (amounts != null && i < amounts.length)
                        ? amounts[i] : "";

                if (name.isEmpty() && (amountText == null || amountText.trim().isEmpty())) {
                    continue; // empty row
                }

                if (name.isEmpty() || name.length() > 100) {
                    throw new IllegalArgumentException(
                            "Component name is required (max 100 characters).");
                }

                SalaryComponent component = new SalaryComponent();
                component.setComponentName(name);
                component.setComponentType(types != null && i < types.length ? types[i] : "");
                component.setCalculationType(calcs != null && i < calcs.length ? calcs[i] : "");
                component.setAmount(decimal(amountText, "amount for " + name));
                components.add(component);
            }
        }

        payrollService.createSalaryStructure(
                employeeId, basic, from, to, components,
                bankName, accountNumber, ifscCode, panNumber);

        return "Salary structure saved for " + employeeId.trim()
                + " (" + components.size() + " component(s)).";
    }

    private String recordPayment(HttpServletRequest request) throws Exception {

        int payrollId = parseId(request.getParameter("payrollId"));
        LocalDate paymentDate = date(request.getParameter("paymentDate"), "Payment date", true);

        if (paymentDate.isAfter(LocalDate.now())) {
            throw new IllegalArgumentException("Payment date cannot be in the future.");
        }

        String method = request.getParameter("paymentMethod");
        if (!("BANK_TRANSFER".equals(method) || "UPI".equals(method)
                || "CASH".equals(method) || "CHEQUE".equals(method))) {
            throw new IllegalArgumentException("Select a valid payment method.");
        }

        if (request.getParameter("confirmPaid") == null) {
            throw new IllegalArgumentException(
                    "Confirm that the payment was actually made before recording it.");
        }

        String reference = request.getParameter("referenceNumber");
        if (reference != null && reference.trim().length() > 100) {
            throw new IllegalArgumentException(
                    "Reference number is too long (max 100 characters).");
        }

        BigDecimal amount = decimal(request.getParameter("amountPaid"), "amount");

        PayrollPayment payment = new PayrollPayment();
        payment.setPayrollId(payrollId);
        payment.setPaymentDate(paymentDate);
        payment.setPaymentMethod(method);
        payment.setReferenceNumber(reference);
        payment.setAmountPaid(amount);

        try {
            paymentDAO.addPayment(payment);
        } catch (java.sql.SQLException e) {
            // payment rules (status, amount > remaining) are reported as plain messages
            throw new IllegalStateException(e.getMessage());
        }

        return "Payment recorded.";
    }
}
