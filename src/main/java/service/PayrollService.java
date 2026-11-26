package service;

import java.math.BigDecimal;
import java.sql.Date;
import java.time.LocalDate;
import java.math.RoundingMode;
import java.sql.SQLException;
import java.time.DayOfWeek;
import java.time.YearMonth;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import DAO.PayrollDAO;
import DAO.SalaryComponentDAO;
import DAO.SalaryStructureDAO;

import model.Payroll;
import model.SalaryComponent;
import model.SalaryStructure;

import util.PayrollCalculator;
import util.PayrollCalculator.PayrollCalculation;

public class PayrollService {

    /** Recorded as "processed by" when a payroll is generated and paid automatically. */
    private static final String AUTO_PAID_BY = "SYSTEM";

    /** Paid leave days every employee gets per month. They are never deducted. */
    public static final double PAID_LEAVES_PER_MONTH = 2;

    private final SalaryStructureDAO salaryStructureDAO;
    private final SalaryComponentDAO salaryComponentDAO;
    private final PayrollDAO payrollDAO;

    public PayrollService() {
        salaryStructureDAO = new SalaryStructureDAO();
        salaryComponentDAO = new SalaryComponentDAO();
        payrollDAO = new PayrollDAO();
    }

    // ------------------------------------------------------------------
    // Result holders used by the dashboard (public fields, read by the JSP)
    // ------------------------------------------------------------------

    public static class AttendanceSummary {
        public int daysInMonth;
        public int workingDays;      // Monday - Friday of the month
        public double presentDays;
        public double leaveDays;     // approved paid leave
        public double lopDays;       // unpaid days = the days that are really deducted
        // paid-leave allowance (2 per month) - shown on the salary slip
        public double paidLeaveAllowance = PAID_LEAVES_PER_MONTH;
        public double paidLeaveUsed;      // part of the allowance used this month (not deducted)
        public double unpaidLeaveDays;    // same as lopDays
    }

    public static class PreviewRow {
        public String employeeId;
        public String name;
        public String department;
        public String personType;    // EMPLOYEE or MANAGER
        public boolean hasStructure;
        public BigDecimal basic;
        public BigDecimal gross;
        public BigDecimal deductions;
        public BigDecimal net;
        public BigDecimal otHours = BigDecimal.ZERO;   // approved overtime hours of the month
        public BigDecimal otAmount = BigDecimal.ZERO;  // overtime pay (already inside gross)
        public AttendanceSummary attendance;
        public int payrollId;        // 0 = not generated yet
        public String payrollStatus; // null = not generated yet
    }

    public static class BatchResult {
        public int generated;
        public int alreadyFinal;
        public int noStructure;
        public int failed;
    }

    // ------------------------------------------------------------------
    // Attendance integration
    // ------------------------------------------------------------------

    private static boolean isUnpaidLeave(String type) {
        String t = type == null ? "" : type.toUpperCase();
        return t.contains("UNPAID") || t.contains("LOP") || t.contains("WITHOUT");
    }

