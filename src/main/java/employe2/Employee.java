//package employe2;
//
//public class Employee {
//
//    private String employeeId;
//    private String name;
//    private String email;
//    private String phone;
//    private String department;
//    private String designation;
//    private double salary;
//
//    public Employee(String employeeId,
//                    String name,
//                    String email,
//                    String phone,
//                    String department,
//                    String designation,
//                    double salary) {
//
//        this.employeeId = employeeId;
//        this.name = name;
//        this.email = email;
//        this.phone = phone;
//        this.department = department;
//        this.designation = designation;
//        this.salary = salary;
//    }
//
//    public String getEmployeeId() {
//        return employeeId;
//    }
//
//    public String getName() {
//        return name;
//    }
//
//    public String getEmail() {
//        return email;
//    }
//
//    public String getPhone() {
//        return phone;
//    }
//
//    public String getDepartment() {
//        return department;
//    }
//
//    public String getDesignation() {
//        return designation;
//    }
//
//    public double getSalary() {
//        return salary;
//    }
//
//    public double getAnnualSalary() {
//        return salary * 12;
//    }
//}



package employe2;

public class Employee {

    private String employeeId;
    private String name;
    private String email;
    private String phone;
    private String department;
    private String designation;
    private double salary;

    public Employee(String employeeId,
                    String name,
                    String email,
                    String phone,
                    String department,
                    String designation,
                    double salary) {

        this.employeeId = employeeId;
        this.name = name;
        this.email = email;
        this.phone = phone;
        this.department = department;
        this.designation = designation;
        this.salary = salary;
    }

    public String getEmployeeId() {
        return employeeId;
    }

    public String getName() {
        return name;
    }

    public String getEmail() {
        return email;
    }

    public String getPhone() {
        return phone;
    }

    public String getDepartment() {
        return department;
    }

    public String getDesignation() {
        return designation;
    }

    public double getSalary() {
        return salary;
    }

    public double getAnnualSalary() {
        return salary * 12;
    }
}




