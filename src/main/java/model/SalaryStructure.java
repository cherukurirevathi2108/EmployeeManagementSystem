
package model;

import java.math.BigDecimal;
import java.time.LocalDate;

public class SalaryStructure {

    private int id;
    private String employeeId;
    private BigDecimal basicSalary;
    private LocalDate effectiveFrom;
    private LocalDate effectiveTo;
    private String employeeName;
    private String department;
    private String bankName;
    private String accountNumber;
    private String ifscCode;
    private String panNumber;

    public SalaryStructure() {
    }

    public String getBankName() { return bankName; }

    public void setBankName(String bankName) { this.bankName = bankName; }

    public String getAccountNumber() { return accountNumber; }

    public void setAccountNumber(String accountNumber) { this.accountNumber = accountNumber; }

    public String getIfscCode() { return ifscCode; }

    public void setIfscCode(String ifscCode) { this.ifscCode = ifscCode; }

    public String getPanNumber() { return panNumber; }

    public void setPanNumber(String panNumber) { this.panNumber = panNumber; }

    public String getEmployeeName() { return employeeName; }

    public void setEmployeeName(String employeeName) { this.employeeName = employeeName; }

    public String getDepartment() { return department; }

    public void setDepartment(String department) { this.department = department; }

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

    public BigDecimal getBasicSalary() {
        return basicSalary;
    }

    public void setBasicSalary(BigDecimal basicSalary) {
        this.basicSalary = basicSalary;
    }

    public LocalDate getEffectiveFrom() {
        return effectiveFrom;
    }

    public void setEffectiveFrom(LocalDate effectiveFrom) {
        this.effectiveFrom = effectiveFrom;
    }

    public LocalDate getEffectiveTo() {
        return effectiveTo;
    }

    public void setEffectiveTo(LocalDate effectiveTo) {
        this.effectiveTo = effectiveTo;
    }
}