    /**
     * Attendance summary for one employee and payroll month.
     *
     * Rules (change here if company policy differs):
     *  - working days = Monday to Friday; future days are not evaluated
     *  - PRESENT = paid; HALF day = 0.5 present + 0.5 day off
     *  - every employee has 2 PAID LEAVES per month (PAID_LEAVES_PER_MONTH).
     *    Days off (approved leave, absent / no record, half-day) use these
     *    paid leaves first and cost NO money.
     *  - only the days beyond the 2 paid leaves are UNPAID and cut salary
     *  - approved leave of an unpaid type (Unpaid / LOP / Without pay) is
     *    always unpaid; it never uses the paid leaves
     */
    public AttendanceSummary getAttendanceSummary(
            String employeeId, int month, int year) throws SQLException {

        validatePeriod(employeeId, month, year);

        YearMonth ym = YearMonth.of(year, month);
        java.time.LocalDate first = ym.atDay(1);
        java.time.LocalDate last = ym.atEndOfMonth();
        java.time.LocalDate today = java.time.LocalDate.now();

        Map<java.time.LocalDate, String> records =
                payrollDAO.getAttendanceStatuses(employeeId, first, last);
        List<Object[]> leaves =
                payrollDAO.getApprovedLeaves(employeeId, first, last);

        AttendanceSummary a = new AttendanceSummary();
        a.daysInMonth = ym.lengthOfMonth();

        double daysOff = 0;          // can be covered by the paid leaves
        double explicitUnpaid = 0;   // unpaid-type leave: never covered

        for (java.time.LocalDate d = first; !d.isAfter(last); d = d.plusDays(1)) {

            DayOfWeek dow = d.getDayOfWeek();

            if (dow == DayOfWeek.SATURDAY || dow == DayOfWeek.SUNDAY) {
                continue;
            }

            a.workingDays++;

            if (d.isAfter(today)) {
                continue;
            }

            String status = records.get(d);
            status = status == null ? "" : status.trim().toUpperCase();

            if ("PRESENT".equals(status)) {
                a.presentDays += 1;
                continue;
            }

            if (status.contains("HALF")) {
                a.presentDays += 0.5;
                daysOff += 0.5;
                continue;
            }

            Object[] covering = null;

            for (Object[] leave : leaves) {
                java.time.LocalDate from = (java.time.LocalDate) leave[0];
                java.time.LocalDate to = (java.time.LocalDate) leave[1];

                if (!d.isBefore(from) && !d.isAfter(to)) {
                    covering = leave;
                    break;
                }
            }

            if (covering != null && isUnpaidLeave((String) covering[2])) {
                explicitUnpaid += 1;
            } else if (covering != null || "LEAVE".equals(status)) {
                a.leaveDays += 1;       // approved paid leave taken
                daysOff += 1;
            } else {
                daysOff += 1;           // absent / no record
            }
        }

        // the 2 paid leaves absorb the first days off; the rest is unpaid
        a.paidLeaveUsed = Math.min(PAID_LEAVES_PER_MONTH, daysOff);
        a.lopDays = (daysOff - a.paidLeaveUsed) + explicitUnpaid;
        a.unpaidLeaveDays = a.lopDays;

        return a;
    }

    /**
     * Salary structure for a payroll month. A structure is entered once and
     * carries forward to every later month automatically (until a newer one
     * is added). See SalaryStructureDAO.getStructureForPayroll.
     */
    private SalaryStructure structureFor(String employeeId, int month, int year)
            throws SQLException {
        return salaryStructureDAO.getStructureForPayroll(
                employeeId, Date.valueOf(YearMonth.of(year, month).atEndOfMonth()));
    }

    /**
     * Loss-of-pay deduction = gross / calendar days in month x LOP days.
     * Capped so that net salary never becomes negative.
     */
    public BigDecimal calculateAttendanceDeduction(
            SalaryStructure structure,
            List<SalaryComponent> components,
            AttendanceSummary attendance) {

        if (attendance == null || attendance.lopDays <= 0) {
            return BigDecimal.ZERO;
        }

        PayrollCalculation base =
                PayrollCalculator.calculate(structure, components, BigDecimal.ZERO);

        BigDecimal deduction = base.getGrossSalary()
                .multiply(BigDecimal.valueOf(attendance.lopDays))
                .divide(BigDecimal.valueOf(attendance.daysInMonth),
                        2, RoundingMode.HALF_UP);

        BigDecimal maximum =
                base.getGrossSalary().subtract(base.getComponentDeductions());

        if (maximum.signum() < 0) {
            maximum = BigDecimal.ZERO;
        }

        return deduction.min(maximum);
    }

    // Draft with the attendance deduction calculated automatically.
    public Payroll generateDraft(String employeeId, int month, int year)
            throws Exception {

        validatePeriod(employeeId, month, year);

        LocalDate payrollDate = LocalDate.of(year, month, 1);

        SalaryStructure structure = structureFor(employeeId, month, year);

        if (structure == null) {
            throw new IllegalArgumentException(
                    "No salary structure found for employee "
                            + employeeId + " on " + payrollDate);
        }

        List<SalaryComponent> components =
                salaryComponentDAO.getComponentsByStructureId(structure.getId());

        AttendanceSummary attendance =
                getAttendanceSummary(employeeId, month, year);

        BigDecimal deduction =
                calculateAttendanceDeduction(structure, components, attendance);

        return generateDraft(employeeId, month, year, deduction);
    }

