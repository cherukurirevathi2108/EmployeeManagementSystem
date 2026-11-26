package util;

import java.math.BigDecimal;
import java.math.RoundingMode;
import java.util.List;

import model.SalaryStructure;
import model.SalaryComponent;

public class PayrollCalculator {

    private static final int SCALE = 2;
    private static final RoundingMode ROUNDING_MODE = RoundingMode.HALF_UP;

    public static PayrollCalculation calculate(
            SalaryStructure salaryStructure,
            List<SalaryComponent> components,
            BigDecimal attendanceDeduction) {

        return calculate(salaryStructure, components,
                attendanceDeduction, BigDecimal.ZERO);
    }

    /**
     * Same calculation, with the overtime pay of the month added to the
     * gross salary (basic + earnings + overtime).
     */
    public static PayrollCalculation calculate(
            SalaryStructure salaryStructure,
            List<SalaryComponent> components,
            BigDecimal attendanceDeduction,
            BigDecimal overtimeAmount) {

        if (overtimeAmount == null) {
            overtimeAmount = BigDecimal.ZERO;
        }

        if (overtimeAmount.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException(
                    "Overtime amount cannot be negative.");
        }

        if (salaryStructure == null) {
            throw new IllegalArgumentException(
                    "Salary structure cannot be null.");
        }

        if (components == null) {
            throw new IllegalArgumentException(
                    "Salary components cannot be null.");
        }

        if (salaryStructure.getBasicSalary() == null
                || salaryStructure.getBasicSalary().compareTo(
                        BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException(
                    "Basic salary must be zero or greater.");
        }

        if (attendanceDeduction == null) {
            attendanceDeduction = BigDecimal.ZERO;
        }

        if (attendanceDeduction.compareTo(BigDecimal.ZERO) < 0) {
            throw new IllegalArgumentException(
                    "Attendance deduction cannot be negative.");
        }

        BigDecimal basicSalary = money(
                salaryStructure.getBasicSalary());

        BigDecimal totalEarnings = BigDecimal.ZERO;
        BigDecimal totalComponentDeductions = BigDecimal.ZERO;

        for (SalaryComponent component : components) {

            if (component == null) {
                continue;
            }

            BigDecimal amount = component.getAmount();

            if (amount == null || amount.compareTo(BigDecimal.ZERO) < 0) {
                throw new IllegalArgumentException(
                        "Component amount must be zero or greater.");
            }

            String componentType = component.getComponentType();
            String calculationType = component.getCalculationType();

            BigDecimal calculatedAmount;

            if ("FIXED".equalsIgnoreCase(calculationType)) {

                calculatedAmount = money(amount);

            } else if ("PERCENTAGE".equalsIgnoreCase(calculationType)) {

                if (amount.compareTo(new BigDecimal("100")) > 0) {
                    throw new IllegalArgumentException(
                            "Percentage cannot exceed 100.");
                }

                /*
                 * Percentage components are calculated on basic salary.
                 * Change this base if your company uses another salary rule.
                 */
                calculatedAmount = money(
                        basicSalary.multiply(amount)
                                .divide(new BigDecimal("100"),
                                        4, ROUNDING_MODE));

            } else {
                throw new IllegalArgumentException(
                        "Invalid calculation type: " + calculationType);
            }

            if ("EARNING".equalsIgnoreCase(componentType)) {

                totalEarnings = totalEarnings.add(calculatedAmount);

            } else if ("DEDUCTION".equalsIgnoreCase(componentType)) {

                totalComponentDeductions =
                        totalComponentDeductions.add(calculatedAmount);

            } else {
                throw new IllegalArgumentException(
                        "Invalid component type: " + componentType);
            }
        }

        totalEarnings = money(totalEarnings);
        totalComponentDeductions = money(totalComponentDeductions);
        attendanceDeduction = money(attendanceDeduction);

        overtimeAmount = money(overtimeAmount);

        BigDecimal grossSalary = money(
                basicSalary.add(totalEarnings).add(overtimeAmount));

        BigDecimal totalDeductions = money(
                totalComponentDeductions.add(attendanceDeduction));

        if (totalDeductions.compareTo(grossSalary) > 0) {
            throw new IllegalArgumentException(
                    "Total deductions cannot exceed gross salary.");
        }

        BigDecimal netSalary = money(
                grossSalary.subtract(totalDeductions));

        PayrollCalculation result = new PayrollCalculation();

        result.setBasicSalary(basicSalary);
        result.setTotalEarnings(totalEarnings);
        result.setOvertimeAmount(overtimeAmount);
        result.setGrossSalary(grossSalary);
        result.setComponentDeductions(totalComponentDeductions);
        result.setAttendanceDeduction(attendanceDeduction);
        result.setTotalDeductions(totalDeductions);
        result.setNetSalary(netSalary);

        return result;
    }

    private static BigDecimal money(BigDecimal amount) {
        return amount.setScale(SCALE, ROUNDING_MODE);
    }

    public static class PayrollCalculation {

        private BigDecimal basicSalary;
        private BigDecimal totalEarnings;
        private BigDecimal overtimeAmount = BigDecimal.ZERO;
        private BigDecimal grossSalary;
        private BigDecimal componentDeductions;
        private BigDecimal attendanceDeduction;
        private BigDecimal totalDeductions;
        private BigDecimal netSalary;

        public BigDecimal getBasicSalary() {
            return basicSalary;
        }

        public void setBasicSalary(BigDecimal basicSalary) {
            this.basicSalary = basicSalary;
        }

        public BigDecimal getTotalEarnings() {
            return totalEarnings;
        }

        public void setTotalEarnings(BigDecimal totalEarnings) {
            this.totalEarnings = totalEarnings;
        }

        public BigDecimal getOvertimeAmount() {
            return overtimeAmount;
        }

        public void setOvertimeAmount(BigDecimal overtimeAmount) {
            this.overtimeAmount = overtimeAmount;
        }

        public BigDecimal getGrossSalary() {
            return grossSalary;
        }

        public void setGrossSalary(BigDecimal grossSalary) {
            this.grossSalary = grossSalary;
        }

        public BigDecimal getComponentDeductions() {
            return componentDeductions;
        }

        public void setComponentDeductions(
                BigDecimal componentDeductions) {
            this.componentDeductions = componentDeductions;
        }

        public BigDecimal getAttendanceDeduction() {
            return attendanceDeduction;
        }

        public void setAttendanceDeduction(
                BigDecimal attendanceDeduction) {
            this.attendanceDeduction = attendanceDeduction;
        }

        public BigDecimal getTotalDeductions() {
            return totalDeductions;
        }

        public void setTotalDeductions(BigDecimal totalDeductions) {
            this.totalDeductions = totalDeductions;
        }

        public BigDecimal getNetSalary() {
            return netSalary;
        }

        public void setNetSalary(BigDecimal netSalary) {
            this.netSalary = netSalary;
        }
    }
}