
package model;

import java.math.BigDecimal;
import java.time.LocalDateTime;

public class Payroll {

    private int id;
    private String employeeId;
    private int payrollMonth;
    private int payrollYear;
    private BigDecimal basicSalary;
    private BigDecimal grossSalary;
    private BigDecimal totalDeductions;
    private BigDecimal netSalary;
    private String status;
    private String processedBy;
    private LocalDateTime processedAt;
    private String employeeName;
    private String department;
    private String designation;
    private BigDecimal paidAmount;
    private String personType; // EMPLOYEE or MANAGER

    public Payroll() {
    }

    public String getPersonType() { return personType; }

    public void setPersonType(String personType) { this.personType = personType; }

    public String getDepartment() { return department; }

    public void setDepartment(String department) { this.department = department; }

    public String getDesignation() { return designation; }

    public void setDesignation(String designation) { this.designation = designation; }

    public BigDecimal getPaidAmount() { return paidAmount; }

    public void setPaidAmount(BigDecimal paidAmount) { this.paidAmount = paidAmount; }

    public String getEmployeeName() {
        return employeeName;
    }

    public void setEmployeeName(String employeeName) {
        this.employeeName = employeeName;
    }

    public int getId() {
        return id;
    }

    public void setId(int id) {
        this.id = id;
    }

    public String getEmployeeId() {
        return employeeId;
    }

    public void setEmployeeId(String employeeId) {
        this.employeeId = employeeId;
    }

    public int getPayrollMonth() {
        return payrollMonth;
    }

    public void setPayrollMonth(int payrollMonth) {
        this.payrollMonth = payrollMonth;
    }

    public int getPayrollYear() {
        return payrollYear;
    }

    public void setPayrollYear(int payrollYear) {
        this.payrollYear = payrollYear;
    }

    public BigDecimal getBasicSalary() {
        return basicSalary;
    }

    public void setBasicSalary(BigDecimal basicSalary) {
        this.basicSalary = basicSalary;
    }

    public BigDecimal getGrossSalary() {
        return grossSalary;
    }

    public void setGrossSalary(BigDecimal grossSalary) {
        this.grossSalary = grossSalary;
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

    public String getStatus() {
        return status;
    }

    public void setStatus(String status) {
        this.status = status;
    }

    public String getProcessedBy() {
        return processedBy;
    }

    public void setProcessedBy(String processedBy) {
        this.processedBy = processedBy;
    }

    public LocalDateTime getProcessedAt() {
        return processedAt;
    }

    public void setProcessedAt(LocalDateTime processedAt) {
        this.processedAt = processedAt;
    }
}