    // Generate drafts for every active employee that has a salary structure.
    public BatchResult generateAllDrafts(int month, int year) throws Exception {

        BatchResult result = new BatchResult();

        for (String[] employee : payrollDAO.getEligibleEmployees()) {
            try {
                generateDraft(employee[0], month, year);
                result.generated++;

            } catch (IllegalStateException e) {
                result.alreadyFinal++;

            } catch (IllegalArgumentException e) {
                if (e.getMessage() != null
                        && e.getMessage().startsWith("No salary structure")) {
                    result.noStructure++;
                } else {
                    result.failed++;
                }

            } catch (Exception e) {
                result.failed++;
            }
        }

        return result;
    }

    // ------------------------------------------------------------------
    // Automatic monthly generation
    // ------------------------------------------------------------------

    private static volatile long lastAutoRun = 0L;
    private static final long AUTO_INTERVAL_MS = 5 * 60 * 1000L;

    /**
     * Once the first payroll month has been generated manually:
     *  - every finished month that is still missing is generated and paid, and
     *  - the RUNNING month is generated and PAID automatically (on the 1st of
     *    each month) for everybody whose salary structure existed before that
     *    month began - the structure is entered once and carries forward.
     * People whose structure starts in the running month are paid from the next
     * month (or manually with Generate). Already paid payrolls are never touched.
     * Runs at 00:01 on the 1st of every month (see PayrollScheduler) and hourly as a
     * catch-up, so salary is paid on the 1st even if nobody opens the dashboard.
     */
    public synchronized BatchResult autoGenerate() throws Exception {

        BatchResult total = new BatchResult();

        settleLeftoverPayrolls();

        YearMonth current = YearMonth.now();

        // Catch up from the latest payroll month; with no payroll yet, only the
        // running month is handled (everybody whose structure started earlier).
        int[] latest = payrollDAO.getLatestPayrollPeriod();
        YearMonth ym = latest == null ? current : YearMonth.of(latest[0], latest[1]);

        int guard = 0;
        while (!ym.isAfter(current) && guard++ < 36) {
            BatchResult r = ym.isBefore(current)
                    ? generateAllDrafts(ym.getMonthValue(), ym.getYear())
                    : generateEnrolledForMonth(ym.getMonthValue(), ym.getYear());
            total.generated += r.generated;
            total.alreadyFinal += r.alreadyFinal;
            total.noStructure += r.noStructure;
            total.failed += r.failed;
            ym = ym.plusMonths(1);
        }

        lastAutoRun = System.currentTimeMillis();
        return total;
    }

    // Running month: only people whose structure started before the month.
    private BatchResult generateEnrolledForMonth(int month, int year) throws Exception {

        BatchResult result = new BatchResult();
        LocalDate monthStart = LocalDate.of(year, month, 1);

        for (String[] employee : payrollDAO.getEligibleEmployees()) {
            try {
                SalaryStructure structure = structureFor(employee[0], month, year);

                if (structure == null || structure.getEffectiveFrom() == null
                        || !structure.getEffectiveFrom().isBefore(monthStart)) {
                    continue;
                }

                Payroll existing = payrollDAO.getPayrollForPeriod(employee[0], month, year);
                if (existing != null && "PAID".equalsIgnoreCase(existing.getStatus())) {
                    continue;
                }

                generateDraft(employee[0], month, year);
                result.generated++;

            } catch (IllegalStateException e) {
                result.alreadyFinal++;
            } catch (Exception e) {
                result.failed++;
            }
        }

        return result;
    }

    /** Same as autoGenerate(), but skipped if it already ran in the last 5 minutes. */
    public void autoGenerateIfDue() {

        if (System.currentTimeMillis() - lastAutoRun < AUTO_INTERVAL_MS) {
            return;
        }

        try {
            autoGenerate();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    /**
     * There is no draft stage any more: generating a payroll pays it. Old DRAFT /
     * PROCESSED rows left from before are recalculated and marked PAID here.
     */
    private void settleLeftoverPayrolls() {

        for (String leftover : new String[]{"DRAFT", "PROCESSED"}) {
            try {
                for (Payroll p : payrollDAO.searchPayroll(0, 0, "", leftover, "")) {
                    try {
                        generateDraft(p.getEmployeeId(), p.getPayrollMonth(), p.getPayrollYear());
                    } catch (Exception ignored) {
                        // e.g. structure removed: stays visible as PENDING
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }

    // Review table for "Process Payroll": estimate for each eligible employee.
    public List<PreviewRow> previewPayroll(int month, int year) throws Exception {
        return previewPayroll(month, year, "ALL");
    }

    // personType: ALL, EMPLOYEE or MANAGER
    public List<PreviewRow> previewPayroll(int month, int year, String personType)
            throws Exception {

        List<PreviewRow> rows = new ArrayList<>();
        LocalDate payrollDate = LocalDate.of(year, month, 1);

        Map<String, Payroll> existing = new java.util.HashMap<>();
        for (Payroll p : payrollDAO.getPayrollByPeriod(month, year)) {
            existing.put(p.getEmployeeId(), p);
        }

        for (String[] employee : payrollDAO.getEligibleEmployees(personType)) {

            PreviewRow row = new PreviewRow();
            row.employeeId = employee[0];
            row.name = employee[1];
            row.department = employee[2];
            row.personType = employee.length > 4 ? employee[4] : "EMPLOYEE";
            row.attendance = getAttendanceSummary(employee[0], month, year);

            Payroll saved = existing.get(employee[0]);

            if (saved != null) {
                row.payrollId = saved.getId();
                row.payrollStatus = saved.getStatus();
            }

            SalaryStructure structure =
                    structureFor(employee[0], month, year);

            row.hasStructure = structure != null;

            if (saved != null && !"DRAFT".equalsIgnoreCase(saved.getStatus())) {
                // finalized: show the stored snapshot, never recalculate
                row.basic = saved.getBasicSalary();
                row.gross = saved.getGrossSalary();
                row.deductions = saved.getTotalDeductions();
                row.net = saved.getNetSalary();

                OvertimeService.OtSummary paidOt = OvertimeService.forPayroll(saved.getId());
                row.otHours = paidOt.hours;
                row.otAmount = paidOt.amount;

            } else if (structure != null) {
                List<SalaryComponent> components =
                        salaryComponentDAO.getComponentsByStructureId(
                                structure.getId());

                try {
                    BigDecimal deduction = calculateAttendanceDeduction(
                            structure, components, row.attendance);

                    OvertimeService.OtSummary ot = OvertimeService.summaryFor(
                            row.employeeId, month, year,
                            PayrollCalculator.calculate(
                                    structure, components, BigDecimal.ZERO).getGrossSalary());

                    PayrollCalculation calc = PayrollCalculator.calculate(
                            structure, components, deduction, ot.amount);

                    row.otHours = ot.hours;
                    row.otAmount = ot.amount;

                    row.basic = calc.getBasicSalary();
                    row.gross = calc.getGrossSalary();
                    row.deductions = calc.getTotalDeductions();
                    row.net = calc.getNetSalary();

                } catch (IllegalArgumentException invalidStructure) {
                    row.basic = structure.getBasicSalary();
                }
            }

            rows.add(row);
        }

        return rows;
    }

    // ------------------------------------------------------------------
    // Salary structure (with components) management
    // ------------------------------------------------------------------

    /** Bank name / type: letters, spaces and . & ' - only (no digits). */
    private static final String BANK_NAME_REGEX = "[A-Za-z][A-Za-z .&'\\-]*";

    public int createSalaryStructure(
            String employeeId,
            BigDecimal basicSalary,
            LocalDate effectiveFrom,
            LocalDate effectiveTo,
            List<SalaryComponent> components) throws Exception {

        return createSalaryStructure(employeeId, basicSalary, effectiveFrom,
                effectiveTo, components, null, null, null, null);
    }

    /**
     * Salary structure with bank details. effectiveFrom is a month: it is stored
     * as the 1st day of that month.
     */
    public int createSalaryStructure(
            String employeeId,
            BigDecimal basicSalary,
            LocalDate effectiveFrom,
            LocalDate effectiveTo,
            List<SalaryComponent> components,
            String bankName,
            String accountNumber,
            String ifscCode,
            String panNumber) throws Exception {

        bankName = bankName == null ? "" : bankName.trim();
        accountNumber = accountNumber == null ? "" : accountNumber.replaceAll("\\s", "");
        ifscCode = ifscCode == null ? "" : ifscCode.trim().toUpperCase();
        panNumber = panNumber == null ? "" : panNumber.trim().toUpperCase();

        if (bankName.length() > 100) {
            throw new IllegalArgumentException("Bank name is too long (max 100 characters).");
        }
        if (!bankName.isEmpty() && !bankName.matches(BANK_NAME_REGEX)) {
            throw new IllegalArgumentException(
                    "Bank name / type must contain letters only - numbers are not allowed.");
        }
        if (!accountNumber.isEmpty() && !accountNumber.matches("[0-9]{9,18}")) {
            throw new IllegalArgumentException("Enter a valid bank account number (9 to 18 digits).");
        }

        if (employeeId == null || employeeId.trim().isEmpty()) {
            throw new IllegalArgumentException("Select an employee.");
        }

        if (!payrollDAO.isActiveEmployee(employeeId.trim())) {
            throw new IllegalArgumentException(
                    "Employee was not found or is not active.");
        }

        if (basicSalary == null || basicSalary.signum() <= 0
                || basicSalary.scale() > 2
                || basicSalary.compareTo(new BigDecimal("9999999999.99")) > 0) {
            throw new IllegalArgumentException(
                    "Enter a valid basic salary greater than zero (max 2 decimals).");
        }

        if (effectiveFrom == null) {
            throw new IllegalArgumentException("Effective-from month is required.");
        }

        effectiveFrom = effectiveFrom.withDayOfMonth(1);

        if (effectiveTo != null && effectiveTo.isBefore(effectiveFrom)) {
            throw new IllegalArgumentException(
                    "Effective-to date cannot be before effective-from.");
        }

        // Entered ONCE: no end date, so every later month uses this structure
        // automatically until a newer structure is saved.
        effectiveTo = null;

        SalaryStructure structure = new SalaryStructure();
        structure.setEmployeeId(employeeId.trim());
        structure.setBasicSalary(basicSalary);
        structure.setEffectiveFrom(effectiveFrom);
        structure.setEffectiveTo(effectiveTo);
        structure.setBankName(bankName);
        structure.setAccountNumber(accountNumber);
        structure.setIfscCode(ifscCode);
        structure.setPanNumber(panNumber);

        // Validates every component (type, rate, deductions <= gross) before saving.
        PayrollCalculator.calculate(structure, components, BigDecimal.ZERO);

        return salaryStructureDAO.addWithComponents(structure, components);
    }

    /**
     * Edit an existing salary structure (basic salary, bank details and the
     * whole earnings / deductions list). Months already paid keep their stored amounts.
     */
    public void updateSalaryStructure(
            int structureId,
            String employeeId,
            LocalDate effectiveFrom,
            BigDecimal basicSalary,
            List<SalaryComponent> components,
            String bankName,
            String accountNumber,
            String ifscCode,
            String panNumber) throws Exception {

        SalaryStructure existing = salaryStructureDAO.getById(structureId);

        if (existing == null) {
            throw new IllegalArgumentException("Salary structure not found.");
        }

        bankName = bankName == null ? "" : bankName.trim();
        accountNumber = accountNumber == null ? "" : accountNumber.replaceAll("\\s", "");
        ifscCode = ifscCode == null ? "" : ifscCode.trim().toUpperCase();
        panNumber = panNumber == null ? "" : panNumber.trim().toUpperCase();

        if (bankName.length() > 100) {
            throw new IllegalArgumentException("Bank name is too long (max 100 characters).");
        }
        if (!bankName.isEmpty() && !bankName.matches(BANK_NAME_REGEX)) {
            throw new IllegalArgumentException(
                    "Bank name / type must contain letters only - numbers are not allowed.");
        }
        if (!accountNumber.isEmpty() && !accountNumber.matches("[0-9]{9,18}")) {
            throw new IllegalArgumentException("Enter a valid bank account number (9 to 18 digits).");
        }

        if (basicSalary == null || basicSalary.signum() <= 0
                || basicSalary.scale() > 2
                || basicSalary.compareTo(new BigDecimal("9999999999.99")) > 0) {
            throw new IllegalArgumentException(
                    "Enter a valid basic salary greater than zero (max 2 decimals).");
        }

        if (employeeId == null || employeeId.trim().isEmpty()) {
            throw new IllegalArgumentException("Select an employee.");
        }
        employeeId = employeeId.trim();

        if (!payrollDAO.isActiveEmployee(employeeId)) {
            throw new IllegalArgumentException("Employee was not found or is not active.");
        }

        if (effectiveFrom == null) {
            throw new IllegalArgumentException("Effective-from month is required.");
        }

        existing.setEmployeeId(employeeId);
        existing.setEffectiveFrom(effectiveFrom.withDayOfMonth(1));
        existing.setEffectiveTo(null); // entered once: valid for every later month
        existing.setBasicSalary(basicSalary);
        // bank details are no longer entered on this screen: keep whatever is stored
        if (!bankName.isEmpty()) existing.setBankName(bankName);
        if (!accountNumber.isEmpty()) existing.setAccountNumber(accountNumber);
        if (!ifscCode.isEmpty()) existing.setIfscCode(ifscCode);
        if (!panNumber.isEmpty()) existing.setPanNumber(panNumber);

        // same validation as a new structure (type, rate, deductions <= gross)
        PayrollCalculator.calculate(existing, components, BigDecimal.ZERO);

        salaryStructureDAO.updateWithComponents(structureId, existing, components);
    }

    // Generate monthly draft payroll
    public Payroll generateDraft(
            String employeeId,
            int month,
            int year,
            BigDecimal attendanceDeduction) throws Exception {

        validatePeriod(employeeId, month, year);

        if (attendanceDeduction == null) {
            attendanceDeduction = BigDecimal.ZERO;
        }

        if (attendanceDeduction.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException(
                    "Attendance deduction cannot be negative.");
        }

        LocalDate payrollDate = LocalDate.of(year, month, 1);

        SalaryStructure salaryStructure =
                structureFor(employeeId, month, year);

        if (salaryStructure == null) {
            throw new IllegalArgumentException(
                    "No salary structure found for employee "
                            + employeeId + " on " + payrollDate);
        }

        List<SalaryComponent> components =
                salaryComponentDAO.getComponentsByStructureId(
                        salaryStructure.getId());

        // Approved overtime of this pay month is added to the gross salary.
        // hourly rate = (basic + earnings) / (working days x 8 h)
        PayrollCalculation base =
                PayrollCalculator.calculate(
                        salaryStructure,
                        components,
                        BigDecimal.ZERO);

        OvertimeService.OtSummary overtime =
                OvertimeService.summaryFor(
                        employeeId, month, year, base.getGrossSalary());

        PayrollCalculation calculation =
                PayrollCalculator.calculate(
                        salaryStructure,
                        components,
                        attendanceDeduction,
                        overtime.amount);

        Payroll payroll = payrollDAO.getPayrollForPeriod(
                employeeId, month, year);

        if (payroll != null) {

            // Old payroll that was processed but never paid: just mark it PAID.
            if ("PROCESSED".equalsIgnoreCase(payroll.getStatus())) {
                payrollDAO.markPaid(payroll.getId(), AUTO_PAID_BY);
                return payrollDAO.getPayrollById(payroll.getId());
            }

            if (!"DRAFT".equalsIgnoreCase(payroll.getStatus())) {
                throw new IllegalStateException(
                        "Only DRAFT payroll can be recalculated. "
                                + "Current status: "
                                + payroll.getStatus());
            }

            payroll.setBasicSalary(
                    calculation.getBasicSalary());

            payroll.setGrossSalary(
                    calculation.getGrossSalary());

            payroll.setTotalDeductions(
                    calculation.getTotalDeductions());

            payroll.setNetSalary(
                    calculation.getNetSalary());

            boolean updated =
                    payrollDAO.updateDraftAmounts(payroll);

            if (!updated) {
                throw new Exception(
                        "Unable to update draft payroll.");
            }

            // link the overtime to this payroll (shown on the salary slip)
            OvertimeService.attachToPayroll(
                    payroll.getId(), employeeId, month, year, overtime.rate);

            // Generating a payroll also pays it: status becomes PAID.
            payrollDAO.markPaid(payroll.getId(), AUTO_PAID_BY);

            return payrollDAO.getPayrollById(payroll.getId());
        }

        Payroll newPayroll = new Payroll();

        newPayroll.setEmployeeId(employeeId);
        newPayroll.setPayrollMonth(month);
        newPayroll.setPayrollYear(year);

        newPayroll.setBasicSalary(
                calculation.getBasicSalary());

        newPayroll.setGrossSalary(
                calculation.getGrossSalary());

        newPayroll.setTotalDeductions(
                calculation.getTotalDeductions());

        newPayroll.setNetSalary(
                calculation.getNetSalary());

        newPayroll.setStatus("DRAFT");

        // createDraft() only inserts the basic salary (gross/deductions/net = 0),
        // so save the calculated amounts right after creating the draft.
        int newId = payrollDAO.createDraft(newPayroll);

        boolean amountsSaved = payrollDAO.updateDraftAmounts(
                newId,
                calculation.getBasicSalary(),
                calculation.getGrossSalary(),
                calculation.getTotalDeductions(),
                calculation.getNetSalary());

        if (!amountsSaved) {
            throw new Exception(
                    "Draft was created but the calculated amounts could not be saved.");
        }

        // link the overtime to this payroll (shown on the salary slip)
        OvertimeService.attachToPayroll(
                newId, employeeId, month, year, overtime.rate);

        // Generating a payroll also pays it: status becomes PAID.
        payrollDAO.markPaid(newId, AUTO_PAID_BY);

        Payroll savedPayroll = payrollDAO.getPayrollForPeriod(
                employeeId, month, year);

        if (savedPayroll == null) {
            throw new Exception(
                    "Payroll was not found after attempting to save it.");
        }

        return savedPayroll;
    }

    // Process a draft payroll
    public boolean processPayroll(
            int payrollId,
            String administratorId) throws Exception {

        if (payrollId <= 0) {
            throw new IllegalArgumentException(
                    "Invalid payroll ID.");
        }

        if (administratorId == null
                || administratorId.trim().isEmpty()) {
            throw new IllegalArgumentException(
                    "Administrator ID is required.");
        }

        Payroll payroll = payrollDAO.getPayrollById(payrollId);

        if (payroll == null) {
            throw new IllegalArgumentException(
                    "Payroll record not found.");
        }

        if (!"DRAFT".equalsIgnoreCase(payroll.getStatus())) {
            throw new IllegalStateException(
                    "Only DRAFT payroll can be processed.");
        }

        return payrollDAO.finalizePayroll(
                payrollId, administratorId);
    }

    // Get payroll for a specific employee and period
    public Payroll getEmployeePayroll(
            String employeeId,
            int month,
            int year) throws Exception {

        validatePeriod(employeeId, month, year);

        return payrollDAO.getPayrollForPeriod(
                employeeId, month, year);
    }

    // Validate employee ID and payroll period
    private void validatePeriod(
            String employeeId,
            int month,
            int year) {

        if (employeeId == null || employeeId.trim().isEmpty()) {
            throw new IllegalArgumentException(
                    "Employee ID is required.");
        }

        if (month < 1 || month > 12) {
            throw new IllegalArgumentException(
                    "Month must be between 1 and 12.");
        }

        if (year < 2000 || year > 9999) {
            throw new IllegalArgumentException(
                    "Invalid payroll year.");
        }
    }
}